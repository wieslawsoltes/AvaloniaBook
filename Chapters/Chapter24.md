# 24. Performance, diagnostics, and DevTools

Goal: Give you a practical toolkit to find, understand, and fix performance issues in Avalonia apps — using logs, built‑in DevTools, and lightweight measurements.

Why it matters: Most “slow UI” reports aren’t about the renderer — they’re caused by excessive layout, re‑templating, heavy data binding, non‑virtualized lists, or expensive work on the UI thread. Measure first. Then change one thing at a time.

What you’ll learn
- When and how to measure (and why Release builds matter)
- Enabling logs and choosing log areas
- Attaching and using DevTools (F12)
- Reading debug overlays (FPS, dirty rects, layout/render graphs)
- A simple performance checklist and fixes

1) Measure first (small, reliable checks)
- Run your app in Release: JIT and inlining matter. A quick check is to run both Debug and Release and compare feel/fps.
- Use a stopwatch for hot code paths: time just the suspected section. Don’t time entire startup at first — narrow it down.
- Reproduce with small data: isolate the control or page that’s slow, then scale up data size gradually to see growth patterns.
- Change one thing at a time: after each small change, re‑measure.

2) Enable logs and tracing
Avalonia has a flexible logging sink system. You can send logs to System.Diagnostics.Trace, a TextWriter, or a custom delegate via AppBuilder extension methods. See source: LoggingExtensions.cs
- GitHub: [Avalonia.Controls/LoggingExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/LoggingExtensions.cs)

Common setup patterns

C#: enable logs to Trace

AppBuilder ConfigureAppLogging(AppBuilder builder)
{
    // Log selected areas at Information or Warning to reduce noise.
    return builder.LogToTrace(
        Avalonia.Logging.LogEventLevel.Information,
        "Binding", "Property", "Layout", "Render" // pick the areas you care about
    );
}

C#: log to a rolling file

using var writer = new StreamWriter("avalonia.log", append: true) { AutoFlush = true };
BuildAvaloniaApp().LogToTextWriter(writer, Avalonia.Logging.LogEventLevel.Information, "Binding", "Property");

Notes
- Areas are strings (see Avalonia.Logging.LogArea constants in the source). Start with “Binding”, “Layout”, “Render”, “Property”.
- Use Information while investigating, then raise to Warning or Error in production to keep output lean.

3) Attach DevTools (F12) and what it offers
DevTools ships with Avalonia and can be attached to a TopLevel (Window) or to the Application. The default open gesture is F12. See DevToolsExtensions.cs
- GitHub: [Avalonia.Diagnostics/DevToolsExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/DevToolsExtensions.cs)

Attach to a window (typical desktop)

public override void OnFrameworkInitializationCompleted()
{
    if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime d)
        d.MainWindow = new MainWindow();

    base.OnFrameworkInitializationCompleted();
    this.AttachDevTools(); // F12 to open
}

Attach with options (choose startup screen, etc.)

this.AttachDevTools(new Avalonia.Diagnostics.DevToolsOptions
{
    StartupScreenIndex = 1, // open on a specific monitor if you have multiple
});

Tip: Only enable DevTools in debug builds or behind a flag if you ship your app to end‑users.

What’s inside DevTools (high‑level tour)
- Visual Tree: inspect hierarchy, pick a control on screen, see its size, properties, and pseudo‑classes (:pointerover, :pressed, etc.).
- Logical Tree: inspect content and data template relationships — useful for understanding DataContext and templated children.
- Properties & Styles: live property viewer with resources and styles; toggle pseudo‑classes to see state‑based styles.
- Layout Explorer: see measure/arrange sizes and constraints; helps pinpoint “why is this control so big/small?”.
- Events: watch routed events fire as you interact (pointer, key, etc.).
- Hotkeys page and settings: view/change the gesture to open DevTools.
- Highlight adorners: enable highlighting to see layout bounds and hit test areas of the selected control.

Extra helpers in the repo
- Visual tree printing helper: VisualTreeDebug.PrintVisualTree(visual) — useful for quick console diagnostics.
  Source: [Avalonia.Diagnostics/Diagnostics/VisualTreeDebug.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/VisualTreeDebug.cs)

