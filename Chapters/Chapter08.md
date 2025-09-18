# 8. Data binding basics you'll use every day

Goal
- Understand the binding engine (DataContext, binding paths, inheritance) and when to use different binding modes.
- Work with binding variations (`Binding`, `CompiledBinding`, `MultiBinding`, `PriorityBinding`, `ElementName`, `RelativeSource`).
- Connect collections to `ItemsControl`/`ListBox` with data templates and selection models.
- Use converters, validation (`INotifyDataErrorInfo`), and asynchronous bindings for real-world scenarios.
- Diagnose bindings using Avalonia's DevTools and `BindingDiagnostics` logging.

Why this matters
- Bindings keep UI and data in sync, reducing boilerplate and keeping views declarative.
- Picking the right binding technique (compiled, multi-value, priority) improves performance and readability.
- Diagnostics help track down "binding isn't working" issues quickly.

Prerequisites
- You can create a project and run it (Chapters 2-7).
- You've seen basic controls and templates (Chapters 3 & 6).

## 1. The binding engine at a glance

Avalonia's binding engine lives under [`src/Avalonia.Base/Data`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Data). Key pieces:
- `DataContext`: inherited down the logical tree. Most bindings resolve relative to the current element's DataContext.
- `Binding`: describes a path, mode, converter, fallback, etc.
- `BindingBase`: base for compiled bindings, multi bindings, priority bindings.
- `BindingExpression`: runtime evaluation created for each binding target.

Bindings resolve in this order:
1. Find the source (DataContext, element name, relative source, etc.).
2. Evaluate the path (e.g., `Customer.Name`).
3. Apply converters or string formatting.
4. Update the target property according to the binding mode.

## 2. Set up the sample project

```bash
dotnet new avalonia.mvvm -o BindingPlayground
cd BindingPlayground
```

We'll expand `MainWindow.axaml` and `MainWindowViewModel.cs`.

## 3. Core bindings (OneWay, TwoWay, OneTime)

View model implementing `INotifyPropertyChanged`:

```csharp
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace BindingPlayground.ViewModels;

public class PersonViewModel : INotifyPropertyChanged
{
    private string _firstName = "Ada";
    private string _lastName = "Lovelace";
    private int _age = 36;

    public string FirstName
    {
        get => _firstName;
        set { if (_firstName != value) { _firstName = value; OnPropertyChanged(); OnPropertyChanged(nameof(FullName)); } }
    }

    public string LastName
    {
        get => _lastName;
        set { if (_lastName != value) { _lastName = value; OnPropertyChanged(); OnPropertyChanged(nameof(FullName)); } }
    }

    public int Age
    {
        get => _age;
        set { if (_age != value) { _age = value; OnPropertyChanged(); } }
    }

    public string FullName => ($"{FirstName} {LastName}").Trim();

    public event PropertyChangedEventHandler? PropertyChanged;
    protected void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
```

In `MainWindow.axaml` set the DataContext:

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="clr-namespace:BindingPlayground.ViewModels"
        x:Class="BindingPlayground.Views.MainWindow">
  <Window.DataContext>
    <vm:MainWindowViewModel />
  </Window.DataContext>

  <Design.DataContext>
    <vm:MainWindowViewModel />
  </Design.DataContext>


