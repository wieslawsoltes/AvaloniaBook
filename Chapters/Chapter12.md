# 12. Navigation, windows, and lifetimes

Goal
- Learn how Avalonia apps start and keep running across platforms, how to create and manage windows on desktop, and simple navigation patterns that work for both desktop (multi-window) and mobile/web (single view) apps.

Why this matters
- Understanding lifetimes ensures your app starts, navigates, and shuts down reliably on each platform.
- Good windowing and navigation patterns reduce coupling and make features easier to test and evolve.

Prerequisites
- Chapters 4 (startup), 8 (bindings), and 11 (MVVM patterns)

What you’ll build
- A desktop app with a main window, an About dialog (modal), and a basic page switcher.
- A single-view setup (mobile/web) that hosts pages inside a single root view.

1) App lifetimes at a glance
- ClassicDesktopStyleApplicationLifetime (desktop):
  - You set MainWindow, can open multiple windows, and control shutdown behavior.
- SingleViewApplicationLifetime (mobile/web):
  - You provide a single root view (MainView). No Window instances; navigation happens inside that view.

Init both from App.OnFrameworkInitializationCompleted
```csharp
public override void OnFrameworkInitializationCompleted()
{
    if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
    {
        desktop.MainWindow = new MainWindow
        {
            DataContext = new ShellViewModel()
        };
        // Optional: choose how the app shuts down
        desktop.ShutdownMode = ShutdownMode.OnLastWindowClose; // or OnMainWindowClose / OnExplicitShutdown
    }
    else if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
    {
        singleView.MainView = new ShellView // a UserControl
        {
            DataContext = new ShellViewModel()
        };
    }

    base.OnFrameworkInitializationCompleted();
}
```

2) Windows on desktop: main, owned, and modal

2.1 Creating another window
```csharp
public class AboutWindow : Window
{
    public AboutWindow()
    {
        Title = "About";
        Width = 400; Height = 220;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Content = new TextBlock { Text = "My App v1.0", Margin = new Thickness(16) };
    }
}
```

2.2 Showing non-modal vs modal
```csharp
// Non-modal (does not block owner)
var about = new AboutWindow { Owner = this }; // 'this' is a Window
about.Show();

// Modal (blocks owner, returns when closed)
var resultTask = new AboutWindow { Owner = this }.ShowDialog(this);
await resultTask; // continues after dialog closes
```

2.3 Returning data from a dialog
```csharp
public class NameDialog : Window
{
    private readonly TextBox _name = new();
    public string? EnteredName { get; private set; }
    public NameDialog()
    {
        Title = "Enter name";
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        var okButton = new Button { Content = "OK", IsDefault = true };
        okButton.Click += (_, __) =>
        {
            EnteredName = _name.Text;
            Close(true);
        };

        var cancelButton = new Button { Content = "Cancel", IsCancel = true };
        cancelButton.Click += (_, __) => Close(false);

        Content = new StackPanel
        {
            Margin = new Thickness(16),
            Children =
            {
                new TextBlock { Text = "Name:" },
                _name,
                new StackPanel
                {
                    Orientation = Orientation.Horizontal,
                    Spacing = 8,
                    Children = { okButton, cancelButton }
                }
            }
        };
    }
}

// Usage (in a Window)
var dlg = new NameDialog { Owner = this };
var ok = await dlg.ShowDialog<bool>(this);
if (ok)
{
    var name = dlg.EnteredName;
    // use name
}
```

Tips
- Always set Owner for child windows so modality/centering behave as expected.
- Use ShowDialog for blocking flows (confirmations, wizards), Show for tool windows.

3) Simple navigation patterns that scale

3.1 View-model–first shell (works for desktop and single-view)
```csharp
public sealed class ShellViewModel : ObservableObject
{
    private object _current;
    public object Current { get => _current; set => SetProperty(ref _current, value); }

    public RelayCommand GoHome { get; }
    public RelayCommand GoSettings { get; }

    public ShellViewModel()
    {
        var home = new HomeViewModel();
        var settings = new SettingsViewModel();
        _current = home;
        GoHome = new RelayCommand(_ => Current = home);
        GoSettings = new RelayCommand(_ => Current = settings);
    }
}
```

