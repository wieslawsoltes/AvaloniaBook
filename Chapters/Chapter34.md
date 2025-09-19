# 34. Layouts and controls authored in pure C#

Goal
- Compose Avalonia visual trees entirely in code using layout containers, attached properties, and fluent helpers.
- Understand how `AvaloniaObject` APIs (`SetValue`, `SetCurrentValue`, observers) replace attribute syntax when you skip XAML.
- Build reusable factory methods and extension helpers that keep code-generated UI readable and testable.

Why this matters
- Code-first teams still need the full power of Avalonia's layout system: panels, attached properties, and templated controls all live in namespaces you can reach from C#.
- Explicit property APIs make dynamic UI safer—no magic strings or runtime parsing, just compile-time members and analyzers.
- Once you see how to structure factories and name scopes, you can generate UI from data, plug-ins, or source generators without sacrificing maintainability.

Prerequisites
- Chapter 7 (styles) for context on how styles interact with control trees.
- Chapter 9 (input) if you plan to attach event handlers in code-behind.
- Chapter 33 (code-first startup) for application scaffolding and DI patterns.

## 1. Layout primitives in code: `StackPanel`, `Grid`, `DockPanel`

Avalonia's panels live in `external/Avalonia/src/Avalonia.Controls/`. Construct them exactly as you would in XAML, but populate `Children` and set properties directly.

```csharp
var layout = new StackPanel
{
    Orientation = Orientation.Vertical,
    Spacing = 12,
    Margin = new Thickness(24),
    Children =
    {
        new TextBlock { Text = "Customer" },
        new TextBox { Watermark = "Name" },
        new TextBox { Watermark = "Email" }
    }
};
```

`StackPanel`'s measure logic (see `StackPanel.cs`) respects `Spacing` and `Orientation`. Because you're in code, you can wrap control creation in helper methods to keep constructors clean:

```csharp
private static TextBox CreateLabeledInput(string label, out TextBlock caption)
{
    caption = new TextBlock { Text = label, FontWeight = FontWeight.SemiBold };
    return new TextBox { Margin = new Thickness(0, 4, 0, 16) };
}
```

### Grids without XAML strings

`Grid` exposes `RowDefinitions`/`ColumnDefinitions` collections of `RowDefinition`/`ColumnDefinition`. You add definitions and set attached properties programmatically.

```csharp
var grid = new Grid
{
    ColumnDefinitions =
    {
        new ColumnDefinition(GridLength.Auto),
        new ColumnDefinition(GridLength.Star)
    },
    RowDefinitions =
    {
        new RowDefinition(GridLength.Auto),
        new RowDefinition(GridLength.Auto),
        new RowDefinition(GridLength.Star)
    }
};

var title = new TextBlock { Text = "Orders", FontSize = 22 }; 
Grid.SetColumnSpan(title, 2);
grid.Children.Add(title);

var filterLabel = new TextBlock { Text = "Status" };
Grid.SetRow(filterLabel, 1);
Grid.SetColumn(filterLabel, 0);
grid.Children.Add(filterLabel);

var filterBox = new ComboBox { Items = Enum.GetValues<OrderStatus>() };
Grid.SetRow(filterBox, 1);
Grid.SetColumn(filterBox, 1);
grid.Children.Add(filterBox);
```

Attached property methods (`Grid.SetRow`, `Grid.SetColumnSpan`) are static for clarity. Because they ultimately call `AvaloniaObject.SetValue`, you can wrap them in fluent helpers if you prefer chaining (example later in section 3).

### Dock layouts and last-child filling

`DockPanel` (source: `DockPanel.cs`) uses the `Dock` attached property. From code you set it with `DockPanel.SetDock(control, Dock.Left)`.

```csharp
var dock = new DockPanel
{
    LastChildFill = true,
    Children =
    {
        CreateSidebar().DockLeft(),
        CreateFooter().DockBottom(),
        CreateMainRegion()
    }
};
```

Implement `DockLeft()` as an extension to keep code terse:

```csharp
public static class DockExtensions
{
    public static T DockLeft<T>(this T control) where T : Control
    {
        DockPanel.SetDock(control, Dock.Left);
        return control;
    }

    public static T DockBottom<T>(this T control) where T : Control
    {
        DockPanel.SetDock(control, Dock.Bottom);
        return control;
    }
}
```

You own these helpers, so you can tailor them for your team's conventions (dock with margins, apply classes, etc.).

## 2. Working with the property system: `SetValue`, `SetCurrentValue`, observers

Without XAML attribute syntax you interact with `AvaloniaProperty` APIs directly. Every control inherits from `AvaloniaObject` (`AvaloniaObject.cs`), which exposes:

- `SetValue(AvaloniaProperty property, object? value)` – sets the property locally, raising change notifications and affecting bindings.
- `SetCurrentValue(AvaloniaProperty property, object? value)` – updates the effective value but preserves existing bindings/animations (great for programmatic defaults).
- `GetObservable<T>(AvaloniaProperty<T>)` – returns an `IObservable<T?>` when you need to react to changes.

Example: highlight focused text boxes by toggling a pseudo-class while keeping bindings intact.

```csharp
var box = new TextBox();
box.GotFocus += (_, _) => box.PseudoClasses.Set(":focused", true);
box.LostFocus += (_, _) => box.PseudoClasses.Set(":focused", false);

// Provide a default width but leave bindings alone
box.SetCurrentValue(TextBox.WidthProperty, 240);
```

To wire property observers, use `GetObservable` or `GetPropertyChangedObservable` (for any property change):

```csharp
box.GetObservable(TextBox.TextProperty)
   .Subscribe(text => _logger.Information("Text changed to {Text}", text));
```

`GetObservable` is defined in `AvaloniaObject`. Remember to dispose subscriptions when controls leave the tree—store `IDisposable` tokens and call `Dispose` in your control's `DetachedFromVisualTree` handler.

### Creating reusable property helpers

When repeating property patterns, encapsulate them:

```csharp
public static class ControlHelpers
{
    public static T WithMargin<T>(this T control, Thickness margin) where T : Control
    {
        control.Margin = margin;
        return control;
    }

    public static T Bind<T, TValue>(this T control, AvaloniaProperty<TValue> property, IBinding binding)
        where T : AvaloniaObject
    {
        control.Bind(property, binding);
        return control;
    }
}
```

These mirror markup extensions in code, making complex layouts more declarative.

## 3. Factories, builders, and fluent composition

Large code-first views benefit from factory methods that return configured controls. Compose factories from smaller functions to keep logic readable.

```csharp
public static class DashboardViewFactory
{
    public static Control Create(IDashboardViewModel vm)
    {
        return new Grid
        {
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Star)
            },
            Children =
            {
                CreateSummary(vm).WithGridPosition(0, 0),
                CreateChart(vm).WithGridPosition(0, 1)
            }
        };
    }

    private static Control CreateSummary(IDashboardViewModel vm)
        => new Border
        {
            Padding = new Thickness(24),
            Child = new TextBlock().Bind(TextBlock.TextProperty, new Binding(nameof(vm.TotalSales)))
        };
}
```

`WithGridPosition` is a fluent helper you define:

```csharp
public static class GridExtensions
{
    public static T WithGridPosition<T>(this T element, int row, int column) where T : Control
    {
        Grid.SetRow(element, row);
        Grid.SetColumn(element, column);
        return element;
    }
}
```

This approach keeps UI declarations near data bindings, reducing mental overhead for reviewers.

### Repeating structures via LINQ or loops

Because you're in C#, generate children dynamically:

```csharp
var cards = vm.Notifications.Select((item, index) =>
    CreateNotificationCard(item).WithGridPosition(index / 3, index % 3));

var grid = new Grid
{
    ColumnDefinitions = { new ColumnDefinition(GridLength.Star), new ColumnDefinition(GridLength.Star), new ColumnDefinition(GridLength.Star) }
};

foreach (var card in cards)
{
    grid.Children.Add(card);
}
```

`Grid` measure logic handles dynamic counts; just ensure `RowDefinitions` fits the generated children (add rows as needed or rely on `GridLength.Auto`).

### Sharing styles between factories

Factories can return both controls and supporting `Styles`:

```csharp
public static Styles DashboardStyles { get; } = new Styles
{
    new Style(x => x.OfType<TextBlock>().Class("section-title"))
    {
        Setters = { new Setter(TextBlock.FontSizeProperty, 18), new Setter(TextBlock.FontWeightProperty, FontWeight.SemiBold) }
    }
};
```

Merge these into `Application.Current.Styles` in `App.Initialize()` or on demand when the feature loads.

## 4. Managing `NameScope`, logical/visual trees, and lookup

XAML automatically registers names in a `NameScope`. In code-first views you create and assign it manually when you need element lookup or `ElementName`-like references.

```csharp
var scope = new NameScope();
var container = new Grid();
NameScope.SetNameScope(container, scope);

var detailPanel = new StackPanel { Orientation = Orientation.Vertical };
scope.Register("DetailPanel", detailPanel);

container.Children.Add(detailPanel);
```

Later you can resolve controls with `FindControl<T>`:

```csharp
var detail = container.FindControl<StackPanel>("DetailPanel");
```

`NameScope` implementation lives in `external/Avalonia/src/Avalonia.Base/LogicalTree/NameScope.cs`. Remember that nested scopes behave like XAML: children inherit the nearest scope unless you assign a new one.