</Window>
```

`Design.DataContext` provides design-time data in the previewer.

## 4. Binding modes in action

```xml
<Grid ColumnDefinitions="*,*" RowDefinitions="Auto,*" Padding="16" RowSpacing="16" ColumnSpacing="24">
  <TextBlock Grid.ColumnSpan="2" Classes="h1" Text="Binding basics"/>

  <StackPanel Grid.Row="1" Spacing="8">
    <TextBox Watermark="First name" Text="{Binding Person.FirstName, Mode=TwoWay}"/>
    <TextBox Watermark="Last name"  Text="{Binding Person.LastName, Mode=TwoWay}"/>
    <NumericUpDown Minimum="0" Maximum="120" Value="{Binding Person.Age, Mode=TwoWay}"/>
  </StackPanel>

  <StackPanel Grid.Column="1" Grid.Row="1" Spacing="8">
    <TextBlock Text="Live view" FontWeight="SemiBold"/>
    <TextBlock Text="{Binding Person.FullName, Mode=OneWay}" FontSize="20"/>
    <TextBlock Text="{Binding Person.Age, Mode=OneWay}"/>
    <TextBlock Text="{Binding CreatedAt, Mode=OneTime, StringFormat='Created on {0:d}'}"/>
  </StackPanel>
</Grid>
```

`MainWindowViewModel` holds `Person` and other state:

```csharp
using System;
using System.Collections.ObjectModel;

namespace BindingPlayground.ViewModels;

public class MainWindowViewModel : INotifyPropertyChanged
{
    public PersonViewModel Person { get; } = new();
    public DateTime CreatedAt { get; } = DateTime.Now;

    // Additional samples below
}
```

## 5. ElementName and RelativeSource

### ElementName binding

```xml
<StackPanel Margin="0,24,0,0" Spacing="6">
  <Slider x:Name="VolumeSlider" Minimum="0" Maximum="100" Value="50"/>
  <ProgressBar Minimum="0" Maximum="100" Value="{Binding #VolumeSlider.Value}"/>
</StackPanel>
```

`#VolumeSlider` targets the element with `x:Name="VolumeSlider"`.

### RelativeSource binding

Use `RelativeSource` to bind to ancestors:

```xml
<TextBlock Text="{Binding DataContext.Person.FullName, RelativeSource={RelativeSource AncestorType=Window}}"/>
```

This binds to the window's DataContext even if the local control has its own DataContext.

Relative source syntax also supports `Self` (`RelativeSource={RelativeSource Self}`) and `TemplatedParent` for control templates.

## 6. Compiled bindings

Compiled bindings (`CompiledBinding`) produce strongly-typed accessors with better performance. Require `x:DataType` or `CompiledBindings` namespace:

1. Add namespace to the root element:

```xml
xmlns:vm="clr-namespace:BindingPlayground.ViewModels"
```

2. Set `x:DataType` on a scope:

```xml
<StackPanel DataContext="{Binding Person}" x:DataType="vm:PersonViewModel">
  <TextBlock Text="{CompiledBinding FullName}"/>
  <TextBox Text="{CompiledBinding FirstName}"/>
</StackPanel>
```

If `x:DataType` is set, `CompiledBinding` uses compile-time checking and generates binding code. Source: [`CompiledBindingExtension.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml/MarkupExtensions/CompiledBindingExtension.cs).

## 7. MultiBinding and PriorityBinding

### MultiBinding

Combine multiple values into one target:

```csharp
public sealed class NameAgeFormatter : IMultiValueConverter
{
    public object? Convert(IList<object?> values, Type targetType, object? parameter, CultureInfo culture)
    {
        var name = values[0] as string ?? "";
        var age = values[1] as int? ?? 0;
        return $"{name} ({age})";
    }

    public object? ConvertBack(IList<object?> values, Type targetType, object? parameter, CultureInfo culture) => throw new NotSupportedException();
}
```

Register in resources:

```xml
<Window.Resources>
  <conv:NameAgeFormatter x:Key="NameAgeFormatter"/>
</Window.Resources>
```

Use it:

```xml
<TextBlock>
  <TextBlock.Text>
    <MultiBinding Converter="{StaticResource NameAgeFormatter}">
      <Binding Path="Person.FullName"/>
      <Binding Path="Person.Age"/>
    </MultiBinding>
  </TextBlock.Text>
</TextBlock>
```

### PriorityBinding

Priority bindings try sources in order and use the first that yields a value:

```xml
<TextBlock>
  <TextBlock.Text>
    <PriorityBinding>
      <Binding Path="OverrideTitle"/>
      <Binding Path="Person.FullName"/>
      <Binding Path="Person.FirstName"/>
      <Binding Path="'Unknown user'"/>
    </PriorityBinding>
  </TextBlock.Text>
</TextBlock>
```

Source: [`PriorityBinding.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup/Data/PriorityBinding.cs).

