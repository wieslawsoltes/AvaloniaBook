# 12. Navigation, windows, and lifetimes

Goal
- Understand how Avalonia lifetimes (desktop, single-view, browser) drive app startup and shutdown.
- Manage windows: main, owned, modal, dialogs; persist placement; respect multiple screens.
- Implement navigation patterns (content swapping, navigation services, transitions) that work across platforms.
- Leverage `TopLevel` services (clipboard, storage, screens) from view models via abstractions.

Why this matters
- Predictable navigation and windowing keep apps maintainable on desktop, mobile, and web.
- Lifetimes differ per platform; knowing them prevents "works on Windows, fails on Android" surprises.
- Services like file pickers or clipboard should be accessible through MVVM-friendly patterns.

Prerequisites
- Chapter 4 (AppBuilder and lifetimes), Chapter 11 (MVVM patterns), Chapter 16 (storage) is referenced later.

## 1. Lifetimes recap

| Lifetime | Use case | Entry method |
| --- | --- | --- |
| `ClassicDesktopStyleApplicationLifetime` | Windows/macOS/Linux windowed apps | `StartWithClassicDesktopLifetime(args)` |
| `SingleViewApplicationLifetime` | Mobile (Android/iOS), embedded | `StartWithSingleViewLifetime(view)` |
| `BrowserSingleViewLifetime` | WebAssembly | `BrowserAppBuilder` setup |

`App.OnFrameworkInitializationCompleted` should handle all lifetimes:

```csharp
public override void OnFrameworkInitializationCompleted()
{
    var services = ConfigureServices();

    if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
    {
        var shell = services.GetRequiredService<MainWindow>();
        desktop.MainWindow = shell;

        // optional: intercept shutdown
        desktop.ShutdownMode = ShutdownMode.OnLastWindowClose;
    }
    else if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
    {
        singleView.MainView = services.GetRequiredService<ShellView>();
    }

    base.OnFrameworkInitializationCompleted();
}
```

When targeting browser, use `BrowserAppBuilder` with `SetupBrowserApp`.

## 2. Desktop windows in depth

### 2.1 Creating a main window with MVVM

```csharp
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Opened += (_, _) => RestorePlacement();
        Closing += (_, e) => SavePlacement();
    }

    private const string PlacementKey = "MainWindowPlacement";

    private void RestorePlacement()
    {
        if (LocalSettings.TryReadWindowPlacement(PlacementKey, out var placement))
        {
            Position = placement.Position;
            Width = placement.Size.Width;
            Height = placement.Size.Height;
        }
    }

    private void SavePlacement()
    {
        LocalSettings.WriteWindowPlacement(PlacementKey, new WindowPlacement
        {
            Position = Position,
            Size = new Size(Width, Height)
        });
    }
}
```

`LocalSettings` is a simple persistence helper (file or user settings). Persisting placement keeps UX consistent.

### 2.2 Owned windows, modal vs modeless

```csharp
public sealed class AboutWindow : Window
{
    public AboutWindow()
    {
        Title = "About";
        Width = 360;
        Height = 200;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Content = new TextBlock { Margin = new Thickness(16), Text = "My App v1.0" };
    }
}

// From main window or service
public Task ShowAboutDialogAsync(Window owner)
    => new AboutWindow { Owner = owner }.ShowDialog(owner);
```

Modeless window:

```csharp
var tool = new ToolWindow { Owner = this };
tool.Show();
```

Always set `Owner` so modal blocks correctly and centering works.

### 2.3 Multiple screens & placement

Use `Screens` service from `TopLevel`:

```csharp
var topLevel = TopLevel.GetTopLevel(this);
if (topLevel?.Screens is { } screens)
{
    var screen = screens.ScreenFromPoint(Position);
    var workingArea = screen.WorkingArea;
    Position = new PixelPoint(workingArea.X, workingArea.Y);
}
```

`Screens` live under [`Avalonia.Controls/Screens.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Screens.cs).

### 2.4 Prevent closing with unsaved changes

```csharp
Closing += async (sender, e) =>
{
    if (DataContext is ShellViewModel vm && vm.HasUnsavedChanges)
    {
        var confirm = await MessageBox.ShowAsync(this, "Unsaved changes", "Exit without saving?", MessageBoxButtons.YesNo);
        if (!confirm)
            e.Cancel = true;
    }
};
```

Implement `MessageBox` yourself or using Avalonia.MessageBox community package.

## 3. Navigation patterns

### 3.1 Content control navigation (shared for desktop & mobile)

```csharp
public sealed class NavigationService : INavigationService
{
    private readonly IServiceProvider _services;
    private object? _current;

    public object? Current
    {
        get => _current;
        private set => _current = value;
    }

    public NavigationService(IServiceProvider services)
        => _services = services;

    public void NavigateTo<TViewModel>() where TViewModel : class
        => Current = _services.GetRequiredService<TViewModel>();
}
```

`ShellViewModel` coordinates navigation:

```csharp
public sealed class ShellViewModel : ObservableObject
{
    private readonly INavigationService _navigationService;
    public object? Current => _navigationService.Current;

    public RelayCommand GoHome { get; }
    public RelayCommand GoSettings { get; }

    public ShellViewModel(INavigationService navigationService)
    {
        _navigationService = navigationService;
        GoHome = new RelayCommand(_ => _navigationService.NavigateTo<HomeViewModel>());
        GoSettings = new RelayCommand(_ => _navigationService.NavigateTo<SettingsViewModel>());
        _navigationService.NavigateTo<HomeViewModel>();
    }
}
```

Bind in view:

```xml
<DockPanel>
  <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Spacing="8">
    <Button Content="Home" Command="{Binding GoHome}"/>
    <Button Content="Settings" Command="{Binding GoSettings}"/>
  </StackPanel>
  <TransitioningContentControl Content="{Binding Current}">
    <TransitioningContentControl.Transitions>
      <PageSlide Transition="{Transitions:Slide FromRight}" Duration="0:0:0.2"/>
    </TransitioningContentControl.Transitions>
  </TransitioningContentControl>
</DockPanel>
```

`TransitioningContentControl` (from `Avalonia.Controls`) adds page transitions. Source: [`TransitioningContentControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TransitioningContentControl.cs).

