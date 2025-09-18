# 4. Application startup: AppBuilder and lifetimes

Goal
- Trace the full AppBuilder pipeline from `Program.Main` to the first window or view.
- Understand how each lifetime (`ClassicDesktopStyleApplicationLifetime`, `SingleViewApplicationLifetime`, `BrowserSingleViewLifetime`, `HeadlessApplicationLifetime`) boots and shuts down your app.
- Learn where to register services, logging, and global configuration before the UI appears.
- Handle startup exceptions gracefully and log early so failures are diagnosable.
- Prepare a project that can swap between desktop, mobile/browser, and headless test lifetimes.

Why this matters
- The startup path decides which platforms you can target and where dependency injection, logging, and configuration happen.
- Knowing the lifetime contracts keeps your code organised when you add secondary windows, mobile navigation, or browser shells later.
- Understanding the AppBuilder steps helps you debug platform issues (e.g., missing native dependencies or misconfigured rendering).

Prerequisites
- You have completed Chapter 2 and can build/run a template project.
- You are comfortable editing `Program.cs`, `App.axaml`, and `App.axaml.cs`.

## 1. Follow the AppBuilder pipeline step by step

`Program.cs` (or `Program.fs` in F#) is the entry point. A typical template looks like this:

```csharp
using Avalonia;
using Avalonia.ReactiveUI; // optional in ReactiveUI template

internal static class Program
{
    [STAThread]
    public static void Main(string[] args) => BuildAvaloniaApp()
        .StartWithClassicDesktopLifetime(args);

    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()       // 1. Choose your Application subclass
            .UsePlatformDetect()             // 2. Detect the right native backend (Win32, macOS, X11, Android, iOS, Browser)
            .UseSkia()                      // 3. Configure the rendering pipeline (Skia GPU/CPU renderer)
            .With(new SkiaOptions {         // 4. (Optional) tweak renderer settings
                MaxGpuResourceSizeBytes = 96 * 1024 * 1024
            })
            .LogToTrace()                   // 5. Hook logging before startup completes
            .UseReactiveUI();               // 6. (Optional) enable ReactiveUI integration
}
```

Each call returns the builder so you can chain configuration. Relevant source:
- `AppBuilder` implementation: [`src/Avalonia.Controls/AppBuilder.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/AppBuilder.cs)
- Skia configuration: [`src/Skia/Avalonia.Skia/SkiaOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Skia/Avalonia.Skia/SkiaOptions.cs)
- Desktop helpers (`StartWithClassicDesktopLifetime`): [`src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs)

### Builder pipeline diagram (mental map)
```
Program.Main
  `--- BuildAvaloniaApp()
        |-- Configure<App>()        (create Application instance)
        |-- UsePlatformDetect()     (choose backend)
        |-- UseSkia()/UseReactiveUI (features)
        |-- LogToTrace()/With(...)  (diagnostics/options)
        `-- StartWith...Lifetime()  (select lifetime and enter main loop)
```

If anything in the pipeline throws, the process exits before UI renders. Log early to catch those cases.

## 2. Lifetimes in detail

| Lifetime type | Purpose | Typical targets | Key members |
| --- | --- | --- | --- |
| `ClassicDesktopStyleApplicationLifetime` | Windowed desktop apps with startup/shutdown events and main window | Windows, macOS, Linux | `MainWindow`, `ShutdownMode`, `Exit`, `OnExit` |
| `SingleViewApplicationLifetime` | Hosts a single root control (`MainView`) | Android, iOS, Embedded | `MainView`, `MainViewClosing`, `OnMainViewClosed` |
| `BrowserSingleViewLifetime` (implements `ISingleViewApplicationLifetime`) | Same contract as single view, tuned for WebAssembly | Browser (WASM) | `MainView`, async app init |
| `HeadlessApplicationLifetime` | No visible UI; runs for tests or background services | Unit/UI tests | `TryGetTopLevel()`, manual pumping |

Key interfaces and classes to read:
- Desktop lifetime: [`ClassicDesktopStyleApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs)
- Single view lifetime: [`SingleViewApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/SingleViewApplicationLifetime.cs)
- Browser lifetime: [`BrowserSingleViewLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserSingleViewLifetime.cs)
- Headless lifetime: [`src/Headless/Avalonia.Headless/AvaloniaHeadlessApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Headless/Avalonia.Headless/AvaloniaHeadlessApplicationLifetime.cs)

## 3. Wiring lifetimes in `App.OnFrameworkInitializationCompleted`

`App.axaml.cs` is the right place to react once the framework is ready:

```csharp
using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Microsoft.Extensions.DependencyInjection; // if using DI

namespace MultiLifetimeSample;

public partial class App : Application
{
    private IServiceProvider? _services;

    public override void Initialize()
        => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        // Create/register services only once
        _services ??= ConfigureServices();

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var shell = _services.GetRequiredService<MainWindow>();
            desktop.MainWindow = shell;
            desktop.Exit += (_, _) => _services.Dispose();
        }
        else if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            singleView.MainView = _services.GetRequiredService<MainView>();
        }
        else if (ApplicationLifetime is IControlledApplicationLifetime controlled)
        {
            controlled.Exit += (_, _) => Console.WriteLine("Application exited");
        }

        base.OnFrameworkInitializationCompleted();
    }

    private IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();
        services.AddSingleton<MainWindow>();
        services.AddSingleton<MainView>();
        services.AddSingleton<DashboardViewModel>();
        services.AddLogging(builder => builder.AddDebug());
        return services.BuildServiceProvider();
    }
}
```

Notes:
- `ApplicationLifetime` always implements `IControlledApplicationLifetime`, so you can subscribe to `Exit` for cleanup even if you do not know the exact subtype.
- Use dependency injection (any container) to share views/view models. Avalonia does not ship a DI container, so you control the lifetime.
- For headless tests, your `App` still runs but you typically return `SingleView` or host view models manually.

## 4. Handling exceptions and logging

Important logging points:
- `AppBuilder.LogToTrace()` uses Avalonia's logging infrastructure (see [`src/Avalonia.Base/Logging`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Logging)). For production apps, plug in `Serilog`, `Microsoft.Extensions.Logging`, or your preferred provider.
- Subscribe to `AppDomain.CurrentDomain.UnhandledException` and `TaskScheduler.UnobservedTaskException` inside `Main` to catch fatal issues before the dispatcher tears down.

Example:

```csharp
[STAThread]
public static void Main(string[] args)
{
    AppDomain.CurrentDomain.UnhandledException += (_, e) => LogFatal(e.ExceptionObject);
    TaskScheduler.UnobservedTaskException += (_, e) => LogFatal(e.Exception);

    try
    {
        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }
    catch (Exception ex)
    {
        LogFatal(ex);
        throw;
    }
}
```

`ClassicDesktopStyleApplicationLifetime` exposes `ShutdownMode` and `Shutdown()` so you can exit explicitly when critical failures occur.

## 5. Switching lifetimes inside one project

You can provide different entry points or compile-time switches:

```csharp
public static void Main(string[] args)
{
#if HEADLESS
    BuildAvaloniaApp().Start(AppMain);
#elif BROWSER
    BuildAvaloniaApp().SetupBrowserApp("app");
#else
    BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
#endif
}
```

- `SetupBrowserApp` is defined in [`BrowserAppBuilder.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserAppBuilder.cs) and attaches the app to a DOM element.
- `Start` (with `AppMain`) lets you provide your own lifetime, often used in headless/integration tests.

