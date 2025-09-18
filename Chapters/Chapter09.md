# 9. Commands, events, and user input

Goal
- Understand Avalonia's input system: routed events, commands, gesture recognizers, and keyboard navigation.
- Choose between MVVM-friendly commands and low-level events effectively.
- Wire keyboard shortcuts, pointer gestures, and access keys; capture pointer input for drag scenarios.
- Implement asynchronous commands and recycle CanExecute logic with reactive or toolkit helpers.
- Diagnose input issues with DevTools (Events view) and logging.

Why this matters
- Robust input handling keeps UI responsive and testable.
- Commands keep business logic in view models; events cover fine-grained gestures.
- Knowing the pipeline (routed events -> gesture recognizers -> commands) helps debug "nothing happened" scenarios.

Prerequisites
- Chapters 3-8 (layouts, controls, binding, theming).
- Basic MVVM knowledge and an `INotifyPropertyChanged` view model.

## 1. Input building blocks

Avalonia input pieces live under:
- Routed events infrastructure: [`src/Avalonia.Interactivity`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Interactivity)
- Input elements & devices: [`src/Avalonia.Base/Input`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Input)
- Gesture recognizers (tap, pointer, scroll): [`src/Avalonia.Base/Input/GestureRecognizers`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Input/GestureRecognizers)

Event flow:
1. Input devices raise raw events (`PointerPressed`, `KeyDown`).
2. Routed events bubble/tunnel through the visual tree.
3. Gesture recognizers translate raw input into high-level events (TapGesture, DoubleTapped).
4. Commands may execute via Buttons, KeyBindings, Access keys.

## 2. Sample project setup

```bash
dotnet new avalonia.mvvm -o InputPlayground
cd InputPlayground
```

`MainWindowViewModel` exposes commands and state. Add `CommunityToolkit.Mvvm` or implement your own `AsyncRelayCommand` to simplify asynchronous logic. Example below uses a simple `RelayCommand` and `AsyncRelayCommand`.

```csharp
using System;
using System.Threading.Tasks;
using System.Windows.Input;

namespace InputPlayground.ViewModels;

public sealed class MainWindowViewModel : ViewModelBase
{
    private string _status = "Ready";
    public string Status
    {
        get => _status;
        private set => SetProperty(ref _status, value);
    }

    private bool _hasChanges;
    public bool HasChanges
    {
        get => _hasChanges;
        set
        {
            if (SetProperty(ref _hasChanges, value))
            {
                SaveCommand.RaiseCanExecuteChanged();
            }
        }
    }

    public RelayCommand SaveCommand { get; }
    public RelayCommand DeleteCommand { get; }
    public AsyncRelayCommand RefreshCommand { get; }

    public MainWindowViewModel()
    {
        SaveCommand = new RelayCommand(_ => Save(), _ => HasChanges);
        DeleteCommand = new RelayCommand(item => Delete(item));
        RefreshCommand = new AsyncRelayCommand(RefreshAsync, () => !IsBusy);
    }

    private bool _isBusy;
    public bool IsBusy
    {
        get => _isBusy;
        private set
        {
            if (SetProperty(ref _isBusy, value))
            {
                RefreshCommand.RaiseCanExecuteChanged();
            }
        }
    }

    private void Save()
    {
        Status = "Saved";
        HasChanges = false;
    }

    private void Delete(object? parameter)
    {
        Status = parameter is string name ? $"Deleted {name}" : "Deleted item";
        HasChanges = true;
    }

    private async Task RefreshAsync()
    {
        try
        {
            IsBusy = true;
            Status = "Refreshing...";
            await Task.Delay(1500);
            Status = "Data refreshed";
        }
        finally
        {
            IsBusy = false;
        }
    }
}
```

Supporting command classes (`RelayCommand`, `AsyncRelayCommand`) go in `Commands` folder. You may reuse the ones from CommunityToolkit.Mvvm or ReactiveUI.

## 3. Commands vs events cheat sheet

| Use command when... | Use event when... |
| --- | --- |
| You expose an action (Save/Delete) from view model | You need pointer coordinates, delta, or low-level control |
| You want CanExecute/disable logic | You're implementing custom gestures/drag interactions |
| The action runs from buttons, menus, shortcuts | Work is purely visual or specific to a view |
| You plan to unit test the action | Data is transient or you need immediate UI feedback |

Most real views mix both: commands for operations, events for gestures.

## 4. Binding commands in XAML

