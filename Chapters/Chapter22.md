# 22. Rendering pipeline in plain words

Goal
- Understand how Avalonia turns your visual tree into frames across every backend.
- Know the responsibilities of the UI thread, render loop, compositor, renderer, and GPU interface.
- Learn how to tune rendering with `SkiaOptions`, `RenderOptions`, timers, and diagnostics tools.

Why this matters
- Smooth, power-efficient UI depends on understanding what triggers redraws and how Avalonia schedules work.
- Debugging rendering glitches is easier when you know each component's role.

Prerequisites
- Chapter 17 (async/background) for thread awareness, Chapter 18/19 (platform differences).

## 1. Mental model

1. **UI thread** builds and updates the visual tree (`Visual`s/`Control`s). When properties change, visuals mark themselves dirty (e.g., via `InvalidateVisual`).
2. **Scene graph** represents visuals and draw operations in a batched form (`SceneGraph.cs`).
3. **Compositor** commits scene graph updates to the render thread and keeps track of dirty rectangles.
4. **Render loop** (driven by an `IRenderTimer`) asks the renderer to draw frames while work is pending.
5. **Renderer** walks the scene graph, issues drawing commands, and marshals them to Skia or another backend.
6. **Skia/render interface** rasterizes shapes/text/images into GPU textures (or CPU bitmaps) before the platform swapchain presents the frame.

Avalonia uses two main threads: UI thread and render thread. Keep the UI thread free of long-running work so animations, input dispatch, and composition stay responsive.

## 2. UI thread: creating and invalidating visuals

- `Visual`s have properties (`Bounds`, `Opacity`, `Transform`, etc.) that trigger redraw when changed.
- `InvalidateVisual()` marks a visual dirty. Most controls call this automatically when a property changes.
- Layout changes may also mark visuals dirty (e.g., size change).

## 3. Render thread and renderer pipeline

- `IRenderer` (see [`IRenderer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/IRenderer.cs)) exposes methods:
  - `AddDirty(Visual visual)` — mark dirty region.
  - `Paint` — handle paint request (e.g., OS says "redraw now").
  - `Resized` — update when target size changes.
  - `Start`/`Stop` — hook into render loop lifetime.

Avalonia ships both `CompositingRenderer` (default) and `DeferredRenderer`. The renderer uses dirty rectangles to redraw minimal regions and produces scene graph nodes consumed by Skia.

### CompositionTarget

`CompositionTarget` abstracts the surface being rendered. It holds references to swapchains, frame buffers, and frame timing metrics. You usually observe it through `IRenderer.Diagnostics` (frame times, dirty rect counts) or via DevTools/remote diagnostics rather than accessing the object directly.

### Immediate renderer

`ImmediateRenderer` renders a visual subtree synchronously into a `DrawingContext`. Used for `RenderTargetBitmap`, `VisualBrush`, etc. Not used for normal window presentation.

## 4. Compositor and render loop

The compositor orchestrates UI → render thread updates (see [`Compositor.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/Composition/Compositor.cs)).

- Batches (serialized UI tree updates) are committed to the render thread.
- `RenderLoop` ticks at platform-defined cadence (vsync/animation timers). When there's dirty content or `CompositionTarget` animations, it schedules a frame.
- Render loop ensures frames draw at stable cadence even if the UI thread is momentarily busy.

### Render timers

