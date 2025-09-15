# 8. Data binding basics you’ll use every day

Goal
- Understand DataContext and how bindings connect your UI to a view model.
- Use binding modes (OneWay, TwoWay, OneTime) and element-to-element bindings.
- Bind lists with ItemsControl/ListBox, track SelectedItem, and display with DataTemplates.
- Create and use a simple value converter; add a minimal validation pattern.

What you’ll build
- A small view with text fields, a live FullName, a ListBox of people, and a simple converter.

Prerequisites
- You can run an Avalonia app and edit XAML/code-behind (Ch. 2–7).
- Basic C# (properties, classes, events) and INotifyPropertyChanged familiarity.

1) Set the DataContext
- The DataContext is the source object for most bindings in a view. Set it in code-behind or XAML.
- In XAML (recommended for samples), you can create a view model instance:

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="clr-namespace:MyApp.ViewModels"
        x:Class="MyApp.MainWindow">
  <Window.DataContext>
    <vm:MainViewModel />
  </Window.DataContext>

  <!-- content here -->
</Window>
```

- Or in code-behind after InitializeComponent:

```csharp
public MainWindow()
{
    InitializeComponent();
    DataContext = new MainViewModel();
}
```

2) Bind text: OneWay vs TwoWay vs OneTime
- Create a simple view model implementing INotifyPropertyChanged:

```csharp
using System.ComponentModel;
using System.Runtime.CompilerServices;

public class MainViewModel : INotifyPropertyChanged
{
    private string? _firstName;
    private string? _lastName;
    private int _age;

    public string? FirstName
    {
        get => _firstName;
        set { if (_firstName != value) { _firstName = value; OnPropertyChanged(); OnPropertyChanged(nameof(FullName)); } }
    }

    public string? LastName
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

- In XAML, TwoWay binding lets TextBox push changes back to the view model as you type:

```xml
<StackPanel Spacing="8">
  <TextBox Watermark="First name" Text="{Binding FirstName, Mode=TwoWay}"/>
  <TextBox Watermark="Last name"  Text="{Binding LastName, Mode=TwoWay}"/>

  <!-- OneWay: computed value from VM to UI -->
  <TextBlock Text="{Binding FullName, Mode=OneWay}"/>

  <!-- Age as number; binding still TwoWay -->
  <NumericUpDown Value="{Binding Age, Mode=TwoWay}" Minimum="0" Maximum="130"/>
</StackPanel>
```

- OneTime binds once at load; useful for constants. OneWay updates from VM to UI. TwoWay updates both ways.

3) Bind to another control (element-to-element)
- Sometimes the source isn’t the DataContext but another control:

```xml
<StackPanel Spacing="8">
  <Slider x:Name="S" Minimum="0" Maximum="100"/>
  <ProgressBar Minimum="0" Maximum="100" Value="{Binding #S.Value}"/>
</StackPanel>
```

- The #S syntax binds to the named element S’s Value.

4) Bind lists with ItemsControl and ListBox
- Add a People collection and SelectedPerson to the view model:

```csharp
using System.Collections.ObjectModel;

public class Person { public string Name { get; set; } = ""; public int Age { get; set; } }

public class MainViewModel : INotifyPropertyChanged
{
    // ... previous properties ...
    public ObservableCollection<Person> People { get; } = new()
    {
        new Person { Name = "Ada", Age = 28 },
        new Person { Name = "Linus", Age = 32 },
        new Person { Name = "Grace", Age = 45 },
    };

    private Person? _selectedPerson;
    public Person? SelectedPerson
    {
        get => _selectedPerson;
        set { if (_selectedPerson != value) { _selectedPerson = value; OnPropertyChanged(); } }
    }
}
```

- Bind ItemsSource and SelectedItem in XAML. Use a simple DataTemplate to display each person:

```xml
<DockPanel LastChildFill="True" Margin="0,8,0,0">
  <ListBox DockPanel.Dock="Left"
           Width="160"
           ItemsSource="{Binding People}"
           SelectedItem="{Binding SelectedPerson, Mode=TwoWay}">
    <ListBox.ItemTemplate>
      <DataTemplate>
        <TextBlock Text="{Binding Name}"/>
      </DataTemplate>
    </ListBox.ItemTemplate>
  </ListBox>

  <StackPanel Margin="12,0,0,0" Spacing="8">
    <TextBlock Text="Details" FontWeight="SemiBold"/>
    <TextBlock Text="{Binding SelectedPerson.Name}"/>
    <TextBlock Text="{Binding SelectedPerson.Age}"/>
  </StackPanel>
</DockPanel>
```

- Bindings can traverse properties: SelectedPerson.Name reads from the current DataContext’s SelectedPerson.

5) A simple value converter
- Converters translate data from the source to the target type. Create one that maps an age to a category:

```csharp
using System;
using Avalonia.Data.Converters;
using System.Globalization;

public class AgeCategoryConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is int age ? (age >= 18 ? "Adult" : "Minor") : null;

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotSupportedException();
}
```

- Register and use it in XAML:

```xml
<Window ... xmlns:conv="clr-namespace:MyApp.Converters">
  <Window.Resources>
    <conv:AgeCategoryConverter x:Key="AgeToCategory"/>
  </Window.Resources>
  <StackPanel>
    <TextBlock Text="{Binding Age, Converter={StaticResource AgeToCategory}}"/>
  </StackPanel>
</Window>
```

6) Minimal validation pattern
- There are several validation approaches. Here’s a simple one you can use immediately: expose an Error string and set it when input is invalid.

```csharp
private string? _ageError;
public string? AgeError
{
    get => _ageError;
    set { if (_ageError != value) { _ageError = value; OnPropertyChanged(); } }
}

public int Age
{
    get => _age;
    set
    {
        if (_age != value)
        {
            _age = value;
            AgeError = _age < 0 || _age > 130 ? "Age must be 0–130" : null;
            OnPropertyChanged();
        }
    }
}
```

- Show the error under the input:

```xml
<StackPanel Spacing="4">
  <NumericUpDown Value="{Binding Age, Mode=TwoWay}" Minimum="0" Maximum="130"/>
  <TextBlock Foreground="#B91C1C" Text="{Binding AgeError}"/>
</StackPanel>
```

- Later, you can adopt IDataErrorInfo or INotifyDataErrorInfo for richer validation (Chapter 11 touches MVVM patterns).

7) Common binding tips
- Use ObservableCollection for lists you modify at runtime.
- When a property depends on another (FullName depends on FirstName/LastName), raise PropertyChanged for both.
- Prefer TwoWay only when the user edits the value; use OneWay otherwise.
- For performance, avoid excessive ConvertBack when unnecessary.

Check yourself
- What does the DataContext do, and where does Avalonia look to resolve a binding?
- When do you use TwoWay vs OneWay vs OneTime?
- How do you bind to another control’s property?
- Why do you prefer ObservableCollection over List for ItemsSource?

Look under the hood (repo reading list)
- Binding engine and base types: src/Avalonia.Base (Data and Binding)
- Controls that display lists: src/Avalonia.Controls (ListBox, ItemsControl)

Extra practice
- Add a TextBox to filter People by name and update the ListBox in real time.
- Show a selected person editor (edit Name and Age) and ensure TwoWay binds update the list item.
- Write a converter that shows “Welcome, {FirstName}!” or a default message when empty.

What’s next
- Next: [Chapter 9](Chapter09.md)
