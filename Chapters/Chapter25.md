# 25. Design‑time tooling and the XAML Previewer

In this chapter you’ll make the Previewer work for you every day. You’ll learn how Avalonia’s design mode works, how to feed realistic sample data to your views, how to preview styles and resources, and how to avoid common previewer pitfalls that waste time.

What you’ll learn
- How the Previewer and design mode work at a high level
- Design-time attached properties (Design.DataContext, Design.Width/Height, DesignStyle) and when to use them
- Feeding sample data safely (without running production services)
- Previewing resource dictionaries and styles with Design.PreviewWith
- Practical IDE usage tips and common troubleshooting

Big picture: how the Previewer works
- Your IDE opens a small “designer host” process that loads your view or resource XAML and sets the app into design mode. Internally, the host uses a special entry point and windowing platform to run your XAML under tighter control. Design mode signals are propagated so your code can opt out of expensive work.
- Key signals and helpers:
  - Design.IsDesignMode is true when running in a designer/previewer session. Your code can branch on this to skip real services, network calls, or timers. See Design.IsDesignMode in source.
  - A XAML compiler transformer removes all Design.* attached properties in normal runtime so they don’t affect shipping builds, and applies them in design mode when loading XAML for preview.
  - The preview host uses a dedicated window implementation and windowing platform shim to render your views without relying on a user’s desktop environment.

Design-time attached properties you’ll actually use
- Design.DataContext: Provide lightweight sample view models so bindings show meaningful data in the Previewer without constructing your real services.
- Design.Width and Design.Height: Force a control’s size in the designer so you can style it comfortably without relying on outer layout.
- Design.DesignStyle: Inject an extra style only in design mode to highlight bounds, show placeholder backgrounds, or adjust layout just for preview.

Example: Design-time DataContext with a simple sample VM
- Add a small sample type (keep it in your UI project for easy access):
  - public class SamplePerson { public string Name { get; set; } = "Ada"; public int Age { get; set; } = 42; }
- Use it in XAML (map the namespace and attach Design.DataContext). At runtime, the transformer strips this, so your real DataContext takes over.

Example: Sizing and design-only style
- You can set Design.Width/Design.Height to get a consistent designer canvas size.
- Use Design.DesignStyle to add a dashed outline, helpful for templated controls while iterating.

Previewing styles and resources with Design.PreviewWith
- You can preview a ResourceDictionary or style in isolation by providing a small host control with Design.PreviewWith. This renders your dictionary wrapped in the host, so you can iterate on colors/templates quickly.
- Typical pattern in a ResourceDictionary:
  - Add a simple host, such as a Border or Panel with a child that uses your styles.
  - Set Design.PreviewWith to that host so the Previewer knows what to render for this dictionary.

Safety first: what not to run in design mode
- Never start network requests, database connections, background threads, or timers from view constructors if Design.IsDesignMode is true.
- Avoid static initialization that reaches out to the environment (files, registry, user profile) in design mode.
- If your ViewModel normally uses services, inject stub/fake implementations when Design.IsDesignMode is true, or use the simple POCO sample objects shown above.

Practical IDE tips
- Keep your view constructors cheap and side-effect free. Heavy work belongs in async commands triggered by user actions, not in constructors or OnApplyTemplate.
- Prefer simple sample models for preview data over spinning up your composition root.
- If the previewer crashes on a view, open a smaller piece (e.g., a UserControl used inside that view) to narrow the issue.
- If a style/resource dictionary doesn’t preview, add Design.PreviewWith with a minimal host and a representative control that consumes your style.

Troubleshooting checklist
- Blank or flickering preview: remove animations/triggers, reduce effects, or temporarily comment expensive bindings. Heavy effects can overwhelm the design host.
- Crashes on load: guard code with if (Design.IsDesignMode) return; in constructors/init paths that run in the designer.
- Stale data: rebuild the project to flush caches. Some IDEs keep a warm previewer instance.
- Missing resources: verify avares URIs and resource include scopes. In design mode, the designer may load only the UI assembly; ensure resources are in the correct project.
- Platform assumptions: don’t assume a particular OS/GPU. The previewer may use a special windowing backend.

Look under the hood (source tour)
- Design-time API surface (Design.*): Design.cs
  - [Avalonia.Controls/Design.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Design.cs)
- Designer XAML loader and property application:
  - [Avalonia.DesignerSupport/DesignWindowLoader.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/DesignWindowLoader.cs)
- Previewer entry point and design mode enablement:
  - [Avalonia.DesignerSupport/Remote/RemoteDesignerEntryPoint.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/Remote/RemoteDesignerEntryPoint.cs)
- XAML compiler transformer that strips Design.* at runtime:
  - [Avalonia.Markup.Xaml.Loader/CompilerExtensions/Transformers/AvaloniaXamlIlDesignPropertiesTransformer.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml.Loader/CompilerExtensions/Transformers/AvaloniaXamlIlDesignPropertiesTransformer.cs)
- Designer window/platform shim used by the preview host:
  - [Avalonia.DesignerSupport/Remote/PreviewerWindowImpl.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/Remote/PreviewerWindowImpl.cs)
  - [Avalonia.DesignerSupport/Remote/PreviewerWindowingPlatform.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/Remote/PreviewerWindowingPlatform.cs)
- PlatformManager helpers used in designer mode:
  - [Avalonia.Controls/Platform/PlatformManager.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Platform/PlatformManager.cs)
- XAML runtime loader with designMode parameter:
  - [Avalonia.Markup.Xaml.Loader/AvaloniaRuntimeXamlLoader.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml.Loader/AvaloniaRuntimeXamlLoader.cs)

Exercise: Make a view designer-friendly
1) Pick an existing UserControl in your app that currently shows poorly in the Previewer.
2) Create a tiny sample POCO model with realistic values and attach it with Design.DataContext.
3) Add Design.Width/Design.Height so you have a predictable canvas while styling.
4) If the view relies on styles from a dictionary, add Design.PreviewWith to that dictionary with a host and a representative control to preview the style.
5) Confirm the preview shows your sample data and styles. Remove any unnecessary design-only helpers once you’re done.


What’s next
- Next: [Chapter 26](Chapter26.md)
