# 9. Commands, events, and user input

Goal
- Understand how routed events flow through `InputElement` and how gesture recognizers, commands, and keyboard navigation fit together.
- Choose between MVVM-friendly commands and low-level events effectively (and bridge them with hotkeys and toolkits).
- Wire keyboard shortcuts, pointer gestures, and access keys; capture pointer input for drag scenarios with `HotKeyManager` and pointer capture APIs.
- Implement asynchronous commands and recycle CanExecute logic with reactive or toolkit helpers.
- Diagnose input issues with DevTools (Events view), logging, and custom event tracing.

Why this matters
- Robust input handling keeps UI responsive and testable.
- Commands keep business logic in view models; events cover fine-grained gestures.
- Knowing the pipeline (routed events -> gesture recognizers -> commands) helps debug "nothing happened" scenarios.

Prerequisites
- Chapters 3-8 (layouts, controls, binding, theming).
- Basic MVVM knowledge and an `INotifyPropertyChanged` view model.

## 1. Input building blocks

Avalonia input pieces live under:
- Routed events: [`Avalonia.Interactivity`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Interactivity) defines `RoutedEvent`, event descriptors, and routing strategies.
- Core element hierarchy: [`InputElement`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/InputElement.cs) (inherits `Interactive` → `Visual` → `Animatable`) exposes focus, input, and command helpers that every control inherits.
- Devices & state: [`Avalonia.Base/Input`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Input) provides `Pointer`, `KeyboardDevice`, `KeyGesture`, `PointerPoint`.
- Gesture recognizers: [`GestureRecognizers`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Input/GestureRecognizers) translate raw pointer data into tap, scroll, drag behaviors.
- Hotkeys & command sources: [`HotkeyManager`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/HotkeyManager.cs) walks the visual tree to resolve `KeyGesture`s against `ICommand` targets.

Event flow:
1. Devices raise raw events (`PointerPressed`, `KeyDown`). Each is registered as a `RoutedEvent` with a routing strategy (tunnel, bubble, direct).
2. `InputElement` hosts the event metadata, raising class handlers and instance handlers.
3. Gesture recognizers subscribe to pointer streams and emit semantic events (`Tapped`, `DoubleTapped`, `PointerPressedEventArgs`).
4. Command sources (`Button.Command`, `KeyBinding`, `InputGesture`) execute `ICommand` implementations and update `CanExecute`.

Creating custom events uses the static registration helpers:

```csharp
public static readonly RoutedEvent<RoutedEventArgs> DragStartedEvent =
    RoutedEvent.Register<Control, RoutedEventArgs>(
        nameof(DragStarted),
        RoutingStrategies.Bubble);

public event EventHandler<RoutedEventArgs> DragStarted
{
    add => AddHandler(DragStartedEvent, value);
    remove => RemoveHandler(DragStartedEvent, value);
}
```

`RoutingStrategies` live in [`RoutedEvent.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Interactivity/RoutedEvent.cs); each handler chooses whether the event should travel from root to leaf (tunnel) or leaf to root (bubble).

## 2. Input playground setup

```bash
dotnet new avalonia.mvvm -o InputPlayground
cd InputPlayground
```

`MainWindowViewModel` exposes commands and state. Add `CommunityToolkit.Mvvm` or implement your own `AsyncRelayCommand` to simplify asynchronous logic. Hotkeys are attached in XAML using `HotKeyManager.HotKey`, keeping the view model free of UI dependencies.

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

## 5. Keyboard shortcuts, KeyGesture, and HotKeyManager

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

`KeyGesture` parsing is handled by [`KeyGesture`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyGesture.cs) and [`KeyGestureConverter`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyGestureConverter.cs). For multiple gestures, add more `KeyBinding` entries on the relevant `InputElement`.

### `HotKeyManager` attached property

`KeyBinding` only fires while the owning control is focused. To register process-wide hotkeys that stay active as long as a control is in the visual tree, attach a `KeyGesture` via `HotKeyManager.HotKey`:

```xml
<Window xmlns:controls="clr-namespace:Avalonia.Controls;assembly=Avalonia.Controls">
  <Button Content="Save"
          Command="{Binding SaveCommand}"
          controls:HotKeyManager.HotKey="Ctrl+Shift+S"/>
</Window>
```

`HotKeyManager` walks up to the owning `TopLevel` and injects a `KeyBinding` for you, even when the button is not focused. In code you can call `HotKeyManager.SetHotKey(button, new KeyGesture(Key.S, KeyModifiers.Control | KeyModifiers.Shift));`. Implementation lives in [`HotkeyManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/HotkeyManager.cs).

