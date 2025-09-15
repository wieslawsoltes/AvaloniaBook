# 4. Application startup: AppBuilder and lifetimes

Goal
- Understand how an Avalonia app starts and what AppBuilder configures.
- Learn the difference between desktop (multi-window) and single-view lifetimes.
- Hook up MainWindow for desktop and MainView for single‑view.

Why this matters
- Startup and lifetimes decide how your app is created and how windows/views are shown.
- Getting this right early saves confusion when you target desktop, mobile, and browser later.

Prerequisites
- You can create and run a new Avalonia app (from Chapter 2).

Mental model
- AppBuilder configures Avalonia (platform backend, renderer, logging, optional libraries like ReactiveUI).
- A lifetime drives the app’s main loop and surface(s):
  - ClassicDesktopStyleApplicationLifetime = desktop windowed apps (Windows/macOS/Linux).
  - SingleViewApplicationLifetime = single-view apps (Android/iOS/Browser, often one root view).

Step-by-step
1) Inspect Program.cs
- Open Program.cs in a new app and you’ll usually see:

```csharp
using Avalonia;
using System;

class Program
{
    public static void Main(string[] args) => BuildAvaloniaApp()
        .StartWithClassicDesktopLifetime(args); // Desktop lifetime entry

    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()   // Pick platform backends (Win32, macOS, X11, Android, iOS, Browser)
            .UseSkia()             // Use Skia renderer (CPU/GPU)
            .LogToTrace();
}
```

- UsePlatformDetect chooses the right platform backends at runtime.
- UseSkia selects Skia as the rendering engine.
- StartWithClassicDesktopLifetime wires the desktop-specific lifetime and passes command‑line args.

2) Wire windows/views in App.axaml.cs
- Open App.axaml.cs and find OnFrameworkInitializationCompleted. Make sure it handles both lifetimes:

```csharp
using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;

public partial class App : Application
{
    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow = new MainWindow(); // Your primary window for desktop apps
        }
        else if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            singleView.MainView = new MainView(); // Your root view for mobile/browser
        }

        base.OnFrameworkInitializationCompleted();
    }
}
```

- Desktop lifetime expects a window; single‑view expects a single root control.
- You can share most app code and choose at runtime based on the actual lifetime.

3) Try single‑view with a basic MainView
- Add a view (MainView.axaml) with a simple layout and set singleView.MainView = new MainView().
- Running on desktop still uses the desktop lifetime (MainWindow). On mobile/browser targets, the single‑view branch is used.

4) Options and add‑ons
- Logging: .LogToTrace() is helpful while developing.
- ReactiveUI: add .UseReactiveUI() when you adopt ReactiveUI in later chapters.
- Renderer and platform options can be customized later (e.g., Skia options), but defaults work well to start.

Check yourself
- Can you explain what BuildAvaloniaApp() returns and where it’s used?
- Where would you put code that must run before showing the first window/view?
- What changes between desktop and single‑view in OnFrameworkInitializationCompleted?

Look under the hood (optional)
- AppBuilder desktop helpers: [Avalonia.Desktop/AppBuilderDesktopExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs)
- Classic desktop lifetime: [Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs)
- Single‑view lifetime interface: [Avalonia.Controls/ApplicationLifetimes/ISingleViewApplicationLifetime.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/ISingleViewApplicationLifetime.cs)

Extra practice
- Add a command‑line flag (e.g., --no-main) and skip creating MainWindow when present.
- For single‑view, replace MainView with a view containing a TabControl and confirm it appears on mobile/browser.
- Log which lifetime branch executed at startup and verify on different targets.

```tip
If your app doesn’t start on desktop, confirm you’re calling StartWithClassicDesktopLifetime(args) in Main.
```

What’s next
- Next: [Chapter 5](Chapter05.md)
