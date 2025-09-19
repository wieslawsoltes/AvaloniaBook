# 36. Templates, indexers, and dynamic component factories

Goal
- Compose control, data, and tree templates in pure C# using Avalonia’s functional template APIs.
- Harness indexer-driven bindings and template bindings to build dynamic, data-driven components.
- Construct factories and selectors that swap templates at runtime without touching XAML.

Why this matters
- Templates define how controls render. In code-first projects you still need `FuncControlTemplate`, `FuncDataTemplate`, and selectors to mirror the flexibility of XAML.
- Indexer bindings and instanced bindings power advanced scenarios such as virtualization, item reuse, and hierarchical data.
- Dynamic factories unlock plugin architectures, runtime theme changes, and feature toggles—all while keeping strong typing and testability.

Prerequisites
- Chapter 34 (layouts) to place templated content within layouts.
- Chapter 35 (bindings/resources) for binding syntax and helper patterns.
- Chapter 23 (custom controls) if you plan to author templated controls that consume templates from code.

## 1. Control templates in code with `FuncControlTemplate`

`FuncControlTemplate<T>` (source: `external/Avalonia/src/Avalonia.Controls/Templates/FuncControlTemplate.cs`) produces a `ControlTemplate` that builds visuals from code. It takes a lambda that receives the templated parent and returns a `Control`/`IControl` tree.

```csharp
public static ControlTemplate CreateCardTemplate()
{
    return new FuncControlTemplate<ContentControl>((parent, scope) =>
    {
        var border = new Border
        {
            Background = Brushes.White,
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(16),
            Child = new ContentPresenter
            {
                Name = "PART_ContentPresenter"
            }
        };

        scope?.RegisterNamed("PART_ContentPresenter", border.Child);
        return border;
    });
}
```

Attach the template to a control:

```csharp
var card = new ContentControl
{
    Template = CreateCardTemplate(),
    Content = new TextBlock { Text = "Dashboard" }
};
```

Notes from the source implementation:
- The second parameter (`INameScope scope`) lets you register named parts exactly like `<ControlTemplate>` does in XAML. Use it to satisfy template part lookups in your control’s code-behind.
- The lambda executes each time the control template is applied, so create new control instances inside the lambda—avoid caching across calls.

### Template bindings and `TemplatedParent`

Use `TemplateBinding` helpers (`TemplateBindingExtensions`) to bind template visual properties to the templated control.

```csharp
return new Border
{
    Background = Brushes.White,
    [!Border.BackgroundProperty] = parent.GetTemplateBinding(ContentControl.BackgroundProperty),
    Child = new ContentPresenter()
};
```

The `[!Property]` indexer syntax is shorthand for creating a template binding (enabled by the `Avalonia.Markup.Declarative` helpers). If you prefer explicit code, use `TemplateBindingExtensions.Bind`:

```csharp
var presenter = new ContentPresenter();
presenter.Bind(ContentPresenter.ContentProperty, parent.GetTemplateBinding(ContentControl.ContentProperty));
```

`TemplateBindingExtensions.cs` shows this helper returns a lightweight binding linked to the templated parent’s property value.

## 2. Data templates with `FuncDataTemplate`

`FuncDataTemplate<T>` (source: `FuncDataTemplate.cs`) creates visuals for data items. Often you assign it to `ContentControl.ContentTemplate` or `ItemsControl.ItemTemplate`.

```csharp
var itemTemplate = new FuncDataTemplate<OrderItem>((item, _) =>
    new Border
    {
        Margin = new Thickness(0, 0, 0, 12),
        Child = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 12,
            Children =
            {
                new TextBlock { Text = item.ProductName, FontWeight = FontWeight.SemiBold },
                new TextBlock { Text = item.Quantity.ToString() }
            }
        }
    }, recycle: true);
```

Pass `recycle: true` to participate in virtualization (controls are reused). Attach to an `ItemsControl`:

```csharp
itemsControl.ItemTemplate = itemTemplate;
```

### Binding inside data templates

Because the template receives the data item, you can access its properties directly or create bindings relative to the template context.