## 8. Lists, selection, and templates

`MainWindowViewModel` exposes collections:

```csharp
public ObservableCollection<PersonViewModel> People { get; } = new()
{
    new PersonViewModel { FirstName = "Ada", LastName = "Lovelace", Age = 36 },
    new PersonViewModel { FirstName = "Grace", LastName = "Hopper", Age = 45 },
    new PersonViewModel { FirstName = "Linus", LastName = "Torvalds", Age = 32 }
};

private PersonViewModel? _selectedPerson;
public PersonViewModel? SelectedPerson
{
    get => _selectedPerson;
    set { if (_selectedPerson != value) { _selectedPerson = value; OnPropertyChanged(); } }
}
```

Template the list:

```xml
<ListBox Items="{Binding People}"
         SelectedItem="{Binding SelectedPerson, Mode=TwoWay}"
         Height="180">
  <ListBox.ItemTemplate>
    <DataTemplate x:DataType="vm:PersonViewModel">
      <StackPanel Orientation="Horizontal" Spacing="12">
        <TextBlock Text="{CompiledBinding FullName}" FontWeight="SemiBold"/>
        <TextBlock Text="{CompiledBinding Age}"/>
      </StackPanel>
    </DataTemplate>
  </ListBox.ItemTemplate>
</ListBox>
```

