# 18. Desktop targets: Windows, macOS, Linux

Goal: Give you a practical map of Avalonia’s desktop features across Windows, macOS, and Linux, focusing on windowing, system decorations, transparency, multi‑monitor support, and scaling.

Why this matters: Desktop apps live in windows. Understanding how to size, position, decorate, and move windows (and how that varies by platform) prevents many bugs and gives your app a polished, native feel.

What you’ll learn
- Window basics you’ll use all the time: state, size‑to‑content, resizability, startup location, topmost/taskbar
- System decorations vs custom chrome (client area extension), and safe drag/resize
- Transparency levels (blur, acrylic, mica) and how to use them safely
- Multiple monitors and DPI scaling with Screens and DesktopScaling/RenderScaling
- Platform differences and troubleshooting tips

1) Window basics
- Window state and resizability
  - WindowState: Minimized, Normal, Maximized, FullScreen
  - CanResize: whether the user can resize the window
  - SizeToContent: Manual, Width, Height, WidthAndHeight

- Show in taskbar and always‑on‑top
  - ShowInTaskbar: show/hide the taskbar or dock icon
  - Topmost: keep the window above others

- Startup position
  - WindowStartupLocation: Manual (default), CenterScreen, CenterOwner

Example (XAML):

```xml
<Window
    xmlns="https://github.com/avaloniaui"
    x:Class="MyApp.MainWindow"
    Width="960" Height="640"
    CanResize="True"
    SizeToContent="Manual"
    WindowStartupLocation="CenterScreen"
    ShowInTaskbar="True"
    Topmost="False">
    <!-- Content here -->
</Window>
```

Example (code‑behind):

```csharp
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        WindowState = WindowState.Normal;
        CanResize = true;
        SizeToContent = SizeToContent.Manual;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        ShowInTaskbar = true;
        Topmost = false;
    }
}
```

2) System decorations and custom chrome
You can let the OS draw the standard window frame and title bar, or draw a custom one.

- SystemDecorations: Full (default) or None
- Extend client area into the title bar area to build custom chrome:
  - ExtendClientAreaToDecorationsHint (bool)
  - ExtendClientAreaChromeHints (flags)
  - ExtendClientAreaTitleBarHeightHint (double)

Safe drag/resize
- BeginMoveDrag(PointerPressedEventArgs) to let users drag your custom title bar
- BeginResizeDrag(WindowEdge, PointerPressedEventArgs) to let users resize by grabbing your custom edges

Minimal custom title bar example:

```xml
<Window
    xmlns="https://github.com/avaloniaui"
    x:Class="MyApp.MainWindow"
    SystemDecorations="None"
    ExtendClientAreaToDecorationsHint="True"
    ExtendClientAreaChromeHints="PreferSystemChrome"
    ExtendClientAreaTitleBarHeightHint="30">
    <Border Background="#1F1F1F" Height="30"
            PointerPressed="TitleBar_OnPointerPressed">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="8,0">
            <TextBlock Text="My App" Foreground="White"/>
            <!-- Add your own caption buttons here -->
        </StackPanel>
    </Border>
</Window>
```

```csharp
private void TitleBar_OnPointerPressed(object? sender, PointerPressedEventArgs e)
{
    // Only start a drag on left button press
    if (e.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
        BeginMoveDrag(e);
}
```

Notes
- Keep accessibility in mind: ensure hit‑targets and tooltips for custom caption buttons.
- Use your theme’s resources for hover/pressed states.

3) Transparency levels (blur, acrylic, mica)
Avalonia exposes a cross‑platform transparency abstraction on TopLevel (Window derives from TopLevel).

- Set a preferred list via TransparencyLevelHint (ordered by preference):
  - WindowTransparencyLevel.None
  - WindowTransparencyLevel.Transparent
  - WindowTransparencyLevel.Blur
  - WindowTransparencyLevel.AcrylicBlur
  - WindowTransparencyLevel.Mica
- Read the achieved level via ActualTransparencyLevel (platform picks the first supported one).

Example:

```xml
<Window
    xmlns="https://github.com/avaloniaui"
    x:Class="MyApp.MainWindow"
    TransparencyLevelHint="AcrylicBlur, Blur, Transparent">
    <!-- Content -->
</Window>
```

```csharp
public MainWindow()
{
    InitializeComponent();
    TransparencyLevelHint = new[]
    {
        WindowTransparencyLevel.AcrylicBlur,
        WindowTransparencyLevel.Blur,
        WindowTransparencyLevel.Transparent
    };

    this.GetObservable(TopLevel.ActualTransparencyLevelProperty)
        .Subscribe(level => Debug.WriteLine($"Actual transparency: {level}"));
}
```

