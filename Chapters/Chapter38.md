# 38. Headless platform fundamentals and lifetimes

Goal
- Run Avalonia apps without a windowing system so tests, previews, and automation can execute in CI.
- Configure headless lifetimes, services, and render loops to mimic production behaviour while remaining deterministic.
- Understand the knobs provided by `Avalonia.Headless` so you can toggle Skia rendering, timers, and focus/input handling on demand.

Why this matters
- Headless execution unlocks fast feedback loops: BDD/UI unit tests, snapshot rendering, and tooling all rely on it.
- CI agents rarely expose desktops or GPUs; the headless backend gives you a predictable environment across Windows, macOS, and Linux.
- Knowing the lifetimes and options ensures app startup mirrors real targets—preventing bugs that only appear when the full desktop lifetime runs.

Prerequisites
- Chapter 4 (startup and lifetimes) for the `AppBuilder` pipeline.
- Chapter 33 (code-first startup) for wiring services/resources without XAML.
- Chapter 21 (Headless and testing overview) for the bigger picture of test tooling.

## 1. Meet the headless platform

The headless backend lives in `external/Avalonia/src/Headless/Avalonia.Headless`. You enable it by calling `UseHeadless()` on `AppBuilder`.

```csharp
using Avalonia;
using Avalonia.Headless;
using Avalonia.Themes.Fluent;

public static class Program
{
    public static AppBuilder BuildAvaloniaApp(bool enableSkia = false)
        => AppBuilder.Configure<App>()
            .UseHeadless(new AvaloniaHeadlessPlatformOptions
            {
                UseHeadlessDrawing = !enableSkia,
                UseSkia = enableSkia,
                AllowEglInitialization = false,
                PreferDispatcherScheduling = true
            })
            .LogToTrace();
}
```

Key extension: `AvaloniaHeadlessAppBuilderExtensions.UseHeadless` registers platform services, render loop, and input plumbing. Options:
- `UseHeadlessDrawing`: if `true`, renders to an in-memory framebuffer without Skia.
- `UseSkia`: when `true`, create a Skia GPU context (requires `UseHeadlessDrawing = false`).
- `AllowEglInitialization`: opt-in to EGL for hardware acceleration when available.
- `PreferDispatcherScheduling`: ensures timers queue work via `Dispatcher` instead of busy loops.

Because `UseHeadless()` skips `UsePlatformDetect()`, call it explicitly in tests. For hybrid apps, provide a `BuildAvaloniaApp` overload that chooses headless vs. desktop based on environment.

## 2. Lifetimes built for tests

Headless apps use `HeadlessLifetime` (see `Avalonia.Headless/HeadlessLifetime.cs`). It mimics `IClassicDesktopStyleApplicationLifetime` but never opens OS windows.

```csharp
public sealed class TestApp : Application
{
    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is HeadlessLifetime lifetime)
        {
            lifetime.MainView = new MainView { DataContext = new MainViewModel() };
        }

        base.OnFrameworkInitializationCompleted();
    }
}
```

`HeadlessLifetime` exposes:
- `MainView`: root visual displayed inside the headless window implementation.
- `Start()`, `Stop()`: manual control for test harnesses.
- `Parameters`: mirrors command-line args.

You can also use `SingleViewLifetime` (`Avalonia.Controls/ApplicationLifetimes/ISingleViewApplicationLifetime.cs`) for mobile-like scenarios. Headless tests frequently wire both so code mirrors production flows.

### Switching lifetimes per environment

```csharp
var builder = Program.BuildAvaloniaApp(enableSkia: true);

if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux) && IsCiAgent)
{
    builder.SetupWithoutStarting();
    using var lifetime = new HeadlessLifetime();
    builder.Instance?.ApplicationLifetime = lifetime;
    lifetime.Start();
}
else
{
    builder.StartWithClassicDesktopLifetime(args);
}
```

`SetupWithoutStarting()` (from `AppBuilderBase`) initializes the app without running the run loop, allowing you to plug in custom lifetimes.

## 3. Headless application sessions for test frameworks

`HeadlessUnitTestSession` (source: `Avalonia.Headless/HeadlessUnitTestSession.cs`) coordinates app startup across tests so each fixture doesn’t rebuild the runtime.

### NUnit integration

`Avalonia.Headless.NUnit` ships attributes (`[AvaloniaTest]`, `[AvaloniaTheory]`) that wrap tests in a session. Example test fixture:

```csharp
[AvaloniaTest(Application = typeof(TestApp))]
public class CounterTests
{
    [Test]
    public void Clicking_increment_updates_label()
    {
        using var app = HeadlessUnitTestSession.Start<App>();
        var window = new MainWindow { DataContext = new MainViewModel() };
        window.Show();

        window.FindControl<Button>("IncrementButton")!.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));

        window.FindControl<TextBlock>("CounterLabel")!.Text.Should().Be("1");
    }
}
```

`HeadlessUnitTestSession.Start<TApp>()` spins up the shared app and dispatcher. `FindControl` works because the visual tree exists even though no OS window renders.

### xUnit integration

`Avalonia.Headless.XUnit` provides `[AvaloniaFact]` and `[AvaloniaTheory]` attributes. Decorate your test class with `[CollectionDefinition]` to ensure single app instance per collection when running in parallel.

## 4. Dispatcher, render loops, and timing

