# 18. Desktop targets: Windows, macOS, Linux

Goal
- Master Avalonia's desktop-specific features: window chrome, transparency, DPI/multi-monitor handling, platform capabilities, and packaging essentials.
- Understand per-platform caveats so your desktop app feels native on Windows, macOS, and Linux.

Why this matters
- Desktop users expect native window behavior, correct scaling, and integration with OS features (taskbar/dock, notifications).
- Avalonia abstracts the basics but you still need to apply platform-specific tweaks.

Prerequisites
- Chapter 4 (lifetimes), Chapter 12 (window navigation), Chapter 13 (menus/dialogs), Chapter 16 (storage).

## 1. Window fundamentals

```xml
<Window xmlns="https://github.com/avaloniaui"
        x:Class="MyApp.MainWindow"
        Width="1024" Height="720"
        CanResize="True"
        SizeToContent="Manual"
        WindowStartupLocation="CenterScreen"
        ShowInTaskbar="True"
        Topmost="False"
        Title="My App">

</Window>
```

Properties:
- `WindowState`: Normal, Minimized, Maximized, FullScreen.
- `CanResize`, `CanMinimize`, `CanMaximize` control system caption buttons.
- `SizeToContent`: `Manual`, `Width`, `Height`, `WidthAndHeight` (works best before window is shown).
- `WindowStartupLocation`: `Manual` (default), `CenterScreen`, `CenterOwner`.
- `ShowInTaskbar`: show/hide taskbar/dock icon.
- `Topmost`: keep above other windows.

Persist position/size between runs:

```csharp
protected override void OnOpened(EventArgs e)
{
    base.OnOpened(e);
    if (LocalSettings.TryReadWindowPlacement(out var placement))
    {
        Position = placement.Position;
        Width = placement.Width;
        Height = placement.Height;
        WindowState = placement.State;
    }
}

protected override void OnClosing(WindowClosingEventArgs e)
{
    base.OnClosing(e);
    LocalSettings.WriteWindowPlacement(new WindowPlacement
    {
        Position = Position,
        Width = Width,
        Height = Height,
        State = WindowState
    });
}
```

## 2. Custom title bars and chrome

`SystemDecorations="None"` removes native chrome; use extend-client-area hints for custom title bars.

```xml
<Window SystemDecorations="None"
        ExtendClientAreaToDecorationsHint="True"
        ExtendClientAreaChromeHints="PreferSystemChrome"
        ExtendClientAreaTitleBarHeightHint="32">
  <Grid>
    <Border Background="#1F2937" Height="32" VerticalAlignment="Top"
            PointerPressed="TitleBar_PointerPressed">
      <StackPanel Orientation="Horizontal" Margin="12,0" VerticalAlignment="Center" Spacing="12">
        <TextBlock Text="My App" Foreground="White"/>

        <Border x:Name="CloseButton" Width="32" Height="24" Background="Transparent"
                PointerPressed="CloseButton_PointerPressed">
          <Path Stroke="White" StrokeThickness="2" Data="M2,2 L10,10 M10,2 L2,10" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
      </StackPanel>
    </Border>

  </Grid>
</Window>
```

```csharp
private void TitleBar_PointerPressed(object? sender, PointerPressedEventArgs e)
{
    if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        BeginMoveDrag(e);
}

private void CloseButton_PointerPressed(object? sender, PointerPressedEventArgs e)
{
    Close();
}
```

- Provide hover/pressed styles for buttons.
- Add keyboard/screen reader support (AutomationProperties).

## 3. Window transparency & effects

```xml
<Window TransparencyLevelHint="Mica, AcrylicBlur, Blur, Transparent">

</Window>
```

```csharp
TransparencyLevelHint = new[]
{
    WindowTransparencyLevel.Mica,
    WindowTransparencyLevel.AcrylicBlur,
    WindowTransparencyLevel.Blur,
    WindowTransparencyLevel.Transparent
};

this.GetObservable(TopLevel.ActualTransparencyLevelProperty)
    .Subscribe(level => Debug.WriteLine($"Transparency: {level}"));
```

Platform support summary (subject to OS version, composition mode):
- Windows 10/11: Transparent, Blur, AcrylicBlur, Mica (Win11).
- macOS: Transparent, Blur (vibrancy).
- Linux (compositor dependent): Transparent, Blur.

Design for fallback: ActualTransparencyLevel may be `None`--ensure backgrounds look good without blur.

## 4. Screens, DPI, and scaling

- `Screens`: enumerate monitors (`Screens.All`, `Screens.Primary`).
- `Screen.WorkingArea`: available area excluding taskbar/dock.
- `Screen.Scaling`: per-monitor scale.
- `Window.DesktopScaling`: DIP to physical pixel ratio for positioning.
- `TopLevel.RenderScaling`: DPI scaling for rendering (affects pixel alignment).

