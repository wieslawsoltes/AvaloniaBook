# 19. Mobile targets: Android and iOS

Goal
- Build and run Avalonia apps on Android and iOS
- Understand SingleView lifetime and what’s different from desktop
- Learn mobile-friendly navigation, input, insets/safe areas, and soft keyboard handling

Why this matters
Desktop habits don’t directly map to phones. On mobile there’s no multi-window UI, touch is the primary input, and the OS controls system bars and safe areas. Small, intentional patterns keep your app feeling native while staying 100% Avalonia.

Quick start: SingleView lifetime (the mobile way)
On Android and iOS, Avalonia apps use a single top-level view instead of windows. In your App class, assign MainView when the application runs with a single-view lifetime.

C# (App)

```csharp
public partial class App : Application
{
    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            singleView.MainView = new MainView
            {
                DataContext = new MainViewModel()
            };
        }
        else if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            // Desktop fallback so the same app runs everywhere
            desktop.MainWindow = new MainWindow
            {
                DataContext = new MainViewModel()
            };
        }

        base.OnFrameworkInitializationCompleted();
    }
}
```

XAML (MainView)

```xml
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="MyApp.Views.MainView">
  <StackPanel Spacing="12" Margin="16">
    <TextBlock Text="Hello mobile" FontSize="24"/>
    <Button Content="Tap me" Command="{Binding TapCommand}"/>
  </StackPanel>
</UserControl>
```

Run targets
- Android: build and deploy to an emulator or device via the Android head project
- iOS: build and deploy to the Simulator or device via the iOS head project
Note: The platform “head” projects host your shared Avalonia app and provide platform manifests, icons, and entitlements.

Navigation on mobile (no windows, just views)
On phones you typically show one screen at a time and navigate forward/back. Two simple patterns:

1) Swap views in a ContentControl
- Keep a navigation stack (List<UserControl> or view models) and set a ContentControl’s Content to the current view
- Provide back/forward commands that push/pop the stack

2) Router-like approach
- You can implement a lightweight router (string or enum for routes → factory method producing a view)
- Or use a routing library (e.g., ReactiveUI’s routing) if you already use ReactiveUI

Minimal example (content swap)

```csharp
public class NavService
{
    private readonly Stack<object> _stack = new();

    public object? Current { get; private set; }

    public void NavigateTo(object vm)
    {
        if (Current is not null)
            _stack.Push(Current);
        Current = vm;
        OnChanged?.Invoke();
    }

    public bool GoBack()
    {
        if (_stack.Count == 0)
            return false;
        Current = _stack.Pop();
        OnChanged?.Invoke();
        return true;
    }

    public event Action? OnChanged;
}
```

Bind a ContentControl to NavService.Current and provide a Back button in your UI. On Android, the system Back button will usually close the activity if you don’t intercept it—so expose a Back command and wire it from your head project if you need to consume system back instead of exiting. On iOS, users expect a visible Back affordance in-app.

Touch input and gestures
- Tapped/DoubleTapped events work well for touch-first interaction
- PointerPressed/PointerReleased/PointerMoved are available when you need fine-grained control
- Avoid hover-only affordances; ensure controls are large enough to tap comfortably (44×44dp+)

Soft keyboard (IInputPane) and layout
When the on-screen keyboard appears, your UI may need to move or resize elements so inputs aren’t obscured. Subscribe to the input pane notifications and adjust paddings/margins accordingly.

```csharp
public partial class LoginView : UserControl
{
    public LoginView()
    {
        InitializeComponent();
        this.AttachedToVisualTree += (_, __) =>
        {
            var tl = TopLevel.GetTopLevel(this);
            var pane = tl?.InputPane;
            if (pane is null) return;

            pane.Showing += (_, __) => MoveContentUp();
            pane.Hiding += (_, __) => ResetLayout();
        };
    }
}
```

Safe areas and cutouts (IInsetsManager)
Modern phones have notches and system bars. Respect safe areas by adding padding from the insets manager and updating when insets change.

```csharp
this.AttachedToVisualTree += (_, __) =>
{
    var tl = TopLevel.GetTopLevel(this);
    var insets = tl?.InsetsManager;
    if (insets is null) return;

    void Apply() => RootPanel.Padding = new Thickness(
        left: insets.SafeAreaPadding.Left,
        top: insets.SafeAreaPadding.Top,
        right: insets.SafeAreaPadding.Right,
        bottom: insets.SafeAreaPadding.Bottom);

    Apply();
    insets.Changed += (_, __) => Apply();
};
```

Resources and assets for mobile
- Prefer vectors (Path/Icon) for crisp results at any DPI
- If you ship bitmaps, keep them reasonably sized; Avalonia scales device-independently but huge images still cost memory
- Fonts work the same as desktop (embed and reference by FontFamily); verify legibility on small screens
- App icons, splash screens, and entitlements live in the platform head projects (Android/iOS)

Storage and permissions
- Use StorageProvider for user file picks; don’t assume open file system access on mobile
- Android and iOS enforce permission models; requests and declarations live in the platform head (AndroidManifest.xml / Info.plist)

Platform differences at a glance
- Android: one activity hosts the app; hardware Back can exit unless handled; navigation/status bars vary by device/theme
- iOS: status bar and home indicator define safe areas; Back is typically an in-app control; background execution is more restricted

Troubleshooting
- Emulator/simulator doesn’t start: confirm SDKs, device images, and architecture match your machine
- App immediately exits on Android when pressing Back: your navigation stack returned false; provide an in-app Back or intercept system back in the head project
- Keyboard covers inputs: handle IInputPane showing/hiding and adjust layout
- Content under status bar or notch: apply padding from IInsetsManager safe area

Exercise
Convert your desktop sample to mobile:
1) Create a MainView that fits on a phone screen and set it as MainView for ISingleViewApplicationLifetime
2) Introduce a simple NavService and two screens (List → Details) with a visible Back button
3) Handle IInputPane to keep login inputs visible when the keyboard appears
4) Add safe area padding via IInsetsManager

Look under the hood
- Lifetimes: ISingleViewApplicationLifetime and SingleViewApplicationLifetime
  [Avalonia.Controls/ApplicationLifetimes](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/ApplicationLifetimes)
- Input pane abstraction (soft keyboard): IInputPane
  [Avalonia.Controls/Platform/IInputPane.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Platform/IInputPane.cs)
- Insets/safe areas: IInsetsManager
  [Avalonia.Controls/Platform/IInsetsManager.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Platform/IInsetsManager.cs)
- Platform heads and samples
  Android: [src/Android | sample heads under samples/](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Android)
  iOS: [src/iOS | sample heads under samples/](https://github.com/AvaloniaUI/Avalonia/tree/master/src/iOS)

What’s next
- Next: [Chapter 20](Chapter20.md)
