# Avalonia Book Plan

A beginner-friendly book about building cross-platform apps with Avalonia (C#/XAML/MVVM). Written in clear, simple English with no hidden steps.

## Audience
- Beginners to C#, XAML, and MVVM
- Developers moving from WPF/WinForms/Web UI to cross‑platform desktop/mobile/web

## Promise
- Learn Avalonia step by step with gentle explanations and hands‑on tasks
- Understand MVVM, XAML, data binding, theming, navigation, testing, and deployment
- Build for Windows, macOS, Linux, Android, iOS, and the Browser (WASM)

## Outcomes
- Create production-grade, cross‑platform UI apps
- Structure apps using MVVM (with and without ReactiveUI)
- Style apps with Fluent theme and custom controls
- Optimize, test, and publish

## Teaching Approach
- Small chapters, plain language, concrete examples
- Every chapter contains: goal, why it matters, step‑by‑step, check yourself, look under the hood, extra practice
- “Look under the hood” links point to real files in the Avalonia repo

## Repository anchors (for cross‑referencing)
- Core source root: [src](https://github.com/AvaloniaUI/Avalonia/tree/master/src)
- Samples root: [samples](https://github.com/AvaloniaUI/Avalonia/tree/master/samples)
- Docs: [docs/index.md](https://github.com/AvaloniaUI/Avalonia/blob/master/docs/index.md), [docs/build.md](https://github.com/AvaloniaUI/Avalonia/blob/master/docs/build.md)
- Startup & lifetimes: 
  - [AppBuilderDesktopExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs)
  - [IClassicDesktopStyleApplicationLifetime.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/IClassicDesktopStyleApplicationLifetime.cs)
  - [ClassicDesktopStyleApplicationLifetime.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs)
- MVVM + ReactiveUI: [src/Avalonia.ReactiveUI](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.ReactiveUI)
- Controls & themes: 
  - [src/Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
  - [src/Avalonia.Controls.DataGrid](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls.DataGrid)
  - [src/Avalonia.Controls.ColorPicker](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls.ColorPicker)
  - [src/Avalonia.Themes.Fluent](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent)
- Rendering (Skia): [src/Skia/Avalonia.Skia](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Skia/Avalonia.Skia)
- Platforms: [src/Windows](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Windows), [src/Avalonia.X11](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.X11), [src/Avalonia.Native](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Native), [src/Android](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Android), [src/iOS](https://github.com/AvaloniaUI/Avalonia/tree/master/src/iOS), [src/Browser](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Browser), [src/Headless](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Headless)
- Diagnostics/DevTools: [src/Avalonia.Diagnostics](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Diagnostics)
- Designer/Previewer: [src/Avalonia.DesignerSupport](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.DesignerSupport)

Note: In chapter content, always link to source using GitHub URLs under https://github.com/AvaloniaUI/Avalonia and never local paths like external/Avalonia.

## Book structure (5 parts, 27 chapters)

### Part I — Foundations you can’t skip
1. Welcome to Avalonia and MVVM — what Avalonia is; C#/XAML/MVVM in simple terms; repo tour
2. Set up tools and build your first project — .NET SDK, IDE, templates, run ControlCatalog, build from source
3. Your first UI: layouts, controls, and XAML basics — XAML, common controls, simple layouts, previewing
4. Application startup: AppBuilder and lifetimes — what AppBuilder configures; desktop vs single‑view lifetimes; `UseSkia`

### Part II — Building beautiful and useful UIs
5. Layout system without mystery — measure/arrange in plain words; panels; alignment and spacing
6. Controls tour you’ll actually use — common controls; DataGrid; ColorPicker; explore ControlCatalog
7. Fluent theming and styles made simple — themes, styles, resource dictionaries; dynamic vs static resources
8. Data binding basics you’ll use every day — DataContext, binding modes, converters, validation
9. Commands, events, and user input — commands vs events; focus; keyboard/mouse/gestures
10. Working with resources, images, and fonts — images/icons; fonts; DPI explained simply

### Part III — Application patterns that scale
11. MVVM in depth (with or without ReactiveUI) — separation of concerns; ReactiveUI quick start; routing; reactive commands
12. Navigation, windows, and lifetimes — multi‑window desktop; single‑view mobile; dialogs and shell patterns
13. Menus, dialogs, tray icons, and system features — menus/context menus; file dialogs; tray/notifications
14. Lists, virtualization, and performance — why virtualization matters; list performance patterns
15. Accessibility and internationalization — keyboard navigation; contrast; localization basics
16. Files, storage, drag/drop, and clipboard — safe file IO patterns; drag/drop; clipboard
17. Background work and networking — async/await; progress reporting; simple HTTP calls

### Part IV — Cross‑platform deployment without headaches
18. Desktop targets: Windows, macOS, Linux — platform options and differences; windowing
19. Mobile targets: Android and iOS — lifecycle differences; input; resources; mobile ControlCatalog
20. Browser (WebAssembly) target — what WASM is; Skia + WebGL high‑level; expectations
21. Headless and testing — snapshot rendering; when and how to use headless mode

### Part V — Rendering, tooling, optimization, and contributing
22. Rendering pipeline in plain words — CPU/GPU; Skia; OpenGL/Metal/Vulkan at a glance; Skia options
23. Custom drawing and custom controls — DrawingContext; when to derive; templating and styling
24. Performance, diagnostics, and DevTools — measure first; logs and tracing; DevTools usage
25. Design‑time tooling and the XAML Previewer — how previewer works; IDE usage; safety
26. Build, publish, and deploy — publishing for each platform; self‑contained vs framework‑dependent
27. Read the source, contribute, and grow — learning from source; tests and samples; contributing

## Teaching style commitments (no hidden steps)
- Explain terms on first use
- Always show where configuration happens (AppBuilder, `UseSkia`, `UseReactiveUI`)
- Contrast “what” and “why” before “how”
- Use small diagrams and screenshots lists for startup, binding, rendering
- One small exercise per chapter with expected result
- “Look under the hood” boxes link to real files in the repo

## Suggested learning path
- Part I in order (Ch. 1–4)
- Part II as needed: 5 → 8 → 7 → 9 → 10
- Part III next for structure (Ch. 11–17)
- Part IV for platform targets and shipping
- Part V for advanced topics and refinement

## TOC Progress Tracker

Use this table to track writing progress for each chapter. Status values: Not started, Drafting, In review, Done.

| Part | # | Chapter Title | Status | Notes |
|------|---:|----------------|--------|-------|
| I | 1 | Welcome to Avalonia and MVVM | Drafting | Initial draft added; covers what Avalonia is, C#/XAML/MVVM basics, and a repo overview |
| I | 2 | Set up tools and build your first project | Drafting | Initial draft added; setup, templates, build/run, and a project file tour |
| I | 3 | Your first UI: layouts, controls, and XAML basics | Drafting | Initial draft added; includes layouts, controls, and XAML basics |
| I | 4 | Application startup: AppBuilder and lifetimes | Drafting | Initial draft added; covers AppBuilder, desktop vs single‑view lifetimes |
| II | 5 | Layout system without mystery | Drafting | Draft covers measure/arrange, StackPanel, Grid, DockPanel, WrapPanel |
| II | 6 | Controls tour you’ll actually use | Drafting | Draft covers core controls, menus, context menus, tooltips, and ControlCatalog tour |
| II | 7 | Fluent theming and styles made simple | Drafting | Draft covers Fluent theme, light/dark variants, resources, styles/selectors, StaticResource vs DynamicResource, and a runtime theme switcher |
| II | 8 | Data binding basics you’ll use every day | Drafting | Draft covers DataContext, binding modes, element-to-element binding, collections/SelectedItem/DataTemplates, simple converter, and minimal validation |
| II | 9 | Commands, events, and user input | Drafting | Draft covers events vs commands, ICommand/RelayCommand, Button/MenuItem/KeyBinding.Command, CommandParameter, pointer/keyboard events, focus/tab, and patterns |
| II | 10 | Working with resources, images, and fonts | Drafting | Draft covers avares URIs and AvaloniaResource assets, Image/ImageBrush usage, vector icons with Path, custom fonts via FontFamily with #face, and DPI basics |
| III | 11 | MVVM in depth (with or without ReactiveUI) | Drafting | Draft covers MVVM responsibilities, INotifyPropertyChanged/ICommand, ViewModel-first DataTemplates, simple navigation and ReactiveUI quick start (ReactiveObject/ReactiveCommand/routing) |
| III | 12 | Navigation, windows, and lifetimes | Drafting | Draft covers lifetimes (ClassicDesktop vs SingleView), App init, windows/ownership, Show vs ShowDialog, simple navigation host, shutdown modes, and file dialogs |
| III | 13 | Menus, dialogs, tray icons, and system features | Drafting | Draft covers in-window Menu and NativeMenuBar, ContextMenu/Flyout, dialog service pattern, tray icon with menu, accelerators, and platform notes |
| III | 14 | Lists, virtualization, and performance | Drafting | Draft covers ItemsControl/ListBox/DataGrid basics, ItemsPanel with VirtualizingStackPanel, lightweight item templates, incremental loading, selection patterns, and performance tips |
| III | 15 | Accessibility and internationalization | Drafting | Draft covers AutomationProperties names/help/live regions, keyboard navigation (IsTabStop/TabIndex/KeyboardNavigation), access keys with AccessText, testing with screen readers, simple .resx-based Localizer with runtime culture switch, FlowDirection for RTL, and default font/fallback guidance |
| III | 16 | Files, storage, drag/drop, and clipboard | Drafting | Draft covers StorageProvider (open/save/folder pickers, filters, well-known folders), safe async file IO, drag-and-drop (events, IDataObject, DoDragDrop), and clipboard (text, data formats) |
| III | 17 | Background work and networking | Drafting | Draft covers async/await patterns, IProgress and cancellation, UI threading/Dispatcher, HttpClient (GET/POST), and file download with progress using IStorageFile |
| IV | 18 | Desktop targets: Windows, macOS, Linux | Drafting | Draft covers window basics (state, size-to-content, startup location, resizability, taskbar/topmost), system decorations and custom chrome (extend client area, BeginMove/ResizeDrag), transparency (TransparencyLevelHint, ActualTransparencyLevel, WindowTransparencyLevel), multiple monitors and scaling (Screens, DesktopScaling/RenderScaling), platform differences, troubleshooting, and exercises |
| IV | 19 | Mobile targets: Android and iOS | Drafting | Draft covers SingleView lifetime, mobile navigation patterns (ContentControl stack/router), touch input, IInputPane for soft keyboard, IInsetsManager for safe areas, platform heads and assets, permissions, and troubleshooting/exercise |
| IV | 20 | Browser (WebAssembly) target | Drafting | Draft covers StartBrowserAppAsync/SetupBrowserAppAsync, BrowserPlatformOptions (RenderingMode WebGL2/WebGL1/Software2D, service worker, file dialog polyfill, managed dispatcher), single‑view lifetime, storage/file dialogs and polyfills, networking/CORS, platform capabilities/limitations, Blazor hosting, troubleshooting, and exercises |
| IV | 21 | Headless and testing | Drafting | Draft covers using Avalonia.Headless with xUnit/NUnit, [AvaloniaFact] runner, simulating input (keyboard/mouse/drag), render ticks, Skia-enabled snapshot capture via GetLastRenderedFrame, Headless VNC option, dispatcher/async patterns, troubleshooting, and exercises |
| V | 22 | Rendering pipeline in plain words | Drafting | Draft explains UI vs render thread, renderer lifecycle (AddDirty/Paint/Start/Stop), Compositor batching/commit/presentation, Skia at the core with GPU/CPU paths, platform GPU abstraction (IPlatformGraphics), ImmediateRenderer vs normal loop, tuning via UseSkia(SkiaOptions) and per‑visual RenderOptions, triggers for redraws, tips, troubleshooting, and an exercise |
| V | 23 | Custom drawing and custom controls | Drafting | Draft explains when to override Render vs use ControlTemplate, DrawingContext primitives and Push* state stack, invalidation via InvalidateVisual and AffectsRender, a full Sparkline custom control example (StreamGeometry + DrawGeometry), a templated Badge control style, tips on caching/measure/arrange, text/images, accessibility/input, troubleshooting, and a practice exercise |
| V | 24 | Performance, diagnostics, and DevTools | Drafting | Draft covers measuring in Release, minimal stopwatch checks, logging via LogToTrace/LogToTextWriter (areas Binding/Property/Layout/Render), attaching DevTools (F12) and options, DevTools panels (Visual/Logical tree, Properties/Styles, Layout Explorer, Events), debug overlays (FPS, DirtyRects, Layout/Render graphs) via RendererDebugOverlays, quick performance checklist (virtualization, avoid re‑templating, async work, image scaling and RenderOptions, caching), troubleshooting, and an exercise |
| V | 25 | Design‑time tooling and the XAML Previewer | Drafting | Draft explains Previewer/design-mode workflow, Design.* attached properties (DataContext, Width/Height, DesignStyle), safe sample data, Design.PreviewWith for resource/style preview, IDE tips, troubleshooting, and an exercise |
| V | 26 | Build, publish, and deploy | Drafting | Draft explains build vs publish, choosing RIDs, framework‑dependent vs self‑contained, single‑file/ReadyToRun/trimming trade‑offs, output locations, platform notes (Windows/macOS/Linux), a pre‑ship checklist, troubleshooting, and an exercise |
| V | 27 | Read the source, contribute, and grow | Drafting | Draft guides exploring the repo (src/tests/samples), building locally, stepping into framework sources, filing great issues, writing high‑quality PRs with tests, contributing to docs and samples, and staying engaged with the community; includes a practical exercise |