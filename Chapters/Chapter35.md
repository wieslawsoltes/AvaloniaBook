# 35. Bindings, resources, and styles with fluent APIs

Goal
- Compose data bindings, resource lookups, and styles from C# using the same primitives Avalonia's XAML markup wraps.
- Harness indexer paths, compiled bindings, and validation hooks when no markup extensions are available.
- Build reusable style/resource factories that keep code-first projects organized and themeable.

Why this matters
- Binding expressions and resource dictionaries power MVVM regardless of markup language; code-first teams need ergonomic patterns to mirror XAML equivalents.
- Explicit APIs (`Binding`, `CompiledBindingFactory`, `IResourceHost`, `Style`) remove stringly-typed errors and enable richer refactoring tools.
- Once bindings and resources live in code, you can conditionally compose them, share helper libraries, and unit test your infrastructure without XML parsing.

Prerequisites
- Chapter 7 (styling) and Chapter 10 (resources) to understand the conceptual model.
- Chapter 33 (code-only startup) for service registration and theme initialization.
- Chapter 34 (layout) for structuring controls that consume bindings/styles.

## 1. Binding essentials without markup

Avalonia's binding engine is expressed via `Binding` (`external/Avalonia/src/Avalonia.Base/Data/Binding.cs`). Construct bindings with property paths, modes, converters, and validation:

```csharp
var binding = new Binding("Customer.Name")
{
    Mode = BindingMode.TwoWay,
    UpdateSourceTrigger = UpdateSourceTrigger.PropertyChanged,
    ValidatesOnExceptions = true
};

nameTextBox.Bind(TextBox.TextProperty, binding);
```

`Bind` is an extension method on `AvaloniaObject` (see `BindingExtensions`). The same API supports command bindings:

```csharp
saveButton.Bind(Button.CommandProperty, new Binding("SaveCommand"));
```

For one-time assignments, use `BindingMode.OneTime`. When you need relative bindings (`RelativeSource` in XAML), use `RelativeSource` objects:

```csharp
var binding = new Binding
{
    RelativeSource = new RelativeSource(RelativeSourceMode.FindAncestor)
    {
        AncestorType = typeof(Window)
    },
    Path = nameof(Window.Title)
};

header.Bind(TextBlock.TextProperty, binding);
```

### Indexer bindings from code

Avalonia supports indexer paths (dictionary or list access) via the same `Binding.Path` syntax used in XAML.

```csharp
var statusText = new TextBlock();
statusText.Bind(TextBlock.TextProperty, new Binding("Statuses[SelectedStatus]"));
```

Internally the binding engine uses `IndexerNode` (see `ExpressionNodes`). You still get change notifications when the indexer raises property change events (`INotifyPropertyChanged` + `IndexerName`). For dynamic dictionaries, call `RaisePropertyChanged("Item[]")` on changes.

### Typed bindings with `CompiledBindingFactory`

Compiled bindings avoid reflection at runtime. Create a factory and supply strongly-typed accessors, mirroring `{CompiledBinding}` usage.

```csharp
var factory = new CompiledBindingFactory();
var compiled = factory.Create<DashboardViewModel, string>(
    vmGetter: static vm => vm.Header,
    vmSetter: static (vm, value) => vm.Header = value,
    name: nameof(DashboardViewModel.Header),
    mode: BindingMode.TwoWay);

headerText.Bind(TextBlock.TextProperty, compiled);
```

`CompiledBindingFactory` resides in `Avalonia.Data.Core`. Pass `BindingPriority` if you need to align with style triggers. Because compiled bindings capture delegates, they work well with source generators or analyzers.

### Binding helpers for fluent composition

Create extension methods to reduce boilerplate:

```csharp
public static class BindingHelpers
{
    public static T BindValue<T, TValue>(this T control, AvaloniaProperty<TValue> property, string path,
        BindingMode mode = BindingMode.Default) where T : AvaloniaObject
    {
        control.Bind(property, new Binding(path) { Mode = mode });
        return control;
    }
}
```

Use them when composing views:

```csharp
var searchBox = new TextBox()
    .BindValue(TextBox.TextProperty, nameof(SearchViewModel.Query), BindingMode.TwoWay);
```

