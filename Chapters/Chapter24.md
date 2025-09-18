# 24. Performance, diagnostics, and DevTools

Goal
- Diagnose and fix Avalonia performance issues using measurement, logging, DevTools, and overlays.
- Focus on the usual suspects: non-virtualized lists, layout churn, binding storms, expensive rendering.
- Build repeatable measurement habits (Release builds, small reproducible tests).

Why this matters
- "UI feels slow" is common feedback. Without data, fixes are guesswork.
- Avalonia provides built-in diagnostics (DevTools, overlays) and logging hooks--learn to leverage them.

Prerequisites
- Chapter 22 (rendering pipeline), Chapter 17 (async patterns), Chapter 16 (custom controls and lists).

## 1. Measure before changing anything

- Run in Release (`dotnet run -c Release`). JIT optimizations affect responsiveness.
- Use a small repro: isolate the view or control and reproduce with minimal data before optimizing.
- Use high-resolution timers only around suspect code sections; avoid timing entire app startup on the first pass.
- Change one variable at a time and re-measure to confirm impact.

## 2. Logging

Enable logging per area using `AppBuilder` extensions (see [`LoggingExtensions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/LoggingExtensions.cs)).

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .LogToTrace(LogEventLevel.Information, new[] { LogArea.Binding, LogArea.Layout, LogArea.Render, LogArea.Property })
    .StartWithClassicDesktopLifetime(args);
```

- Areas: see `Avalonia.Logging.LogArea` (`Binding`, `Layout`, `Render`, `Property`, `Control`, etc.).
- Reduce noise by lowering level (`Warning`) or limiting areas once you identify culprit.
- Optionally log to file via `LogToTextWriter`.

## 3. DevTools (F12)

Attach DevTools after app initialization:

```csharp
public override void OnFrameworkInitializationCompleted()
{
    // configure windows/root view
    this.AttachDevTools();
    base.OnFrameworkInitializationCompleted();
}
```

Supports options: `AttachDevTools(new DevToolsOptions { StartupScreenIndex = 1 })` for multi-monitor setups.

### DevTools tour

- **Visual Tree**: inspect hierarchy, properties, pseudo-classes, and layout bounds.
- **Logical Tree**: understand DataContext/template relationships.
- **Layout Explorer**: measure/arrange info, constraints, actual sizes.
- **Events**: view event flow; detect repeated pointer/keyboard events.
- **Styles & Resources**: view applied styles/resources; test pseudo-class states.
- **Hotkeys/Settings**: adjust F12 gesture.

Use the target picker to select elements on screen and inspect descendants/ancestors.

## 4. Debug overlays (`RendererDebugOverlays`)

Access via DevTools "Diagnostics" pane or programmatically:

```csharp
if (this.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
{
    desktop.MainWindow.AttachedToVisualTree += (_, __) =>
    {
        if (desktop.MainWindow?.Renderer is { } renderer)
            renderer.DebugOverlays = RendererDebugOverlays.Fps | RendererDebugOverlays.DirtyRects;
    };
}
```

Overlays include:
- `Fps` -- frames per second.
- `DirtyRects` -- regions redrawn each frame.
- `LayoutTimeGraph` -- layout duration per frame.
- `RenderTimeGraph` -- render duration per frame.

Interpretation:
- Large dirty rects = huge redraw areas; find what invalidates entire window.
- LayoutTime spikes = heavy measure/arrange; check Layout Explorer to spot bottleneck.
- RenderTime spikes = expensive drawing (big bitmaps, custom rendering).

## 5. Performance checklist

Lists & templates
- Use virtualization (`VirtualizingStackPanel`) for list controls.
- Keep item templates light; avoid nested panels and convert heavy converters to cached data.
- Pre-compute value strings/colors in view models to avoid per-frame conversion.

Layout & binding
- Minimize property changes that re-trigger layout of large trees.
- Avoid swapping entire templates when simple property changes suffice.
- Watch for binding storms (log `LogArea.Binding`). Debounce or use state flags.

Rendering
- Use vector assets where possible; for bitmaps, match display resolution.
- Set `RenderOptions.BitmapInterpolationMode` for scaling to avoid blurry or overly expensive scaling.
- Cache expensive geometries (`StreamGeometry`), `FormattedText`, etc.

Async & threading
- Move heavy work off UI thread (async/await, `Task.Run` for CPU-bound tasks).
- Use `IProgress<T>` to report progress instead of manual UI thread dispatch.

Profiling
- Use `.NET` profilers (dotTrace, PerfView, dotnet-trace) to capture CPU/memory.
- For GPU, use platform tools if necessary (RenderDoc for GL/DirectX when supported).

## 6. Considerations per platform

- Windows: ensure GPU acceleration enabled; check drivers. Acrylic/Mica can cost extra GPU time.
- macOS: retina scaling multiplies pixel counts; ensure vector assets and efficient drawing.
- Linux: varying window managers/compositors. If using software rendering, expect lower FPS--optimize accordingly.
- Mobile & Browser: treat CPU/GPU resources as more limited; avoid constant redraw loops.

## 7. Automation & CI

- Combine unit tests with headless UI tests (Chapter 21).
- Create regression tests for performance-critical features (measure time for known operations, fail if above threshold).
- Capture baseline metrics (FPS, load time) and compare across commits; tools like BenchmarkDotNet can help (for logic-level measurements).

## 8. Workflow summary

1. Reproduce in Release with logging disabled -> measure baseline.
2. Enable DevTools overlays (FPS, dirty rects, layout/render graphs) -> identify pattern.
3. Enable targeted logging (Binding/Layout/Render) -> correlate with overlays.
4. Apply fix (virtualization, caching, reducing layout churn)
5. Re-measure with overlays/logs to confirm improvements.
6. Capture notes and, if beneficial, automate tests for future regressions.

## 9. Practice exercises

1. Attach DevTools to your app, enable `RendererDebugOverlays.Fps`, and record FPS before/after virtualizing a long list.
2. Log `Binding`/`Property` areas and identify recurring property changes; batch or throttle updates.
3. Measure layout time via overlay before/after simplifying a nested panel layout; compare results.
4. Add a unit/UITest that asserts a time-bound operation completes under a threshold (e.g., load 1,000 items). Use Release build to verify.
5. Capture a profile with `dotnet-trace` or `dotnet-counters` during a slow interaction; interpret CPU/memory graphs.

## Look under the hood (source bookmarks)
- DevTools attach helpers: [`DevToolsExtensions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/DevToolsExtensions.cs)
- DevTools view models (toggling overlays): [`MainViewModel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/ViewModels/MainViewModel.cs)
- Renderer overlays: [`RendererDebugOverlays.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDebugOverlays.cs)
- Logging infrastructure: [`LogArea`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Logging/LogArea.cs)
- RenderOptions (quality settings): [`RenderOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs)
- Layout diagnostics: [`LayoutHelper`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Layout/LayoutHelper.cs)

## Check yourself
- Why must performance measurements be done in Release builds?
- Which overlay would you enable to track layout time spikes? What about render time spikes?
- How do DevTools and logging complement each other?
- List three common causes of UI lag and their fixes.
- How would you automate detection of a performance regression?

What's next
- Next: [Chapter 25](Chapter25.md)