## 6. Headless/testing scenarios

Avalonia's headless assemblies let you boot an app without rendering:

```csharp
using Avalonia;
using Avalonia.Headless;

public static class Program
{
    public static void Main(string[] args)
        => BuildAvaloniaApp().StartWithHeadless(new HeadlessApplicationOptions
        {
            RenderingMode = HeadlessRenderingMode.None,
            UseHeadlessDrawingContext = true
        });
}
```

- `Avalonia.Headless` lives under [`src/Headless`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Headless) and powers automated UI tests (`Avalonia.Headless.XUnit`, `Avalonia.Headless.NUnit`).
- You can pump the dispatcher manually to run asynchronous UI logic in tests (`HeadlessUnitTestSession.Run` displays an example).

## 7. Putting it together: desktop + single-view sample

`Program.cs`:

```csharp
public static AppBuilder BuildAvaloniaApp() => AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .UseSkia()
    .LogToTrace();

[STAThread]
public static void Main(string[] args)
{
    if (args.Contains("--single-view"))
    {
        BuildAvaloniaApp().StartWithSingleViewLifetime(new MainView());
    }
    else
    {
        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }
}
```

`App.axaml.cs` sets up both `MainWindow` and `MainView` (as shown earlier). At runtime, you can switch lifetimes via command-line or compile condition.