Inside the details pane, bind to `SelectedPerson` safely using null-conditional binding (C#) or triggers. XAML automatically handles null (shows blank). Use `x:DataType` for compile-time checks.

### `SelectionModel`

For advanced selection (multi-select, range), use `SelectionModel<T>` from [`SelectionModel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Selection/SelectionModel.cs). Example:

```csharp
public SelectionModel<PersonViewModel> PeopleSelection { get; } = new() { SelectionMode = SelectionMode.Multiple };
```

Bind it:

```xml
<ListBox Items="{Binding People}" Selection="{Binding PeopleSelection}"/>
```

## 9. Validation with `INotifyDataErrorInfo`

Implement `INotifyDataErrorInfo` for asynchronous validation.

```csharp
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;

public class ValidatingPersonViewModel : PersonViewModel, INotifyDataErrorInfo
{
    private readonly Dictionary<string, List<string>> _errors = new();

    public bool HasErrors => _errors.Count > 0;

    public event EventHandler<DataErrorsChangedEventArgs>? ErrorsChanged;

    public IEnumerable GetErrors(string? propertyName)
        => propertyName is not null && _errors.TryGetValue(propertyName, out var errors) ? errors : Array.Empty<string>();

    protected override void OnPropertyChanged(string? propertyName)
    {
        base.OnPropertyChanged(propertyName);
        Validate(propertyName);
    }

    private void Validate(string? propertyName)
    {
        if (propertyName is nameof(Age))
        {
            if (Age < 0 || Age > 120)
                AddError(propertyName, "Age must be between 0 and 120");
            else
                ClearErrors(propertyName);
        }
    }

    private void AddError(string propertyName, string error)
    {
        if (!_errors.TryGetValue(propertyName, out var list))
            _errors[propertyName] = list = new List<string>();

        if (!list.Contains(error))
        {
            list.Add(error);
            ErrorsChanged?.Invoke(this, new DataErrorsChangedEventArgs(propertyName));
        }
    }

    private void ClearErrors(string propertyName)
    {
        if (_errors.Remove(propertyName))
            ErrorsChanged?.Invoke(this, new DataErrorsChangedEventArgs(propertyName));
    }
}
```

Bind the validation feedback automatically:

```xml
<TextBox Text="{Binding ValidatingPerson.FirstName, Mode=TwoWay}"/>
<TextBox Text="{Binding ValidatingPerson.Age, Mode=TwoWay}"/>
<TextBlock Foreground="#B91C1C" Text="{Binding (Validation.Errors)[0].ErrorContent, RelativeSource={RelativeSource Self}}"/>
```

Avalonia surfaces validation errors via attached properties. For a full pattern see [`Validation`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Validation).

## 10. Asynchronous bindings

Use `Task`-returning properties with `Binding` and `BindingPriority.AsyncLocalValue`. Example view model property:

```csharp
private string? _weather;
public string? Weather
{
    get => _weather;
    private set { if (_weather != value) { _weather = value; OnPropertyChanged(); } }
}

public async Task LoadWeatherAsync()
{
    Weather = "Loading...";
    var result = await _weatherService.GetForecastAsync();
    Weather = result;
}
```

Bind with fallback until the value arrives:

```xml
<TextBlock Text="{Binding Weather, FallbackValue='Fetching forecast...'}"/>
```

You can also bind directly to `Task` results using `TaskObservableCollection` or reactive extensions (Chapter 17 covers background work).

## 11. Binding diagnostics

- **DevTools**: press F12 -> Diagnostics -> Binding Errors tab. Inspect live errors (missing properties, converters failing).
- **Binding logging**: enable via `BindingDiagnostics`.

```csharp
using Avalonia.Diagnostics;

public override void OnFrameworkInitializationCompleted()
{
    BindingDiagnostics.Enable(
        log => Console.WriteLine(log.Message),
        new BindingDiagnosticOptions
        {
            Level = BindingDiagnosticLogLevel.Warning
        });

    base.OnFrameworkInitializationCompleted();
}
```

Source: [`BindingDiagnostics.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/BindingDiagnostics.cs).

Use `TraceBindingFailures` extension to log failures for specific bindings.

## 12. Practice exercises

1. **Compiled binding sweep**: add `x:DataType` to each data template and replace `Binding` with `CompiledBinding` where possible. Observe compile-time errors when property names are mistyped.
2. **MultiBinding formatting**: create a multi binding that formats `FirstName`, `LastName`, and `Age` into a sentence like "Ada Lovelace is 36 years old." Add a converter parameter for custom formats.
3. **Priority fallback**: allow a user-provided display name to override `FullName`, falling back to initials if names are empty.
4. **Validation UX**: display validation errors inline using `INotifyDataErrorInfo` and highlight inputs (`Style Selector="TextBox:invalid"`).
5. **Diagnostics drill**: intentionally break a binding (typo) and use DevTools and `BindingDiagnostics` to find it. Fix the binding and confirm logs clear.

## Look under the hood (source bookmarks)
- Binding implementation: [`Binding.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Data/Binding.cs), [`BindingExpression.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Data/BindingExpression.cs)
- Compiled bindings: [`CompiledBindingExtension.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml/MarkupExtensions/CompiledBindingExtension.cs)
- Multi/Priority binding: [`MultiBinding.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup/Data/MultiBinding.cs), [`PriorityBinding.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup/Data/PriorityBinding.cs)
- Selection model: [`SelectionModel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Selection/SelectionModel.cs)
- Validation: [`Validation.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Validation/Validation.cs)
- Diagnostics: [`BindingDiagnostics.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/BindingDiagnostics.cs)

## Check yourself
- When would you choose `CompiledBinding` over `Binding`? What prerequisites does it have?
- How do `ElementName` and `RelativeSource` differ in resolving binding sources?
- What scenarios call for `MultiBinding` or `PriorityBinding`?
- How does `INotifyDataErrorInfo` surface validation errors to the UI? What attached properties expose them?
- Which tools can you use to debug binding failures during development?

What's next
- Next: [Chapter 9](Chapter09.md)
