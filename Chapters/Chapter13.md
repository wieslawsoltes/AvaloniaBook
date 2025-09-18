# 13. Menus, dialogs, tray icons, and system features

Goal
- Build desktop‑friendly menus and context menus, design testable dialog flows, add a system tray icon with a menu, and learn platform notes so your features behave correctly on Windows, macOS, and Linux.

Why this matters
- Menus and dialogs are core desktop UX.
- A clean dialog and tray‑icon approach keeps ViewModels testable and UI responsive.
- Platform‑aware patterns save time when you target multiple OSes.

Prerequisites
- Chapters 8–12 (binding, commands, lifetimes, windows)

What you’ll build
- A top app menu (in‑window Menu and native menu bar) with keyboard shortcuts.
- Context menus and flyouts for in‑place actions.
- A reusable dialog pattern (task‑based) without coupling VMs to Window.
- A tray icon with a small menu and actions.

1) Application menu bar (desktop)

1.1 In‑window Menu (cross‑platform)
```xml
<!-- MainWindow.axaml -->
<Window xmlns="https://github.com/avaloniaui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="MyApp.MainWindow" Width="800" Height="500" Title="My App">
  <DockPanel>
    <Menu DockPanel.Dock="Top">
      <MenuItem Header="_File">
        <MenuItem Header="_New" Command="{Binding NewCommand}" InputGestureText="Ctrl+N"/>
        <MenuItem Header="_Open…" Command="{Binding OpenCommand}" InputGestureText="Ctrl+O"/>
        <Separator/>
        <MenuItem Header="_Exit" Command="{Binding ExitCommand}"/>
      </MenuItem>
      <MenuItem Header="_Help">
        <MenuItem Header="_About…" Command="{Binding ShowAboutCommand}"/>
      </MenuItem>
    </Menu>

    <!-- main content here -->
    <ContentControl Content="{Binding Current}"/>
  </DockPanel>
</Window>
```

- InputGestureText shows the shortcut in the menu; bind actual shortcuts with KeyBindings in the Window or App (see Chapter 9).

1.2 Native menu bar (macOS‑style global menu)
```xml
<!-- MainWindow.axaml (top-level menu that can integrate with the OS) -->
<Window ... xmlns:native="clr-namespace:Avalonia.Controls;assembly=Avalonia.Controls">
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
            <native:NativeMenuItem Header="Open…" Command="{Binding OpenCommand}"/>
          </native:NativeMenuItem>
        </native:NativeMenu>
      </native:NativeMenuBar.Menu>
    </native:NativeMenuBar>
    <!-- rest of layout -->
  </DockPanel>
</Window>
```

Notes
- Use in‑window Menu for all platforms; NativeMenuBar gives tighter OS integration on macOS and supported platforms.
- Keep commands in your ViewModel; menus should be just bindings.

2) Context menus and flyouts

2.1 ContextMenu on any control
```xml
<Button Content="Options">
  <Button.ContextMenu>
    <ContextMenu>
      <MenuItem Header="Copy" Command="{Binding Copy}"/>
      <MenuItem Header="Paste" Command="{Binding Paste}"/>
      <Separator/>
      <MenuItem Header="Delete" Command="{Binding Delete}"/>
    </ContextMenu>
  </Button.ContextMenu>
</Button>
```

2.2 Flyouts for lightweight actions
```xml
<Button Content="More" xmlns:ui="https://github.com/avaloniaui">
  <Button.Flyout>
    <Flyout>
      <StackPanel Margin="8" Spacing="8">
        <TextBlock Text="Quick actions"/>
        <Button Content="Refresh" Command="{Binding Refresh}"/>
        <Button Content="Settings" Command="{Binding OpenSettings}"/>
      </StackPanel>
    </Flyout>
  </Button.Flyout>
</Button>
```

Tips
- Prefer ContextMenu for command lists; prefer Flyout for custom content and small toolpanels.
- For list items, provide an ItemContainerStyle that sets a ContextMenu per row if needed.

3) Dialogs without tight coupling

