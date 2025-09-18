# 22. Rendering pipeline in plain words

Goal
- Understand how Avalonia turns your visual tree into frames on screen across platforms.
- Know the responsibilities of the UI thread, render thread, compositor, renderer, and Skia.
- Learn how to tune rendering with `SkiaOptions`, `RenderOptions`, and diagnostics tools.

Why this matters
- Smooth, power-efficient UI depends on understanding what triggers redraws and how Avalonia schedules work.
- Debugging rendering glitches is easier when you know each component's role.

Prerequisites
- Chapter 17 (async/background) for thread awareness, Chapter 18/19 (platform differences).

## 1. Mental model

1. **UI thread** builds and updates the visual tree (`Visual`s/`Control`s). When properties change, visuals mark themselves dirty (e.g., via `InvalidateVisual`).
2. **Compositor** batches dirty visuals, serializes changes, and schedules a render pass.
3. **Renderer** walks the visual tree, issues drawing commands, and hands them to Skia.
4. **Skia** rasterizes shapes/text/images into GPU textures (or CPU bitmaps).
5. **Platform swapchain** presents the frame in a window or surface.

Avalonia uses a multithreaded architecture: UI thread and render thread. Animation scheduling, input handling, and compositing rely on the UI thread staying responsive.

## 2. UI thread: creating and invalidating visuals

- `Visual`s have properties (`Bounds`, `Opacity`, `Transform`, etc.) that trigger redraw when changed.
- `InvalidateVisual()` marks a visual dirty. Most controls call this automatically when a property changes.
- Layout changes may also mark visuals dirty (e.g., size change).

## 3. Render thread and renderer pipeline

- `IRenderer` (see [`IRenderer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/IRenderer.cs)) exposes methods:
  - `AddDirty(Visual visual)` -- mark dirty region.
  - `Paint` -- handle paint request (e.g., OS says "redraw now").
  - `Resized` -- update when target size changes.
  - `Start`/`Stop` -- hook into render loop lifetime.

Avalonia includes `CompositingRenderer` (default) and `DeferredRenderer`. The renderer uses dirty rectangles to redraw minimal regions.

### Immediate renderer

`ImmediateRenderer` renders a visual subtree synchronously into a `DrawingContext`. Used for `RenderTargetBitmap`, `VisualBrush`, etc. Not used for normal window presentation.

## 4. Compositor and render loop

The compositor orchestrates UI -> render thread updates (see [`Compositor.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/Composition/Compositor.cs)).

- Batches (serialized UI tree updates) are committed to render thread.
- `RenderLoop` ticks at platform-defined cadence (vsync/animation timers). When there's dirty content or `CompositionTarget` animations, it schedules a frame.
- Render loop ensures frames draw at stable cadence even if UI thread is busy momentarily.

## 5. Skia backend

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

## 8. Profiling & diagnostics

### DevTools

- Press `F12` to open DevTools.
- Use `Rendering` panel (if available) to inspect GPU usage, show dirty rectangles.
- `Visual Tree` shows realized visuals; `Events` logs layout/render events.

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

1. Enable `RendererDebugOverlays.Fps` and animate a control; observe frame rate.
2. Switch `BitmapInterpolationMode` on an image while scaling up/down; compare results.
3. Apply `UseOpacitySaveLayer = true` and stack semi-transparent panels; compare visual results to default.
4. Render a control to `RenderTargetBitmap` using `RenderOptions` tweaks and inspect output.
5. Log render/layout events at `Debug` level and analyze which updates cause frames using DevTools.

## Look under the hood (source bookmarks)
- Renderer interface: [`IRenderer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/IRenderer.cs)
- Compositor: [`Compositor.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/Composition/Compositor.cs)
- Immediate renderer: [`ImmediateRenderer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/ImmediateRenderer.cs)
- Render loop: [`RenderLoop.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RenderLoop.cs)
- Render options: [`RenderOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs)
- Skia options and platform interface: [`SkiaOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Skia/Avalonia.Skia/SkiaOptions.cs), [`PlatformRenderInterface.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Skia/Avalonia.Skia/PlatformRenderInterface.cs)
- Debug overlays: [`RendererDebugOverlays.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDebugOverlays.cs)

## Check yourself
- What components run on the UI thread vs render thread?
- How does `InvalidateVisual` lead to a new frame?
- When would you adjust `SkiaOptions.MaxGpuResourceSizeBytes` vs `RenderOptions.BitmapInterpolationMode`?
- What tools help you diagnose rendering bottlenecks?

What's next
- Next: [Chapter 23](Chapter23.md)