- `IRenderTimer` (see [`IRenderTimer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/IRenderTimer.cs)) abstracts ticking. Implementations include `DefaultRenderTimer`, `DispatcherRenderTimer`, and headless timers used in tests.
- Customize via `AppBuilder.UseRenderLoop(new RenderLoop(new DispatcherRenderTimer()))` to integrate external timing sources (e.g., game loops).
- Timers raise `Tick` on the render thread. Avoid heavy work in handlers: queue work through the UI thread if necessary.

### Scene graph commits

Each `RenderLoop` tick calls `Compositor.CommitScenes`. The compositor transforms dirty visuals into render passes, prunes unchanged branches, and tracks retained GPU resources for reuse across frames.

## 5. Backend selection and GPU interfaces

Avalonia targets multiple render interfaces via `IRenderInterface`. Skia is the default implementation and chooses GPU versus CPU paths per platform.

### Backend selection logic

- Desktop defaults to GPU (OpenGL/ANGLE on Windows, OpenGL/Vulkan on Linux, Metal on macOS).
- Mobile uses OpenGL ES (Android) or Metal (iOS/macOS Catalyst).
- Browser compiles Skia to WebAssembly and falls back to WebGL2/WebGL1/software.
- Server/headless falls back to CPU rendering.

Force a backend with `UseSkia(new SkiaOptions { RenderMode = RenderMode.Software })` or by setting `AVALONIA_RENDERER` environment variable (e.g., `software`, `open_gl`). Always pair overrides with tests on target hardware.

### GPU resource management

- `SkiaOptions` exposes GPU cache limits and toggles like `UseOpacitySaveLayer`.
- `IRenderSurface` implementations (swapchains, framebuffers) own platform handles; leaks appear as rising `RendererDiagnostics.SceneGraphDirtyRectCount`.

### Skia configuration

Avalonia uses Skia for cross-platform drawing:
- GPU or CPU rendering depending on platform capabilities.
- GPU backend chosen automatically (OpenGL, ANGLE, Metal, Vulkan, WebGL, etc.).
- `UseSkia(new SkiaOptions { ... })` in `AppBuilder` to tune.

### SkiaOptions

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .UseSkia(new SkiaOptions
    {
        MaxGpuResourceSizeBytes = 64L * 1024 * 1024,
        UseOpacitySaveLayer = false
    })
    .LogToTrace();
```

- `MaxGpuResourceSizeBytes`: limit Skia resource cache.
- `UseOpacitySaveLayer`: forces Skia to use save layers for opacity stacking (accuracy vs performance).

## 6. RenderOptions (per Visual)

`RenderOptions` attached properties influence interpolation and text rendering:
- `BitmapInterpolationMode`: Low/Medium/High quality vs default.
- `BitmapBlendingMode`: blend mode for images.
- `TextRenderingMode`: Default, Antialias, SubpixelAntialias, Aliased.
- `EdgeMode`: Antialias vs Aliased for geometry edges.
- `RequiresFullOpacityHandling`: handle complex opacity composition.

Example:

```csharp
RenderOptions.SetBitmapInterpolationMode(image, BitmapInterpolationMode.HighQuality);
RenderOptions.SetTextRenderingMode(smallText, TextRenderingMode.Aliased);
```

RenderOptions apply to a visual and flow down to children unless overridden.

## 7. When does a frame render?

- Property changes on visuals (brush, text, transform).
- Layout updates affecting size/position.
- Animations (composition or binding-driven) schedule continuous frames.
- Input (pointer events) may cause immediate redraw (e.g., ripple effect).
- External events: window resize, DPI change.

Prevent unnecessary redraws:
- Avoid toggling properties frequently without change.
- Batch updates on UI thread; let binding/animation handle smooth changes.
- Free large bitmaps once no longer needed.

## 8. Frame timing instrumentation

### Renderer diagnostics

- Enable `RendererDiagnostics` (see [`RendererDiagnostics.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDiagnostics.cs)) via `RenderRoot.Renderer.Diagnostics`. Metrics include dirty rectangle counts, render phase durations, and draw call tallies.
- Pair diagnostics with `SceneInvalidated`/`RenderLoop` timestamps to push frame data into tracing systems such as `EventSource` or Prometheus exporters.

### DevTools

- Press `F12` to open DevTools.
- `Diagnostics` panel toggles overlays and displays frame timing graphs.
- `Rendering` view (when available) shows render loop cadence, render thread load, and GPU backend in use.

### Logging

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .LogToTrace(LogEventLevel.Debug, new[] { LogArea.Rendering, LogArea.Layout })
    .StartWithClassicDesktopLifetime(args);
```

### Render overlays

`RendererDebugOverlays` (see [`RendererDebugOverlays.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDebugOverlays.cs)) enable overlays showing dirty rectangles, FPS, layout costs.

```csharp
if (TopLevel is { Renderer: { } renderer })
    renderer.DebugOverlays = RendererDebugOverlays.Fps | RendererDebugOverlays.LayoutTimeGraph;
```

### Tools

- Use .NET memory profiler or `dotnet-counters` to monitor GC while animating UI.
- GPU profilers (RenderDoc) can capture Skia GPU commands (advanced scenario).
- `Avalonia.Diagnostics.RenderingDebugOverlays` integrates with `Avalonia.Remote.Protocol`. Use `avalonia-devtools://` clients to stream metrics from remote devices (Chapter 24).

## 9. Immediate rendering utilities

### RenderTargetBitmap

```csharp
var bitmap = new RenderTargetBitmap(new PixelSize(300, 200), new Vector(96, 96));
await bitmap.RenderAsync(myControl);
bitmap.Save("snapshot.png");
```

Uses `ImmediateRenderer` to render a control off-screen.

### Drawing manually

`DrawingContext` allows custom drawing via immediate renderer.

## 10. Platform-specific notes

- Windows: GPU backend typically ANGLE (OpenGL) or D3D via Skia; transparency support (Mica/Acrylic) may involve compositor-level effects.
- macOS: uses Metal via Skia; retina scaling via `RenderScaling`.
- Linux: OpenGL (or Vulkan) depending on driver; virtualization/backends vary.
- Mobile: OpenGL ES on Android, Metal on iOS; consider battery impact when scheduling animations.
- Browser: WebGL2/WebGL1/Software2D (Chapter 20); one-threaded unless WASM threading enabled.

## 11. Practice exercises

1. Replace the render timer with a custom `IRenderTimer` implementation and graph frame cadence using timestamps collected from `SceneInvalidated`.
2. Override `SkiaOptions.RenderMode` to force software rendering, then switch back to GPU; profile render time using overlays in both modes.
3. Capture frame diagnostics (`RendererDebugOverlays.LayoutTimeGraph | RenderTimeGraph`) during an animation and export metrics for analysis.
4. Instrument `RenderRoot.Renderer.Diagnostics` to log dirty rectangle counts when toggling `InvalidateVisual`; correlate with DevTools overlays.
5. Use DevTools remote transport to attach from another process (Chapter 24) and verify frame timing matches local instrumentation.

## Look under the hood (source bookmarks)
- Renderer interface: [`IRenderer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/IRenderer.cs)
- Compositor: [`Compositor.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/Composition/Compositor.cs)
- Scene graph: [`RenderDataDrawingContext.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/Composition/Drawing/RenderDataDrawingContext.cs)
- Immediate renderer: [`ImmediateRenderer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/ImmediateRenderer.cs)
- Render loop: [`RenderLoop.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RenderLoop.cs)
- Render timer abstraction: [`IRenderTimer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/IRenderTimer.cs)
- Render options: [`RenderOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs)
- Skia options and platform interface: [`SkiaOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Skia/Avalonia.Skia/SkiaOptions.cs), [`PlatformRenderInterface.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Skia/Avalonia.Skia/PlatformRenderInterface.cs)
- Renderer diagnostics: [`RendererDiagnostics.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDiagnostics.cs)
- Debug overlays: [`RendererDebugOverlays.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDebugOverlays.cs)

## Check yourself
- What components run on the UI thread vs render thread?
- How does `InvalidateVisual` lead to a new frame?
- When would you adjust `SkiaOptions.MaxGpuResourceSizeBytes` vs `RenderOptions.BitmapInterpolationMode`?
- What tools help you diagnose rendering bottlenecks?

What's next
- Next: [Chapter 23](Chapter23.md)
