# 32. Platform services, embedding, and native interop

Goal
- Integrate Avalonia with native hosts: Windows, macOS, X11, browsers, mobile shells, and custom embedding scenarios.
- Leverage `NativeControlHost`, `EmbeddableControlRoot`, and platform services (`IWindowingPlatform`, tray icons, system dialogs) to build hybrid applications.
- Understand remote protocols and thin-client options to drive Avalonia content from external processes.

Why this matters
- Many teams embed Avalonia inside existing apps (Win32, WPF, WinForms), or host native controls inside Avalonia shells.
- Platform services expose tray icons, system navigation managers, storage providers, and more. Using them correctly keeps UX idiomatic per OS.
- Remote rendering and embedding power tooling (previewers, diagnostics, multi-process architectures).

Prerequisites
- Chapter 12 (windows & lifetimes) for top-level concepts.
- Chapter 18–20 (platform targets) for backend overviews.
- Chapter 32 builds on Chapter 29 (animations/composition) when synchronizing native surfaces.

## 1. Platform abstractions overview

Avalonia abstracts windowing via interfaces in `Avalonia.Controls.Platform` and `Avalonia.Platform`:

| Interface | Location | Purpose |
| --- | --- | --- |
| `IWindowingPlatform` | `external/Avalonia/src/Avalonia.Controls/Platform/IWindowingPlatform.cs` | Creates windows, embeddable top levels, tray icons |
| `INativeControlHostImpl` | platform backends (Win32, macOS, iOS, Browser) | Hosts native HWND/NSView/UIViews inside Avalonia (`NativeControlHost`) |
| `ITrayIconImpl` | backend-specific | Implements tray icons (`PlatformManager.CreateTrayIcon`) |
| `IPlatformStorageProvider`, `ILauncher` | `Avalonia.Platform.Storage` | File pickers, launchers across platforms |
| `IApplicationPlatformEvents` | `Avalonia.Controls.Platform` | System-level events (activation, protocol handlers) |

`PlatformManager` coordinates these services and surfaces high-level helpers (tray icons, dialogs). Check `TopLevel.PlatformImpl` to access backend-specific features.

## 2. Hosting native controls inside Avalonia

`NativeControlHost` (`external/Avalonia/src/Avalonia.Controls/NativeControlHost.cs`) lets you wrap native views:

- Override `CreateNativeControlCore(IPlatformHandle parent)` to instantiate native widgets (Win32 HWND, NSView, Android View).
- Avalonia attaches/detaches the native control when the host enters/leaves the visual tree, using `INativeControlHostImpl` from the current `TopLevel`.
- `TryUpdateNativeControlPosition` translates Avalonia bounds into platform coordinates and resizes the native child.

Example (Win32 HWND):

```csharp
public class Win32WebViewHost : NativeControlHost
{
    protected override IPlatformHandle CreateNativeControlCore(IPlatformHandle parent)
    {
        var hwnd = Win32Interop.CreateWebView(parent.Handle);
        return new PlatformHandle(hwnd, "HWND");
    }

    protected override void DestroyNativeControlCore(IPlatformHandle control)
    {
        Win32Interop.DestroyWindow(control.Handle);
    }
}
```

Guidelines:
- Ensure thread affinity: most native controls expect creation/destruction on the UI thread.
- Handle DPI changes by listening to size changes (`BoundsProperty`) and calling the platform API to adjust scaling.
- Use `NativeControlHandleChanged` for interop with additional APIs (e.g., hooking message loops).
- For accessibility, expose appropriate semantics; Avalonia's `NativeControlHostAutomationPeer` helps but you may need custom peers.

## 3. Embedding Avalonia inside native hosts

`EmbeddableControlRoot` (`external/Avalonia/src/Avalonia.Controls/Embedding/EmbeddableControlRoot.cs`) wraps a `TopLevel` that can live in non-Avalonia environments:

- Construct with an `ITopLevelImpl` supplied by platform-specific hosts (`WinFormsAvaloniaControlHost`, `X11 XEmbed`, `Android AvaloniaView`, `iOS AvaloniaView`).
- Call `Prepare()` to initialize the logical tree and run the initial layout pass.
- Use `StartRendering`/`StopRendering` to control drawing when the host window shows/hides.
- `EnforceClientSize` ensures Avalonia matches the host surface size; disable for custom measure logic.

