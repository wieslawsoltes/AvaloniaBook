# 28. Advanced input system and interactivity

Goal
- Coordinate pointer, keyboard, gamepad/remote, and text input so complex UI stays responsive.
- Build custom gestures and capture strategies that feel natural across mouse, touch, and pen.
- Keep advanced interactions accessible by mirroring behaviour across input modalities and IME scenarios.

Why this matters
- Modern apps must work with touch, pen, mouse, keyboard, remotes, and assistive tech simultaneously.
- Avalonia's input stack is highly extensible; understanding the pipeline prevents subtle bugs (ghost captures, lost focus, broken gestures).
- When you marry gestures with automation, you avoid excluding keyboard- or screen-reader-only users.

Prerequisites
- Chapter 9 (commands, events, and user input) for routed-event basics.
- Chapter 15 (accessibility) to validate keyboard/automation parity.
- Chapter 23 (custom controls) if you plan to surface bespoke surfaces that drive input directly.

## 1. How Avalonia routes input

Avalonia turns OS-specific events into a three-stage pipeline (`InputManager.ProcessInput`).

1. **Raw input** arrives as `RawInputEventArgs` (mouse, touch, pen, keyboard, gamepad). Each `IRenderRoot` has devices that call `Device.ProcessRawEvent`.
2. **Pre-process observers** (`InputManager.Instance?.PreProcess`) can inspect or cancel before routing. Use this sparingly for diagnostics, not business logic.
3. **Device routing** converts raw data into routed events (`PointerPressedEvent`, `KeyDownEvent`, `TextInputMethodClientRequestedEvent`).
4. **Process/PostProcess observers** see events after routing—handy for analytics or global shortcuts.

Because the input manager lives in `AvaloniaLocator`, you can temporarily subscribe:

```csharp
using IDisposable? sub = InputManager.Instance?
    .PreProcess.Subscribe(raw => _log.Debug("Raw input {Device} {Type}", raw.Device, raw.RoutedEvent));
```

Remember to dispose subscriptions; the pipeline never terminates while the app runs.

## 2. Pointer fundamentals and event order

`InputElement` exposes pointer events (bubble strategy by default).

| Event | Trigger | Key data |
| --- | --- | --- |
| `PointerEntered` / `PointerExited` | Pointer crosses hit-test boundary | `Pointer.Type`, `KeyModifiers`, `Pointer.IsPrimary` |
| `PointerPressed` | Button/contact press | `PointerUpdateKind`, `PointerPointProperties`, `ClickCount` in `PointerPressedEventArgs` |
| `PointerMoved` | Pointer moves while inside or captured | `GetPosition`, `GetIntermediatePoints` |
| `PointerWheelChanged` | Mouse wheel / precision scroll | `Vector delta`, `PointerPoint.Properties` |
| `PointerReleased` | Button/contact release | `Pointer.IsPrimary`, `Pointer.Captured` |
| `PointerCaptureLost` | Capture re-routed, element removed, or pointer disposed | `PointerCaptureLostEventArgs.Pointer` |

Event routing is tunable:

```csharp
protected override void OnInitialized()
{
    base.OnInitialized();
    AddHandler(PointerPressedEvent, OnPreviewPressed, handledEventsToo: true);
    AddHandler(PointerPressedEvent, OnPressed, routingStrategies: RoutingStrategies.Tunnel | RoutingStrategies.Bubble);
}
```

Use tunnel handlers (`RoutingStrategies.Tunnel`) for global shortcuts (e.g., closing flyouts). Keep bubbling logic per control.

### Working with pointer positions

- `e.GetPosition(this)` projects coordinates into any visual's space; pass `null` for top-level coordinates.
- `e.GetIntermediatePoints(this)` yields historical samples—crucial for smoothing freehand ink.
- `PointerPoint.Properties` exposes pressure, tilt, contact rectangles, and button states. Always verify availability (`Pointer.Type == PointerType.Pen` before reading pressure).

## 3. Pointer capture and lifetime handling

Capturing sends subsequent input to an element regardless of pointer location—vital for drags.

```csharp
protected override void OnPointerPressed(PointerPressedEventArgs e)
{
    if (e.Pointer.Type == PointerType.Touch)
    {
        e.Pointer.Capture(this);
        _dragStart = e.GetPosition(this);
        e.Handled = true;
    }
}

protected override void OnPointerReleased(PointerReleasedEventArgs e)
{
    if (ReferenceEquals(e.Pointer.Captured, this))
    {
        e.Pointer.Capture(null);
        CompleteDrag(e.GetPosition(this));
        e.Handled = true;
    }
}
```