```xml
<StackPanel Spacing="12">
  <TextBox Watermark="Name" Text="{Binding SelectedName, Mode=TwoWay}"/>

  <StackPanel Orientation="Horizontal" Spacing="12">
    <Button Content="Save" Command="{Binding SaveCommand}"/>
    <Button Content="Refresh" Command="{Binding RefreshCommand}" IsEnabled="{Binding !IsBusy}"/>
    <Button Content="Delete" Command="{Binding DeleteCommand}"
            CommandParameter="{Binding SelectedName}"/>
  </StackPanel>

  <TextBlock Text="{Binding Status}"/>
</StackPanel>
```

Buttons disable automatically when `SaveCommand.CanExecute` returns false.

## 5. Keyboard shortcuts and access keys

### KeyBinding / KeyGesture

```xml
<Window ...>
  <Window.InputBindings>
    <KeyBinding Gesture="Ctrl+S" Command="{Binding SaveCommand}"/>
    <KeyBinding Gesture="Ctrl+R" Command="{Binding RefreshCommand}"/>
    <KeyBinding Gesture="Ctrl+Delete" Command="{Binding DeleteCommand}" CommandParameter="{Binding SelectedName}"/>
  </Window.InputBindings>


</Window>
```

`KeyGesture` parsing is handled by [`KeyGestureConverter`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyGestureConverter.cs). For multiple gestures, add more `KeyBinding` entries.

### Access keys (mnemonics)

Use `_` to define an access key in headers (e.g., `_Save`). Access keys work when Alt is pressed.

```xml
<Menu>
  <MenuItem Header="_File">
    <MenuItem Header="_Save" Command="{Binding SaveCommand}" InputGesture="Ctrl+S"/>
  </MenuItem>
</Menu>
```