```xml
<!-- ShellView.axaml (UserControl used for both desktop MainWindow content and single-view MainView) -->
<UserControl xmlns="https://github.com/avaloniaui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <DockPanel>
    <StackPanel Orientation="Horizontal" Spacing="8" DockPanel.Dock="Top" Margin="8">
      <Button Content="Home" Command="{Binding GoHome}"/>
      <Button Content="Settings" Command="{Binding GoSettings}"/>
    </StackPanel>
    <ContentControl Content="{Binding Current}"/>
  </DockPanel>
</UserControl>
```

3.2 Mapping ViewModels to Views via DataTemplates
```xml
<!-- App.axaml -->
<Application xmlns="https://github.com/avaloniaui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Application.DataTemplates>
    <DataTemplate DataType="{x:Type vm:HomeViewModel}" xmlns:vm="clr-namespace:MyApp.ViewModels" xmlns:v="clr-namespace:MyApp.Views">
      <v:HomeView/>
    </DataTemplate>
    <DataTemplate DataType="{x:Type vm:SettingsViewModel}" xmlns:vm="clr-namespace:MyApp.ViewModels" xmlns:v="clr-namespace:MyApp.Views">
      <v:SettingsView/>
    </DataTemplate>
  </Application.DataTemplates>
</Application>
```

Note: If you’re using ReactiveUI, you can also adopt its Router + RoutedViewHost (see Chapter 11).

4) Closing, shutdown, and lifetime APIs

4.1 Window closing and cancel
```csharp
// In a Window constructor
this.Closing += (s, e) =>
{
    if (HasUnsavedChanges)
    {
        // Ask the user and optionally cancel
        // e.Cancel = true; // keep window open
    }
};
```

4.2 Controlling application shutdown (desktop)
```csharp
if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
{
    desktop.ShutdownMode = ShutdownMode.OnMainWindowClose; // Or OnLastWindowClose / OnExplicitShutdown
    // Later, when appropriate
    // desktop.Shutdown();
}
```

Single-view apps don’t manage process shutdown directly—platforms (mobile/web) handle lifecycle; navigate back or update the root view instead of closing windows.

5) File dialogs and pickers

5.1 Classic file dialogs (desktop)
```csharp
var ofd = new OpenFileDialog
{
    AllowMultiple = false,
    Filters =
    {
        new FileDialogFilter { Name = "Text", Extensions = { "txt", "md" } },
        new FileDialogFilter { Name = "All", Extensions = { "*" } }
    }
};
var files = await ofd.ShowAsync(this); // 'this' is a Window
if (files?.Length > 0)
{
    var path = files[0];
    // open file
}
```

```csharp
var sfd = new SaveFileDialog
{
    InitialFileName = "document.txt",
    Filters = { new FileDialogFilter { Name = "Text", Extensions = { "txt" } } }
};
var path = await sfd.ShowAsync(this);
if (!string.IsNullOrEmpty(path))
{
    // save file
}
```

5.2 Cross‑platform storage provider (works in single‑view)
```csharp
var top = TopLevel.GetTopLevel(this); // from a Control
if (top?.StorageProvider is { } sp)
{
    var results = await sp.OpenFilePickerAsync(new FilePickerOpenOptions
    {
        AllowMultiple = false,
        FileTypeFilter = new[] { FilePickerFileTypes.TextPlain }
    });
    var file = results.FirstOrDefault();
    if (file is not null)
    {
        await using var stream = await file.OpenReadAsync();
        // read stream
    }
}
```

6) Cross‑platform guidelines
- Desktop: prefer windows for tools and modal flows; keep ownership set and use CenterOwner.
- Mobile/web (single‑view): keep everything in a single root view; navigate by swapping ViewModels in a ContentControl.
- Shared code: keep services (dialogs, storage) behind interfaces so ViewModels don’t depend on Window.

Look under the hood (source)
- Window class: [Avalonia.Controls/Window.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Window.cs)
- Classic desktop lifetime: [Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs)
- Single‑view lifetime: [Avalonia.Controls/ApplicationLifetimes/SingleViewApplicationLifetime.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/SingleViewApplicationLifetime.cs)
- Open/Save dialogs: [Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)

Check yourself
- What’s the difference between ClassicDesktopStyleApplicationLifetime and SingleViewApplicationLifetime?
- When should you use Show vs ShowDialog?
- How do DataTemplates enable view‑model–first navigation?
- Where would you set ShutdownMode and why?

Extra practice
- Add a Settings dialog to your app that returns a result and updates the main view.
- Implement a shell with three pages and keyboard shortcuts for navigation.
- Replace OpenFileDialog with the StorageProvider API and make it work in a single‑view setup.

What’s next
- Next: [Chapter 13](Chapter13.md)
