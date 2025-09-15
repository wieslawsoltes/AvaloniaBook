# 9. Commands, events, and user input

Goal
- Understand when to use events vs commands and how they relate to MVVM.
- Implement and bind ICommand for Buttons and menu items.
- Pass CommandParameter, wire up keyboard shortcuts with KeyBinding, and handle pointer/keyboard events.
- Manage focus and common user input patterns.

What you’ll build
- A small screen that:
  - Uses commands for Save/Delete actions (with CanExecute logic).
  - Binds a keyboard shortcut (Ctrl+S) to Save.
  - Handles a double‑click and a pointer press event.
  - Demonstrates focus and Enter‑to‑submit behavior.

Prerequisites
- You can run an Avalonia app, edit XAML, and create a basic view model (Ch. 2–8).

1) Events vs commands (and why MVVM favors commands)
- Events call methods directly in code‑behind (imperative): great for low‑level input and one‑off UI behaviors.
- Commands expose intent (Save, Delete) on your view model via the ICommand interface: great for testability and re‑use.
- Rule of thumb:
  - UI intent → Command (Button.Command, MenuItem.Command, KeyBinding → Command)
  - Low‑level input or gestures → Event (PointerPressed, KeyDown, DoubleTapped)

2) Create a simple ICommand implementation (RelayCommand)
- Add a lightweight command class:

```csharp
using System;
using System.Windows.Input;

public class RelayCommand : ICommand
{
    private readonly Action<object?> _execute;
    private readonly Func<object?, bool>? _canExecute;

    public RelayCommand(Action<object?> execute, Func<object?, bool>? canExecute = null)
    {
        _execute = execute ?? throw new ArgumentNullException(nameof(execute));
        _canExecute = canExecute;
    }

    public bool CanExecute(object? parameter) => _canExecute?.Invoke(parameter) ?? true;
    public void Execute(object? parameter) => _execute(parameter);

    public event EventHandler? CanExecuteChanged;
    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}
```

3) Expose commands in your view model

```csharp
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Input;

public class MainViewModel : INotifyPropertyChanged
{
    private bool _hasChanges;
    public bool HasChanges
    {
        get => _hasChanges;
        set { if (_hasChanges != value) { _hasChanges = value; OnPropertyChanged(); (SaveCommand as RelayCommand)?.RaiseCanExecuteChanged(); } }
    }

    public ICommand SaveCommand { get; }
    public ICommand DeleteCommand { get; }

    public MainViewModel()
    {
        SaveCommand = new RelayCommand(_ => Save(), _ => HasChanges);
        DeleteCommand = new RelayCommand(p => Delete(p));
    }

    private void Save()
    {
        // Persist data...
        HasChanges = false; // Re-evaluate CanExecute
    }

    private void Delete(object? parameter)
    {
        // Use parameter (e.g., currently selected item)
        HasChanges = true;
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    void OnPropertyChanged([CallerMemberName] string? n = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(n));
}
```

4) Bind Button.Command (and pass CommandParameter)

```xml
<StackPanel Spacing="8">
  <TextBox Watermark="Type something" Text="{Binding SomeText, Mode=TwoWay}"/>

  <Button Content="Save"
          Command="{Binding SaveCommand}"/>

  <Button Content="Delete selected"
          Command="{Binding DeleteCommand}"
          CommandParameter="{Binding SelectedItem}"/>
</StackPanel>
```

- CommandParameter can pass a selected item, an ID, or any value the command needs.
- Buttons automatically disable when CanExecute returns false.

5) Add keyboard shortcuts with KeyBinding
- Wire Ctrl+S to Save at your Window level so it works anywhere in the view:

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="MyApp.MainWindow">
  <Window.InputBindings>
    <KeyBinding Gesture="Ctrl+S" Command="{Binding SaveCommand}"/>
  </Window.InputBindings>

  <!-- content -->