## 2. Validation, converters, and multi-bindings

### Validation feedback

Avalonia surfaces validation errors via `BindingNotification`. In code you set validation options on binding instances:

```csharp
var amountBinding = new Binding("Amount")
{
    Mode = BindingMode.TwoWay,
    ValidatesOnDataErrors = true,
    ValidatesOnExceptions = true
};
amountTextBox.Bind(TextBox.TextProperty, amountBinding);
```

Listen for errors using `BindingObserver` or property change notifications on `DataValidationErrors` (see `external/Avalonia/src/Avalonia.Controls/DataValidationErrors.cs`). Example hooking into the attached property:

```csharp
amountTextBox.GetObservable(DataValidationErrors.HasErrorsProperty)
    .Subscribe(hasErrors => amountTextBox.Classes.Set(":invalid", hasErrors));
```

### Converters and converter parameters

Instantiate converters directly and assign them to `Binding.Converter`:

```csharp
var converter = new BooleanToVisibilityConverter();
var binding = new Binding("IsBusy")
{
    Converter = converter
};

spinner.Bind(IsVisibleProperty, binding);
```

For inline converters, create lambda-based converter classes implementing `IValueConverter`. In code-first setups you can keep converter definitions close to usage.

### Multi-binding composition

`MultiBinding` lives in `Avalonia.Base/Data/MultiBinding.cs`. Configure binding collection and converters directly.

```csharp
var multi = new MultiBinding
{
    Bindings =
    {
        new Binding("FirstName"),
        new Binding("LastName")
    },
    Converter = FullNameConverter.Instance
};

fullNameText.Bind(TextBlock.TextProperty, multi);
```

`FullNameConverter` implements `IMultiValueConverter`. When multi-binding in code, consider static singletons to avoid allocations.

## 3. Commands and observables from code

Avalonia command support is just binding to `ICommand`. With code-first patterns, leverage `ReactiveCommand` or custom commands while still using `Bind`:

```csharp
refreshButton.Bind(Button.CommandProperty, new Binding("RefreshCommand"));
```

To observe property changes for reactive flows, use `GetObservable` or `PropertyChanged` events. Combine with `ReactiveUI` by using `WhenAnyValue` inside view models—code-first views don’t change this interop.

## 4. Resource dictionaries and lookup patterns

`ResourceDictionary` is just a C# collection (see `external/Avalonia/src/Avalonia.Base/Controls/ResourceDictionary.cs`). Create dictionaries and merge them programmatically.

```csharp
var typographyResources = new ResourceDictionary
{
    ["Heading.FontSize"] = 24.0,
    ["Body.FontSize"] = 14.0
};

Application.Current!.Resources.MergedDictionaries.Add(typographyResources);
```

For per-control resources:

```csharp
var card = new Border
{
    Resources =
    {
        ["CardBackground"] = Brushes.White,
        ["CardShadow"] = new BoxShadow { Color = Colors.Black, Opacity = 0.1, Blur = 8 }
    }
};
```

`Resources` property is itself a `ResourceDictionary`. Use strongly-typed wrapper classes to centralize resource keys:

```csharp
public static class ResourceKeys
{
    public const string AccentBrush = nameof(AccentBrush);
    public const string AccentForeground = nameof(AccentForeground);
}

var accent = (IBrush)Application.Current!.Resources[ResourceKeys.AccentBrush];
```

Wrap lookups with helper methods to provide fallbacks:

```csharp
public static TResource GetResource<TResource>(this IResourceHost host, string key, TResource fallback)
{
    return host.TryFindResource(key, out var value) && value is TResource typed
        ? typed
        : fallback;
}
```

`IResourceHost`/`IResourceProvider` interfaces are defined in `Avalonia.Styling`. Controls implement them, so you can call `control.TryFindResource` directly.

## 5. Building styles fluently

`Style` objects can be constructed with selectors and setters. The selector API mirrors XAML but uses lambda syntax.