## Troubleshooting
- **Black screen on startup**: check `UsePlatformDetect()`; on Linux you might need extra packages (mesa, libwebkit) or use `UseSkia` explicitly.
- **No window appearing**: ensure `desktop.MainWindow` is assigned before calling `base.OnFrameworkInitializationCompleted()`.
- **Single view renders but inputs fail**: confirm you used the right lifetime (`StartWithSingleViewLifetime`) and that your root view is a `Control` with focusable children.
- **DI container disposed too early**: if you `using` the provider, keep it alive for the app lifetime and dispose in `Exit`.
- **Unhandled exception after closing last window**: check `ShutdownMode`. Default is `OnLastWindowClose`; switch to `OnMainWindowClose` or call `Shutdown()` to exit on demand.

## Practice and validation
1. Modify your project so the same `App` supports both desktop and single-view lifetimes. Use a command-line switch (`--mobile`) to select `StartWithSingleViewLifetime` and verify your `MainView` renders inside a mobile head (Android emulator or `dotnet run -- --mobile` + `SingleView` desktop simulation).
2. Register a logging provider using `Microsoft.Extensions.Logging`. Log the current lifetime type inside `OnFrameworkInitializationCompleted` and observe the output.
3. Add a simple DI container (as shown) and resolve `MainWindow`/`MainView` through it. Confirm disposal happens when the app exits.
4. Create a headless console entry point (`BuildAvaloniaApp().Start(AppMain)`) and run a unit test that constructs a view, invokes bindings, and pumps the dispatcher.
5. Intentionally throw inside `OnFrameworkInitializationCompleted` and observe how logging captures the stack. Then add a `try/catch` to show a fallback dialog or log and exit gracefully.

## Look under the hood (source bookmarks)
- `AppBuilder` internals: [`src/Avalonia.Controls/AppBuilder.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/AppBuilder.cs)
- Desktop startup helpers: [`src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs)
- Desktop lifetime implementation: [`src/Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs)
- Single-view lifetime: [`src/Avalonia.Controls/ApplicationLifetimes/SingleViewApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/SingleViewApplicationLifetime.cs)
- Browser lifetime: [`src/Browser/Avalonia.Browser/BrowserSingleViewLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserSingleViewLifetime.cs)
- Headless lifetime and tests: [`src/Headless`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Headless)

## Check yourself
- What steps does `BuildAvaloniaApp()` perform before choosing a lifetime?
- Which lifetime would you use for Windows/macOS, Android/iOS, browser, and automated tests?
- Where should you place dependency injection setup and where should you dispose the container?
- How can you capture and log unhandled exceptions thrown during startup?
- How would you attach the app to a DOM element in a WebAssembly host?

What's next
- Next: [Chapter 5](Chapter05.md)
