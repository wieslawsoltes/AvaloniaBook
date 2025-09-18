# 13. Menus, dialogs, tray icons, and system features

Goal
- Build desktop-friendly menus (in-window and native), wire accelerators, and update menu state dynamically.
- Provide dialogs through MVVM-friendly services (file pickers, confirmation dialogs, message boxes) that run on desktop and single-view lifetimes.
- Integrate system tray icons/notifications responsibly and respect platform nuances (Windows, macOS, Linux).
- Access `TopLevel` services (IStorageProvider, Clipboard, Screens) through abstractions.

Why this matters
- Menus/tray icons are expected on desktop apps; implementing them cleanly keeps UI testable and idiomatic.
- Dialog flows should not couple view models to windows; service abstractions allow unit testing and platform reuse.
- Platform-specific APIs (macOS menu bar, Windows tray icons) need awareness to avoid glitches.

Prerequisites
- Chapter 9 (commands/input), Chapter 11 (MVVM patterns), Chapter 12 (lifetimes/navigation).

## 1. Menus and accelerators

### 1.1 In-window menu (cross-platform)

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="MyApp.MainWindow"
        Title="My App" Width="900" Height="600">
  <DockPanel>
    <Menu DockPanel.Dock="Top">
      <MenuItem Header="_File">
        <MenuItem Header="_New" Command="{Binding NewCommand}" InputGestureText="Ctrl+N"/>
        <MenuItem Header="_Open..." Command="{Binding OpenCommand}" InputGestureText="Ctrl+O"/>
        <MenuItem Header="_Save" Command="{Binding SaveCommand}" InputGestureText="Ctrl+S"/>
        <Separator/>
        <MenuItem Header="E_xit" Command="{Binding ExitCommand}"/>
      </MenuItem>
      <MenuItem Header="_Edit">
        <MenuItem Header="_Undo" Command="{Binding UndoCommand}" InputGestureText="Ctrl+Z"/>
        <MenuItem Header="_Redo" Command="{Binding RedoCommand}" InputGestureText="Ctrl+Y"/>
      </MenuItem>
      <MenuItem Header="_Help">
        <MenuItem Header="_About" Command="{Binding ShowAboutCommand}"/>
      </MenuItem>
    </Menu>

    <ContentControl Content="{Binding Current}"/>
  </DockPanel>
</Window>
```

Add `KeyBinding` entries (Chapter 9) so shortcuts invoke commands everywhere:

```xml
<Window.InputBindings>
  <KeyBinding Gesture="Ctrl+N" Command="{Binding NewCommand}"/>
  <KeyBinding Gesture="Ctrl+O" Command="{Binding OpenCommand}"/>
</Window.InputBindings>
```

### 1.2 Native menu bar (macOS/global menu)

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:native="clr-namespace:Avalonia.Controls;assembly=Avalonia.Controls">
  <DockPanel>
    <native:NativeMenuBar DockPanel.Dock="Top">
      <native:NativeMenuBar.Menu>
        <native:NativeMenu>
          <native:NativeMenuItem Header="My App">
            <native:NativeMenuItem Header="About" Command="{Binding ShowAboutCommand}"/>
            <native:NativeMenuSeparator/>
            <native:NativeMenuItem Header="Quit" Command="{Binding ExitCommand}"/>
          </native:NativeMenuItem>
          <native:NativeMenuItem Header="File">
            <native:NativeMenuItem Header="New" Command="{Binding NewCommand}"/>
            <native:NativeMenuItem Header="Open..." Command="{Binding OpenCommand}"/>
          </native:NativeMenuItem>
        </native:NativeMenu>
      </native:NativeMenuBar.Menu>
    </native:NativeMenuBar>
  </DockPanel>
</Window>
```

Use NativeMenuBar on platforms that support global menus (macOS). In-window Menu remains for Windows/Linux.

### 1.3 Dynamic menu updates

Bag commands that toggle state and call `RaiseCanExecuteChanged()`. Example: enabling "Save" only when there are changes.

```csharp
public bool CanSave => HasChanges;
public RelayCommand SaveCommand { get; }

private void OnDocumentChanged()
{
    HasChanges = true;
    SaveCommand.RaiseCanExecuteChanged();
}
```

Menu item automatically disables when `CanExecute` returns false.

## 2. Context menus and flyouts

### 2.1 Context menu per control

