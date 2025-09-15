# 22. Rendering pipeline in plain words

Goal
- Understand how Avalonia turns your visual tree into pixels on screen
- Know the core pieces: UI thread, render loop, renderer, compositor, Skia
- Learn the few options you can safely tune (SkiaOptions, RenderOptions)

Why this matters
- Performance and correctness: knowing what triggers redraws (and what doesn’t) helps you write smooth, battery‑friendly UI
- Debugging: when frames don’t appear, knowing who is responsible saves hours
- Confidence: you’ll recognize what is platform‑specific and what is cross‑platform by design

A simple mental model
- You manipulate a tree of Visuals (Controls are Visuals) on the UI thread
- Changes mark parts of the scene as “dirty” and schedule work on the render loop
- The renderer converts visuals to draw calls (Skia commands)
- The compositor coordinates sending updates to the render thread and presents frames to a window/surface
- Skia draws into GPU textures or CPU bitmaps; the platform presents them to the screen

What runs where (threads)
- UI thread: you create/update controls, styles, bindings, animations, and handle input
- Render thread: receives serialized batches of composition changes and performs GPU/Skia work, then presents
- Separation keeps input/UI responsive even if a heavy frame is rendering

Requesting and producing frames
- Marking visuals dirty: controls call InvalidateVisual (protected) or update properties that affect rendering; the renderer’s queue is notified
- The renderer implements lifecycle methods:
  - AddDirty(Visual): a visual or region needs redraw
  - Resized(Size): target size changed
  - Paint(Rect): handle a paint request from the platform
  - Start()/Stop(): hook the render loop
- SceneInvalidated event signals that low‑level scene data changed (useful for input hit‑testing state)

Skia at the core
- Avalonia uses Skia for cross‑platform drawing: shapes, text, images, effects
- Skia can render using CPU or GPU; Avalonia prefers GPU when available
- AppBuilder.UseSkia() enables the Skia backend; you can pass SkiaOptions for tuning

GPU backends at a glance
- Avalonia abstracts GPU access with IPlatformGraphics; platform heads bind an available backend (OpenGL/ANGLE, Metal, Vulkan, etc.)
- On Windows, macOS, Linux, Android, iOS, and Browser, Skia draws into a surface backed by the platform’s GPU context or a software bitmap; the windowing system then presents the result
- You don’t choose the low‑level API directly; you use UseSkia and optional platform options, and Avalonia picks the most appropriate graphics stack

Composition and presentation
- The compositor coordinates updates between UI and render threads using batches; commits serialize object changes and send them to the render side
- A render loop ticks at a platform‑determined cadence; when there are dirty visuals or animations, a new frame is rendered and presented
- Effects like opacity, transforms, and clips are applied while traversing the visual tree; platform composition APIs may assist with efficient presentation on some systems

Immediate vs. normal rendering
- Normal application rendering uses the threaded compositor + Skia pipeline described above
- ImmediateRenderer is a utility that walks a Visual subtree directly into a DrawingContext without the full presentation path (used by features like VisualBrush or RenderTargetBitmap)
- Think of ImmediateRenderer as a synchronous “draw this once into a bitmap” tool, not the app’s live render loop

Tuning Skia with UseSkia(SkiaOptions)
- SkiaOptions.MaxGpuResourceSizeBytes (long?): caps Skia’s GPU resource cache (textures, glyph atlases)
  - Defaults to a value suitable for typical apps; set null to let Skia decide; set lower to constrain memory, higher to reduce cache churn
- SkiaOptions.UseOpacitySaveLayer (bool): forces use of Skia’s SaveLayer for opacity handling
  - Can fix edge cases with nested opacity but may cost performance; leave off unless you need it
- Example:
  
  AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .UseSkia(new SkiaOptions
    {
        MaxGpuResourceSizeBytes = 64L * 1024 * 1024, // 64 MB
        UseOpacitySaveLayer = false
    })
    .StartWithClassicDesktopLifetime(args);

RenderOptions: per‑visual quality knobs
- RenderOptions is a value applied per Visual and merged down the tree; it controls how bitmaps and text are sampled/blended
- Properties you can set:
  - BitmapInterpolationMode: Unspecified, LowQuality/MediumQuality/HighQuality
  - BitmapBlendingMode: Unspecified or a blend mode for images
  - EdgeMode: Antialias, Aliased, Unspecified (affects geometry edges and text defaults)
  - TextRenderingMode: Default, Antialias, SubpixelAntialias, Aliased
  - RequiresFullOpacityHandling: bool? (forces full opacity handling for complex compositions)
- Use attached helpers:
  
  // Make images crisper when scaled down
  RenderOptions.SetBitmapInterpolationMode(myImage, BitmapInterpolationMode.MediumQuality);
  
  // Force aliased text on a small LED‑style display
  RenderOptions.SetTextRenderingMode(myTextBlock, TextRenderingMode.Aliased);

What actually triggers redraws
- Property changes that affect layout or appearance (e.g., Brush, Text, Bounds) mark visuals dirty
- Animations and timers schedule continuous frames while active
- Input and window resize generate paint/size events
- Pure ViewModel changes trigger rendering only when they update bound UI properties

Practical tips
- Prefer vector drawing and let RenderOptions/Interpolation control quality on scaled assets
- Avoid layout thrash: batch property changes; let animations drive smooth frames instead of manual timers
- Do image decoding/resizing off the UI thread; then set the final Bitmap on UI thread
- Profile on the slowest target first; GPU availability and drivers vary across platforms

Troubleshooting
- “Nothing updates until I interact”: ensure the app is started with a lifetime that runs a message loop and that you haven’t stopped the renderer; long‑running work should be off the UI thread
- “Blurry text or images”: adjust TextRenderingMode/EdgeMode and BitmapInterpolationMode as needed; check DPI settings
- “High GPU memory”: tune MaxGpuResourceSizeBytes and use smaller images; free large bitmaps when not needed
- “Opacity stacking looks wrong”: try SkiaOptions.UseOpacitySaveLayer = true for correctness, then measure

Look under the hood (selected source)
- Renderer interface: IRenderer.cs (methods like AddDirty, Paint, Start/Stop) — [Avalonia.Base/Rendering/IRenderer.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/IRenderer.cs)
- Immediate renderer utility — [Avalonia.Base/Rendering/ImmediateRenderer.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/ImmediateRenderer.cs)
- Compositor (UI↔render threads, commit batches) — [Avalonia.Base/Rendering/Composition/Compositor.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/Composition/Compositor.cs)
- RenderOptions (bitmap/text/edge/blend/opacity) — [Avalonia.Base/Media/RenderOptions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs)
- Skia options (resource cache, opacity save layer) — [Skia/Avalonia.Skia/SkiaOptions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Skia/Avalonia.Skia/SkiaOptions.cs)
- Skia render interface and GPU plumbing — [Skia/Avalonia.Skia/PlatformRenderInterface.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Skia/Avalonia.Skia/PlatformRenderInterface.cs)
- Platform GPU abstraction (IPlatformGraphics) — [Avalonia.Base/Platform/IPlatformGpu.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/IPlatformGpu.cs)

Exercise
- Create a small page with an Image and a TextBlock. Try these:
  1) Set BitmapInterpolationMode to LowQuality, then HighQuality while scaling the image; observe differences
  2) Toggle TextRenderingMode between Antialias and Aliased on small font sizes; note readability
  3) Start the app with UseSkia(new SkiaOptions { UseOpacitySaveLayer = true }) and layer two semi‑transparent panels; compare visuals and measure frame time on an animated resize

What’s next
- Next: [Chapter 23](Chapter23.md)