```csharp
var buttonStyle = new Style(x => x.OfType<Button>().Class("primary"))
{
    Setters =
    {
        new Setter(Button.BackgroundProperty, Brushes.MediumPurple),
        new Setter(Button.ForegroundProperty, Brushes.White),
        new Setter(Button.PaddingProperty, new Thickness(20, 10))
    },
    Triggers =
    {
        new Trigger
        {
            Property = Button.IsPointerOverProperty,
            Value = true,
            Setters = { new Setter(Button.BackgroundProperty, Brushes.DarkMagenta) }
        }
    }
};
```

Add styles to `Application.Current.Styles` or to a specific control’s `Styles` collection. Remember to freeze brushes (call `ToImmutable()` or use static brushes) when reusing them widely.

### Style includes and theme variants

You can still load existing `.axaml` resources via `StyleInclude`, or create purely code-based ones:

```csharp
var theme = new Styles
{
    new StyleInclude(new Uri("avares://App/Styles"))
    {
        Source = new Uri("avares://App/Styles/Buttons.axaml")
    },
    buttonStyle
};

Application.Current!.Styles.AddRange(theme);
```

In pure C#, `Styles` is just a list. If you don’t have `AddRange`, iterate:

```csharp
foreach (var style in theme)
{
    Application.Current!.Styles.Add(style);
}
```

Theme variants (`ThemeVariant`) can be set directly on styles:

```csharp
buttonStyle.Resources[ThemeVariant.Light] = Brushes.Black;
buttonStyle.Resources[ThemeVariant.Dark] = Brushes.White;
```

## 6. Code-first binding infrastructure patterns

### Binding factories per view-model

Encapsulate binding creation in dedicated classes to avoid scattering strings:

```csharp
public static class DashboardBindings
{
    public static Binding TotalSales => new(nameof(DashboardViewModel.TotalSales)) { Mode = BindingMode.OneWay };
    public static Binding RefreshCommand => new(nameof(DashboardViewModel.RefreshCommand));
}

salesText.Bind(TextBlock.TextProperty, DashboardBindings.TotalSales);
refreshButton.Bind(Button.CommandProperty, DashboardBindings.RefreshCommand);
```

### Expression-based helpers

Use expression trees to produce path strings while maintaining compile-time checks:

```csharp
public static class BindingFactory
{
    public static Binding Create<TViewModel, TValue>(Expression<Func<TViewModel, TValue>> expression,
        BindingMode mode = BindingMode.Default)
    {
        var path = ExpressionHelper.GetMemberPath(expression); // custom helper
        return new Binding(path) { Mode = mode };
    }
}
```

`ExpressionHelper` can walk the expression tree to build `Customer.Addresses[0].City` style paths, ensuring refactors update bindings.

### Declarative resource builders

Provide factories for resource dictionaries similar to style factories:

```csharp
public static class ResourceFactory
{
    public static ResourceDictionary CreateColors() => new()
    {
        [ResourceKeys.AccentBrush] = new SolidColorBrush(Color.Parse("#4F8EF7")),
        [ResourceKeys.AccentForeground] = Brushes.White
    };
}
```

Merge them in `App.Initialize()` or feature modules when needed.

## 7. Practice lab

1. **Binding library** – Implement a helper class that exposes strongly-typed bindings for a view-model using expression trees. Replace string-based paths in an existing code-first view.
2. **Indexer dashboards** – Build a dashboard card that binds to `Metrics["TotalRevenue"]` from a dictionary-backed view-model. Raise change notifications on dictionary updates and verify the UI refreshes.
3. **Validation styling** – Create a reusable style that applies an `:invalid` pseudo-class template to controls with validation errors. Trigger validation via a headless test.
4. **Resource fallback provider** – Write an extension method that locates a resource by key and throws a descriptive exception if missing, including current logical tree path. Use it in a headless test to catch missing theme registrations.
5. **Theme toggler** – Compose two `Styles` collections (light/dark) in code, swap them at runtime, and ensure all bindings to theme resources update automatically. Validate behaviour with a headless pixel test (Chapter 40).

With bindings, resources, and styles expressed in code, your Avalonia app gains powerful refactorability and testability. Embrace the fluent APIs and helper patterns to keep code-first UI as expressive as any XAML counterpart.

What's next
- Next: [Chapter36](Chapter36.md)
