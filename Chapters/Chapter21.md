# 21. Headless and testing

Goal
- Write fast, reliable UI tests that run on CI with no display server
- Simulate user input (keyboard/mouse) and verify UI behavior programmatically
- Capture and assert rendered frames for visual regression tests (optional)

Why this matters
UI you can’t test will regress. Avalonia’s headless platform lets you run your app and controls without a window manager, so tests run anywhere (including CI) and stay deterministic.

What “headless” means in Avalonia
- Headless is a special platform backend that implements windowing, input, and rendering without a real OS window.
- You can drive your UI programmatically and even capture frames for pixel tests.
- There are helpers for popular test frameworks (xUnit, NUnit) so you don’t write plumbing.

Quick start (xUnit): [Avalonia.Headless.XUnit]
1) Add test packages to your test project:
   - Avalonia.Headless
   - Avalonia.Headless.XUnit
   - Optionally Avalonia.Skia for Skia rendering when you need screenshots
2) Use the [AvaloniaFact] attribute to run a test on the Avalonia UI thread with a headless platform.

Example: a minimal UI interaction test

```csharp
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless; // Headless helpers + [AvaloniaFact]
using Avalonia.Threading;
using Xunit;

public class TextBoxTests
{
    private static AppBuilder BuildApp() => AppBuilder.Configure<App>()
        .UseHeadless(new Avalonia.Headless.AvaloniaHeadlessPlatformOptions
        {
            // For logic-only tests, keep this true (fast, no Skia); for screenshot tests set to false and also call UseSkia.
            UseHeadlessDrawing = true
        })
        .AfterSetup(_ => { /* put global test services if needed */ });

    [AvaloniaFact]
    public async Task TextBox_Receives_Typed_Text()
    {
        BuildApp();

        var textBox = new TextBox { Width = 200, Height = 30 };
        var window = new Window { Content = textBox };
        window.Show();

        // Focus and type via headless helpers
        await Dispatcher.UIThread.InvokeAsync(() => textBox.Focus());
        window.KeyPress(Key.A, RawInputModifiers.Control, PhysicalKey.A, ""); // Ctrl+A (select all)
        window.TextInput("Hello");

        // Let layout/rendering advance one tick
        Avalonia.Headless.AvaloniaHeadlessPlatform.ForceRenderTimerTick();

        Assert.Equal("Hello", textBox.Text);
    }
}
```

Notes
- BuildApp(): In test assemblies, the Headless runner auto-starts a session; you can configure extra services via AppBuilder as needed.
- Input helpers: After `using Avalonia.Headless;`, extension methods like `KeyPress`, `KeyRelease`, `TextInput`, `MouseDown`, `MouseMove`, `MouseUp`, `MouseWheel`, and `DragDrop` are available on TopLevel/Window.
- Rendering tick: Use `AvaloniaHeadlessPlatform.ForceRenderTimerTick()` to advance timers and trigger layout/render when needed.

Capturing rendered frames (visual regression)
To capture frames you must render with Skia and disable headless drawing:
- Call UseSkia() during setup
- Pass UseHeadlessDrawing = false when using UseHeadless
- Then use GetLastRenderedFrame() from HeadlessWindowExtensions

Example: capture a frame and assert size

```csharp
using Avalonia;
using Avalonia.Controls;
using Avalonia.Headless;
using Xunit;

public class SnapshotTests
{
    private static AppBuilder BuildApp() => AppBuilder.Configure<App>()
        .UseSkia() // enable Skia
        .UseHeadless(new Avalonia.Headless.AvaloniaHeadlessPlatformOptions { UseHeadlessDrawing = false });

    [AvaloniaFact]
    public void Window_Renders_Frame()
    {
        BuildApp();
        var window = new Window { Width = 300, Height = 200, Content = new Button { Content = "Click" } };
        window.Show();

        // Make sure a render tick happens
        AvaloniaHeadlessPlatform.ForceRenderTimerTick();

        using var frame = window.GetLastRenderedFrame();
        Assert.NotNull(frame);
        Assert.Equal(300, frame.Size.Width);
        Assert.Equal(200, frame.Size.Height);
    }
}
```

Tip: You can persist frames to disk for debugging when running locally; for CI, prefer comparing against a baseline image with a small tolerance. Keep baselines per theme/DPI if relevant.

NUnit option
- Use Avalonia.Headless.NUnit and the provided attributes/utilities (AvaloniaTheory, test wrappers) to initialize a HeadlessUnitTestSession for your assembly.
- The patterns mirror xUnit; prefer your team’s test framework.

Driving complex interactions
- Pointer/mouse: `MouseDown(point, button, modifiers)`, `MouseMove(point, modifiers)`, `MouseUp(point, modifiers)`
- Keyboard: `KeyPress`, `KeyRelease`, `TextInput`
- Drag and drop: `DragDrop(point, type, data, effects, modifiers)`
- Always focus the control first, and advance one tick afterward to flush input effects: `Focus()`, then `ForceRenderTimerTick()`

Dispatcher and async work in tests
- Use `Dispatcher.UIThread.InvokeAsync` to execute code on the UI thread.
- Use `await Task.Yield()` and a render tick to allow bindings and layout to settle.
- Avoid unbounded waits; if you poll for a condition, cap attempts and fail with a helpful message.

Headless VNC (debug a headless app visually)
- For app-level diagnostics (not typical for unit tests), you can run the Headless VNC platform and connect with a VNC client to see frames.
- See ControlCatalog sample: it supports `--vnc`/`--full-headless` switches and uses `StartWithHeadlessVncPlatform(...)` to boot an app with a VNC framebuffer.

What to test where
- ViewModels: test without any Avalonia dependency (fastest); verify commands, properties, validation.
- Controls/Views: use headless tests to simulate input and verify behavior/visuals.
- Integration flows: a few end-to-end headless tests are valuable; keep them focused to avoid flakiness.

Troubleshooting
- “TopLevel must be a headless window.”: Ensure tests initialize the headless platform (UseHeadless) and that the TopLevel is created after setup.
- “Frame is null” or empty: Call UseSkia + set UseHeadlessDrawing=false and ensure you tick the render timer.
- Input does nothing: Ensure the control has focus and a render tick occurs after the simulated input.
- Hanging tests: Never block the UI thread; prefer InvokeAsync + short waits and ticks.

Exercise
1) Write a test that types “Avalonia” into a TextBox via `TextInput` and asserts the text.
2) Add a Button with a command bound to a ViewModel; simulate a `MouseDown`/`MouseUp` to click it and assert the command executed.
3) Create a snapshot test that captures the frame of a 200×100 Border with a red background; assert the bitmap size and optionally compare with a baseline image.

Look under the hood
- Headless platform entry: [AvaloniaHeadlessPlatform](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Headless/Avalonia.Headless/AvaloniaHeadlessPlatform.cs)
- Rendering interface (headless stubs): [HeadlessPlatformRenderInterface.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Headless/Avalonia.Headless/HeadlessPlatformRenderInterface.cs)
- Simulated input and frame capture: [HeadlessWindowExtensions](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Headless/Avalonia.Headless/HeadlessWindowExtensions.cs)
- xUnit integration: [Avalonia.Headless.XUnit](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Headless/Avalonia.Headless.XUnit)
- NUnit integration: [Avalonia.Headless.NUnit](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Headless/Avalonia.Headless.NUnit)
- ControlCatalog example switches (VNC/headless): [ControlCatalog.NetCore/Program.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/samples/ControlCatalog.NetCore/Program.cs)

What’s next
- Next: [Chapter 22](Chapter22.md)
