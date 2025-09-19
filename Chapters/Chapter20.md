# 20. Browser (WebAssembly) target

Goal
- Run your Avalonia app in the browser using WebAssembly (WASM) with minimal changes to shared code.
- Understand browser-specific lifetimes, hosting options, rendering modes, and platform limitations (files, networking, threading, DOM interop).
- Debug, profile, and deploy a browser build with confidence.

Why this matters
- Web delivery eliminates install friction for demos, tooling, and dashboards.
- Browser rules (sandboxing, CORS, user gestures) require tweaks compared to desktop/mobile, and understanding how Avalonia binds to the JS runtime keeps those differences manageable.

Prerequisites
- Chapter 19 (single-view navigation), Chapter 16 (storage provider), Chapter 17 (async/networking).

## 1. Project structure and setup

Install `wasm-tools` workload:

```bash
sudo dotnet workload install wasm-tools
```

A multi-target solution has:
- Shared project (`MyApp`): Avalonia code.
- Browser head (`MyApp.Browser`): hosts the app (`Program.cs`, `index.html`, static assets).

Avalonia template (`dotnet new avalonia.app --multiplatform`) can create the browser head for you. `MyApp.Browser` references `Avalonia.Browser`, which wraps the WebAssembly host (`BrowserAppBuilder`, `BrowserSingleViewLifetime`, `BrowserNativeControlHost`).

When adding the head manually, target `net8.0-browserwasm`, configure `<WasmMainJSPath>wwwroot/main.js</WasmMainJSPath>`, and keep trimming hints (e.g., `<InvariantGlobalization>true</InvariantGlobalization>`). Browser heads use the NativeAOT toolchain; Release builds can set `<PublishAot>true</PublishAot>` for faster startup and smaller payloads.

## 2. Start the browser app

`StartBrowserAppAsync` attaches Avalonia to a DOM element by ID.

```csharp
using Avalonia;
using Avalonia.Browser;

internal sealed class Program
{
    private static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .LogToTrace();

    public static Task Main(string[] args)
        => BuildAvaloniaApp()
            .StartBrowserAppAsync("out");
}
```

Ensure host HTML contains `<div id="out"></div>`.

For advanced embedding, use `BrowserAppBuilder` directly:

```csharp
await BrowserAppBuilder.Configure<App>()
    .SetupBrowserAppAsync(options =>
    {
        options.MainAssembly = typeof(App).Assembly;
        options.AppBuilder = AppBuilder.Configure<App>().LogToTrace();
        options.Selector = "#out";
    });
```

`SetupBrowserAppAsync` lets you delay instantiation (wait for configuration, auth, etc.) or mount multiple roots in different DOM nodes.

## 3. Single view lifetime

Browser uses `ISingleViewApplicationLifetime` (same as mobile). Configure in `App.OnFrameworkInitializationCompleted`:

```csharp
public override void OnFrameworkInitializationCompleted()
{
    if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        singleView.MainView = new ShellView { DataContext = new ShellViewModel() };
    else if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        desktop.MainWindow = new MainWindow { DataContext = new ShellViewModel() };

    base.OnFrameworkInitializationCompleted();
}
```

Navigation patterns from Chapter 19 apply (content control with back stack).

## 4. Rendering options

Configure `BrowserPlatformOptions` to choose rendering mode and polyfills.

```csharp
await BuildAvaloniaApp().StartBrowserAppAsync(
    "out",
    new BrowserPlatformOptions
    {
        RenderingMode = new[]
        {
            BrowserRenderingMode.WebGL2,
            BrowserRenderingMode.WebGL1,
            BrowserRenderingMode.Software2D
        },
        RegisterAvaloniaServiceWorker = true,
        AvaloniaServiceWorkerScope = "/",
        PreferFileDialogPolyfill = false,
        PreferManagedThreadDispatcher = true
    });
```

- WebGL2: best performance (default when supported).
- WebGL1: fallback for older browsers.
- Software2D: ultimate fallback (slower).
- Service worker: required for save-file polyfill; serve over HTTPS/localhost.
- `PreferManagedThreadDispatcher`: run dispatcher on worker thread when WASM threading enabled (requires server sending COOP/COEP headers).
- `PreferFileDialogPolyfill`: toggle between File System Access API and download/upload fallback for unsupported browsers.

## 5. Storage and file dialogs

`IStorageProvider` uses the File System Access API when available; otherwise a polyfill (service worker + download anchor) handles saves.

Limitations:
- Browsers require user gestures (click) to open dialogs.
- File handles may not persist between sessions; use IDs and re-request access if needed.
- No direct file system access outside the user-chosen handles.

Example save using polyfill-friendly code (Chapter 16 shows full pattern). Test with/without service worker to ensure both paths work.

## 6. Clipboard & drag-drop

Clipboard operations require user gestures and may only support text formats.
- `Clipboard.SetTextAsync` works after user interaction (button click).
- Advanced formats require clipboard permissions or aren't supported.

Drag/drop from browser to app is supported, but dragging files out of the app is limited by browser APIs.

## 7. Networking & CORS

- HttpClient uses `fetch`. All requests obey CORS. Configure server with correct `Access-Control-Allow-*` headers.
- WebSockets supported via `ClientWebSocket` if server enables them.
- HTTPS recommended; some APIs (clipboard, file access) require secure context.
- `HttpClient` respects browser caching rules. Adjust `Cache-Control` headers or add cache-busting query parameters during development to avoid stale responses.

## 8. JavaScript interop

Call JS via `window.JSObject` or `JSRuntime` helpers (Avalonia.Browser exposes interop helpers). Example:

```csharp
using Avalonia.Browser.Interop;

await JSRuntime.InvokeVoidAsync("console.log", "Hello from Avalonia");
```

Use interop to integrate with existing web components or to access Web APIs not wrapped by Avalonia.

To host native DOM content inside Avalonia, use `BrowserNativeControlHost` with a `JSObjectControlHandle`:

```csharp
var handle = await JSRuntime.CreateControlHandleAsync("div", new { @class = "web-frame" });
var host = new BrowserNativeControlHost { Handle = handle };
```

This enables hybrid UI scenarios (rich HTML editors, video elements) while keeping sizing/layout under Avalonia control.

## 9. Hosting in Blazor (optional)

`Avalonia.Browser.Blazor` lets you embed Avalonia controls in a Blazor app. Example sample: `ControlCatalog.Browser.Blazor`. Use when you need Blazor's routing/layout but Avalonia UI inside components.

## 10. Hosting strategies

- Static hosting: publish bundle to `AppBundle` and serve from any static host (GitHub Pages, S3 + CloudFront, Azure Static Web Apps). Ensure service worker scope matches site root.
- ASP.NET Core: use `MapFallbackToFile("index.html")` or `UseBlazorFrameworkFiles()` to serve the bundle from a Minimal API or MVC backend.
- Reverse proxies: configure caching (Brotli, gzip) and set `Cross-Origin-Embedder-Policy`/`Cross-Origin-Opener-Policy` headers when enabling multithreaded WASM.

During development, `dotnet run` on the browser head launches a Kestrel server with live reload and proxies console logs back to the terminal.

## 11. Debugging and diagnostics

- Inspector: use browser devtools (F12). Evaluate DOM, watch console logs.
- Source maps: publish with `dotnet publish -c Debug` to get wasm debugging symbols for supported browsers.
- Logging: `AppBuilder.LogToTrace()` outputs to console.
- Performance: use Performance tab to profile frames, memory, CPU.
- Pass `--logger:WebAssembly` to `dotnet run` for runtime messages (assembly loading, exception details).
- Use `wasm-tools wasm-strip` or `wasm-tools wasm-opt` (installed via `dotnet wasm build-tools --install`) to analyze and reduce bundle sizes.

## 12. Performance tips

- Measure download size: inspect `AppBundle`, track `.wasm`, `.dat`, and compressed assets.
- Prefer compiled bindings and avoid reflection-heavy converters to keep the IL linker effective.
- Enable multithreading (COOP/COEP headers) when animations or background tasks stutter; Avalonia will schedule the render loop on a dedicated worker thread.
- Integrate `BrowserSystemNavigationManager` with your navigation service so browser back/forward controls work as expected.

## 13. Deployment

Publish the browser head:

```bash
cd MyApp.Browser
# Debug
dotnet run
# Release bundle
dotnet publish -c Release
```

Output under `bin/Release/net8.0/browser-wasm/AppBundle`. Serve via static web server (ASP.NET, Node, Nginx, GitHub Pages). Ensure service worker scope matches hosting path.

Remember to enable compression (Brotli) for faster load times.

## 14. Platform limitations

| Feature | Browser behavior |
| --- | --- |
| Windows/Dialogs | Single view only; no OS windows, tray icons, native menus |
| File system | User-selection only via pickers; no arbitrary file access |
| Threading | Multi-threaded WASM requires server headers (COOP/COEP) and browser support |
| Clipboard | Requires user gesture; limited formats |
| Notifications | Use Web Notifications API via JS interop |
| Storage | LocalStorage/IndexedDB via JS interop for persistence |

Design for progressive enhancement: provide alternative flows if feature unsupported.

## 15. Practice exercises

1. Add a browser head and run the app in Chrome/Firefox, verifying rendering fallbacks.
2. Implement file export via `IStorageProvider` and test save polyfill with service worker enabled/disabled.
3. Add logging to report `BrowserPlatformOptions.RenderingMode` and `ActualTransparencyLevel` (should be `None`).
4. Integrate a JavaScript API (e.g., Web Notifications) via interop and show a notification after user action.
5. Publish a release build and deploy to a static host (GitHub Pages or local web server), verifying service worker scope and COOP/COEP headers.
6. Use `wasm-tools wasm-strip` (or `wasm-opt`) to inspect bundle size before/after trimming and record the change.

## Look under the hood (source bookmarks)
- Browser app builder: [`BrowserAppBuilder.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserAppBuilder.cs)
- DOM interop: [`JSObjectControlHandle.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/Interop/JSObjectControlHandle.cs)
- Browser lifetime: [`BrowserSingleViewLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserSingleViewLifetime.cs)
- Native control host: [`BrowserNativeControlHost.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserNativeControlHost.cs)
- Storage provider: [`BrowserStorageProvider.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/Storage/BrowserStorageProvider.cs)
- System navigation manager: [`BrowserSystemNavigationManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserSystemNavigationManager.cs)
- Input pane & insets: [`BrowserInputPane.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserInputPane.cs), [`BrowserInsetsManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Browser/Avalonia.Browser/BrowserInsetsManager.cs)
- Blazor integration: [`Avalonia.Browser.Blazor`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Browser/Avalonia.Browser.Blazor)

## Check yourself
- How do you configure rendering fallbacks for the browser target?
- What limitations exist for file access and how does the polyfill help?
- Which headers or hosting requirements enable WASM multi-threading? Why might you set `PreferManagedThreadDispatcher`?
- How do CORS rules affect HttpClient calls in the browser?
- What deployment steps are required to serve a browser bundle with service worker support and COOP/COEP headers?

What's next
- Next: [Chapter 21](Chapter21.md)
