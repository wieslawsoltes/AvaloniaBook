# 21. Headless and testing

Goal
- Test Avalonia UI components without a display server using `Avalonia.Headless` (`AvaloniaHeadlessPlatformExtensions.UseHeadless`).
- Simulate user input, capture rendered frames, and integrate UI tests into CI (xUnit, NUnit, other frameworks).
- Organize your test strategy: view models, control-level tests, visual regression, automation, fast feedback.

Why this matters
- UI you can't test will regress. Headless testing runs anywhere (CI, Docker) and stays deterministic.
- Automated UI tests catch regressions in bindings, styles, commands, and layout quickly.

Prerequisites
- Chapter 11 (MVVM patterns), Chapter 17 (async patterns), Chapter 16 (storage) for file-based assertions.

## 1. Packages and setup

Add packages to your test project:
- `Avalonia.Headless`
- `Avalonia.Headless.XUnit` or `Avalonia.Headless.NUnit`
- `Avalonia.Skia` (only if you need rendered frames)

### xUnit setup (`AssemblyInfo.cs`)

```csharp
using Avalonia;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;

[assembly: AvaloniaTestApplication(typeof(TestApp))]

public sealed class TestApp : Application
{
    public static AppBuilder BuildAvaloniaApp() => AppBuilder.Configure<TestApp>()
        .UseHeadless(new AvaloniaHeadlessPlatformOptions
        {
            UseHeadlessDrawing = true, // set false + UseSkia for frame capture
            UseCpuDisabledRenderLoop = true
        })
        .AfterSetup(_ => Dispatcher.UIThread.VerifyAccess());
}
```

`UseHeadlessDrawing = true` skips Skia (fast). For pixel tests, set false and call `.UseSkia()`.

### NUnit setup

Use `[AvaloniaTestApp]` attribute (from `Avalonia.Headless.NUnit`) and the provided `AvaloniaTestFixture` base.

## 2. Writing a simple headless test

```csharp
public class TextBoxTests
{
    [AvaloniaFact]
    public async Task TextBox_Receives_Typed_Text()
    {
        var textBox = new TextBox { Width = 200, Height = 24 };
        var window = new Window { Content = textBox };
        window.Show();

        // Focus on UI thread
        await Dispatcher.UIThread.InvokeAsync(() => textBox.Focus());

        window.KeyTextInput("Avalonia");
        AvaloniaHeadlessPlatform.ForceRenderTimerTick();

        Assert.Equal("Avalonia", textBox.Text);
    }
}
```

Helpers from `Avalonia.Headless` add extension methods to `TopLevel`/`Window` (`KeyTextInput`, `KeyPress`, `MouseDown`, etc.). Always call `ForceRenderTimerTick()` after inputs to flush layout/bindings.

## 3. Simulating pointer input

```csharp
[ AvaloniaFact ]
public async Task Button_Click_Executes_Command()
{
    var commandExecuted = false;
    var button = new Button
    {
        Width = 100,
        Height = 30,
        Content = "Click me",
        Command = ReactiveCommand.Create(() => commandExecuted = true)
    };

    var window = new Window { Content = button };
    window.Show();

    await Dispatcher.UIThread.InvokeAsync(() => button.Focus());
    window.MouseDown(button.Bounds.Center, MouseButton.Left);
    window.MouseUp(button.Bounds.Center, MouseButton.Left);
    AvaloniaHeadlessPlatform.ForceRenderTimerTick();

    Assert.True(commandExecuted);
}
```

`Bounds.Center` obtains center point from `Control.Bounds`. For container-based coordinates, offset appropriately.

## 4. Frame capture & visual regression

Configure Skia rendering in test app builder:

```csharp
public static AppBuilder BuildAvaloniaApp() => AppBuilder.Configure<TestApp>()
    .UseSkia()
    .UseHeadless(new AvaloniaHeadlessPlatformOptions
    {
        UseHeadlessDrawing = false,
        UseCpuDisabledRenderLoop = true
    });
```

Capture frames:

```csharp
[ AvaloniaFact ]
public void Border_Renders_Correct_Size()
{
    var border = new Border
    {
        Width = 200,
        Height = 100,
        Background = Brushes.Red
    };

    var window = new Window { Content = border };
    window.Show();
    AvaloniaHeadlessPlatform.ForceRenderTimerTick();

    using var frame = window.GetLastRenderedFrame();
    Assert.Equal(200, frame.Size.Width);
    Assert.Equal(100, frame.Size.Height);

    // Optional: save to disk for debugging
    // frame.Save("border.png");
}
```

Compare pixels to baseline image using e.g., `ImageMagick` or custom diff with tolerance. Keep baselines per theme/resolution to avoid false positives.

If you need Avalonia to drive the render loop before reading pixels, call `CaptureRenderedFrame()` instead of `GetLastRenderedFrame()`—it schedules a composition pass and forces a render tick. This mirrors what desktop renderers do when they flush the `CompositionTarget`, keeping the snapshot pipeline close to production.

## 5. Organizing tests

