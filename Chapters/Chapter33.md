# 33. Code-only startup and architecture blueprint

Goal
- Bootstrap Avalonia apps entirely from C# so you can skip XAML without losing features.
- Structure resources, styles, and themes in code-first projects that still feel modular.
- Integrate dependency injection, services, and lifetimes using the same primitives Avalonia's XAML templates rely on internally.

Why this matters
- Many teams prefer a single-language stack (pure C#) for greater refactorability, dynamic UI, or source generator workflows.
- Understanding the startup pipeline (`AppBuilder`, lifetimes, `Application.RegisterServices`) lets you shape architecture to match modular backends or plug-ins.
- Code-first projects must explicitly wire themes, resources, and styles—knowing the underlying APIs prevents surprises when copying snippets from XAML-centric samples.

Prerequisites
- Chapter 4 (startup and lifetimes) for the `AppBuilder` pipeline.
- Chapter 7 (styling) to recognize how selectors, themes, and resources work.
- Chapter 11 (MVVM) for structuring view-models and locator patterns that code-first projects often lean on.

## 1. Start from `Program.cs`: configuring the builder yourself

Avalonia templates scaffold XAML, but the real work happens in `Program.BuildAvaloniaApp()` (see `external/Avalonia/src/Avalonia.Templates/`). Code-first apps use the same `AppBuilder<TApp>` API.

```csharp
using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.ReactiveUI; // optional: add once for ReactiveUI-centric apps

internal static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        BuildAvaloniaApp()
            .StartWithClassicDesktopLifetime(args);
    }

    private static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .LogToTrace()
            .With(new Win32PlatformOptions
            {
                CompositionMode = new[] { Win32CompositionMode.WinUIComposition } // example tweak
            })
            .With(new X11PlatformOptions { EnableIme = true })
            .With(new AvaloniaNativePlatformOptions { UseDeferredRendering = true })
            .UseSkia();
}
```

Key points from `AppBuilder.cs`:
- `Configure<App>()` wires Avalonia's service locator (`AvaloniaLocator`) with the type parameter you pass.
- `UsePlatformDetect()` resolves the proper backend at runtime. Replace it with `UseWin32()`, `UseAvaloniaNative()`, etc., to force a backend for tests.
- `.UseReactiveUI()` (from `Avalonia.ReactiveUI/AppBuilderExtensions.cs`) registers ReactiveUI's scheduler, command binding, and view locator glue—call it in code-first projects that rely on `ReactiveCommand`.
- `.With<TOptions>()` registers backend-specific option objects. Because you're not using `App.axaml`, code is the only place to set them.

Remember you can split configuration across methods for clarity:

```csharp
private static AppBuilder ConfigurePlatforms(AppBuilder builder)
    => builder.UsePlatformDetect()
              .With(new Win32PlatformOptions { UseWgl = false })
              .With(new AvaloniaNativePlatformOptions { UseGpu = true });
```

Chaining explicit helper methods keeps `BuildAvaloniaApp` readable while preserving fluent semantics.

## 2. Crafting an `Application` subclass without XAML

`Application` lives in `external/Avalonia/src/Avalonia.Controls/Application.cs`. The default XAML template overrides `OnFrameworkInitializationCompleted()` after loading XAML. In code-first scenarios you:

1. Override `Initialize()` to register styles/resources explicitly.
2. (Optionally) override `RegisterServices()` to set up dependency injection.
3. Override `OnFrameworkInitializationCompleted()` to set the root visual for the selected lifetime.

```csharp
using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml.Styling;
using Avalonia.Themes.Fluent;

public sealed class App : Application
{
    public override void Initialize()
    {
        Styles.Clear();

        Styles.Add(new FluentTheme
        {
            Mode = FluentThemeMode.Dark
        });

        Styles.Add(new StyleInclude(new Uri("avares://App/Styles"))
        {
            Source = new Uri("avares://App/Styles/Controls.axaml") // optional: you can still load XAML fragments
        });

        Styles.Add(CreateButtonStyle());

        Resources.MergedDictionaries.Add(CreateAppResources());
    }

    protected override void RegisterServices()
    {
        // called before Initialize(). Great spot for DI container wiring.
        AvaloniaLocator.CurrentMutable.Bind<IMyService>().ToSingleton<MyService>();
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow = new MainWindow
            {
                DataContext = new MainWindowViewModel()
            };
        }
        else if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            singleView.MainView = new HomeView
            {
                DataContext = new HomeViewModel()
            };
        }

        base.OnFrameworkInitializationCompleted();
    }

    private static Style CreateButtonStyle()
        => new(x => x.OfType<Button>())
        {
            Setters =
            {
                new Setter(Button.CornerRadiusProperty, new CornerRadius(6)),
                new Setter(Button.PaddingProperty, new Thickness(16, 8)),
                new Setter(Button.ClassesProperty, Classes.Parse("accent"))
            }
        };

    private static ResourceDictionary CreateAppResources()
    {
        return new ResourceDictionary
        {
            ["AccentBrush"] = new SolidColorBrush(Color.Parse("#FF4F8EF7")),
            ["AccentForegroundBrush"] = Brushes.White,
            ["BorderRadiusSmall"] = new CornerRadius(4)
        };
    }
}
```

Notes from source:
- `Styles` is an `IList<IStyle>` exposed by `Application`. Clearing it ensures you start from a blank slate (no default theme). Add `FluentTheme` or your own style tree.
- `StyleInclude` can still ingest axaml fragments—code-first doesn't forbid XAML, it just avoids `Application.LoadComponent`.
- `RegisterServices()` is invoked early in `AppBuilderBase<TApp>.Setup()` before the app is instantiated. It's designed for code-first registration patterns.
- Always call `base.OnFrameworkInitializationCompleted()` to ensure any registered `OnFrameworkInitializationCompleted` handlers fire.

## 3. Building windows and views directly in C#

When you skip XAML, every control tree is instantiated manually. You can:
- Derive from `Window`, `UserControl`, or `ContentControl` and compose UI in the constructor.
- Use factory methods to build complex layouts.
- Compose view-model bindings using `Binding` objects or extension helpers.

```csharp
public sealed class MainWindow : Window
{
    public MainWindow()
    {
        Title = "Code-first Avalonia";
        Width = 800;
        Height = 600;

        Content = BuildLayout();
    }

    private static Control BuildLayout()
    {
        return new DockPanel
        {
            LastChildFill = true,
            Children =
            {
                CreateHeader(),
                CreateBody()
            }
        };
    }

    private static Control CreateHeader()
        => new Border
        {
            Background = (IBrush)Application.Current!.Resources["AccentBrush"],
            Padding = new Thickness(24, 16),
            Child = new TextBlock
            {
                Text = "Dashboard",
                FontSize = 22,
                Foreground = Brushes.White,
                FontWeight = FontWeight.SemiBold
            }
        }.DockTop();

    private static Control CreateBody()
        => new StackPanel
        {
            Margin = new Thickness(24),
            Spacing = 16,
            Children =
            {
                new TextBlock { Text = "Welcome!", FontSize = 18 },
                new Button
                {
                    Content = "Refresh",
                    Command = ReactiveCommand.Create(() => Debug.WriteLine("Refresh requested"))
                }
            }
        };
}
```

Helper extension methods keep layout code tidy. You can author them in a static class:

```csharp
public static class DockPanelExtensions
{
    public static T DockTop<T>(this T control) where T : Control
    {
        DockPanel.SetDock(control, Dock.Top);
        return control;
    }
}
```

Because you're constructing controls in code, you can register them with the `NameScope` for later lookup:

```csharp
var scope = new NameScope();
NameScope.SetNameScope(this, scope);

var statusText = new TextBlock { Text = "Idle" };
scope.Register("StatusText", statusText);
```

This matches `NameScope` behaviour from XAML (see `external/Avalonia/src/Avalonia.Base/LogicalTree/NameScope.cs`).

## 4. Binding, commands, and services without markup extensions

Code-first projects rely on the same binding engine, but you create bindings manually or use compiled binding helpers.

### Creating bindings programmatically

```csharp
var textBox = new TextBox();
textBox.Bind(TextBox.TextProperty, new Binding("Query")
{
    Mode = BindingMode.TwoWay,
    UpdateSourceTrigger = UpdateSourceTrigger.PropertyChanged,
    ValidatesOnDataErrors = true
});

var searchButton = new Button
{
    Content = "Search"
};
searchButton.Bind(Button.CommandProperty, new Binding("SearchCommand"));
```

`Binding` lives in `external/Avalonia/src/Avalonia.Base/Data/Binding.cs`. Anything you can express via `{Binding}` markup is available as properties on this class. For compiled bindings, use `CompiledBindingFactory` from `Avalonia.Data.Core` directly:

```csharp
var factory = new CompiledBindingFactory();
var compiled = factory.Create<object, string>(
    vmGetter: static vm => ((SearchViewModel)vm).Query,
    vmSetter: static (vm, value) => ((SearchViewModel)vm).Query = value,
    name: nameof(SearchViewModel.Query),
    mode: BindingMode.TwoWay);

textBox.Bind(TextBox.TextProperty, compiled);
```

### Services and dependency injection

Use `AvaloniaLocator.CurrentMutable` (defined in `Application.RegisterServices`) to register services. For richer DI, integrate libraries like `Microsoft.Extensions.DependencyInjection`.

```csharp
protected override void RegisterServices()
{
    var services = new ServiceCollection();
    services.AddSingleton<IMyService, MyService>();
    services.AddSingleton<HomeViewModel>();

    var provider = services.BuildServiceProvider();

    AvaloniaLocator.CurrentMutable.Bind<IMyService>().ToSingleton(() => provider.GetRequiredService<IMyService>());
    AvaloniaLocator.CurrentMutable.Bind<HomeViewModel>().ToTransient(() => provider.GetRequiredService<HomeViewModel>());
}
```

Later, resolve services via `AvaloniaLocator.Current.GetService<HomeViewModel>()` or inject them into controls. Because `RegisterServices` runs before `Initialize`, you can use registered services while building resources.

## 5. Theming, resources, and modular structure

Code-first theming revolves around `ResourceDictionary`, `Styles`, and `StyleInclude`.

### Centralize app resources

```csharp
private static ResourceDictionary CreateAppResources()
{
    return new ResourceDictionary
    {
        MergedDictionaries =
        {
            new ResourceDictionary
            {
                ["Spacing.Small"] = 4.0,
                ["Spacing.Medium"] = 12.0,
                ["Spacing.Large"] = 24.0
            }
        },
        ["AccentBrush"] = Brushes.CornflowerBlue,
        ["AccentForegroundBrush"] = Brushes.White
    };
}
```

Use namespaced keys (`Spacing.Medium`) to avoid collisions. If you rely on resizable themes, store them in a dedicated class:

```csharp
public static class AppTheme
{
    public static Styles Light { get; } = new Styles
    {
        new FluentTheme { Mode = FluentThemeMode.Light },
        CreateSharedStyles()
    };

    public static Styles Dark { get; } = new Styles
    {
        new FluentTheme { Mode = FluentThemeMode.Dark },
        CreateSharedStyles()
    };

    private static Styles CreateSharedStyles()
        => new Styles
        {
            new Style(x => x.OfType<Window>())
            {
                Setters =
                {
                    new Setter(Window.BackgroundProperty, Brushes.Transparent)
                }
            }
        };
}
```

Switch themes at runtime:

```csharp
public void UseDarkTheme()
{
    Application.Current!.Styles.Clear();
    foreach (var style in AppTheme.Dark)
    {
        Application.Current.Styles.Add(style);
    }
}
```

Iterate the collection when swapping themes—`Styles` implements `IEnumerable<IStyle>` so a simple `foreach` keeps dependencies minimal. Remember to freeze brushes (`Brushes.Transparent` is already frozen) when reusing them to avoid unnecessary allocations.

### Organize modules by feature

A common pattern is to place each feature in its own namespace with:
- A factory method returning a `Control` (for pure code) or a partial class if you mix `.axaml` for templates.
- A `ViewModel` class registered via DI.
- Optional `IStyle`/`ResourceDictionary` definitions encapsulated in static classes.

Example folder layout:

```
src/
  Infrastructure/
    Services/
    Styles/
  Features/
    Dashboard/
      DashboardView.cs
      DashboardViewModel.cs
      DashboardStyles.cs
    Settings/
      SettingsView.cs
      SettingsViewModel.cs
```

`DashboardStyles` might expose a `Styles` property you merge into `Application.Styles`. Keep style/helper definitions close to the controls they customize to maintain cohesion.

## 6. Migrating from XAML to code-first

To convert an existing XAML-based app:

1. **Copy property settings**: For each control, move attribute values into constructors or object initializers. Attached properties map to static setters (`Grid.SetColumn(button, 1)`).
2. **Convert bindings**: Replace `{Binding}` with `control.Bind(Property, new Binding("Path"))`. For `ElementName` references, call `NameScope.Register` and `FindControl`.
3. **Transform styles**: Use `new Style(x => x.OfType<Button>().Class("accent"))` for selectors. Set `Setters` to match `<Setter>` elements.
4. **Load templates**: Where XAML used `<ControlTemplate>`, build `FuncControlTemplate`. The constructor signature matches the control type and returns the template content.
5. **Merge resources**: Replace `<ResourceDictionary.MergedDictionaries>` with `ResourceDictionary.MergedDictionaries.Add(...)`.
6. **Replace markup extensions**: Many map to APIs (`DynamicResource` → `DynamicResourceBindingExtensions`, `StaticResource` → dictionary lookup). For `OnPlatform` or `OnFormFactor`, implement custom helper methods that return values based on `RuntimeInformation`.

Testing after each step keeps parity. Avalonia DevTools still works with code-first UI, so inspect logical/visual trees to confirm bindings and styles resolved correctly.

## 7. Practice lab

1. **From template to C#** – Scaffold a standard Avalonia MVVM template, then delete `App.axaml` and `MainWindow.axaml`. Recreate them as classes mirroring their original layout using C# object initializers. Verify styles, resources, and data bindings behave identically using DevTools.
2. **Theme switcher** – Implement light/dark `Styles` groups in code. Add a toggle button that swaps `Application.Current.Styles` and persists the choice using your service layer.
3. **DI-first startup** – Register services in `RegisterServices()` using your preferred container. Resolve view-models in `OnFrameworkInitializationCompleted` rather than `new`, ensuring the container owns lifetimes.
4. **Factory-based navigation** – Build a code-first navigation shell where pages are created via factories (`Func<Control>`). Inject factories through DI and demonstrate a plugin module adding new pages without touching XAML.
5. **Headless smoke test** – Pair with Chapter 38 by writing a headless unit test that spins up your code-first app, navigates to a view, and asserts control properties to guarantee the code-only tree is intact.

By mastering these patterns you gain confidence that Avalonia's internals don’t require XAML. The framework's property system, theming engine, and lifetimes remain fully accessible from C#, letting teams tailor architecture to their tooling and review preferences.

What's next
- Next: [Chapter34](Chapter34.md)