```xml
<ListBox Items="{Binding Documents}" SelectedItem="{Binding SelectedDocument}">
  <ListBox.ItemContainerTheme>
    <ControlTheme TargetType="ListBoxItem">
      <Setter Property="ContextMenu">
        <ContextMenu>
          <MenuItem Header="Rename" Command="{Binding DataContext.RenameCommand, RelativeSource={RelativeSource AncestorType=ListBox}}" CommandParameter="{Binding}"/>
          <MenuItem Header="Delete" Command="{Binding DataContext.DeleteCommand, RelativeSource={RelativeSource AncestorType=ListBox}}" CommandParameter="{Binding}"/>
        </ContextMenu>
      </Setter>
    </ControlTheme>
  </ListBox.ItemContainerTheme>
</ListBox>
```

- `RelativeSource AncestorType=ListBox` lets the item access commands on the parent view model.

### 2.2 Flyout for custom UI

```xml
<Button Content="More">
  <Button.Flyout>
    <Flyout>
      <StackPanel Margin="8" Spacing="8">
        <TextBlock Text="Quick actions"/>
        <ToggleSwitch Content="Enable feature" IsChecked="{Binding IsFeatureEnabled}"/>
        <Button Content="Open settings" Command="{Binding OpenSettingsCommand}"/>
      </StackPanel>
    </Flyout>
  </Button.Flyout>
</Button>
```

Flyouts support arbitrary content; use `MenuItem` when you only need command lists.

## 3. Dialog patterns

### 3.1 ViewModel-friendly dialog service

```csharp
public interface IDialogService
{
    Task<bool> ShowConfirmationAsync(string title, string message);
    Task<string?> ShowOpenFilePickerAsync();
}

public sealed class DialogService : IDialogService
{
    private readonly Window _owner;

    public DialogService(Window owner) => _owner = owner;

    public async Task<bool> ShowConfirmationAsync(string title, string message)
    {
        var dialog = new ConfirmationDialog(title, message) { Owner = _owner };
        return await dialog.ShowDialog<bool>(_owner);
    }

    public async Task<string?> ShowOpenFilePickerAsync()
    {
        var ofd = new OpenFileDialog
        {
            AllowMultiple = false,
            Filters = { new FileDialogFilter { Name = "Documents", Extensions = { "txt", "md" } } }
        };
        var files = await ofd.ShowAsync(_owner);
        return files?.FirstOrDefault();
    }
}
```

Register per window in DI:

```csharp
services.AddScoped<IDialogService>(sp =>
{
    var window = sp.GetRequiredService<MainWindow>();
    return new DialogService(window);
});
```

Provide `IDialogService` to `ShellViewModel`. For single-view apps, implement the same interface using `TopLevel.GetTopLevel(view)` to access storage provider.

### 3.2 Storage provider (cross-platform)

```csharp
public sealed class CrossPlatformDialogService : IDialogService
{
    private readonly TopLevel _topLevel;

    public CrossPlatformDialogService(TopLevel topLevel) => _topLevel = topLevel;

    public Task<bool> ShowConfirmationAsync(string title, string message)
        => MessageBox.ShowAsync(_topLevel, title, message, MessageBoxButtons.YesNo);

    public async Task<string?> ShowOpenFilePickerAsync()
    {
        if (_topLevel.StorageProvider is null)
            return null;

        var result = await _topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            AllowMultiple = false,
            FileTypeFilter = new[] { FilePickerFileTypes.TextPlain }
        });
        var file = result.FirstOrDefault();
        return file is null ? null : file.Path.LocalPath;
    }
}
```

## 4. Message boxes and notifications

Avalonia doesn't ship a default message box, but community packages (`Avalonia.MessageBox`) or custom windows work. A simple custom message box window:

```csharp
public sealed class MessageBoxWindow : Window
{
    public MessageBoxWindow(string title, string message)
    {
        Title = title;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        var ok = new Button { Content = "OK", IsDefault = true };
        ok.Click += (_, __) => Close(true);
        Content = new StackPanel
        {
            Margin = new Thickness(16),
            Spacing = 12,
            Children = { new TextBlock { Text = message }, ok }
        };
    }
}
```

## 5. Tray icons and notifications