- **ViewModel tests**: no Avalonia dependencies; test commands and property changes (fastest).
- **Control tests**: headless platform; simulate inputs to verify states.
- **Visual regression**: limited number; capture frames and compare.
- **Integration/E2E**: run full app with navigation; keep few due to complexity.

## 6. Custom fixtures and automation hooks

- Build reusable fixtures around `HeadlessUnitTestSession.StartNew(typeof(App))` when you need deterministic startup logic outside the provided xUnit/NUnit attributes. Wrap it in `IAsyncLifetime` so tests share a dispatcher loop safely.
- Register platform services for tests inside the session by entering an `AvaloniaLocator` scope and injecting fakes (e.g., mock `IClipboard`, stub `IStorageProvider`).
- Expose convenience methods (e.g., `ShowControlAsync<TControl>()`) that create a `Window`, attach the control, call `ForceRenderTimerTick`, and return the control for assertions.
- For automation cues, use Avalonia's UI automation peers: call `AutomationPeer.CreatePeerForElement(control)` and assert patterns (`InvokePattern`, `ValuePattern`) without relying on visual tree traversal.
- Study the headless unit tests in `external/Avalonia/tests/Avalonia.Headless.UnitTests` for patterns that wrap `AppBuilder` and expose helpers for reuse across cases.

## 7. Advanced headless scenarios

### 7.1 VNC mode

For debugging, you can run headless with a VNC server and observe the UI.

```csharp
AppBuilder.Configure<App>()
    .UseHeadless(new AvaloniaHeadlessPlatformOptions { UseVnc = true, UseSkia = true })
    .StartWithClassicDesktopLifetime(args);
```

Connect with a VNC client to view frames and interact.

### 7.2 Simulating time & timers

Use `AvaloniaHeadlessPlatform.ForceRenderTimerTick()` to advance timers. For `DispatcherTimer` or animations, call it repeatedly.

### 7.3 File system in tests

For file-based assertions, use in-memory streams or temp directories. Avoid writing to the repo path; tests should be self-cleaning.

## 8. Testing async flows

- Use `Dispatcher.UIThread.InvokeAsync` for UI updates.
- Await tasks; avoid `.Result` or `.Wait()`.
- To wait for state changes, poll with timeout:

```csharp
async Task WaitForAsync(Func<bool> condition, TimeSpan timeout)
{
    var deadline = DateTime.UtcNow + timeout;
    while (!condition())
    {
        if (DateTime.UtcNow > deadline)
            throw new TimeoutException("Condition not met");
        AvaloniaHeadlessPlatform.ForceRenderTimerTick();
        await Task.Delay(10);
    }
}
```

## 9. CI integration

- Headless tests run under `dotnet test` in GitHub Actions/Azure Pipelines/GitLab.
- On Linux CI, no display server required (no `Xvfb`).
- Provide environment variables or test-specific configuration as needed.
- Collect snapshots as build artifacts when tests fail (optional).

## 10. Practice exercises

1. Write a headless test that types into a TextBox, presses Enter, and asserts a command executed.
2. Simulate a drag-and-drop using `DragDrop` helpers and confirm target list received data.
3. Capture a frame of an entire form and compare to a baseline image stored under `tests/BaselineImages`.
4. Create a test fixture that launches the app's main view, navigates to a secondary page, and verifies a label text.
5. Add headless tests to CI and configure the pipeline to upload snapshot diffs for failing cases.
6. Write an automation-focused test that inspects `AutomationPeer` patterns (Invoke/Value) to validate accessibility contracts alongside visual assertions.

## Look under the hood (source bookmarks)
- Headless platform setup: [`AvaloniaHeadlessPlatform.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Headless/Avalonia.Headless/AvaloniaHeadlessPlatform.cs)
- Session control: [`HeadlessUnitTestSession.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Headless/Avalonia.Headless/HeadlessUnitTestSession.cs)
- Input helpers: [`HeadlessWindowExtensions`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Headless/Avalonia.Headless/HeadlessWindowExtensions.cs)
- Test adapters: [`Avalonia.Headless.XUnit`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Headless/Avalonia.Headless.XUnit), [`Avalonia.Headless.NUnit`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Headless/Avalonia.Headless.NUnit)
- Samples: [`tests/Avalonia.Headless.UnitTests`](https://github.com/AvaloniaUI/Avalonia/tree/master/tests/Avalonia.Headless.UnitTests), [`tests/Avalonia.Headless.XUnit.UnitTests`](https://github.com/AvaloniaUI/Avalonia/tree/master/tests/Avalonia.Headless.XUnit.UnitTests)

## Check yourself
- How do you initialize the headless platform for xUnit? Which attribute is required?
- How do you simulate keyboard and pointer input in headless tests?
- What steps are needed to capture rendered frames? Why might you use them sparingly?
- How can you run the headless platform visually (e.g., via VNC) for debugging?
- How does your test strategy balance view model tests, control tests, and visual regression tests?
- When would you reach for AutomationPeers in headless tests instead of asserting on visuals alone?

What's next
- Next: [Chapter 22](Chapter22.md)
