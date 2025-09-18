# 1. Welcome to Avalonia and MVVM

Goal
- Understand what Avalonia is today, how it has grown, and where it is heading.
- Learn the roles of C#, XAML, and MVVM (with their core building blocks) inside an Avalonia app.
- Map Avalonia's layered architecture so you can navigate the source confidently.
- Compare Avalonia with WPF, WinUI, .NET MAUI, and Uno to make an informed platform choice.
- Follow the journey from `AppBuilder.Configure` to the first window, and know how to inspect it in the samples.

Why this matters
- Picking a UI framework is a strategic decision. Knowing Avalonia's history, roadmap, and governance helps you judge its momentum.
- Understanding the framework layers and MVVM primitives prevents "magic" and makes documentation, samples, and source code less intimidating.
- Being able to contrast Avalonia with sibling frameworks keeps expectations realistic and helps you explain the choice to teammates.

Avalonia in simple words
- Avalonia is an open-source, cross-platform UI framework. One code base targets Windows, macOS, Linux, Android, iOS, and the browser (WebAssembly).
- It brings a modern Fluent-inspired theme, a deep control set, rich data binding, and tooling such as DevTools and the XAML Previewer.
- If you have WPF experience, Avalonia feels familiar; if you are new, you get gradual guidance with MVVM, XAML, and C#.

A short history, governance, and roadmap
- Origins (2013-2018): The project began as a community effort to bring a modern, cross-platform take on the WPF programming model.
- Maturing releases (0.9-0.10): Stabilised control set, styling, and platform backends while adding mobile and browser support.
- Avalonia 11 (2023): The 11.x line introduced the Fluent 2 theme refresh, compiled bindings, a new rendering backend, and long-term support. New minor updates land roughly every 2-3 months with patch releases in between.
- Governance: AvaloniaUI is stewarded by a core team at Avalonia Solutions Ltd. with an active GitHub community. Development is fully open with public issue tracking and roadmap discussions.
- Roadmap themes: continuing Fluent updates, performance and tooling investments, deeper designer integration, and steady platform parity across desktop, mobile, and web.

