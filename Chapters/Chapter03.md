# 3. Your first UI: layouts, controls, and XAML basics

Goal
- Build your first meaningful window with StackPanel, Grid, and reusable user controls.
- Learn how `ContentControl`, `UserControl`, and `NameScope` help you compose UIs cleanly.
- See how logical and visual trees differ so you can find controls and debug bindings.
- Use `ItemsControl` with `DataTemplate` and a simple value converter to repeat UI for collections.
- Understand XAML namespaces (`xmlns:`) and how to reference custom classes or Avalonia namespaces.

Why this matters
- Real apps are more than a single window--you compose views, reuse user controls, and bind lists of data.
- Understanding the logical tree versus the visual tree makes tooling (DevTools, FindControl, bindings) predictable.
- Data templates and converters are the backbone of MVVM-friendly UIs; learning them early prevents hacks later.

Prerequisites
- Chapter 2 completed. You can run `dotnet new`, `dotnet build`, and `dotnet run` on your machine.

## 1. Scaffold the sample project

```bash
# Create a new sample app for this chapter
dotnet new avalonia.mvvm -o SampleUiBasics
cd SampleUiBasics

# Restore packages and run once to ensure the template works
dotnet run
```

Open the project in your IDE before continuing.

## 2. Quick primer on XAML namespaces

The root `<Window>` tag declares namespaces so XAML can resolve types:

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:ui="clr-namespace:SampleUiBasics.Views"
        x:Class="SampleUiBasics.Views.MainWindow">
```

- The default namespace maps to common Avalonia controls (Button, Grid, StackPanel).
- `xmlns:x` exposes XAML keywords like `x:Name`, `x:Key`, and `x:DataType`.
- Custom prefixes (e.g., `xmlns:ui`) point to CLR namespaces in your project or other assemblies so you can reference your own classes or controls (`ui:OrderRow`).
- To import controls from other assemblies, add the prefix defined by their `[XmlnsDefinition]` attribute (for example, `xmlns:fluent="avares://Avalonia.Themes.Fluent"`).

## 3. How Avalonia loads this XAML

- `InitializeComponent()` in `MainWindow.axaml.cs` invokes [`AvaloniaXamlLoader.Load`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs), wiring the compiled XAML into the partial class defined by `x:Class`.
- During build, Avalonia's MSBuild tasks generate code that registers resources, name scopes, and compiled bindings for the loader (see Chapter 30 for the full pipeline).
- In design-time or hot reload scenarios, the same loader can parse XAML streams when no compiled version exists, so runtime errors usually originate from this method.
- Keep `x:Class` values in sync with your namespace; mismatches result in `XamlLoadException` messages complaining about missing compiled XAML.

## 4. Build the main layout (StackPanel + Grid)

Open `Views/MainWindow.axaml` and replace the `<Window.Content>` with:

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:ui="clr-namespace:SampleUiBasics.Views"
        x:Class="SampleUiBasics.Views.MainWindow"
        Width="540" Height="420"
        Title="Customer overview">
  <DockPanel LastChildFill="True" Margin="16">
    <TextBlock DockPanel.Dock="Top"
               Classes="h1"
               Text="Customer overview"
               Margin="0,0,0,16"/>

    <Grid ColumnDefinitions="2*,3*"
          RowDefinitions="Auto,*"
          ColumnSpacing="16"
          RowSpacing="16">

      <StackPanel Grid.Column="0" Spacing="8">
        <TextBlock Classes="h2" Text="Details"/>

        <Grid ColumnDefinitions="Auto,*" RowDefinitions="Auto,Auto,Auto" RowSpacing="8" ColumnSpacing="12">
          <TextBlock Text="Name:"/>
          <TextBox Grid.Column="1" Width="200" Text="{Binding Customer.Name}"/>

          <TextBlock Grid.Row="1" Text="Email:"/>
          <TextBox Grid.Row="1" Grid.Column="1" Text="{Binding Customer.Email}"/>

          <TextBlock Grid.Row="2" Text="Status:"/>
          <ComboBox Grid.Row="2" Grid.Column="1" SelectedIndex="0">
            <ComboBoxItem>Prospect</ComboBoxItem>
            <ComboBoxItem>Active</ComboBoxItem>
            <ComboBoxItem>Dormant</ComboBoxItem>
          </ComboBox>
        </Grid>
      </StackPanel>


      <StackPanel Grid.Column="1" Spacing="8">
        <TextBlock Classes="h2" Text="Recent orders"/>
        <ItemsControl Items="{Binding RecentOrders}">
          <ItemsControl.ItemTemplate>
            <DataTemplate>
              <ui:OrderRow />
            </DataTemplate>
          </ItemsControl.ItemTemplate>
        </ItemsControl>
      </StackPanel>
    </Grid>
  </DockPanel>
</Window>
```

