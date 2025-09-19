# 41. Simulating input and automation in headless runs

Goal
- Drive Avalonia UI interactions programmatically inside headless tests, mirroring real user gestures.
- Coordinate keyboard, pointer, and text input events through `HeadlessWindowExtensions` so focus and routing behave exactly as on desktop.
- Assert downstream automation effects—commands, behaviors, drag/drop—without launching OS-level windows.

Why this matters
- Interactive flows (menus, drag handles, keyboard shortcuts) break easily if you only test bindings or view-models; simulated input keeps coverage honest.
- CI agents lack real hardware. The headless platform proxies devices so you can rehearse full user journeys deterministically.
- Automation/UIP frameworks often rely on routed events and focus transitions; reproducing them in tests prevents last-minute surprises.

Prerequisites
- Chapter 38 for headless dispatcher control and platform options.
- Chapter 39 for integrating Avalonia’s headless test attributes in xUnit or NUnit.
- Chapter 40 if you plan to pair input simulation with pixel verification.

## 1. Meet the headless input surface

Every headless `TopLevel` implements `IHeadlessWindow` (`external/Avalonia/src/Headless/Avalonia.Headless/IHeadlessWindow.cs:7`), exposing methods for keyboard, pointer, wheel, and drag/drop events. `HeadlessWindowExtensions` (`external/Avalonia/src/Headless/Avalonia.Headless/HeadlessWindowExtensions.cs:20`) wraps those APIs, handling dispatcher ticks before and after each gesture so routed events fire on time.

```csharp
var window = new Window { Content = new Button { Content = "Click me" } };
window.Show();

window.MouseMove(new Point(20, 20));
window.MouseDown(new Point(20, 20), MouseButton.Left);
window.MouseUp(new Point(20, 20), MouseButton.Left);
```

Under the hood the extension flushes outstanding work (`Dispatcher.UIThread.RunJobs()`), triggers the render timer (`AvaloniaHeadlessPlatform.ForceRenderTimerTick()`), invokes the requested gesture on the `IHeadlessWindow`, and drains the dispatcher again. This ensures property changes, focus updates, and automation events complete before your assertions run.

## 2. Keyboard and text input

`HeadlessWindowExtensions` provides multiple helpers for synthesizing key strokes:

- `KeyPress`/`KeyRelease` accept logical `Key` values plus `RawInputModifiers`.
- `KeyPressQwerty`/`KeyReleaseQwerty` map physical scan codes to logical keys using a QWERTY layout.
- `KeyTextInput` sends text composition events directly to controls that listen for `TextInput`.

```csharp
var textBox = new TextBox { AcceptsReturn = true };
var window = new Window { Content = textBox };
window.Show();
textBox.Focus();

window.KeyPressQwerty(PhysicalKey.KeyH, RawInputModifiers.Shift);
window.KeyPressQwerty(PhysicalKey.KeyI, RawInputModifiers.None);
window.KeyReleaseQwerty(PhysicalKey.Enter, RawInputModifiers.None);
window.KeyTextInput("!");

textBox.Text.Should().Be("Hi!\n");
```

Avalonia routes the events through `KeyboardDevice` so controls experience the same bubbling/tunneling as in production. Remember to set focus explicitly (`textBox.Focus()` or `KeyboardDevice.Instance.SetFocusedElement`) before typing—headless windows do not auto-focus when shown.

## 3. Pointer gestures and drag/drop

Mouse helpers cover move, button transitions, wheel scrolling, and drag/drop scenarios. The headless platform maintains a single virtual pointer (`HeadlessWindowImpl` uses `PointerDevice`, see `external/Avalonia/src/Headless/Avalonia.Headless/HeadlessWindowImpl.cs:34`).

```csharp
var listBox = new ListBox
{
    ItemsSource = new[] { "Alpha", "Beta", "Gamma" }
};
var window = new Window { Content = listBox };
window.Show();

// Click first item
window.MouseMove(new Point(10, 20));
window.MouseDown(new Point(10, 20), MouseButton.Left);
window.MouseUp(new Point(10, 20), MouseButton.Left);
listBox.SelectedIndex.Should().Be(0);

// Scroll down
window.MouseWheel(new Point(10, 20), new Vector(0, -120));
```

For drag/drop, build a `DataObject` and send a sequence of drag events:

```csharp
var data = new DataObject();
data.Set(DataFormats.Text, "payload");
window.DragDrop(new Point(10, 20), RawDragEventType.DragEnter, data, DragDropEffects.Copy);
window.DragDrop(new Point(80, 40), RawDragEventType.DragOver, data, DragDropEffects.Copy);
window.DragDrop(new Point(80, 40), RawDragEventType.Drop, data, DragDropEffects.Copy);
```

Your controls will receive `DragEventArgs`, invoke drop handlers, and update view-models just as they would with real user input.

## 4. Focus, capture, and multi-step workflows

Headless tests still rely on Avalonia’s focus and capture services:

- Call `control.Focus()` or `FocusManager.Instance.Focus(control)` before keyboard entry.
- Pointer capture happens automatically when a control handles `PointerPressed` and calls `e.Pointer.Capture(control)`. To assert capture, inspect `Pointer.Captured` inside your test after dispatching input.
- Release capture manually with `pointer.Capture(null)` when simulating complex gestures to avoid stale state.

Example: testing a custom drag handle that requires capture and modifier keys.

```csharp
[AvaloniaFact]
public void DragHandle_updates_offset()
{
    var handle = new DragHandleControl();
    var window = new Window { Content = handle };
    window.Show();

    window.MouseMove(new Point(5, 5));
    window.MouseDown(new Point(5, 5), MouseButton.Left, RawInputModifiers.LeftMouseButton);
    handle.PointerIsCaptured.Should().BeTrue();

    window.MouseMove(new Point(45, 5), RawInputModifiers.LeftMouseButton | RawInputModifiers.Shift);
    window.MouseUp(new Point(45, 5), MouseButton.Left);

    handle.Offset.Should().BeGreaterThan(0);
}
```

Because `HeadlessWindowExtensions` executes all gestures on the UI thread, your control can update dependency properties, trigger animations, and publish events synchronously within the test.

## 5. Compose higher-level automation helpers

Most suites wrap common interaction patterns in reusable functions to keep tests declarative:

```csharp
public sealed class HeadlessUser
{
    private readonly Window _window;
    public HeadlessUser(Window window) => _window = window;

    public void Click(Control control)
    {
        var point = control.TranslatePoint(new Point(control.Bounds.Width / 2, control.Bounds.Height / 2), _window) ?? default;
        _window.MouseMove(point);
        _window.MouseDown(point, MouseButton.Left);
        _window.MouseUp(point, MouseButton.Left);
    }

    public void Type(string text)
    {
        foreach (var ch in text)
            _window.KeyTextInput(ch.ToString());
    }
}
```

Pair these helpers with assertions against `AutomationProperties` to verify accessibility metadata as you drive the UI. Tests in `external/Avalonia/tests/Avalonia.Headless.UnitTests/InputTests.cs:29` demonstrate structuring fixtures that open a window in `[SetUp]`/constructor, execute gestures, and dispose deterministically.

## 6. Raw input modifiers and multiple devices

`RawInputModifiers` combines buttons, keyboard modifiers, and touch states into a single bit field. Use it to emulate complex shortcuts:

```csharp
window.MouseDown(point, MouseButton.Left, RawInputModifiers.LeftMouseButton | RawInputModifiers.Control);
window.KeyPress(Key.S, RawInputModifiers.Control, PhysicalKey.KeyS, "s");
```

Headless currently exposes a single mouse pointer and keyboard. To simulate multi-pointer scenarios (e.g., pinch gestures), create custom `RawPointerEventArgs` and push them through `InputManager.Instance.ProcessInput`. That advanced path uses `IInputRoot.Input` (hook available via `HeadlessWindowImpl.Input`), giving you full control when default helpers are insufficient.

## 7. Troubleshooting

- **No events firing** – confirm you called `window.Show()` and that the target control is in the visual tree. Without showing, the platform impl doesn’t attach an `InputRoot`.
- **Focus lost between gestures** – check whether your control closes popups or dialogs. Re-focus before continuing or assert against `FocusManager.Instance.Current`.
- **Pointer coordinates off** – convert control-relative coordinates to window coordinates (`TranslatePoint`) and double-check logical vs. visual point units (headless always uses logical units, scaling = 1 unless you override).
- **Keyboard text missing** – some controls ignore `KeyTextInput` without focus or when `AcceptsReturn` is false. Set the right properties or use `TextInputOptions` when testing IME handling (`external/Avalonia/src/Avalonia.Base/Input/TextInput/TextInputOptions.cs`).
- **Drag/drop crashes** – make sure Skia is enabled for capture-heavy tests and that you dispose `DataObject` content streams after the drop completes.

## Practice lab

1. **User DSL** – Build a `HeadlessUser` helper that supports click, double-click, context menu, typing, and modifier-aware shortcuts. Use it to script multi-page navigation flows.
2. **Pointer capture assertions** – Write a test that verifies a custom canvas captures the pointer during drawing and releases it when `PointerReleased` fires, asserting against `Pointer.Captured`.
3. **Keyboard navigation** – Simulate `Tab`/`Shift+Tab` sequences across a dialog and assert `FocusManager.Instance.Current` to ensure accessibility order is correct.
4. **Drag/drop harness** – Create reusable helpers for `DragEnter`/`DragOver`/`Drop` with specific `IDataObject` payloads. Verify your view-model receives the right data and that effects (`DragDropEffects`) match expectations.
5. **IME/text services** – Toggle `TextInputOptions` on a `TextBox`, send mixed `KeyPress` and `KeyTextInput` events, and confirm composition events surface in your view-model for languages requiring IME support.

What's next
- Next: [Chapter42](Chapter42.md)