Center on active screen:

```csharp
protected override void OnOpened(EventArgs e)
{
    base.OnOpened(e);
    var currentScreen = Screens?.ScreenFromWindow(this) ?? Screens?.Primary;
    if (currentScreen is null)
        return;

    var frameSize = PixelSize.FromSize(ClientSize, DesktopScaling);
    var target = currentScreen.WorkingArea.CenterRect(frameSize);
    Position = target.Position;
}
```

Handle scaling changes when moving between monitors:

```csharp
ScalingChanged += (_, _) =>
{
    // Renderer scaling updated; adjust cached bitmaps if necessary.
};
```

## 5. Platform integration

### 5.1 Windows

- Taskbar/dock menus: use Jump Lists via `System.Windows.Shell` interop or community packages.
- Notifications: `WindowNotificationManager` or Windows toast (via WinRT APIs).
- Acrylic/Mica: require Windows 10 or 11; fallback on earlier versions.
- System backdrops: set `TransparencyLevelHint` and ensure the OS supports it; consider theme-aware backgrounds.

### 5.2 macOS

- Menu bar: use `NativeMenuBar` (Chapter 13).
- Dock menu: `NativeMenuBar.Menu` can include items that appear in dock menu.
- Application events (Quit, About): integrate with `AvaloniaNativeMenuCommands` or handle native application events.
- Fullscreen: Mac expects toggle via green traffic-light button; `WindowState.FullScreen` works, but ensure custom chrome still accessible.

### 5.3 Linux

- Variety of window managers; test SystemDecorations/ExtendClientArea on GNOME/KDE.
- Transparency requires compositor (e.g., Mutter, KWin). Provide fallback.
- Fractional scaling support varies; check `RenderScaling` for the active monitor.
- Packaging (Flatpak, Snap, AppImage) may affect file dialog behavior (portal APIs).

## 6. Packaging & deployment overview

- Windows: `dotnet publish -r win-x64 --self-contained` or MSIX via `dotnet publish /p:PublishTrimmed=false /p:WindowsPackageType=msix`.
- macOS: `.app` bundle; codesign and notarize for distribution (`dotnet publish -r osx-x64 --self-contained` followed by bundle packaging via Avalonia templates or scripts).
- Linux: produce .deb/.rpm, AppImage, or Flatpak; ensure dependencies (GTK, Skia) available.

Reference docs: Avalonia publishing guide ([docs/publish.md](https://github.com/AvaloniaUI/Avalonia/blob/master/docs/publish.md)).

## 7. Multiple window management tips

- Track open windows via `ApplicationLifetime.Windows` (desktop only).
- Use `IClassicDesktopStyleApplicationLifetime.Exit` to exit the app.
- Owner/child relationships ensure modality, centering, and Z-order (Chapter 12).
- Provide "Move to Next Monitor" command by cycling through `Screens.All` and setting `Position` accordingly.

## 8. Troubleshooting

| Issue | Fix |
| --- | --- |
| Window blurry on high DPI | Use vector assets; adjust RenderScaling; ensure `UseCompositor` is default |
| Transparency ignored | Check ActualTransparencyLevel; verify OS support; remove conflicting settings |
| Custom chrome drag fails | Ensure `BeginMoveDrag` only on left button down; avoid starting drag from interactive controls |
| Incorrect monitor on startup | Set `WindowStartupLocation` or compute position using `Screens` before showing window |
| Linux packaging fails | Include `libAvaloniaNative.so` dependencies; use Avalonia Debian/RPM packaging scripts |

## 9. Practice exercises

1. Build a window with custom title bar, including minimize, maximize, close, and move/resize handles.
2. Request Mica/Acrylic, detect fallback, and apply theme-specific backgrounds for each transparency level.
3. Implement a "Move to Next Monitor" command cycling through available screens.
4. Persist window placement (position/size/state) to disk and restore on startup.
5. Create deployment artifacts: MSIX (Windows), .app (macOS), and AppImage/AppImage (Linux) for a simple app.

## Look under the hood (source bookmarks)
- Window & TopLevel: [`Window.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Window.cs), [`TopLevel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TopLevel.cs)
- Transparency enums: [`WindowTransparencyLevel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/WindowTransparencyLevel.cs)
- Screens API: [`Screens.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Screens.cs)
- Extend client area hints: [`Window.cs` lines around ExtendClientArea properties](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Window.cs)
- Desktop lifetime: [`ClassicDesktopStyleApplicationLifetime.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ApplicationLifetimes/ClassicDesktopStyleApplicationLifetime.cs)

## Check yourself
- How do you request and detect the achieved transparency level on each platform?
- What steps are needed to build a custom title bar that supports drag and resize?
- How do you center a window on the active monitor using `Screens` and scaling info?
- What packaging options are available per desktop platform?

What's next
- Next: [Chapter 19](Chapter19.md)