```csharp
public sealed class TrayIconService : IDisposable
{
    private readonly IClassicDesktopStyleApplicationLifetime _lifetime;
    private readonly TrayIcon _trayIcon;

    public TrayIconService(IClassicDesktopStyleApplicationLifetime lifetime)
    {
        _lifetime = lifetime;

        var showItem = new NativeMenuItem("Show");
        showItem.Click += (_, _) => _lifetime.MainWindow?.Show();

        var exitItem = new NativeMenuItem("Exit");
        exitItem.Click += (_, _) => _lifetime.Shutdown();

        _trayIcon = new TrayIcon
        {
            ToolTipText = "My App",
            Icon = new WindowIcon("avares://MyApp/Assets/AppIcon.ico"),
            Menu = new NativeMenu { Items = { showItem, exitItem } }
        };
        _trayIcon.Show();
    }

    public void Dispose() => _trayIcon.Dispose();
}
```

Register the service in `App.OnFrameworkInitializationCompleted` when using desktop lifetime; dispose on exit. Tray icons are not supported on mobile/web.

### Notifications

Avalonia's `Avalonia.Controls.Notifications` package provides in-app notifications or Windows toast integrations. Example in-app notification manager:

```csharp
using Avalonia.Controls.Notifications;

var manager = new WindowNotificationManager(MainWindow)
{
    Position = NotificationPosition.TopRight,
    MaxItems = 3
};

manager.Show(new Notification("Saved", "Document saved successfully", NotificationType.Success));
```

## 6. Accessing system services via `TopLevel`

### 6.1 Clipboard service

```csharp
public interface IClipboardService
{
    Task SetTextAsync(string text);
    Task<string?> GetTextAsync();
}

public sealed class ClipboardService : IClipboardService
{
    private readonly TopLevel _topLevel;
    public ClipboardService(TopLevel topLevel) => _topLevel = topLevel;

    public Task SetTextAsync(string text) => _topLevel.Clipboard?.SetTextAsync(text) ?? Task.CompletedTask;
    public Task<string?> GetTextAsync() => _topLevel.Clipboard?.GetTextAsync() ?? Task.FromResult<string?>(null);
}
```

Include this service in DI so view models request clipboard operations without referencing controls.

### 6.2 Drag and drop / system features

Drag-and-drop uses `DragDrop` APIs (Chapter 16). System features like power notifications or window effects are platform-specific--wrap them in services like the dialog example.

## 7. Platform guidance

- **macOS**: use `NativeMenuBar`, ensure About/Quit live under the first menu. Tray icons appear in the status bar; `WindowIcon` must be sized to `NSImage` standards.
- **Windows**: `Menu` inside window is standard. Tray icons appear in the notification area; wrap `TrayIcon` show/hide in a service.
- **Linux**: Menus vary per environment; in-window `Menu` works everywhere. Tray icons depend on desktop environment (GNOME may require extensions).
- **Mobile/Web**: skip menus/tray icons; use flyouts, toolbars, and bottom sheets.

## 8. Practice exercises

1. Add menu commands that update their text or visibility when application state changes, verifying `PropertyChanged` triggers menu updates.
2. Implement a dialog service interface that supports open/save dialogs via `IStorageProvider` and falls back to message boxes when unsupported.
3. Add context menus to list items with enable/disable states reflecting `CanExecute`.
4. Create a tray icon that toggles a "compact mode", minimizing the window when closing and restoring on double-click.
5. Build a notification manager that displays toast-like overlays using `WindowNotificationManager` and ensure they hide on navigation.

## Look under the hood (source bookmarks)
- Menus/Native menus: [`Menu.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Menu.cs), [`NativeMenuBar.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/NativeMenuBar.cs)
- Context menu & flyouts: [`ContextMenu.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ContextMenu.cs), [`Flyout.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Flyout.cs)
- Tray icons: [`TrayIcon.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TrayIcon.cs)
- Notifications: [`WindowNotificationManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls.Notifications/WindowNotificationManager.cs)
- Storage provider: [`IStorageProvider`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/IStorageProvider.cs)

## Check yourself
- When do you prefer `NativeMenuBar` vs in-window `Menu`? How do you attach shortcuts to the same command?
- How do you expose dialogs to view models without referencing `Window`?
- What should you consider before adding a tray icon (platform support, lifecycle)?
- Which `TopLevel` services help with clipboard or file picking?

What's next
- Next: [Chapter 14](Chapter14.md)