Headless rendering still uses Avalonia’s dispatcher and render loop. `HeadlessWindowImpl` (source: `Avalonia.Headless/HeadlessWindowImpl.cs`) implements `IWindowImpl` with an in-memory framebuffer. Understanding its behaviour is crucial for deterministic tests.

### Forcing layout/render ticks

Headless tests don’t run an infinite loop unless you start it. Use `AvaloniaHeadlessPlatform.ForceRenderTimerTick()` to advance timers manually.

```csharp
public static void RenderFrame(TopLevel topLevel)
{
    AvaloniaHeadlessPlatform.ForceRenderTimerTick();
    topLevel.RunJobsOnMainThread();
}
```

`RunJobsOnMainThread()` is a helper extension defined in `HeadlessWindowExtensions`. It drains pending dispatcher work and ensures layout/render happens before assertions.

### Simulating async work

Combine `Dispatcher.UIThread.InvokeAsync` with `ForceRenderTimerTick` to await UI updates:

```csharp
await Dispatcher.UIThread.InvokeAsync(() => viewModel.LoadAsync());
AvaloniaHeadlessPlatform.ForceRenderTimerTick();
```

In tests, call `Dispatcher.UIThread.RunJobs()` to flush pending tasks (extension in `Avalonia.Headless` as well).

## 5. Input, focus, and window services

`HeadlessWindowImpl` implements `IHeadlessWindow`, exposing methods to simulate input:

```csharp
var topLevel = new Window();
var headless = (IHeadlessWindow)topLevel.PlatformImpl!;

headless.MouseMove(new Point(50, 30), RawInputModifiers.None);
headless.MouseDown(new Point(50, 30), MouseButton.Left, RawInputModifiers.LeftMouseButton);
headless.MouseUp(new Point(50, 30), MouseButton.Left, RawInputModifiers.LeftMouseButton);
```

Use extension methods from `HeadlessWindowExtensions` (e.g., `Click(Point)`) to simplify. Focus management works: call `topLevel.Focus()` or `KeyboardDevice.Instance.SetFocusedElement`.

Services like storage providers or dialogs aren’t available by default. If your app depends on them, register test doubles in `Application.RegisterServices()`:

```csharp
protected override void RegisterServices()
{
    var services = AvaloniaLocator.CurrentMutable;
    services.Bind<IPlatformLifetimeEvents>().ToConstant(new TestLifetimeEvents());
    services.Bind<IClipboard>().ToSingleton<HeadlessClipboard>();
}
```

`Avalonia.Headless` already provides `HeadlessClipboard`, `HeadlessCursorFactory`, and other minimal implementations; inspect `Avalonia.Headless` folder for available services before writing your own.

## 6. Rendering options and Skia integration

By default headless renders via CPU copy. To generate bitmaps (Chapter 40), enable Skia:

```csharp
var builder = Program.BuildAvaloniaApp(enableSkia: true);
var options = AvaloniaLocator.Current.GetService<AvaloniaHeadlessPlatformOptions>();
```

When `UseSkia` is true, the backend creates a Skia surface per frame. Ensure the CI environment has the necessary native dependencies (`libSkiaSharp`). If you stick with `UseHeadlessDrawing = true`, `RenderTargetBitmap` still works but without GPU acceleration.

`HeadlessWindowExtensions.CaptureRenderedFrame(topLevel)` captures an `IBitmap` of the latest frame—use it for snapshot tests.

## 7. Troubleshooting common issues

- **App not initialized**: Ensure `AppBuilder.Configure<App>()` runs before calling `HeadlessUnitTestSession.Start`. Missing static constructor often stems from trimming or linking; mark entry point classes with `[assembly: RequiresUnreferencedCode]` if needed.
- **Dispatcher deadlocks**: Always schedule UI work via `Dispatcher.UIThread`. If a test blocks the UI thread, there’s no OS event loop to bail you out.
- **Missing services**: Headless backend only registers core services. Provide mocks for file dialogs, storage, or notifications.
- **Time-dependent tests**: When using timers, call `ForceRenderTimerTick` repeatedly or provide deterministic scheduler wrappers.
- **Memory leaks**: Dispose windows (`window.Close()`) and subscriptions (`CompositeDisposable`) after each test—headless sessions persist across multiple tests by default.

## 8. Practice lab

1. **Headless bootstrap** – Build a reusable `HeadlessTestApplication` that mirrors your production `App` styles/resources. Verify service registration via unit tests that resolve dependencies from `AvaloniaLocator`.
2. **Lifetime switcher** – Write a helper that starts your app with `HeadlessLifetime` when `DOTNET_RUNNING_IN_CONTAINER` is set. Assert via tests that both classic desktop and headless lifetimes share the same `OnFrameworkInitializationCompleted` flow.
3. **Deterministic render loop** – Create a headless fixture that mounts a view, updates the view-model, calls `ForceRenderTimerTick`, and asserts layout/visual changes with zero sleeps.
4. **Input harness** – Implement extensions wrapping `IHeadlessWindow` for click, drag, and keyboard simulation. Use them to test complex interactions (drag-to-reorder list) without real input devices.
5. **Service fallback** – Provide headless implementations for storage provider and clipboard, inject them in `RegisterServices`, and write tests asserting your UI handles success/failure cases.

Mastering the headless platform ensures Avalonia apps stay testable, portable, and CI-friendly. With lifetimes, options, and input surfaces under your control, you can script rich UI scenarios without ever opening an OS window.

What's next
- Next: [Chapter39](Chapter39.md)