Examples:
- **WinForms**: `WinFormsAvaloniaControlHost` hosts `EmbeddableControlRoot` inside Windows Forms. Remember to call `InitAvalonia()` before creating controls.
- **X11 embedding**: `XEmbedPlug` uses `EmbeddableControlRoot` to embed into foreign X11 windows (tooling, remote previews).
- **Mobile views**: `Avalonia.Android.AvaloniaView` and `Avalonia.iOS.AvaloniaView` wrap `EmbeddableControlRoot` to integrate with native UI stacks.

Interop tips:
- Manage lifecycle carefully: dispose the root when the host closes to release GPU/threads.
- Expose the `Content` property to your native layer for dynamic view injection.
- Bridge focus and input: e.g., WinForms host sets `TabStop` and forwards focus events to the Avalonia root.

### MicroCom bridges for Windows interop

Avalonia relies on [MicroCom](https://github.com/AvaloniaUI/MicroCom) to generate COM-compatible wrappers. When embedding on Windows (drag/drop, menus, Win32 interop):
- Use `Avalonia.MicroCom.CallbackBase` as the base for custom COM callbacks; it handles reference counting and error reporting.
- `OleDropTarget` and native menu exporters in `Avalonia.Win32` demonstrate wrapping Win32 interfaces without hand-written COM glue.
- When exposing Avalonia controls to native hosts, keep MicroCom proxies alive for the lifetime of the host window to avoid releasing underlying HWND/IDispatch too early.

You rarely need to touch MicroCom directly, but understanding it helps when diagnosing drag/drop or accessibility issues on Windows.

## 4. Remote rendering and previews

Avalonia's remote protocol (`external/Avalonia/src/Avalonia.Remote.Protocol`) powers the XAML previewer and custom remoting scenarios.

- `RemoteServer` (`external/Avalonia/src/Avalonia.Controls/Remote/RemoteServer.cs`) wraps an `EmbeddableControlRoot` backed by `RemoteServerTopLevelImpl`. It responds to transport messages (layout updates, pointer events) from a remote client.
- Transports: BSON over TCP (`BsonTcpTransport`), streams (`BsonStreamTransport`), or custom `IAvaloniaRemoteTransportConnection` implementations.
- Use `Avalonia.DesignerSupport` components to spin up preview hosts; they bind to `IWindowingPlatform` stubs suitable for design-time.
- On the client side, `RemoteWidget` hosts the mirrored visual tree. It pairs with `RemoteServer` to marshal input/output.
- Implement a custom `ITransport` when you need alternate channels (named pipes, WebSockets). The protocol is message-based, so you can plug in encryption or compression as needed.

Potential use cases:
- Live XAML preview in IDEs (already shipped).
- Remote control panels (render UI in a service, interact via TCP).
- UI testing farms capturing frames via remote composition.

Security note: remote transports expose the UI tree—protect endpoints if you ship this beyond trusted tooling.

## 5. Tray icons, dialogs, and platform services

`IWindowingPlatform.CreateTrayIcon()` supplies backend-specific tray icon implementations. Use `PlatformManager.CreateTrayIcon()` to instantiate one:

```csharp
var trayIcon = PlatformManager.CreateTrayIcon();
trayIcon.Icon = new WindowIcon("avares://Assets/tray.ico");
trayIcon.ToolTipText = "My App";
trayIcon.Menu = new NativeMenu
{
    Items =
    {
        new NativeMenuItem("Show", (sender, args) => mainWindow.Show()),
        new NativeMenuItem("Exit", (sender, args) => app.Shutdown())
    }
};
trayIcon.IsVisible = true;
```

Other services:
- **File pickers/storage**: `StorageProvider` (Chapter 16) uses platform storage APIs; embed scenarios must supply providers in DI.
- **System dialogs**: `SystemDialog` classes fallback to managed dialogs when native APIs are unavailable.
- **Application platform events**: `IApplicationPlatformEvents` handles activation (protocol URLs, file associations). Register via `AppBuilder` extensions.
- **System navigation**: On mobile, `SystemNavigationManager` handles back-button events; ensure `UsePlatformDetect` registers the appropriate lifetime.
- **Window chrome**: `Window` exposes `SystemDecorations`, `ExtendClientAreaToDecorationsHint`, `WindowTransparencyLevel`, and the `Chrome.WindowChrome` helpers so you can blend custom title bars with OS hit testing. Always provide resize grips and fall back to system chrome when composition is disabled.

## 6. Browser, Android, iOS views

- **Browser**: `Avalonia.Browser.AvaloniaView` hosts `EmbeddableControlRoot` atop WebAssembly; `NativeControlHost` implementations for the browser route to JS interop.
- **Android/iOS**: `AvaloniaView` provides native controls (Android View, iOS UIView) embedding Avalonia UI. Use `SingleViewLifetime` to tie app lifetimes to host platforms.
- Expose Avalonia content to native navigation stacks, but run Avalonia's message loop (`AppBuilder.AndroidLifecycleEvents` / `AppBuilder.iOS`).

## 7. Offscreen rendering and interoperability

`OffscreenTopLevel` (`external/Avalonia/src/Avalonia.Controls/Embedding/Offscreen/OffscreenTopLevel.cs`) allows rendering to a framebuffer without showing a window—useful for:
- Server-side rendering (generate bitmaps for PDFs, emails).
- Unit tests verifying layout/visual output.
- Thumbnail generation for design tools.

Pair with `RenderTargetBitmap` to save results.

## 8. Practice lab: hybrid UI playbook

1. **Embed native control** – Host a Win32 WebView or platform-specific map view inside Avalonia using `NativeControlHost`. Ensure resize and DPI updates work.
2. **Avalonia-in-native** – Create a WinForms or WPF shell embedding `EmbeddableControlRoot`. Swap Avalonia content dynamically and synchronize focus/keyboard.
3. **Tray integration** – Add a tray icon that controls window visibility and displays context menus. Test on Windows and Linux (AppIndicator fallback).
4. **Remote preview** – Spin up `RemoteServer` with a TCP transport and connect using the Avalonia preview client to render a view remotely.
5. **Offscreen rendering** – Render a control to bitmap using `OffscreenTopLevel` + `RenderTargetBitmap` and compare results in a unit test.

Document interop boundaries (threading, disposal, event forwarding) for your team.

## Troubleshooting & best practices

- Always dispose hosts (`EmbeddableControlRoot`, tray icons, remote transports) to release native resources.
- Ensure Avalonia is initialized (`BuildAvaloniaApp().SetupWithoutStarting()`) before embedding in native shells.
- Watch for DPI mismatches: use `TopLevel.PlatformImpl?.TryGetFeature<IDpiProvider>()` or subscribe to scaling changes.
- For `NativeControlHost`, guard against parent changes; detach native handles during visual tree transitions to avoid orphaned HWNDs.
- Remote transports may drop messages under heavy load—implement reconnection logic and validation.
- On macOS, tray icons require the app to stay alive (use `NSApplication.ActivateIgnoringOtherApps` when needed).

## Look under the hood (source bookmarks)
- Native hosting: `external/Avalonia/src/Avalonia.Controls/NativeControlHost.cs`
- Embedding root: `external/Avalonia/src/Avalonia.Controls/Embedding/EmbeddableControlRoot.cs`
- Platform manager & services: `external/Avalonia/src/Avalonia.Controls/Platform/PlatformManager.cs`
- Remote protocol: `external/Avalonia/src/Avalonia.Controls/Remote/RemoteServer.cs`, `external/Avalonia/src/Avalonia.Controls/Remote/RemoteWidget.cs`, `external/Avalonia/src/Avalonia.Remote.Protocol/*`
- Win32 platform: `external/Avalonia/src/Windows/Avalonia.Win32/Win32Platform.cs`
- Browser/Android/iOS hosts: `external/Avalonia/src/Browser/Avalonia.Browser/AvaloniaView.cs`, `external/Avalonia/src/Android/Avalonia.Android/AvaloniaView.cs`, `external/Avalonia/src/iOS/Avalonia.iOS/AvaloniaView.cs`
- MicroCom interop: `external/Avalonia/src/Avalonia.MicroCom/CallbackBase.cs`, `external/Avalonia/src/Windows/Avalonia.Win32/OleDropTarget.cs`
- Window chrome helpers: `external/Avalonia/src/Avalonia.Controls/Chrome/WindowChrome.cs`, `external/Avalonia/src/Avalonia.Controls/Window.cs`

## Check yourself
- How does `NativeControlHost` coordinate `INativeControlHostImpl` and what events trigger repositioning?
- What steps are required to embed Avalonia inside an existing WinForms/WPF app?
- Which services does `IWindowingPlatform` expose, and how do you use them to create tray icons or embeddable top levels?
- How would you stream Avalonia UI to a remote client for live previews?
- When rendering offscreen, which classes help you create an isolated top level and capture the framebuffer?

What's next
- Return to [Index](../Index.md) for appendices, publishing checklists, or future updates.