Platform support summary (typical)
- Windows: Transparent, AcrylicBlur, Mica
- macOS: Transparent, AcrylicBlur
- Linux (X11 + compositor): Transparent, Blur
- Headless/Browser: None (not applicable for this chapter)

Tip
- Always provide a fallback chain (e.g., Mica → AcrylicBlur → Blur → Transparent) and design your theme to look good even with None.

4) Multiple monitors and scaling
Desktop apps must handle multiple displays and DPI scaling.

- Screens: enumerate and query monitors
  - this.Screens.All, this.Screens.Primary
  - this.Screens.ScreenFromPoint(PixelPoint), ScreenFromWindow(Window), ScreenFromBounds(PixelRect)
- Screen.Scaling: system DPI scaling factor for that monitor
- Window/Desktop scaling vs render scaling
  - Window.DesktopScaling: used for window positioning/sizing
  - TopLevel.RenderScaling: used for rendering primitives

Center the window on the primary screen in code:

```csharp
protected override void OnOpened(EventArgs e)
{
    base.OnOpened(e);

    var screen = Screens?.Primary;
    if (screen is null)
        return;

    // Convert logical size to pixel size using DesktopScaling
    var frame = PixelRect.FromBounds(new PixelPoint(0, 0),
        PixelSize.FromSize(ClientSize, DesktopScaling));

    var target = screen.WorkingArea.CenterRect(frame.Size);

    Position = target.Position;
}
```

React to scaling changes (e.g., when moving between monitors):

```csharp
ScalingChanged += (_, __) =>
{
    // RenderScaling changed; update sizes or pixel perfect resources if needed
};
```

5) Fullscreen, z‑order, and window interactions
- Fullscreen: set WindowState = WindowState.FullScreen; toggle back to Normal to exit
- Topmost: keep the window on top of others
- ShowDialog(owner): open modal child windows centered on the owner (see Chapter 12)
- BeginResizeDrag: implement resize handles in custom chrome

6) Platform notes and differences
Windows
- Transparency: AcrylicBlur and Mica are available on supported OS versions; Transparent works broadly
- System decorations: rich control; ExtendClientArea recommended for custom title bars
- Taskbar and z‑order: ShowInTaskbar and Topmost are fully supported

macOS
- Transparency: Transparent and Acrylic‑style blur supported via the native compositor
- Title area: ExtendClientAreaTitleBarHeightHint lets you align custom content; keep native feel
- Taskbar (Dock): ShowInTaskbar maps to Dock visibility semantics

Linux (X11)
- Transparency: Transparent and Blur depend on the window manager/compositor (e.g., GNOME, KDE)
- Decorations: behavior can vary by WM; test with SystemDecorations=None + ExtendClientArea
- Scaling: fractional scaling support depends on the environment; verify RenderScaling at runtime

7) Troubleshooting
- Window looks blurry on high‑DPI displays
  - Ensure images/icons are vector or have multiple raster scales; read RenderScaling to pick assets
- Transparency request ignored
  - Check ActualTransparencyLevel; fall back gracefully
- Custom title bar dragging doesn’t work
  - Call BeginMoveDrag only on a left‑button press; don’t start a drag from interactive children
- Window opens on the wrong monitor
  - Set WindowStartupLocation to CenterScreen for primary screen; or compute a position using Screens

Look under the hood (source)
- Window: [Avalonia.Controls/Window.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Window.cs)
- WindowStartupLocation: [Avalonia.Controls/WindowStartupLocation.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/WindowStartupLocation.cs)
- WindowState: [Avalonia.Controls/WindowState.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/WindowState.cs)
- SystemDecorations and extend‑client‑area hints: [Window.cs (L100–L161)](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Window.cs#L100-L161)
- TopLevel transparency properties: [TopLevel.cs (L69–L86)](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TopLevel.cs#L69-L86)
- WindowTransparencyLevel values: [Avalonia.Controls/WindowTransparencyLevel.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/WindowTransparencyLevel.cs)
- Screens and Screen: [Avalonia.Controls/Screens.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Screens.cs) and [Avalonia.Controls/Platform/Screen.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Platform/Screen.cs)

Check yourself
- Can you toggle between Normal, Maximized, and FullScreen at runtime?
- Can you build a minimal custom title bar that supports drag and window state buttons?
- Can you request Mica/Acrylic and fall back to Transparent when not supported?
- Can you query the current Screen and move the window to its center?

Extra practice
- Add a “Move To Next Monitor” command that cycles the window through Screens.All
- Create a theme that visually adapts to ActualTransparencyLevel
- Implement resize handles around your custom chrome using BeginResizeDrag

What’s next
- Next: [Chapter 19](Chapter19.md)
