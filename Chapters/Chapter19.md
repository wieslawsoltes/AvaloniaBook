# 19. Mobile targets: Android and iOS

Goal
- Configure, build, and run Avalonia apps on Android and iOS using the single-project workflow.
- Understand single-view lifetimes, navigation patterns, safe areas, and mobile services (storage, clipboard, permissions).
- Integrate platform-specific features (back button, app icons, splash screens) while keeping shared MVVM architecture.

Why this matters
- Mobile devices have different UI expectations (single window, touch, safe areas, OS-managed lifecycle).
- Avalonia lets you share code across desktop and mobile, but you must adjust windowing, navigation, and services.

Prerequisites
- Chapter 12 (lifetimes/navigation), Chapter 16 (storage provider), Chapter 17 (async/networking).

## 1. Projects and workload setup

Install .NET workloads and mobile SDKs:

```bash
# Android
sudo dotnet workload install android

# iOS (macOS only)
sudo dotnet workload install ios

# Optional: wasm-tools for browser
sudo dotnet workload install wasm-tools
```

Check workloads with `dotnet workload list`.

Project structure:
- Shared project (e.g., `MyApp`): Avalonia cross-platform code.
- Platform heads (Android, iOS): host the Avalonia app, provide manifests, icons, metadata.

Avalonia templates (`dotnet new avalonia.app --multiplatform`) create the shared project plus heads (`MyApp.Android`, `MyApp.iOS`).

## 2. Single-view lifetime

`ISingleViewApplicationLifetime` hosts one root view. Configure in `App.OnFrameworkInitializationCompleted` (Chapter 4 showed desktop branch).

```csharp
public override void OnFrameworkInitializationCompleted()
{
    var services = ConfigureServices();

    if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
    {
        singleView.MainView = services.GetRequiredService<ShellView>();
    }
    else if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
    {
        desktop.MainWindow = services.GetRequiredService<MainWindow>();
    }

    base.OnFrameworkInitializationCompleted();
}
```

`ShellView` is a `UserControl` with mobile-friendly layout and navigation.

## 3. Mobile navigation patterns

Use view-model-first navigation (Chapter 12) but ensure a visible Back control.

```xml
<UserControl xmlns="https://github.com/avaloniaui" x:Class="MyApp.Views.ShellView">
  <Grid RowDefinitions="Auto,*">
    <StackPanel Orientation="Horizontal" Spacing="8" Margin="16">
      <Button Content="Back"
              Command="{Binding BackCommand}"
              IsVisible="{Binding CanGoBack}"/>
      <TextBlock Text="{Binding Title}" FontSize="20" VerticalAlignment="Center"/>
    </StackPanel>
    <TransitioningContentControl Grid.Row="1" Content="{Binding Current}"/>
  </Grid>
</UserControl>
```

`ShellViewModel` keeps a stack of view models and implements `BackCommand`/`NavigateTo`. Hook Android back button (Next section) to `BackCommand`.

## 4. Safe areas and input insets

Phones have notches and OS-controlled bars. Use `IInsetsManager` to apply safe-area padding.

```csharp
public partial class ShellView : UserControl
{
    public ShellView()
    {
        InitializeComponent();
        this.AttachedToVisualTree += (_, __) =>
        {
            var top = TopLevel.GetTopLevel(this);
            var insets = top?.InsetsManager;
            if (insets is null) return;

            void ApplyInsets()
            {
                RootPanel.Padding = new Thickness(
                    insets.SafeAreaPadding.Left,
                    insets.SafeAreaPadding.Top,
                    insets.SafeAreaPadding.Right,
                    insets.SafeAreaPadding.Bottom);
            }

            ApplyInsets();
            insets.Changed += (_, __) => ApplyInsets();
        };
    }
}
```

Soft keyboard (IME) adjustments: subscribe to `TopLevel.InputPane.Showing/Hiding` and adjust margins above keyboard.

```csharp
var pane = top?.InputPane;
if (pane is not null)
{
    pane.Showing += (_, args) => RootPanel.Margin = new Thickness(0, 0, 0, args.OccludedRect.Height);
    pane.Hiding += (_, __) => RootPanel.Margin = new Thickness(0);
}
```