4) Read the debug overlays (your real‑time dashboard)
DevTools exposes toggles for debug overlays backed by the RendererDebugOverlays enum. Source files:
- RendererDebugOverlays.cs: [Avalonia.Base/Rendering/RendererDebugOverlays.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDebugOverlays.cs)
- Where DevTools toggles them: Diagnostics MainViewModel: [Avalonia.Diagnostics/Diagnostics/ViewModels/MainViewModel.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/ViewModels/MainViewModel.cs)

Overlays you can enable
- FPS: shows frames per second to gauge overall responsiveness.
- DirtyRects: draws the areas that are actually repainted each frame — if the whole window repaints, you’ll see it.
- LayoutTimeGraph: a rolling chart of layout time — spikes hint at measure/arrange cost or re‑layout storms.
- RenderTimeGraph: a rolling chart of render time — spikes hint at custom drawing/bitmap work, or GPU uploads.

How to use overlays effectively
- Turn on FPS + RenderTimeGraph. Interact with your slow view. Do spikes correlate with pointer moves, scrolling, or data updates?
- If dirty rects cover the entire window on small changes, find what’s invalidating broadly (global properties, effects, or a single control that invalidates too aggressively).
- Combine LayoutTimeGraph with DevTools Layout Explorer to find which subtree is causing repeated measures.

5) Quick performance checklist (fix the common causes)
- Virtualize long lists: use ItemsPanel with VirtualizingStackPanel when appropriate. Keep item templates simple and cheap.
- Avoid re‑creating heavy visuals: prefer bindings/state changes over replacing entire controls or DataTemplates repeatedly.
- Defer expensive work off the UI thread: use async/await and IProgress to report progress to the UI.
- Use images wisely: prefer correct sizes to avoid runtime scaling; choose BitmapInterpolationMode carefully when scaling.
  Per‑visual RenderOptions are available and can be pushed during drawing.
  Source: RenderOptions.cs — [Avalonia.Base/Media/RenderOptions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs)
- Cache and reuse text/geometry where possible: freeze re‑usable geometries, keep FormattedText or GlyphRun if you render often.
- Minimize layout churn: avoid frequently changing properties that trigger re‑measure/re‑arrange for large subtrees.
- Measure and render in release: always verify improvements in Release builds.

6) DevTools vs. logs — when to use which
- Use DevTools first when the problem is “visual”: too many re‑layouts, big dirty rects, low FPS only when hovering/scrolling.
- Use logs when the problem is “structural”: noisy bindings, property change storms, repeated template application, or unexpected errors.
- Use both together: turn on overlays and collect minimal logs (Information) to correlate what happened and when.

7) Troubleshooting
- DevTools doesn’t open: ensure AttachDevTools is called after App initialization (e.g., at the end of OnFrameworkInitializationCompleted). If you changed the hotkey, verify the gesture. See DevToolsExtensions remarks in source.
- Overlays don’t show: make sure the DevTools debug overlay toggles are enabled in the DevTools UI; some overlays need a frame or two to appear.
- Logs too noisy: reduce the level (Warning) or restrict areas to the ones you’re investigating.
- Release is fast, Debug is slow: that’s expected — use Release for realistic performance checks.

Exercise
- Add this.AttachDevTools() to your app and open DevTools with F12. Turn on FPS and RenderTimeGraph. Interact with your slowest view and note the pattern.
- Enable logging to Trace at Information for areas: Binding, Property, Layout, Render. Reproduce the issue and look for bursts.
- Apply one fix from the checklist (e.g., replace an ItemsPanel with VirtualizingStackPanel or simplify a DataTemplate). Re‑measure: did FPS improve or did render/layout spikes shrink?

Look under the hood (source links)
- DevTools attach helpers: [Avalonia.Diagnostics/DevToolsExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/DevToolsExtensions.cs)
- DevTools options and window plumbing: [Avalonia.Diagnostics/Diagnostics/DevToolsOptions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/DevToolsOptions.cs) and [Avalonia.Diagnostics/Diagnostics/DevTools.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/DevTools.cs)
- Debug overlays enum: [Avalonia.Base/Rendering/RendererDebugOverlays.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDebugOverlays.cs)
- Where DevTools toggles overlays: [Avalonia.Diagnostics/Diagnostics/ViewModels/MainViewModel.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/ViewModels/MainViewModel.cs)
- Logging extensions: [Avalonia.Controls/LoggingExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/LoggingExtensions.cs)
- Per‑visual render options: [Avalonia.Base/Media/RenderOptions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs)

What’s next
- Next: [Chapter 25](Chapter25.md)