How Avalonia is layered
- **Avalonia.Base**: foundational services--dependency properties (`AvaloniaProperty`), threading, layout primitives, and rendering contracts. Source: [src/Avalonia.Base](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base).
- **Avalonia.Controls**: the control set, templated controls, panels, windowing, and lifetimes. Source: [src/Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls) with the `Application` class in [Application.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Application.cs).
- **Styling and themes**: styles, selectors, control themes, and Fluent resources. Source: [src/Avalonia.Base/Styling](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Styling) and [src/Avalonia.Themes.Fluent](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent).
- **Markup**: XAML parsing, compiled XAML, and the runtime loader used at startup. Source: [src/Avalonia.Markup.Xaml](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Markup.Xaml) with [AvaloniaXamlLoader.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs).
- **Platform backends**: per-OS integrations--for example [src/Windows/Avalonia.Win32](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Windows/Avalonia.Win32), [src/Avalonia.Native](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Native), [src/Android/Avalonia.Android](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Android/Avalonia.Android), [src/iOS/Avalonia.iOS](https://github.com/AvaloniaUI/Avalonia/tree/master/src/iOS/Avalonia.iOS), and [src/Browser/Avalonia.Browser](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Browser/Avalonia.Browser).

C#, XAML, and MVVM--who does what
- **C#**: application startup (`AppBuilder`), services, models, and view models. Logic lives in strongly typed classes.
- **XAML**: declarative UI markup--controls, layout, styles, resources, and data templates.
- **MVVM**: separates responsibilities. The View (XAML) binds to a ViewModel (C#) which exposes Models and services. Tests target ViewModels and models directly.

MVVM building blocks you should recognise early
- `INotifyPropertyChanged`: standard .NET interface. When a ViewModel property raises `PropertyChanged`, bound controls refresh.
- `AvaloniaProperty`: Avalonia's dependency property system (see [AvaloniaProperty.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/AvaloniaProperty.cs)) powers styling, animation, and templated control state.
- Binding expressions: XAML bindings are parsed and applied via the XAML loader. The runtime loader lives in [AvaloniaXamlLoader.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs).
- Commands: typically `ICommand` implementations on the ViewModel (plain or via libraries such as CommunityToolkit.Mvvm or ReactiveUI) so buttons and menu items can invoke logic.
- Data templates: define how ViewModels render in lists and navigation. We will use them extensively starting in Chapter 3.

From `AppBuilder.Configure` to the first window (annotated flow)
1. **Program entry point** creates a builder: `BuildAvaloniaApp()` returns `AppBuilder.Configure<App>()`.
2. **Platform detection** (`UsePlatformDetect`) selects the right backend (Win32, macOS, X11, Android, iOS, Browser).
3. **Rendering setup** (`UseSkia`) chooses the rendering pipeline--Skia by default.
4. **Logging and services** (`LogToTrace`, custom DI) configure diagnostics.
5. **Start a lifetime**: `StartWithClassicDesktopLifetime(args)` (desktop) or `StartWithSingleViewLifetime` (mobile/browser). Lifetimes live under [ApplicationLifetimes](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/ApplicationLifetimes).
6. **`Application` initialises**: `App.OnFrameworkInitializationCompleted` is called; this is where you typically create and show the first `Window` or set `MainView`.
7. **XAML loads**: `AvaloniaXamlLoader` reads `App.axaml` and your window/user control XAML.
8. **Bindings connect**: when the window's data context is set to a ViewModel, bindings listen for `PropertyChanged` events and keep UI and data in sync.

Tour the ControlCatalog (your guided sample)
- Clone the repo (or open the [ControlCatalog sample](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog)).
- `ControlCatalog.Desktop` demonstrates desktop controls, theming, and navigation. Inspect `App.axaml`, `MainWindow.axaml`, and their code-behind to see how `AppBuilder` and MVVM connect.
- Use DevTools (press `F12` when running the sample) to inspect bindings, the visual tree, and live styles.
- Explore the repository mapping: the `Button` page in the catalog points to code under [src/Avalonia.Controls/Button.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Button.cs); style resources originate from Fluent theme XAML under [src/Avalonia.Themes.Fluent/Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent/Controls).

Why Avalonia instead of...
- **WPF** (Windows only): mature desktop tooling and huge ecosystem, but no cross-platform story. Avalonia keeps the mental model while expanding to macOS, Linux, mobile, and web.
- **WinUI 3** (Windows 10/11): modern Windows UI with native Win32 packaging. Great for Windows-only solutions; Avalonia wins when you must ship beyond Windows.
- **.NET MAUI**: Microsoft's cross-platform evolution of Xamarin.Forms focused on mobile-first UI. Avalonia emphasises desktop parity, theming flexibility, and XAML consistency across platforms.
- **Uno Platform**: reuses WinUI XAML across platforms via WebAssembly and native controls. Avalonia offers a single rendering pipeline (Skia) for consistent visuals when you prefer pixel-perfect fidelity over native look-and-feel.

Repository landmarks (bookmark these)
- Framework source: [src](https://github.com/AvaloniaUI/Avalonia/tree/master/src)
- Samples: [samples](https://github.com/AvaloniaUI/Avalonia/tree/master/samples)
- Docs: [docs](https://github.com/AvaloniaUI/Avalonia/tree/master/docs)
- ControlCatalog entry point: [ControlCatalog.csproj](https://github.com/AvaloniaUI/Avalonia/blob/master/samples/ControlCatalog/ControlCatalog.csproj)

Check yourself
- Can you describe how Avalonia evolved to its current release cadence and governance model?
- Can you name the key Avalonia layers (Base, Controls, Markup, Themes, Platforms) and what each provides?
- Can you explain the MVVM building blocks (`INotifyPropertyChanged`, `AvaloniaProperty`, bindings, commands) in your own words?
- Can you sketch the `AppBuilder` startup steps that end with a `Window` or `MainView` being shown?
- Can you list one reason you might choose Avalonia over WPF, WinUI, .NET MAUI, or Uno?

Practice and validation
- Clone the Avalonia repository, build, and run the desktop ControlCatalog. Set a breakpoint in `Application.OnFrameworkInitializationCompleted` inside `App.axaml.cs` to watch the lifetime hand-off.
- While ControlCatalog runs, open DevTools (F12) and track a ViewModel property change (for example, toggle a CheckBox) in the binding diagnostics panel to see `PropertyChanged` events flowing.
- Inspect the source jump-offs for `Application` ([Application.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Application.cs)), `AvaloniaProperty` ([AvaloniaProperty.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/AvaloniaProperty.cs)), and the XAML loader ([AvaloniaXamlLoader.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs)). Note how the pieces you just read about appear in real code.

What's next
- Next: [Chapter 2](Chapter02.md)