</Window>
```

- You can also set CommandParameter on KeyBinding if your command expects one.

6) Handle common events (low‑level input)
- Use events when you need raw input or quick UI reactions.

Double‑click on a list:
```xml
<ListBox x:Name="People" ItemsSource="{Binding People}" DoubleTapped="People_DoubleTapped"/>
```

```csharp
using Avalonia.Interactivity;
using Avalonia.Controls;

private void People_DoubleTapped(object? sender, RoutedEventArgs e)
{
    if (sender is ListBox lb && lb.SelectedItem is not null)
    {
        // Open details, or execute a command with the selected item
        if (DataContext is MainViewModel vm && vm.DeleteCommand.CanExecute(lb.SelectedItem))
            vm.DeleteCommand.Execute(lb.SelectedItem);
    }
}
```

Pointer position inside a control:
```xml
<Border Background="#EEE" Padding="8" PointerPressed="Border_PointerPressed">
  <TextBlock Text="Click in this area"/>
</Border>
```

```csharp
using Avalonia.Input;
using Avalonia.VisualTree;

private void Border_PointerPressed(object? sender, PointerPressedEventArgs e)
{
    if (sender is IVisual v)
    {
        var p = e.GetPosition(v);
        // Use p.X, p.Y as needed
    }
}
```

Handle Enter key in a TextBox to trigger Save:
```xml
<TextBox x:Name="Input" KeyDown="Input_KeyDown"/>
```

```csharp
using Avalonia.Input;

private void Input_KeyDown(object? sender, KeyEventArgs e)
{
    if (e.Key == Key.Enter && DataContext is MainViewModel vm)
    {
        if (vm.SaveCommand.CanExecute(null))
            vm.SaveCommand.Execute(null);
        e.Handled = true;
    }
}
```

7) Focus and tab navigation
- Any control with Focusable="True" can receive focus. Call Focus() from code to move focus.

```xml
<TextBox x:Name="First"/>
<TextBox x:Name="Second"/>
<Button Content="Focus second" Click="FocusSecond_Click"/>
```

```csharp
private void FocusSecond_Click(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
{
    Second.Focus();
}
```

- Use TabIndex to control tab order. Disable focus for decorative elements with Focusable="False".

8) CheckBox and RadioButton patterns
- Toggle inputs still work great with commands:

```xml
<CheckBox Content="Enable advanced" IsChecked="{Binding IsAdvanced, Mode=TwoWay}"/>
<StackPanel IsEnabled="{Binding IsAdvanced}">
  <!-- advanced controls here -->
</StackPanel>

<StackPanel>
  <RadioButton Content="Small" GroupName="Size" IsChecked="{Binding IsSmall, Mode=TwoWay}"/>
  <RadioButton Content="Large" GroupName="Size" IsChecked="{Binding IsLarge, Mode=TwoWay}"/>
</StackPanel>
```

9) Choosing between events and commands
- Prefer Command for user intentions you might test, invoke from multiple places (button, menu, shortcut), or enable/disable.
- Prefer Events for raw input data and gestures where parameters are positional or transient.
- You can mix both: an event handler may delegate to a command in the view model.

Check yourself
- Why do commands fit MVVM better than handling all logic in code‑behind events?
- What happens to a Button when its Command’s CanExecute returns false?
- How do you attach Ctrl+S to a command?
- When would you pass a CommandParameter?

Look under the hood (repo reading list)
- Input and routed events: src/Avalonia.Interactivity, src/Avalonia.Input
- Command binding points: ButtonBase.Command, MenuItem.Command, KeyBinding/KeyGesture

Extra practice
- Add a CommandParameter to SaveCommand that includes the current text and a timestamp.
- Add Ctrl+Delete to trigger DeleteCommand on the selected list item.
- Disable Save when a required TextBox is empty (tie CanExecute to your validation).
- Show a context menu with a command that acts on the right‑clicked item.

What’s next
- Next: [Chapter 10](Chapter10.md)