```csharp
var template = new FuncDataTemplate<Customer>((item, scope) =>
{
    var balance = new TextBlock();
    balance.Bind(TextBlock.TextProperty, new Binding("Balance")
    {
        StringFormat = "{0:C}"
    });

    return new StackPanel
    {
        Children =
        {
            new TextBlock { Text = item.Name },
            balance
        }
    };
});
```

`FuncDataTemplate` sets the `DataContext` to the item automatically, so bindings with explicit paths work without additional setup.

### Template selectors

`FuncDataTemplate` supports predicates for conditional templates. Use the overload that accepts a `Func<object?, bool>` predicate.

```csharp
var positiveTemplate = new FuncDataTemplate<Transaction>((item, _) => CreateTransactionRow(item));
var negativeTemplate = new FuncDataTemplate<Transaction>((item, _) => CreateTransactionRow(item, isDebit: true));

var selector = new FuncDataTemplate<Transaction>((item, _) =>
    (item.Amount >= 0 ? positiveTemplate.Build(item) : negativeTemplate.Build(item))!,
    supportsRecycling: true);
```

For more complex selection logic, implement `IDataTemplate` manually or use `DataTemplateSelector` base classes from community packages.

## 3. Hierarchical templates with `FuncTreeDataTemplate`

`FuncTreeDataTemplate<T>` builds item templates for hierarchical data such as tree views. It receives the item and a recursion function.

```csharp
var treeTemplate = new FuncTreeDataTemplate<DirectoryNode>((item, _) =>
    new StackPanel
    {
        Orientation = Orientation.Horizontal,
        Children =
        {
            new TextBlock { Text = item.Name }
        }
    },
    x => x.Children,
    true);

var treeView = new TreeView
{
    Items = fileSystem.RootNodes,
    ItemTemplate = treeTemplate
};
```

The third argument is `supportsRecycling`. The second argument is the accessor returning child items. This mirrors XAML’s `<TreeDataTemplate ItemsSource="{Binding Children}">`.

`FuncTreeDataTemplate` internally wires `TreeDataTemplate` with lambda-based factories, so you get the same virtualization behaviour as XAML templates.

## 4. Instanced bindings and indexer tricks

`InstancedBinding` (source: `external/Avalonia/src/Avalonia.Data/Core/InstancedBinding.cs`) lets you precompute a binding for a known source. It’s powerful when a template needs to bind to an item-specific property or when you assemble UI from graphs.

```csharp
var binding = new Binding("Metrics[\"Total\"]") { Mode = BindingMode.OneWay };
var instanced = InstancedBinding.OneWay(binding, metricsDictionary);

var text = new TextBlock();
text.Bind(text.TextProperty, instanced);
```

Because you supply the source (`metricsDictionary`), the binding bypasses `DataContext`. This is useful in templates where you juggle multiple sources (e.g., templated parent + external service).

### Binding to template parts via indexers

Within templates you can reference named parts registered through `scope.RegisterNamed`. After applying the template, resolve them via `TemplateAppliedEventArgs`.

```csharp
protected override void OnApplyTemplate(TemplateAppliedEventArgs e)
{
    base.OnApplyTemplate(e);
    _presenter = e.NameScope.Find<ContentPresenter>("PART_ContentPresenter");
}
```

From code-first templates, ensure the name scope registration occurs inside the template lambda as shown earlier.

## 5. Swapping templates at runtime

Because templates are just CLR objects, you can replace them dynamically to support different visual representations.

```csharp
public void UseCompactTemplates(Window window)
{
    window.Resources["CardTemplate"] = Templates.CompactCard;
    window.Resources["ListItemTemplate"] = Templates.CompactListItem;

    foreach (var presenter in window.GetVisualDescendants().OfType<ContentPresenter>())
    {
        presenter.UpdateChild(); // apply new template
    }
}
```

`ContentPresenter.UpdateChild()` forces the presenter to re-evaluate its template. `GetVisualDescendants` comes from `VisualTreeExtensions`. Consider performance: only call on affected presenters.

Use `IStyle` triggers or the view-model to change templates automatically. Example using a binding:

```csharp
contentControl.Bind(ContentControl.ContentTemplateProperty, new Binding("SelectedTemplate")
{
    Mode = BindingMode.OneWay
});
```