What you just used:
- `DockPanel` places a title bar on top and fills the rest.
- `Grid` split into two columns for the form (left) and list (right).
- `ItemsControl` repeats a data template for each item in `RecentOrders`.

## 5. Create a reusable user control (`OrderRow`)

Add a new file `Views/OrderRow.axaml`:

```xml
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="SampleUiBasics.Views.OrderRow"
             Padding="8"
             Classes="card">
  <Border Background="{DynamicResource ThemeBackgroundBrush}"
          CornerRadius="6"
          Padding="12">
    <Grid ColumnDefinitions="*,Auto" RowDefinitions="Auto,Auto" ColumnSpacing="12">
      <TextBlock Classes="h3" Text="{Binding Title}"/>
      <TextBlock Grid.Column="1"
                 Foreground="{DynamicResource ThemeAccentBrush}"
                 Text="{Binding Total, Converter={StaticResource CurrencyConverter}}"/>

      <TextBlock Grid.Row="1" Grid.ColumnSpan="2" Text="{Binding PlacedOn, StringFormat='Ordered on {0:d}'}"/>
    </Grid>
  </Border>
</UserControl>
```

- `UserControl` encapsulates UI so you can reuse it via `<ui:OrderRow />`.
- It relies on bindings (`Title`, `Total`, `PlacedOn`) which come from the current item in the data template.
- Using a user control keeps the item template readable and testable.

## 6. Add a value converter

Converters adapt data for display. Create `Converters/CurrencyConverter.cs`:

```csharp
using System;
using System.Globalization;
using Avalonia.Data.Converters;

namespace SampleUiBasics.Converters;

public sealed class CurrencyConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is decimal amount)
            return string.Format(culture, "{0:C}", amount);

        return value;
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) => value;
}
```

Register the converter in `App.axaml` so XAML can reference it:

```xml
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:converters="clr-namespace:SampleUiBasics.Converters"
             x:Class="SampleUiBasics.App">
  <Application.Resources>
    <converters:CurrencyConverter x:Key="CurrencyConverter"/>
  </Application.Resources>

  <Application.Styles>
    <FluentTheme />
  </Application.Styles>
</Application>
```

## 7. Populate the ViewModel with nested data

Open `ViewModels/MainWindowViewModel.cs` and replace its contents with:

```csharp
using System;
using System.Collections.ObjectModel;

namespace SampleUiBasics.ViewModels;

public sealed class MainWindowViewModel
{
    public CustomerViewModel Customer { get; } = new("Avery Diaz", "avery@example.com");

    public ObservableCollection<OrderViewModel> RecentOrders { get; } = new()
    {
        new OrderViewModel("Starter subscription", 49.00m, DateTime.Today.AddDays(-2)),
        new OrderViewModel("Design add-on", 129.00m, DateTime.Today.AddDays(-12)),
        new OrderViewModel("Consulting", 900.00m, DateTime.Today.AddDays(-20))
    };
}

public sealed record CustomerViewModel(string Name, string Email);

public sealed record OrderViewModel(string Title, decimal Total, DateTime PlacedOn);
```

Now bindings like `{Binding Customer.Name}` and `{Binding RecentOrders}` have backing data.

## 8. Understand `ContentControl`, `UserControl`, and `NameScope`

- **`ContentControl`** (see [ContentControl.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ContentControl.cs)) holds a single content object. Windows, Buttons, and many controls inherit from it. Setting `Content` or placing child XAML elements populates that content.
- **`UserControl`** (see [UserControl.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/UserControl.cs)) packages a reusable view with its own XAML and code-behind. Each `UserControl` creates its own `NameScope` so `x:Name` values remain local.
- **`NameScope`** (see [NameScope.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/NameScope.cs)) governs how `x:Name` lookups work. Use `this.FindControl<T>("OrdersList")` or `NameScope.GetNameScope(this)` to resolve names inside the nearest scope.

Example: add `x:Name="OrdersList"` to the `ItemsControl` in `MainWindow.axaml` and access it from code-behind:

```csharp
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        var ordersList = this.FindControl<ItemsControl>("OrdersList");
        // Inspect or manipulate generated visuals here if needed.
    }
}
```

When you nest user controls, remember: a name defined in `OrderRow` is not visible in `MainWindow` because each `UserControl` has its own scope. This avoids name collisions in templated scenarios.

## 9. Logical tree vs visual tree (why it matters)

- The **logical tree** tracks content relationships: windows -> user controls -> ItemsControl items. Bindings and resource lookups walk the logical tree. Inspect with `this.GetLogicalChildren()` or DevTools -> Logical tree.
- The **visual tree** includes the actual visuals created by templates (Borders, TextBlocks, Panels). DevTools -> Visual tree shows the rendered hierarchy.
- Some controls (e.g., `ContentPresenter`) exist in the visual tree but not in the logical tree. When `FindControl` fails, confirm whether the element is in the logical tree.
- Reference implementation: [LogicalTreeExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/LogicalTree/LogicalTreeExtensions.cs) and [Visual.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Visual.cs).