Access keys are processed via `AccessKeyHandler` ([`AccessKeyHandler.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/AccessKeyHandler.cs)).

## 6. Pointer gestures and recognizers

Avalonia includes built-in gesture recognizers. You can attach them via `GestureRecognizers` collection:

```xml
<Border Background="#1e293b" Padding="16">
  <Border.GestureRecognizers>
    <TapGestureRecognizer NumberOfTapsRequired="2" Command="{Binding DoubleTapCommand}" CommandParameter="Canvas"/>
    <ScrollGestureRecognizer CanHorizontallyScroll="True" CanVerticallyScroll="True"/>
  </Border.GestureRecognizers>

  <TextBlock Foreground="White" Text="Double-tap or scroll"/>
</Border>
```

Implementation: [`TapGestureRecognizer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/GestureRecognizers/TapGestureRecognizer.cs).

For custom gestures (drag to reorder), handle `PointerPressed`, call `e.Pointer.Capture(control)` to capture input, and release on `PointerReleased`. Pointer capture ensures subsequent move/press events go to the capture target even if the pointer leaves its bounds.

```csharp
private bool _isDragging;
private Point _dragStart;

private void Card_PointerPressed(object? sender, PointerPressedEventArgs e)
{
    _isDragging = true;
    _dragStart = e.GetPosition((Control)sender!);
    e.Pointer.Capture((IInputElement)sender!);
}

private void Card_PointerMoved(object? sender, PointerEventArgs e)
{
    if (_isDragging && sender is Control control)
    {
        var offset = e.GetPosition(control) - _dragStart;
        Canvas.SetLeft(control, offset.X);
        Canvas.SetTop(control, offset.Y);
    }
}

private void Card_PointerReleased(object? sender, PointerReleasedEventArgs e)
{
    _isDragging = false;
    e.Pointer.Capture(null);
}
```

See [`PointerCapture`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/Pointer/PointerDevice.cs) for details.

## 7. Text input pipeline (IME & composition)

Text entry flows through `TextInput` events. For IME (Asian languages), Avalonia raises `TextInput` with composition events. To hook into the pipeline, subscribe to `TextInput` or implement `ITextInputMethodClient` in custom controls. Source: [`TextInputMethodClient.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputMethodClient.cs).

```xml
<TextBox TextInput="TextBox_TextInput"/>
```

```csharp
private void TextBox_TextInput(object? sender, TextInputEventArgs e)
{
    Debug.WriteLine($"TextInput: {e.Text}");
}
```

In most MVVM apps you rely on `TextBox` handling IME; implement this only when creating custom text editors.

## 8. Focus management and keyboard navigation

- Set `Focus()` to move focus programmatically.
- Use `Focusable="False"` on non-interactive elements.
- Control tab order with `TabIndex` (lower numbers focus first).
- Create focus scopes with `FocusManager` when using popups or overlays.

```xml
<StackPanel>
  <TextBox x:Name="First"/>
  <TextBox x:Name="Second"/>
  <Button Content="Focus second" Command="{Binding FocusSecondCommand}"/>
</StackPanel>
```

In the view model, expose a command that raises an event or use a focus service. For small cases, code-behind calling `Second.Focus()` is sufficient.

## 9. Routed commands and command routing

Avalonia supports routed commands similar to WPF. Define a `RoutedCommand` (`RoutedCommandLibrary.Save`, etc.) and attach handlers via `CommandBinding`.

```xml
<Window.CommandBindings>
  <CommandBinding Command="{x:Static commands:AppCommands.Save}" Executed="Save_Executed" CanExecute="Save_CanExecute"/>
</Window.CommandBindings>
```

```csharp
private void Save_Executed(object? sender, ExecutedRoutedEventArgs e)
{
    if (DataContext is MainWindowViewModel vm)
        vm.SaveCommand.Execute(null);
}

private void Save_CanExecute(object? sender, CanExecuteRoutedEventArgs e)
{
    e.CanExecute = (DataContext as MainWindowViewModel)?.SaveCommand.CanExecute(null) == true;
}
```

Routed commands bubble up the tree if not handled, allowing menu items and toolbars to share command logic.

Source: [`RoutedCommand.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Interactivity/Input/RoutedCommand.cs).

## 10. Asynchronous commands

Avoid blocking the UI thread. Use `AsyncRelayCommand` or custom `ICommand` that runs `Task`.

```csharp
public sealed class AsyncRelayCommand : ICommand
{
    private readonly Func<Task> _execute;
    private readonly Func<bool>? _canExecute;
    private bool _isExecuting;

    public AsyncRelayCommand(Func<Task> execute, Func<bool>? canExecute = null)
    {
        _execute = execute;
        _canExecute = canExecute;
    }

    public bool CanExecute(object? parameter) => !_isExecuting && (_canExecute?.Invoke() ?? true);

    public async void Execute(object? parameter)
    {
        if (!CanExecute(parameter))
            return;

        try
        {
            _isExecuting = true;
            RaiseCanExecuteChanged();
            await _execute();
        }
        finally
        {
            _isExecuting = false;
            RaiseCanExecuteChanged();
        }
    }

    public event EventHandler? CanExecuteChanged;
    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}
```

## 11. Diagnostics: watch input live

DevTools (F12) -> **Events** tab let you monitor events (PointerPressed, KeyDown). Select an element, toggle events to watch.

Enable input logging:

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .LogToTrace(LogEventLevel.Debug, new[] { LogArea.Input })
    .StartWithClassicDesktopLifetime(args);
```

`LogArea.Input` (source: [`LogArea.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Logging/LogArea.cs)) emits detailed input information.

## 12. Practice exercises

1. Add `Ctrl+Shift+S` for "Save As" (new command) and ensure it's disabled when nothing is selected.
2. Implement a drag-to-reorder list using pointer capture. Use DevTools to verify pointer events.
3. Add a `TapGestureRecognizer` to a card view that toggles selection; log the event using `LogArea.Input`.
4. Implement asynchronous refresh with a cancellation token (Chapter 17) and tie the cancel command to the Esc key.
5. Use access keys (`_File`, `_Save`) and verify they work on Windows, macOS, and Linux keyboard layouts.

## Look under the hood (source bookmarks)
- Commands: [`ButtonBase.Command`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Primitives/ButtonBase.cs), [`MenuItem.Command`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/MenuItem.cs), [`KeyBinding`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Input/KeyBinding.cs)
- Input elements & events: [`InputElement.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/InputElement.cs), [`PointerGestureRecognizer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/GestureRecognizers/PointerGestureRecognizer.cs)
- Access keys: [`AccessText`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/AccessText.cs), [`AccessKeyHandler`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/AccessKeyHandler.cs)
- Text input pipeline: [`TextInputMethodClient.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputMethodClient.cs)

## Check yourself
- What advantages do commands offer over events in MVVM architectures?
- How do you wire Ctrl+S and Ctrl+Shift+S to different commands?
- When do you need pointer capture?
- What pieces are involved in handling a DoubleTap gesture?
- Which tooling surfaces input events and binding? How would you enable verbose input logging?

What's next
- Next: [Chapter 10](Chapter10.md)