### Logical tree utilities

Avalonia's logical tree helpers (`LogicalTreeExtensions.cs`) are just as useful without XAML. Use them to inspect or traverse the tree:

```csharp
Control? parent = myControl.GetLogicalParent();
IEnumerable<IControl> children = myControl.GetLogicalChildren().OfType<IControl>();
```

This is handy when you dynamically add/remove controls and need to ensure data contexts or resources flow correctly. To validate at runtime, enable DevTools (`Avalonia.Diagnostics`) even in code-only views—the visual tree is identical.

## 5. Advanced controls entirely from C#

### `TabControl` and dynamic pages

`TabControl` expects `TabItem` children. Compose them programmatically and bind headers/content.

```csharp
var tabControl = new TabControl
{
    Items = new[]
    {
        new TabItem
        {
            Header = "Overview",
            Content = new OverviewView { DataContext = vm.Overview }
        },
        new TabItem
        {
            Header = "Details",
            Content = CreateDetailsGrid(vm.Details)
        }
    }
};
```

If you prefer data-driven tabs, set `Items` to a collection of view-models and provide `ItemTemplate` using `FuncDataTemplate` (see Chapter 36 for full coverage). Even then, you create the template in code:

```csharp
tabControl.ItemTemplate = new FuncDataTemplate<IDetailViewModel>((context, _) =>
    new DetailView { DataContext = context },
    supportsRecycling: true);
```

### Lists with factories

`ItemsControl` and `ListBox` take `Items` plus optional panel templates. Build the items panel in code to control layout.

```csharp
var list = new ListBox
{
    ItemsPanel = new FuncTemplate<Panel?>(() => new WrapPanel { ItemWidth = 160, ItemHeight = 200 }),
    Items = vm.Products.Select(p => CreateProductCard(p))
};
```

Here `FuncTemplate` comes from `Avalonia.Controls.Templates` (source: `FuncTemplate.cs`). It mirrors `<ItemsPanelTemplate>`.

### Popups and overlays

Controls like `FlyoutBase` or `Popup` are fully accessible in code. Example: attach a contextual menu.

```csharp
var button = new Button { Content = "Options" };
button.Flyout = new MenuFlyout
{
    Items =
    {
        new MenuItem { Header = "Refresh", Command = vm.RefreshCommand },
        new MenuItem { Header = "Export", Command = vm.ExportCommand }
    }
};
```

The object initializer syntax keeps the code close to the equivalent XAML while exposing full IntelliSense.

## 6. Diagnostics and testing for code-first layouts

Because no XAML compilation step validates your layout, lean on:
- **Unit tests** using `Avalonia.Headless` to instantiate controls and assert layout bounds.
- **DevTools** to inspect the visual tree ( launch via `AttachDevTools()` in debug builds ).
- **Logging** via property observers to catch binding mistakes early.

Example headless test snippet:

```csharp
[Fact]
public void Summary_panel_contains_totals()
{
    using var app = AvaloniaApp();

    var view = DashboardViewFactory.Create(new FakeDashboardVm());
    var panel = view.GetLogicalDescendants().OfType<TextBlock>()
        .First(t => t.Classes.Contains("total"));

    panel.Text.Should().Be("$42,000");
}
```

`GetLogicalDescendants` is defined in `LogicalTreeExtensions`. Pair this with Chapter 38 for deeper testing patterns.

## 7. Practice lab

1. **StackPanel to Grid refactor** – Start with a simple `StackPanel` form built in code. Refactor it to a `Grid` with columns and auto-sizing rows using only C# helpers. Confirm layout parity via DevTools.
2. **Dashboard factory** – Implement a `DashboardViewFactory` that returns a `Grid` with cards arranged dynamically based on a view-model collection. Add fluent helpers for grid position, dock, and margin management.
3. **Attached property assertions** – Write a headless unit test that constructs your view, retrieves a control by name, and asserts attached properties (`Grid.GetRow`, `DockPanel.GetDock`) to prevent regressions.
4. **Dynamic modules** – Load modules at runtime that contribute layout fragments via `Func<Control>`. Merge their `Styles`/`ResourceDictionary` contributions when modules activate and remove them when deactivated.
5. **Performance profiling** – Use `RenderTimerDiagnostics` from DevTools to monitor layout passes. Compare baseline vs. dynamic code generation to ensure your factories don't introduce unnecessary measure/arrange churn.

Mastering these patterns means you can weave Avalonia's layout system into any C#-driven architecture—no XAML required, just the underlying property system and a toolbox of fluent helpers tailored to your project.

What's next
- Next: [Chapter35](Chapter35.md)