The view-model exposes `IDataTemplate SelectedTemplate`, and your code-first view updates this property to switch visuals.

## 6. Component factories and virtualization

### Control factories

Wrap template logic in factories that accept data and return controls, useful for plugin systems.

```csharp
public interface IWidgetFactory
{
    bool CanHandle(string widgetType);
    Control Create(IWidgetContext context);
}

public sealed class ChartWidgetFactory : IWidgetFactory
{
    public bool CanHandle(string widgetType) => widgetType == "chart";

    public Control Create(IWidgetContext context)
    {
        return new Border
        {
            Child = new ChartControl { DataContext = context.Data }
        };
    }
}
```

Register factories and pick one at runtime:

```csharp
var widget = factories.First(f => f.CanHandle(config.Type)).Create(context);
panel.Children.Add(widget);
```

Factories can also emit data templates instead of controls. For virtualization, return a `FuncDataTemplate` that participates in recycling.

### Items panel factories

`ItemsControl` allows specifying the `ItemsPanel` with `FuncTemplate<Panel?>`. Build them from code to align virtualization mode with runtime options.

```csharp
itemsControl.ItemsPanel = new FuncTemplate<Panel?>(() =>
    new VirtualizingStackPanel
    {
        Orientation = Orientation.Vertical,
        VirtualizationMode = ItemVirtualizationMode.Simple
    });
```

`FuncTemplate<T>` lives in `external/Avalonia/src/Avalonia.Controls/Templates/FuncTemplate.cs` and returns a new panel per items presenter.

### Recycling with `RecyclingElementFactory`

Avalonia’s element factories provide direct control over virtualization (see `external/Avalonia/src/Avalonia.Controls/Generators/`). You can use `RecyclingElementFactory` and supply templates via `IDataTemplate` implementations defined in code.

```csharp
var factory = new RecyclingElementFactory
{
    RecycleKey = "Widget",
    Template = new FuncDataTemplate<IWidgetViewModel>((item, _) => WidgetFactory.CreateControl(item))
};

var items = new ItemsRepeater { ItemTemplate = factory };
```

`ItemsRepeater` (in `Avalonia.Controls`) mirrors WinUI’s control. Providing a factory integrates with virtualization surfaces better than raw `ItemsControl` in performance-sensitive scenarios.

## 7. Testing templates and factories

- **Unit tests**: Use `FuncDataTemplate.Build(item)` to materialize the control tree in memory and assert shape/values.

```csharp
[Fact]
public void Order_item_template_renders_quantity()
{
    var template = Templates.OrderItem;
    var control = (Control)template.Build(new OrderItem { Quantity = 5 }, null)!;

    control.GetVisualDescendants().OfType<TextBlock>().Should().Contain(t => t.Text == "5");
}
```

- **Headless rendering**: Combine with Chapter 40 to capture template output bitmaps.
- **Name scope checks**: After applying control templates, call `TemplateAppliedEventArgs.NameScope.Find` in tests to guarantee required parts exist.

## 8. Practice lab

1. **Card control template** – Build a `FuncControlTemplate` for a `CardControl` that registers named parts, uses template bindings for background/content, and applies to multiple instances with different content.
2. **Conditional data templates** – Create templates for `IssueViewModel` that render differently based on `IsClosed`. Swap templates dynamically by changing a property on the view-model.
3. **Hierarchical explorer** – Compose a `TreeView` for file system data using `FuncTreeDataTemplate`, including icons and lazy loading. Ensure child collections load on demand.
4. **Template factory registry** – Implement a registry of `IDataTemplate` factories keyed by type names. Resolve templates at runtime and verify virtualization with an `ItemsRepeater` in a headless test.
5. **Template swap diagnostics** – Write a helper that re-applies templates when theme changes occur, logging how many presenters were updated. Ensure the log stays small by limiting scope to affected regions.

By mastering code-based templates, indexers, and factories, you gain full control over Avalonia’s presentation layer without depending on XAML. Combine these techniques with the binding and layout patterns from earlier chapters to build highly dynamic, testable UI modules in pure C#.

What's next
- Next: [Chapter37](Chapter37.md)