Bring `Avalonia.Input` into scope when assigning gestures programmatically so `KeyGesture` and `KeyModifiers` resolve.

### Access keys (mnemonics)

Use `_` to define an access key in headers (e.g., `_Save`). Access keys work when Alt is pressed.

```xml
<Menu>
  <MenuItem Header="_File">
    <MenuItem Header="_Save" Command="{Binding SaveCommand}" InputGesture="Ctrl+S"/>
  </MenuItem>
</Menu>
```

Access keys are processed via `AccessKeyHandler` ([`AccessKeyHandler.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/AccessKeyHandler.cs)). Combine them with `HotKeyManager` to offer both menu accelerators and global commands.

## 6. Pointer gestures, capture, and drag initiation

Avalonia ships gesture recognizers derived from [`GestureRecognizer`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/GestureRecognizers/GestureRecognizer.cs). Attach them via `GestureRecognizers` to translate raw pointer data into commands:

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

For custom gestures (e.g., drag-to-reorder), handle `PointerPressed`, call `e.Pointer.Capture(control)` to capture input, and release on `PointerReleased`. Pointer capture ensures subsequent move/press events go to the capture target even if the pointer leaves its bounds. Use `PointerEventArgs.GetCurrentPoint` to inspect buttons, pressure, tilt, or contact rectangles for richer interactions.

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

To cancel capture, call `e.Pointer.Capture(null)` or use `Pointer.Captured`. See [`PointerDevice.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/Pointer/PointerDevice.cs) and [`PointerEventArgs.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/PointerEventArgs.cs) for details.

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

## 8. Keyboard focus management and navigation

- Call `Focus()` to move input programmatically. `InputElement.Focus()` delegates to [`FocusManager`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/FocusManager.cs).
- Use `Focusable="False"` on decorative elements so they are skipped in traversal.
- Control tab order with `TabIndex` (lower numbers focus first); combine with `KeyboardNavigation.TabNavigation` to scope loops.
- Create focus scopes (`Focusable="True"` + `IsTabStop="True"`) for popups/overlays so focus returns to the invoking control when closed.
- Use `TraversalRequest` and `KeyboardNavigationHandler` to implement custom arrow-key navigation for grids or toolbars.

```xml
<StackPanel KeyboardNavigation.TabNavigation="Cycle" Spacing="8">
  <TextBox x:Name="First" Watermark="First name"/>
  <TextBox x:Name="Second" Watermark="Last name"/>
  <Button Content="Focus second" Command="{Binding FocusSecondCommand}"/>
</StackPanel>
```

```csharp
public void FocusSecond()
{
    var scope = FocusManager.Instance.Current;
    var second = this.FindControl<TextBox>("Second");
    scope?.Focus(second);
}
```

For MVVM-safe focus changes, expose an interaction request (event or `Interaction<T>` from ReactiveUI) and let the view handle it. Keyboard navigation services live under [`IKeyboardNavigationHandler`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/IKeyboardNavigationHandler.cs).

## 9. Bridging commands with MVVM frameworks

- **CommunityToolkit.Mvvm** – `RelayCommand`/`AsyncRelayCommand` implement `ICommand` and expose `CanExecuteChanged`. Use `[RelayCommand]` attributes to generate commands and wrap business logic in partial classes.
- **ReactiveUI** – `ReactiveCommand` exposes `IObservable` execution pipelines, throttling, and cancellation. Bind with `{Binding SaveCommand}` just like any other `ICommand`.
- **Prism / DryIoc** – `DelegateCommand` supports `ObservesCanExecute` and integrates with dependency injection lifetimes.

To unify event-heavy code paths with commands, expose interaction helpers instead of code-behind:

```csharp
public Interaction<Unit, PointerPoint?> StartDragInteraction { get; } = new();

public async Task BeginDragAsync()
{
    var pointerPoint = await StartDragInteraction.Handle(Unit.Default);
    if (pointerPoint is { } point)
    {
        // Use pointer data to seed drag operation
    }
}
```

The example uses `ReactiveUI.Interaction` and `Avalonia.Input.PointerPoint`; adapt the pattern to your MVVM framework of choice.

In XAML, use `Interaction` behaviors (`<interactions:Interaction.Triggers>` or toolkit `EventToCommandBehavior`) to connect events such as `PointerPressed` to `ReactiveCommand`s without writing code-behind. This keeps event routing logic discoverable while leaving testable command logic in the view model.

## 10. Routed commands and command routing

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

## 11. Asynchronous command patterns

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

## 12. Diagnostics: watch input live

DevTools (F12) -> **Events** tab let you monitor events (PointerPressed, KeyDown). Select an element, toggle events to watch.

Enable input logging:

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .LogToTrace(LogEventLevel.Debug, new[] { LogArea.Input })
    .StartWithClassicDesktopLifetime(args);
```

`LogArea.Input` (source: [`LogArea.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Logging/LogArea.cs)) emits detailed input information.

## 13. Practice exercises

1. Extend InputPlayground with a routed event logger: call `AddHandler` for `PointerPressedEvent`/`KeyDownEvent`, display bubbling order, and compare to the DevTools Events tab.
2. Register a global `Ctrl+Shift+S` gesture with `HotKeyManager.HotKey` (in XAML or via `HotKeyManager.SetHotKey`), then toggle the button’s `IsEnabled` state and confirm `CanExecute` updates propagate.
3. Build a drag-to-reorder list that uses pointer capture and `PointerPoint.Properties` to track left vs right button drags.
4. Integrate a `ReactiveCommand` or toolkit `AsyncRelayCommand` with a drag `Interaction<T>` so the view model decides when async work starts.
5. Configure `KeyboardNavigation.TabNavigation="Cycle"` on a popup and verify focus returns to the launcher when it closes.

## Look under the hood (source bookmarks)
- Routed events: [`RoutedEvent.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Interactivity/RoutedEvent.cs), [`RoutingStrategies`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Interactivity/RoutingStrategies.cs)
- Commands: [`ButtonBase.Command`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Primitives/ButtonBase.cs), [`MenuItem.Command`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/MenuItem.cs), [`KeyBinding`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Input/KeyBinding.cs)
- Hotkeys: [`KeyGesture.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyGesture.cs), [`HotkeyManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/HotkeyManager.cs)
- Input elements & gestures: [`InputElement.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/InputElement.cs), [`GestureRecognizer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/GestureRecognizers/GestureRecognizer.cs)
- Focus: [`FocusManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/FocusManager.cs), [`IKeyboardNavigationHandler`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/IKeyboardNavigationHandler.cs)
- Text input pipeline: [`TextInputMethodClient.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputMethodClient.cs)

## Check yourself
- What advantages do commands offer over events in MVVM architectures?
- When would you choose `KeyBinding` vs registering a gesture with `HotKeyManager`?
- Which API captures `PointerPoint` data during drag initiation and why does it matter?
- How would you bridge a pointer event to a `ReactiveCommand` or toolkit command without code-behind?
- Which tooling surfaces routed events, and how do you enable verbose input logging?

What's next
- Next: [Chapter 10](Chapter10.md)