## 10. Data templates explained

- `ItemsControl.ItemTemplate` applies a `DataTemplate` for each item. Inside a data template, the `DataContext` is the individual item (an `OrderViewModel`).
- You can inline XAML or reference a key: `<DataTemplate x:Key="OrderTemplate"> ...` and then `ItemTemplate="{StaticResource OrderTemplate}"`.
- Data templates can contain user controls, panels, or inline elements. They are the foundation for list virtualization later.
- Template source: [DataTemplate.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml/Templates/DataTemplate.cs).

## 11. Work with resources (`FindResource`)

- Declare brushes, converters, or styles in `Window.Resources` or `Application.Resources`.
- Retrieve them at runtime with `FindResource` or `TryFindResource`:

```xml
<Window.Resources>
  <SolidColorBrush x:Key="HighlightBrush" Color="#FFE57F"/>
</Window.Resources>
```

```csharp
private void OnHighlight(object? sender, RoutedEventArgs e)
{
    if (FindResource("HighlightBrush") is IBrush brush)
    {
        Background = brush;
    }
}
```

- `FindResource` walks the logical tree first, then escalates to application resources, mirroring how the XAML parser resolves `StaticResource`.
- Resources defined inside a `UserControl` or `DataTemplate` are scoped; use `this.Resources` to override per-view resources without affecting the rest of the app.

## 12. Run, inspect, and iterate

```bash
dotnet run
```

While the app runs:
- Press **F12** (DevTools). Explore both logical and visual trees for `OrderRow` entries.
- Select an `OrderRow` TextBlock and confirm the binding path (`Total`) resolves to the right data.
- Try editing `OrderViewModel` values in code and rerun to see updates.

## Troubleshooting
- **Binding path errors**: DevTools -> Diagnostics -> Binding Errors shows typos. Ensure properties exist or set `x:DataType="vm:OrderViewModel"` in templates for compile-time checks (once you add namespaces for view models).
- **Converter not found**: ensure the namespace prefix in `App.axaml` matches the converter's CLR namespace and the key matches `StaticResource CurrencyConverter`.
- **User control not rendering**: confirm the namespace prefix `xmlns:ui` matches the CLR namespace of `OrderRow` and that the class is `partial` with matching `x:Class`.
- **FindControl returns null**: check `NameScope`. If the element is inside a data template, use `e.Source` from events or bind through the ViewModel instead of searching.

## Practice and validation
1. Add a `ui:AddressCard` user control showing billing address details. Bind it to `Customer` using `ContentControl.Content="{Binding Customer}"` and define a data template for `CustomerViewModel`.
2. Add a `ValueConverter` that highlights orders above $500 by returning a different brush; apply it to the Border background via `{Binding Total, Converter=...}`.
3. Name the `ItemsControl` (`x:Name="OrdersList"`) and call `this.FindControl<ItemsControl>("OrdersList")` in code-behind to verify name scoping.
4. Override `HighlightBrush` in `MainWindow.Resources` and use `FindResource` to swap the window background at runtime (e.g., from a button click).
5. Add a `ListBox` instead of `ItemsControl` and observe how selection adds visual states in the visual tree.
6. Use DevTools to inspect both logical and visual trees for `OrderRow`. Toggle the Namescope overlay to see how scopes nest.

## Look under the hood (source bookmarks)
- XAML loader: [src/Markup/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs)
- Content control composition: [src/Avalonia.Controls/ContentControl.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ContentControl.cs)
- User controls and name scopes: [src/Avalonia.Controls/UserControl.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/UserControl.cs)
- `NameScope` implementation: [src/Avalonia.Base/Styling/NameScope.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/NameScope.cs)
- Logical tree helpers: [src/Avalonia.Base/LogicalTree/LogicalTreeExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/LogicalTree/LogicalTreeExtensions.cs)
- Data template implementation: [src/Markup/Avalonia.Markup.Xaml/Templates/DataTemplate.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml/Templates/DataTemplate.cs)
- Value converters: [src/Avalonia.Base/Data/Converters](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Data/Converters)

## Check yourself
- How do XAML namespaces (`xmlns`) relate to CLR namespaces and assemblies?
- What is the difference between the logical and visual tree, and why does it matter for bindings?
- How do `ContentControl` and `UserControl` differ and when would you choose each?
- Where do you register value converters so they can be referenced in XAML?
- Inside a `DataTemplate`, what object provides the `DataContext`?

What's next
- Next: [Chapter 4](Chapter04.md)
