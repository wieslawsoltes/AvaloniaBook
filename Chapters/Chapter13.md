# 13. Menus, dialogs, tray icons, and system features

Goal
- Wire desktop menus, context menus, and native menu bars using `Menu`, `MenuItem`, `ContextMenu`, and `NativeMenu`.
- Surface dialogs through MVVM-friendly services that switch between `ManagedFileChooser`, `SystemDialog`, and storage providers.
- Integrate tray icons, notifications, and app-level commands with the `TrayIcon` API and `TopLevel` services.
- Document platform-specific behaviour so menus, dialogs, and tray features degrade gracefully.

Why this matters
- Desktop users expect menu bars, keyboard accelerators, and tray icons that follow their OS conventions.
- Dialog flows that stay inside services remain unit-testable and work across desktop, mobile, and browser hosts.
- System integrations (storage, notifications, clipboard) require a clear view of per-platform capabilities to avoid runtime surprises.

Prerequisites
- Chapters 9 (commands and input), 11 (MVVM patterns), and 12 (lifetimes and windowing).

Key namespaces
- [`Menu.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Menu.cs)
- [`MenuItem.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/MenuItem.cs)
- [`NativeMenu.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/NativeMenu.cs)
- [`ContextMenu.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ContextMenu.cs)
- [`TrayIcon.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TrayIcon.cs)
- [`SystemDialog.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/SystemDialog.cs)
- [`ManagedFileChooser.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Dialogs/ManagedFileChooser.cs)

## 1. Menu surfaces at a glance

### 1.1 In-window menus (`Menu`/`MenuItem`)

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="MyApp.MainWindow"
        Title="My App" Width="1000" Height="700">
  <DockPanel>
    <Menu DockPanel.Dock="Top">
      <MenuItem Header="_File">
        <MenuItem Header="_New" Command="{Binding AppCommands.New}" HotKey="Ctrl+N"/>
        <MenuItem Header="_Open..." Command="{Binding AppCommands.Open}" HotKey="Ctrl+O"/>
        <MenuItem Header="_Save" Command="{Binding AppCommands.Save}" HotKey="Ctrl+S"/>
        <MenuItem Header="Save _As..." Command="{Binding AppCommands.SaveAs}"/>
        <Separator/>
        <MenuItem Header="E_xit" Command="{Binding AppCommands.Exit}"/>
      </MenuItem>
      <MenuItem Header="_Edit">
        <MenuItem Header="_Undo" Command="{Binding AppCommands.Undo}"/>
        <MenuItem Header="_Redo" Command="{Binding AppCommands.Redo}"/>
      </MenuItem>
      <MenuItem Header="_Help">
        <MenuItem Header="_About" Command="{Binding AppCommands.ShowAbout}"/>
      </MenuItem>
    </Menu>

    <ContentControl Content="{Binding CurrentView}"/>
  </DockPanel>
</Window>
```

- `MenuItem.HotKey` accepts `KeyGesture` syntax, keeping accelerators in sync with displayed text.
- `AppCommands` is a shared command aggregate in the view model layer; use the same instances for menus, toolbars, and tray commands so `CanExecute` state stays consistent.
- Add `KeyBinding` entries on the window so shortcuts remain active even when focus is inside a text box:

```xml
<Window.InputBindings>
  <KeyBinding Gesture="Ctrl+N" Command="{Binding AppCommands.New}"/>
  <KeyBinding Gesture="Ctrl+O" Command="{Binding AppCommands.Open}"/>
</Window.InputBindings>
```

### 1.2 Native menus and the macOS menu bar

`NativeMenu` exports menu metadata to the host OS when available (macOS, some Linux environments). Attach it to the `TopLevel` so Avalonia’s native exporters keep it in sync with window focus.

```csharp
public override void OnFrameworkInitializationCompleted()
{
    if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
    {
        var window = Services.GetRequiredService<MainWindow>();
        desktop.MainWindow = window;

        NativeMenu.SetMenu(window, BuildNativeMenu());
    }

    base.OnFrameworkInitializationCompleted();
}

private static NativeMenu BuildNativeMenu()
{
    var appMenu = new NativeMenu
    {
        new NativeMenuItem("About", (_, _) => Locator.Commands.ShowAbout.Execute(null)),
        new NativeMenuItemSeparator(),
        new NativeMenuItem("Quit", (_, _) => Locator.Commands.Exit.Execute(null))
    };

    var fileMenu = new NativeMenu
    {
        new NativeMenuItem("New", (_, _) => Locator.Commands.New.Execute(null))
        {
            Gesture = new KeyGesture(Key.N, KeyModifiers.Control)
        },
        new NativeMenuItem("Open...", (_, _) => Locator.Commands.Open.Execute(null))
    };

    return new NativeMenu
    {
        new NativeMenuItem("MyApp") { Menu = appMenu },
        new NativeMenuItem("File") { Menu = fileMenu }
    };
}
```

- `NativeMenuItem.Gesture` mirrors `MenuItem.HotKey` and feeds the OS accelerator tables.
- Use `NativeMenuBar` in XAML when you want markup control over the native bar:

```xml
<native:NativeMenuBar DockPanel.Dock="Top">
  <native:NativeMenuBar.Menu>
    <native:NativeMenu>
      <native:NativeMenuItem Header="My App">
        <native:NativeMenuItem Header="About" Command="{Binding AppCommands.ShowAbout}"/>
      </native:NativeMenuItem>
      <native:NativeMenuItem Header="File">
        <native:NativeMenuItem Header="New" Command="{Binding AppCommands.New}"/>
      </native:NativeMenuItem>
    </native:NativeMenu>
  </native:NativeMenuBar.Menu>
</native:NativeMenuBar>
```

### 1.3 Command state and routing

`MenuItem` observes `ICommand.CanExecute`. Use commands that publish notifications (`ReactiveCommand`, `DelegateCommand`) and call `RaiseCanExecuteChanged()` whenever state changes. Keep command instances long-lived (registered in DI or a singleton `AppCommands` class) so every menu, toolbar, context menu, and tray icon reflects the same enable/disable state.

## 2. Context menus and flyouts

Attach `ContextMenu` to items directly or via styles so each container gets the same commands:

```xml
<ListBox Items="{Binding Documents}" SelectedItem="{Binding SelectedDocument}">
  <ListBox.Styles>
    <Style Selector="ListBoxItem">
      <Setter Property="ContextMenu">
        <ContextMenu>
          <MenuItem Header="Rename"
                    Command="{Binding DataContext.Rename, RelativeSource={RelativeSource AncestorType=ListBox}}"
                    CommandParameter="{Binding}"/>
          <MenuItem Header="Delete"
                    Command="{Binding DataContext.Delete, RelativeSource={RelativeSource AncestorType=ListBox}}"
                    CommandParameter="{Binding}"/>
        </ContextMenu>
      </Setter>
    </Style>
  </ListBox.Styles>
</ListBox>
```

- `RelativeSource AncestorType=ListBox` bridges from the item container back to the list’s data context.
- For richer layouts (toggles, sliders, forms) use `Flyout` or `MenuFlyout` – both live in `Avalonia.Controls` and share placement logic with context menus.
- Remember accessibility: set `MenuItem.InputGestureText` or `HotKey` so screen readers announce shortcuts.

## 3. Dialog pipelines

### 3.1 Define a dialog service interface

```csharp
public interface IFileDialogService
{
    Task<IReadOnlyList<FilePickResult>> PickFilesAsync(FilePickerOpenOptions options, CancellationToken ct = default);
    Task<FilePickResult?> SaveFileAsync(FilePickerSaveOptions options, CancellationToken ct = default);
    Task<IReadOnlyList<FilePickResult>> PickFoldersAsync(FolderPickerOpenOptions options, CancellationToken ct = default);
}

public record FilePickResult(string Path, IStorageItem? Handle);
```

Expose the service through dependency injection so view models request it instead of referencing `Window` or `TopLevel`.

### 3.2 Choose between `IStorageProvider`, `SystemDialog`, and `ManagedFileChooser`

`TopLevel.StorageProvider` supplies the native picker implementation (`IStorageProvider`). When it is unavailable (custom hosts, limited backends), fall back to the managed dialog stack built on `ManagedFileChooser`. The extension method `OpenFileDialog.ShowManagedAsync` renders the managed UI and is enabled automatically when you call `AppBuilder.UseManagedSystemDialogs()` during startup.

```csharp
using Avalonia.Dialogs;
using Avalonia.Platform.Storage;

public sealed class FileDialogService : IFileDialogService
{
    private readonly TopLevel _topLevel;

    public FileDialogService(TopLevel topLevel) => _topLevel = topLevel;

    public async Task<IReadOnlyList<FilePickResult>> PickFilesAsync(FilePickerOpenOptions options, CancellationToken ct = default)
    {
        var provider = _topLevel.StorageProvider;
        if (provider is { CanOpen: true })
        {
            var files = await provider.OpenFilePickerAsync(options, ct);
            return files.Select(f => new FilePickResult(f.TryGetLocalPath() ?? f.Name, f)).ToArray();
        }

        if (_topLevel is Window window)
        {
            var dialog = new OpenFileDialog { AllowMultiple = options.AllowMultiple };
            var paths = await dialog.ShowManagedAsync(window, new ManagedFileDialogOptions());
            return paths.Select(p => new FilePickResult(p, handle: null)).ToArray();
        }

        return Array.Empty<FilePickResult>();
    }

    public async Task<FilePickResult?> SaveFileAsync(FilePickerSaveOptions options, CancellationToken ct = default)
    {
        var provider = _topLevel.StorageProvider;
        if (provider is { CanSave: true })
        {
            var file = await provider.SaveFilePickerAsync(options, ct);
            return file is null ? null : new FilePickResult(file.TryGetLocalPath() ?? file.Name, file);
        }

        if (_topLevel is Window window)
        {
            var dialog = new SaveFileDialog
            {
                DefaultExtension = options.DefaultExtension,
                InitialFileName = options.SuggestedFileName
            };
            var path = await dialog.ShowAsync(window);
            return path is null ? null : new FilePickResult(path, handle: null);
        }

        return null;
    }

    public async Task<IReadOnlyList<FilePickResult>> PickFoldersAsync(FolderPickerOpenOptions options, CancellationToken ct = default)
    {
        var provider = _topLevel.StorageProvider;
        if (provider is { CanPickFolder: true })
        {
            var folders = await provider.OpenFolderPickerAsync(options, ct);
            return folders.Select(f => new FilePickResult(f.TryGetLocalPath() ?? f.Name, f)).ToArray();
        }

        if (_topLevel is Window window)
        {
            var dialog = new OpenFolderDialog();
            var path = await dialog.ShowAsync(window);
            return path is null
                ? Array.Empty<FilePickResult>()
                : new[] { new FilePickResult(path, handle: null) };
        }

        return Array.Empty<FilePickResult>();
    }
}
```

- `OpenFileDialog`, `SaveFileDialog`, and `OpenFolderDialog` derive from `SystemDialog`. They remain useful when you need to force specific behaviour or when the platform lacks a proper storage provider.
- `AppBuilder.UseManagedSystemDialogs()` configures Avalonia to instantiate `ManagedFileChooser` by default whenever a native dialog is unavailable.
- Treat `FilePickResult.Handle` as optional: on browser/mobile targets you might only receive virtual URIs, while desktop gives full file system access.

## 4. Tray icons, notifications, and app commands

The tray API exports icons through the `Application`. Add them during application initialization so they follow the application lifetime automatically.

```csharp
public override void Initialize()
{
    base.Initialize();

    if (ApplicationLifetime is not IClassicDesktopStyleApplicationLifetime)
        return;

    var trayIcons = new TrayIcons
    {
        new TrayIcon
        {
            Icon = new WindowIcon("avares://MyApp/Assets/App.ico"),
            ToolTipText = "My App",
            Menu = new NativeMenu
            {
                new NativeMenuItem("Show", (_, _) => Locator.Commands.ShowMain.Execute(null)),
                new NativeMenuItemSeparator(),
                new NativeMenuItem("Exit", (_, _) => Locator.Commands.Exit.Execute(null))
            }
        }
    };

    TrayIcon.SetIcons(this, trayIcons);
}
```

- Toggle `TrayIcon.IsVisible` in response to `Window` events to implement “minimize to tray”. Guard the feature by checking `TrayIcon.SetIcons` only when running with a desktop lifetime.
- `NativeMenu` attached to a tray icon becomes the right-click menu. Reuse the same command implementations that power your primary menu to avoid duplication.
- Detect tray support by asking `AvaloniaLocator.Current.GetService<IWindowingPlatform>()?.CreateTrayIcon()` inside a try/catch before you rely on it.

In-app notifications come from `Avalonia.Controls.Notifications`:

```csharp
using Avalonia.Controls.Notifications;

var manager = new WindowNotificationManager(_desktopLifetime.MainWindow!)
{
    Position = NotificationPosition.TopRight,
    MaxItems = 3
};

manager.Show(new Notification("Saved", "Document saved successfully", NotificationType.Success));
```

## 5. Top-level services and system integrations

`TopLevel` exposes cross-platform services you should wrap behind interfaces for testability:

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

Other helpful services on `TopLevel`:
- `Screens` for multi-monitor awareness and DPI scaling.
- `DragDrop` helpers (covered in Chapter 16) for integrating system drag-and-drop.
- `TryGetFeature<T>` for platform-specific features (`ITrayIconImpl`, `IPlatformThemeVariant`).

## 6. Platform notes

- **Windows** – In-window `Menu` is standard. Tray icons appear in the notification area and expect `.ico` assets with multiple sizes. Native system dialogs are available; managed dialogs appear only if you opt in.
- **macOS** – Use `NativeMenu`/`NativeMenuBar` so menu items land in the global menu bar. Provide monochrome template tray icons via `MacOSProperties.SetIsTemplateIcon`.
- **Linux** – Desktop environments vary. Ship an in-window `Menu` even if you export a `NativeMenu`. Tray support may require AppIndicator or extensions.
- **Mobile (Android/iOS)** – Skip menu bars and tray icons. Replace them with toolbars, flyouts, and platform navigation. Storage providers surface document pickers that may not expose local file paths.
- **Browser** – No native menus or tray. Use in-app overlays and rely on the browser storage APIs (`BrowserStorageProvider`). Managed dialogs are not available.

## 7. Practice exercises

1. Build a shared `AppCommands` class that drives in-window menus, a `NativeMenu`, and a toolbar, verifying that `CanExecute` disables items everywhere.
2. Implement the dialog service above and log whether each operation used `IStorageProvider`, `SystemDialog`, or `ManagedFileChooser`. Run it on Windows, macOS, and Linux to compare behaviour.
3. Add a tray icon that toggles a “compact mode”: closing the window hides it, the tray command re-opens it, and the tray menu reflects the current state.
4. Provide context menus for list items that reuse the same commands as the main menu. Confirm command parameters work for both entry points.
5. Surface toast notifications for long-running operations using `WindowNotificationManager`, and ensure they disappear automatically when the user navigates away.

## Look under the hood (source bookmarks)
- Menus and native export: [`Menu.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Menu.cs), [`NativeMenu.Export.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/NativeMenu.Export.cs)
- Context menus & flyouts: [`ContextMenu.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ContextMenu.cs), [`FlyoutBase.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Flyouts/FlyoutBase.cs)
- Dialog infrastructure: [`SystemDialog.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/SystemDialog.cs), [`ManagedFileChooser.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Dialogs/ManagedFileChooser.cs)
- Storage provider abstractions: [`IStorageProvider.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/IStorageProvider.cs)
- Tray icons: [`TrayIcon.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TrayIcon.cs)
- Notifications: [`WindowNotificationManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls.Notifications/WindowNotificationManager.cs)

## Check yourself
- How do `MenuItem` and `NativeMenuItem` share the same command instances, and why does that matter for `CanExecute`?
- When would you enable `UseManagedSystemDialogs`, and what UX differences should you anticipate compared to native dialogs?
- Which `TopLevel` services help you access storage, clipboard, and screens without referencing `Window` in view models?
- How can you detect tray icon availability before exposing tray-dependent features?
- What platform-specific adjustments do macOS and Linux require for menus and tray icons?

What's next
- Next: [Chapter 14](Chapter14.md)
