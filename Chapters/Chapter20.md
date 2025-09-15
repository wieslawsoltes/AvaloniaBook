# 20. Browser (WebAssembly) target

Goal
- Build and run your Avalonia app in the browser using WebAssembly
- Understand startup with StartBrowserAppAsync and the single-view lifetime
- Choose rendering modes (WebGL2/WebGL1/Software2D) and know web-specific limits

Why this matters
Running in the browser lets you reuse your UI and logic without installing native apps. It’s perfect for demos, admin screens, and tools. The browser has different rules (security, file access, multi-window) and you’ll make better design choices if you know them.

Quick start: StartBrowserAppAsync
In the browser, Avalonia runs with a single-view lifetime and renders into a specific HTML element by id. The simplest startup creates and attaches a view for you.

Program.cs

```csharp
using Avalonia;
using Avalonia.Browser;

internal class Program
{
    private static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .LogToTrace();

    public static Task Main(string[] args)
        => BuildAvaloniaApp()
            .StartBrowserAppAsync("out"); // attaches to <div id="out"></div>
}
```

HTML host (conceptual)

```html
<body>
  <div id="out"></div>
</body>
```

Note: In real projects the template sets up the host page and static assets for you. The important part is that an element with id="out" exists.

Rendering modes and options
You can pick renderers and configure web-specific behaviors via BrowserPlatformOptions.

```csharp
await BuildAvaloniaApp().StartBrowserAppAsync(
    "out",
    new BrowserPlatformOptions
    {
        // Try WebGL2, then WebGL1, then fallback to Software2D
        RenderingMode = new[]
        {
            BrowserRenderingMode.WebGL2,
            BrowserRenderingMode.WebGL1,
            BrowserRenderingMode.Software2D
        },

        // Register a service worker used for save-file polyfill (optional)
        RegisterAvaloniaServiceWorker = true,
        AvaloniaServiceWorkerScope = "/",

        // Force using the file dialog polyfill even if native is available
        PreferFileDialogPolyfill = false,

        // Use a managed dispatcher on a worker thread when WASM threads are enabled
        PreferManagedThreadDispatcher = true,
    });
```

- RenderingMode: a priority list, first supported value wins (best performance: WebGL2).
- RegisterAvaloniaServiceWorker/AvaloniaServiceWorkerScope: enables a service worker used by the save file polyfill on browsers without a native File System Access API.
- PreferFileDialogPolyfill: forces use of the “native-file-system-adapter” polyfill even if a native API is present.
- PreferManagedThreadDispatcher: when WASM threads are enabled, run the dispatcher on a worker thread for responsiveness.

Alternative: SetupBrowserAppAsync (advanced)
SetupBrowserAppAsync loads the browser backend without creating a view. This is useful for custom embedding scenarios; most apps should use StartBrowserAppAsync.

Single view lifetime on the web
Avalonia uses ISingleViewApplicationLifetime in the browser. In App.OnFrameworkInitializationCompleted, set MainView like you do for mobile:

```csharp
public override void OnFrameworkInitializationCompleted()
{
    if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
    {
        singleView.MainView = new MainView
        {
            DataContext = new MainViewModel()
        };
    }

    base.OnFrameworkInitializationCompleted();
}
```

Storage and file dialogs in the browser
- Use IStorageProvider for open/save/folder pickers. On supported browsers Avalonia uses the File System Access API; otherwise it uses a polyfill with a service worker to enable saving.
- Browsers require a secure context (HTTPS or localhost) for advanced file APIs. Expect different UX than desktop.

Networking and CORS
- Browser networking follows CORS rules. If your API doesn’t set the right headers, requests can be blocked.
- Use HTTPS and correct Access-Control-Allow-* headers on your server; the browser controls what’s allowed, not Avalonia.

Platform capabilities and limitations
- Windows & menus: Browser runs with a single view; native menus/tray icons, system dialogs, and OS integrations are not available.
- Input and focus: Works with keyboard, mouse, touch; clipboard access is gated by browser rules and user gestures.
- Graphics: WebGL2 is fastest; WebGL1 is a fallback; Software2D is a last resort and is slower.
- Local files: You don’t have broad file system access; always go through IStorageProvider.
- Threads: WASM threads require explicit hosting support and appropriate headers; if unavailable the app runs single-threaded.

Blazor hosting option
You can host Avalonia inside a Blazor app using Avalonia.Browser.Blazor. This is handy when you need existing Blazor routing/layout with embedded Avalonia UI. See the ControlCatalog.Browser.Blazor sample for a working project structure.

Troubleshooting
- Blank page: Verify the div id matches StartBrowserAppAsync("...") and that the static assets are served. Check the browser console for module load errors.
- WebGL errors or poor performance: Ensure your GPU/browser supports WebGL2; try WebGL1 fallback or Software2D.
- Save file doesn’t work: Enable the service worker option, serve over HTTPS/localhost, and verify the polyfill is allowed by the browser.
- CORS failures: Fix server headers; the browser blocks disallowed cross-origin requests.

Exercise
1) Add a browser head to your app and wire StartBrowserAppAsync("out").
2) Configure RenderingMode to try WebGL2→WebGL1→Software2D and verify the app runs on at least two different browsers.
3) Implement an Export button using IStorageProvider to test the save polyfill with and without the service worker.

Look under the hood
- Browser startup and options: BrowserAppBuilder
  [Avalonia.Browser/BrowserAppBuilder.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserAppBuilder.cs)
- Single view lifetime (browser): BrowserSingleViewLifetime
  [Avalonia.Browser/BrowserSingleViewLifetime.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserSingleViewLifetime.cs)
- ControlCatalog browser sample (Program.cs)
  [samples/ControlCatalog.Browser/Program.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/samples/ControlCatalog.Browser/Program.cs)
- Input/keyboard pane for browser
  [Avalonia.Browser/BrowserInputPane.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserInputPane.cs)
- Insets/safe areas for browser
  [Avalonia.Browser/BrowserInsetsManager.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserInsetsManager.cs)
- Storage provider and polyfill
  [Avalonia.Browser/Storage/BrowserStorageProvider.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/Storage/BrowserStorageProvider.cs)
- Platform settings (browser)
  [Avalonia.Browser/BrowserPlatformSettings.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserPlatformSettings.cs)
- Blazor hosting
  [Avalonia.Browser.Blazor](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Browser/Avalonia.Browser.Blazor)

What’s next
- Next: [Chapter 21](Chapter21.md)