### 3.2 View mapping via DataTemplates

Register view-model-to-view templates (Chapter 11 showed details). Example snippet:

```xml
<Application.DataTemplates>
  <DataTemplate DataType="{x:Type vm:HomeViewModel}">
    <views:HomeView />
  </DataTemplate>
  <DataTemplate DataType="{x:Type vm:SettingsViewModel}">
    <views:SettingsView />
  </DataTemplate>
</Application.DataTemplates>
```

### 3.3 Dialog service abstraction

Expose a dialog API from view models without referencing `Window`:

```csharp
public interface IDialogService
{
    Task<bool> ShowConfirmationAsync(string title, string message);
}

public sealed class DialogService : IDialogService
{
    private readonly Window _owner;
    public DialogService(Window owner) => _owner = owner;

    public async Task<bool> ShowConfirmationAsync(string title, string message)
    {
        var dialog = new ConfirmationWindow(title, message) { Owner = _owner };
        return await dialog.ShowDialog<bool>(_owner);
    }
}
```

Register a per-window dialog service in DI. For single-view scenarios, use `TopLevel.GetTopLevel(control)` to retrieve the root and use `StorageProvider` or custom dialogs.

## 4. Single-view navigation (mobile/web)

For `ISingleViewApplicationLifetime`, use a root `UserControl` (e.g., `ShellView`) with the same `TransitioningContentControl` pattern. Keep navigation inside that control.

```xml
<UserControl xmlns="https://github.com/avaloniaui" x:Class="MyApp.Views.ShellView">
  <TransitioningContentControl Content="{Binding Current}"/>
</UserControl>
```

From view models, use `INavigationService` as before; the lifetime determines whether a window or root view hosts the content.

## 5. TopLevel services: clipboard, storage, screens

`TopLevel.GetTopLevel(control)` returns the hosting top-level (Window or root). Useful for services.

### 5.1 Clipboard

```csharp
var topLevel = TopLevel.GetTopLevel(control);
if (topLevel?.Clipboard is { } clipboard)
{
    await clipboard.SetTextAsync("Copied text");
}
```

Clipboard API defined in [`IClipboard`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/Platform/IClipboard.cs).

### 5.2 Storage provider

Works in both desktop and single-view (browser has OS limitations):

```csharp
var topLevel = TopLevel.GetTopLevel(control);
if (topLevel?.StorageProvider is { } sp)
{
    var file = (await sp.OpenFilePickerAsync(new FilePickerOpenOptions
    {
        AllowMultiple = false,
        FileTypeFilter = new[] { FilePickerFileTypes.TextPlain }
    })).FirstOrDefault();
}
```

### 5.3 Screens info

`topLevel!.Screens` provides monitor layout. Use for placing dialogs on active monitor or respecting working area.

## 6. Browser (WebAssembly) considerations

Use `BrowserAppBuilder` and `BrowserSingleViewLifetime`:

```csharp
public static void Main(string[] args)
    => BuildAvaloniaApp().SetupBrowserApp("app");
```

Use `TopLevel.StorageProvider` for limited file access (via JavaScript APIs). Use JS interop for features missing from storage provider.

## 7. Practice exercises

1. Persist window placement, including maximized state, and restore on startup.
2. Implement a navigation history stack (back/forward) using a `Stack<object>` alongside `Current` binding.
3. Create a dialog service that exposes file open dialogs via `StorageProvider` and unit test the abstraction.
4. Detect the active screen and center modals on that screen, even when the main window spans monitors.
5. Implement transitions that differ per platform (e.g., slide on mobile, fade on desktop) by injecting transition providers.

## Look under the hood (source bookmarks)
- Window management: [`Window.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Window.cs)
- Lifetimes: [`ClassicDesktopStyleApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs), [`SingleViewApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/SingleViewApplicationLifetime.cs)
- TopLevel services: [`TopLevel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TopLevel.cs)
- Transitioning content: [`TransitioningContentControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TransitioningContentControl.cs)

## Check yourself
- How does `ClassicDesktopStyleApplicationLifetime` differ from `SingleViewApplicationLifetime` when showing windows?
- When should you use `Show` vs `ShowDialog`? Why set `Owner`?
- How do `TransitioningContentControl` and DataTemplates enable platform-neutral navigation?
- Which `TopLevel` service would you use to access the clipboard or file picker from a view model?

What's next
- Next: [Chapter 13](Chapter13.md)