Key rules:
- Always release capture (`Capture(null)`) on completion or cancellation.
- Watch `PointerCaptureLost`—it fires if the element leaves the tree or another control steals capture.
- Don't forget to handle the gesture recognizer case: if a recognizer captures the pointer, your control stops receiving `PointerMoved` events until capture returns.
- When chaining capture up the tree (`Control` → `Window`), consider `e.Pointer.Capture(this)` in the top-level to avoid anomalies when children are removed mid-gesture.

## 4. Multi-touch, pen, and high-precision data

Avalonia assigns unique IDs per contact (`Pointer.Id`) and marks a primary contact (`Pointer.IsPrimary`). Keep per-pointer state in a dictionary:

```csharp
private readonly Dictionary<int, PointerTracker> _active = new();

protected override void OnPointerPressed(PointerPressedEventArgs e)
{
    _active[e.Pointer.Id] = new PointerTracker(e.Pointer.Type, e.GetPosition(this));
    UpdateManipulation();
}

protected override void OnPointerReleased(PointerReleasedEventArgs e)
{
    _active.Remove(e.Pointer.Id);
    UpdateManipulation();
}
```

Pen-specific data lives in `PointerPoint.Properties`:

```csharp
var sample = e.GetCurrentPoint(this);
float pressure = sample.Properties.Pressure; // 0-1
bool isEraser = sample.Properties.IsEraser;
```

Touch sends a contact rectangle (`ContactRect`) you can use for palm rejection or handle-size aware UI.

## 5. Gesture recognizers in depth

Two gesture models coexist:

1. **Predefined routed events** in `Avalonia.Input.Gestures` (`Tapped`, `DoubleTapped`, `RightTapped`). Attach with `Gestures.AddDoubleTappedHandler` or `AddHandler`.
2. **Composable recognizers** (`InputElement.GestureRecognizers`) for continuous gestures (pinch, pull-to-refresh, scroll).

To attach built-in recognizers:

```csharp
GestureRecognizers.Add(new PinchGestureRecognizer
{
    // Your subclasses can expose properties via styled setters
});
```

Creating your own recognizer lets you coordinate multiple pointers and maintain internal state:

```csharp
public class PressAndHoldRecognizer : GestureRecognizer
{
    public static readonly RoutedEvent<RoutedEventArgs> PressAndHoldEvent =
        RoutedEvent.Register<InputElement, RoutedEventArgs>(
            nameof(PressAndHoldEvent), RoutingStrategies.Bubble);

    public TimeSpan Threshold { get; set; } = TimeSpan.FromMilliseconds(600);

    private CancellationTokenSource? _hold;
    private Point _pressOrigin;

    protected override async void PointerPressed(PointerPressedEventArgs e)
    {
        if (Target is not Visual visual)
            return;

        _pressOrigin = e.GetPosition(visual);
        Capture(e.Pointer);

        _hold = new CancellationTokenSource();
        try
        {
            await Task.Delay(Threshold, _hold.Token);
            Target?.RaiseEvent(new RoutedEventArgs(PressAndHoldEvent));
        }
        catch (TaskCanceledException)
        {
            // Swallow cancellation when pointer moves or releases early.
        }
    }

    protected override void PointerMoved(PointerEventArgs e)
    {
        if (Target is not Visual visual || _hold is null || _hold.IsCancellationRequested)
            return;

        var current = e.GetPosition(visual);
        if ((current - _pressOrigin).Length > 8)
            _hold.Cancel();
    }

    protected override void PointerReleased(PointerReleasedEventArgs e) => _hold?.Cancel();
    protected override void PointerCaptureLost(IPointer pointer) => _hold?.Cancel();
}
```

Register the routed event (`PressAndHoldEvent`) on your control and listen just like other events. Note the call to `Capture(e.Pointer)` which also calls `PreventGestureRecognition()` to stop competing recognizers.

## 6. Designing complex pointer experiences

Strategies for common scenarios:

- **Drag handles on templated controls:** capture the pointer in the handle `Thumb`, raise a routed `DragDelta` event, and update layout in response. Release capture in `PointerReleased` and `PointerCaptureLost`.
- **Drawing canvases:** store sampled points per pointer ID, use `GetIntermediatePoints` for smooth curves, and throttle invalidation with `DispatcherTimer` to keep the UI responsive.
- **Canvas panning + zooming:** differentiate gestures by pointer count—single pointer pans, two pointers feed `PinchGestureRecognizer` for zoom. Combine with `MatrixTransform` on the content.
- **Edge swipe or pull-to-refresh:** use `PullGestureRecognizer` with `PullDirection` to recognise deflection and expose progress to the view model.
- **Hover tooltips:** `PointerEntered` kicks off a timer, `PointerExited` cancels it; inspect `e.GetCurrentPoint(this).Properties.PointerUpdateKind` to ignore quick flicks.

## 7. Keyboard navigation, focus, and shortcuts

Avalonia's focus engine is pluggable.

- Each `TopLevel` exposes a `FocusManager` (via `(this.GetVisualRoot() as IInputRoot)?.FocusManager`) that drives tab order (`TabIndex`, `IsTabStop`).
- `IKeyboardNavigationHandler` orchestrates directional nav; register your own implementation before building the app, e.g. `AvaloniaLocator.CurrentMutable.Bind<IKeyboardNavigationHandler>().ToSingleton<CustomHandler>();`.
- `XYFocus` attached properties override directional targets for gamepad/remote scenarios:

```xml
<StackPanel
    input:XYFocus.Up="{Binding ElementName=SearchBox}"
    input:XYFocus.NavigationModes="Keyboard,Gamepad" />
```

Key bindings complement commands without requiring specific controls:

```csharp
KeyBindings.Add(new KeyBinding
{
    Gesture = new KeyGesture(Key.N, KeyModifiers.Control | KeyModifiers.Shift),
    Command = ViewModel.NewNoteCommand
});
```

`HotKeyManager` subscribes globally:

```csharp
HotKeyManager.SetHotKey(this, KeyGesture.Parse("F2"));
```

Ensure the target control implements `ICommandSource` or `IClickableControl`; Avalonia wires the gesture into the containing `TopLevel` and executes the command or raises `Click`.

Ensure focus cues remain visible: call `NavigationMethod.Tab` when moving focus programmatically so keyboard users see an adorner.

## 8. Gamepad, remote, and spatial focus

When Avalonia detects non-keyboard key devices, it sets `KeyDeviceType` on key events. Use `FocusManager.GetFocusManager(this)?.Focus(elem, NavigationMethod.Directional, modifiers)` to respect D-Pad navigation.

Configure XY focus per visual:

| Property | Purpose |
| --- | --- |
| `XYFocus.Up/Down/Left/Right` | Explicit neighbours when layout is irregular |
| `XYFocus.NavigationModes` | Enable keyboard, gamepad, remote individually |
| `XYFocus.LeftNavigationStrategy` | Choose default algorithm (closest edge, projection, navigation axis) |

For dense grids (e.g., TV apps), set `XYFocus.NavigationModes="Gamepad,Remote"` and assign explicit neighbours to avoid diagonal jumps. Pair with `KeyBindings` for shortcuts like `Back` or `Menu` buttons on controllers (map gamepad keys via key modifiers on the key event).

## 9. Text input services and IME integration

Text input flows through `InputMethod`, `TextInputMethodClient`, and `TextInputOptions`.

- `TextInputOptions` attached properties describe desired keyboard UI.
- `TextInputMethodClient` adapts a text view to IMEs (caret rectangle, surrounding text, reconversion).
- `InputMethod.GetIsInputMethodEnabled` lets you disable the IME for password fields.

Set options in XAML:

```xml
<TextBox
    Text=""
    input:TextInputOptions.ContentType="Email"
    input:TextInputOptions.ReturnKeyType="Send"
    input:TextInputOptions.ShowSuggestions="True"
    input:TextInputOptions.IsSensitive="False" />
```

When you implement custom text surfaces (code editors, chat bubbles):

1. Implement `TextInputMethodClient` to expose text range, caret rect, and surrounding text.
2. Handle `TextInputMethodClientRequested` in your control to supply the client.
3. Call `InputMethod.SetIsInputMethodEnabled(this, true)` and update the client's `TextViewVisual` so IME windows track the caret.
4. On geometry changes, raise `TextInputMethodClient.CursorRectangleChanged` so the backend updates composition windows.

Remember to honor `TextInputOptions.IsSensitive`—set it when editing secrets so onboard keyboards hide predictions.

## 10. Accessibility and multi-modal parity

Advanced interactions must fall back to keyboard and automation:

- Offer parallel commands (`KeyBindings`, buttons) for pointer-only gestures.
- When adding custom gestures, raise semantic routed events (e.g., `CopyRequested`) so automation peers can invoke them.
- Keep automation peers updated (`AutomationProperties.ControlType`, `AutomationProperties.IsControlElement`) when capture changes visual state.
- Respect `FocusManager` decisions—never suppress focus adorners merely because a pointer started the interaction.
- Use `InputMethod.SetIsInputMethodEnabled` and `TextInputOptions` to support assistive text input (switch control, dictation).

## 11. Multi-modal input lab (practice)

Create a playground that exercises every surface:

1. **Project setup**: scaffold `dotnet new avalonia.mvvm -n InputLab`. Add a `CanvasView` control hosting drawing, a side panel for logs, and a bottom toolbar.
2. **Pointer canvas**: capture touch/pen input, buffer points per pointer ID, and render trails using `DrawingContext.DrawGeometry`. Display pressure as stroke thickness.
3. **Custom gesture**: add the `PressAndHoldRecognizer` (above) to show context commands after 600 ms. Hook the resulting routed event to toggle a radial menu.
4. **Pinch & scroll**: attach `PinchGestureRecognizer` and `ScrollGestureRecognizer` to pan/zoom the canvas. Update a `MatrixTransform` as gesture delta arrives.
5. **Keyboard navigation**: define `KeyBindings` for `Ctrl+Z`, `Ctrl+Shift+Z`, and arrow-key panning. Update `XYFocus` properties so D-Pad moves between toolbar buttons.
6. **Gamepad test**: using a controller or emulator, verify focus flows across the UI. Log `KeyDeviceType` in `KeyDown` to confirm Avalonia recognises it as Gamepad.
7. **IME sandbox**: place a chat-style `TextBox` with `TextInputOptions.ReturnKeyType="Send"`, plus a custom `MentionTextBox` implementing `TextInputMethodClient` to surface inline completions.
8. **Accessibility pass**: ensure every action has a keyboard alternative, set automation names on dynamically created controls, and test the capture cycle with screen reader cursor.
9. **Diagnostics**: subscribe to `InputManager.Instance?.Process` and log pointer ID, update kind, and capture target into a side list for debugging.

Document findings in README (which gestures compete, how capture behaves on focus loss) so the team can adjust default UX.

## 12. Troubleshooting & best practices

- **Missing pointer events**: ensure `IsHitTestVisible` is true and that no transparent sibling intercepts input. For overlays, set `IsHitTestVisible="False"`.
- **Stuck capture**: always release capture during `PointerCaptureLost` and when the control unloads. Wrap capture in `try/finally` on operations that may throw.
- **Gesture conflicts**: call `e.PreventGestureRecognition()` when manual pointer logic should trump recognizers—or avoid attaching recognizers to nested elements.
- **High-DPI offsets**: convert to screen coordinates using `Visual.PointToScreen` when working across popups; pointer positions are per-visual, not global.
- **Keyboard focus lost after drag**: store `(this.GetVisualRoot() as IInputRoot)?.FocusManager?.GetFocusedElement()` before capture and restore it when the operation completes to preserve keyboard flow.
- **IME composition rectangles misplaced**: update `TextInputMethodClient.TextViewVisual` whenever layout changes; failing to do so leaves composition windows floating in the old position.

## Look under the hood (source bookmarks)
- Pointer lifecycle: [`Pointer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/Pointer.cs)
- Pointer events & properties: [`PointerEventArgs.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/PointerEventArgs.cs), [`PointerPoint.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/PointerPoint.cs)
- Gesture infrastructure: [`GestureRecognizer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/GestureRecognizers/GestureRecognizer.cs), [`Gestures.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/Gestures.cs)
- Keyboard & XY navigation: [`IKeyboardNavigationHandler.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/IKeyboardNavigationHandler.cs), [`XYFocus.Properties.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/Navigation/XYFocus.Properties.cs)
- Text input pipeline: [`TextInputOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputOptions.cs), [`TextInputMethodManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/InputMethodManager.cs)
- Input manager stages: [`InputManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/InputManager.cs)

## Check yourself
- How do tunnelling handlers differ from bubbling handlers when mixing pointer capture and gestures?
- Which `PointerPointProperties` matter for pen input and how do you guard against unsupported platforms?
- What steps are required to surface a custom `TextInputMethodClient` in your control?
- How can you ensure a drag interaction remains keyboard-accessible?
- When would you replace the default `IKeyboardNavigationHandler`?

What's next
- Next: [Chapter29](Chapter29.md)