3.1 Simple custom dialog window pattern
```csharp
public class AboutWindow : Window
{
    public AboutWindow()
    {
        Title = "About";
        Width = 360; Height = 220;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        var okButton = new Button { Content = "OK", IsDefault = true };
        okButton.Click += (_, __) => Close(true);

        Content = new StackPanel
        {
            Margin = new Thickness(16),
            Children =
            {
                new TextBlock { Text = "My App v1.0" },
                okButton
            }
        };
    }
}
```

Show it from a Window
```csharp
var ok = await new AboutWindow { Owner = this }.ShowDialog<bool>(this);
```

3.2 A dialog service interface (testable ViewModels)
```csharp
public interface IDialogService
{
    Task<bool> ShowAboutAsync(Window owner);
}

public sealed class DialogService : IDialogService
{
    public async Task<bool> ShowAboutAsync(Window owner)
        => await new AboutWindow { Owner = owner }.ShowDialog<bool>(owner);
}
```

Use it in a ViewModel via an abstraction
```csharp
public sealed class ShellViewModel : ObservableObject
{
    private readonly IDialogService _dialogs;
    public RelayCommand ShowAboutCommand { get; }

    public ShellViewModel(IDialogService dialogs)
    {
        _dialogs = dialogs;
        ShowAboutCommand = new RelayCommand(async o =>
        {
            // Owner is supplied by the View (e.g., via CommandParameter binding)
            if (o is Window owner)
                await _dialogs.ShowAboutAsync(owner);
        });
    }
}
```

View wiring example
```xml
<Window ...>
  <Window.DataContext>
    <!-- Assume a DI container provides DialogService; for demo we use x:FactoryMethod in code-behind -->
  </Window.DataContext>
  <Button Content="About" Command="{Binding ShowAboutCommand}" CommandParameter="{Binding $parent[Window]}"/>
</Window>
```

Notes
- This keeps the ViewModel free of Window references; only the View passes the owner.
- For more advanced flows, consider ReactiveUI Interactions (covered in Chapter 11).

4) Tray icon (system notification area)

4.1 Creating and showing a tray icon
```csharp
// In App.OnFrameworkInitializationCompleted (desktop lifetime)
if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
{
    var showItem = new NativeMenuItem("Show");
    showItem.Click += (_, __) => desktop.MainWindow?.Show();

    var exitItem = new NativeMenuItem("Exit");
    exitItem.Click += (_, __) => desktop.Shutdown();

    var tray = new TrayIcon
    {
        ToolTipText = "My App",
        Icon = new WindowIcon("avares://MyApp/Assets/AppIcon.ico"),
        Menu = new NativeMenu
        {
            Items = { showItem, exitItem }
        }
    };
    tray.Show();
}
```

Notes
- Keep a reference to the TrayIcon if you need to toggle visibility or update its menu.
- Tray menus should be short and essential; keep the main app UI for complex tasks.

5) Shortcuts and accelerators in menus
- Use InputGestureText on MenuItem to display the shortcut (e.g., Ctrl+N) and pair it with a KeyBinding at Window/App level to trigger the same command.
- On macOS, Cmd is the conventional modifier; consider platform‑specific gesture strings in your help text.

6) Platform notes and guidance
- macOS: Prefer NativeMenuBar for the top menu; tray icon shows in the status bar. Some menu roles are handled by the OS.
- Windows/Linux: In‑window Menu is the default. Tray icons rely on a running notification area.
- Mobile/Web (single‑view): Menus and tray icons don’t apply; use flyouts, toolbars, and page navigation instead.

Look under the hood (source)
- Menus (in‑window): [Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- Native menus: [Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- ContextMenu and Flyout: [Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- TrayIcon: [Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- Optional notifications: [Avalonia.Controls.Notifications](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls.Notifications)

Check yourself
- When would you choose NativeMenuBar over an in‑window Menu?
- How do you attach a ContextMenu to a control, and when would a Flyout be a better fit?
- How do you invoke a dialog without coupling the ViewModel to Window?
- Where should the tray icon be created and how do you handle its menu actions?

Extra practice
- Add keyboard shortcuts for File → New/Open using KeyBinding, and show them via InputGestureText.
- Add a context menu to a ListBox that exposes row‑level actions (Rename/Delete).
- Add a tray icon with “Show/Hide” and “Exit”, and ensure it restores the window when closed to tray.

What’s next
- Next: [Chapter 14](Chapter14.md)