## 5. Platform head customization

### 5.1 Android head (MyApp.Android)

- `MainActivity.cs` hosts Avalonia.
- `AndroidManifest.xml`: declare permissions (`INTERNET`, `READ_EXTERNAL_STORAGE`), orientation, minimum SDK.
- App icons/splash: `Resources/mipmap-*`, `Resources/layout` for splash.
- Intercept hardware Back button: override `OnBackPressed` to call service.

```csharp
public override void OnBackPressed()
{
    if (!AvaloniaApp.Current?.TryGoBack() ?? true)
        base.OnBackPressed();
}
```

`TryGoBack` calls into shared navigation service and returns true if you consumed the event.

### 5.2 iOS head (MyApp.iOS)

- `AppDelegate.cs` sets up Avalonia.
- `Info.plist`: permissions (e.g., camera), orientation, status bar style.
- Launch screen via `LaunchScreen.storyboard` or SwiftUI resources.

Handle universal links or background tasks by bridging to shared services in `AppDelegate`.

## 6. Permissions & storage

- StorageProvider works but returns sandboxed streams. Request platform permissions:
  - Android: declare `<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>` and use runtime requests.
  - iOS: add entries to Info.plist (e.g., `NSPhotoLibraryUsageDescription`).
- Consider packaging specific data (e.g., from `AppBundle`) instead of relying on arbitrary file system access.

## 7. Touch and gesture design

- Ensure controls are at least 44x44 DIP.
- Provide ripple/highlight states for buttons (Fluent theme handles this). Avoid hover-only interactions.
- Use `Tapped`/`DoubleTapped` events for simple gestures; `PointerGestureRecognizer` for advanced ones.

## 8. Performance & profiling

- Keep navigation stacks small; heavy animations may impact lower-end devices.
- Profile with Android Studio's profiler / Xcode Instruments for CPU, memory, GPU.
- When using `Task.Run`, consider battery impact; use async I/O where possible.

## 9. Packaging and deployment

### Android

```bash
cd MyApp.Android
# Debug build to device
msbuild /t:Run /p:Configuration=Debug

# Release APK/AAB
msbuild /t:Publish /p:Configuration=Release /p:AndroidPackageFormat=aab
```

Sign with keystore for app store.

### iOS

- Use Xcode to build and deploy to simulator/device. `dotnet build -t:Run -f net8.0-ios` works on macOS with Xcode installed.
- Provisioning profiles & certificates required for devices/app store.

## 10. Browser compatibility (bonus)

Mobile code often reuses single-view logic for WebAssembly. Check `ApplicationLifetime` for `BrowserSingleViewLifetime` and swap to a `ShellView`. Storage/clipboard behave like Chapter 16 with browser limitations.

## 11. Practice exercises

1. Configure the Android/iOS heads and run the app on emulator/simulator with a shared `ShellView`.
2. Implement a navigation service with back stack and wire Android back button to it.
3. Adjust safe-area padding and keyboard insets for a login screen (Inputs remain visible when keyboard shows).
4. Add file pickers via `StorageProvider` and test on device (consider permission prompts).
5. Package a release build (.aab for Android, .ipa for iOS) and validate icons/splash screens.

## Look under the hood (source bookmarks)
- Single-view lifetime: [`SingleViewApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/SingleViewApplicationLifetime.cs)
- Input pane (soft keyboard): [`IInputPane`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Platform/IInputPane.cs)
- Insets manager: [`IInsetsManager`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Platform/IInsetsManager.cs)
- Android platform project: [`src/Android`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Android)
- iOS platform project: [`src/iOS`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/iOS)
- Mobile samples: [`samples/ControlCatalog.Android`](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog.Android), [`samples/ControlCatalog.iOS`](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog.iOS)

## Check yourself
- How does the navigation pattern differ between desktop and mobile? How do you surface back navigation?
- How do you ensure inputs remain visible when the on-screen keyboard appears?
- What permission declarations are required for file access on Android/iOS?
- Where in the platform heads do you configure icons, splash screens, and orientation?

What's next
- Next: [Chapter 20](Chapter20.md)
