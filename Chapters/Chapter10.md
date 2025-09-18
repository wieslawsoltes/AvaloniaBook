# 10. Working with resources, images, and fonts

Goal
- Master `avares://` URIs, `AssetLoader`, and resource dictionaries so you can bundle assets cleanly.
- Display raster and vector images, control caching/interpolation, and brush surfaces with images.
- Load custom fonts, configure `FontManagerOptions`, and support fallbacks.
- Understand DPI scaling, bitmap interpolation, and how RenderOptions affects quality.
- Hook resources into theming (DynamicResource) and diagnose missing assets quickly.

Why this matters
- Assets and fonts give your app brand identity; doing it right avoids blurry visuals or missing resources.
- Avalonia's resource system mirrors WPF/UWP but with cross-platform packaging; once you know the patterns, you can deploy confidently.

Prerequisites
- You can edit `App.axaml`, views, and bind data (Ch. 3-9).
- Familiarity with MVVM and theming (Ch. 7) helps when wiring assets dynamically.

## 1. `avares://` URIs and project structure

Assets live under your project (e.g., `Assets/Images`, `Assets/Fonts`). Include them as `AvaloniaResource` in the `.csproj`:

```xml
<ItemGroup>
  <AvaloniaResource Include="Assets/**" />
</ItemGroup>
```

URI structure: `avares://<AssemblyName>/<RelativePath>`.

Example: `avares://InputPlayground/Assets/Images/logo.png`.

`avares://` references the compiled resource stream (not the file system). Use it consistently even within the same assembly to avoid issues with resource lookups.

## 2. Loading assets in XAML and code

### XAML

```xml
<Image Source="avares://AssetsDemo/Assets/Images/logo.png"
       Stretch="Uniform" Width="160"/>
```

### Code using `AssetLoader`

```csharp
using Avalonia.Platform;
using Avalonia.Media.Imaging;

var uri = new Uri("avares://AssetsDemo/Assets/Images/logo.png");
await using var stream = AssetLoader.Open(uri);
LogoImage.Source = new Bitmap(stream);
```

`AssetLoader` lives in [`Avalonia.Platform`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/AssetLoader.cs).

### Resource dictionaries

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui">
  <Bitmap x:Key="LogoBitmap">avares://AssetsDemo/Assets/Images/logo.png</Bitmap>
</ResourceDictionary>
```

You can then `StaticResource` expose `LogoBitmap`. Bitmaps created this way are cached.

## 3. Raster images and caching

`Image` control displays bitmaps. Performance tips:
- Set `Stretch` to avoid unexpected distortions (Uniform, UniformToFill, Fill, None).
- Use `RenderOptions.BitmapInterpolationMode` for scaling quality:

```xml
<Image Source="avares://AssetsDemo/Assets/Images/photo.jpg"
       Width="240" Height="160"
       RenderOptions.BitmapInterpolationMode="HighQuality"/>
```

Interpolation modes defined in [`RenderOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs).

`Bitmap` supports caching and decoding. You can reuse preloaded bitmaps to avoid repeating disk IO.

## 4. ImageBrush and tiled backgrounds

`ImageBrush` paints surfaces:

```xml
<Ellipse Width="96" Height="96">
  <Ellipse.Fill>
    <ImageBrush Source="avares://AssetsDemo/Assets/Images/avatar.png"
                Stretch="UniformToFill" AlignmentX="Center" AlignmentY="Center"/>
  </Ellipse.Fill>
</Ellipse>
```

Tile backgrounds:

```xml
<Border Width="200" Height="120">
  <Border.Background>
    <ImageBrush Source="avares://AssetsDemo/Assets/Images/pattern.png"
                TileMode="Tile"
                Stretch="None"
                Transform="{ScaleTransform 0.5,0.5}"/>
  </Border.Background>
</Border>
```

`ImageBrush` documentation: [`ImageBrush.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/ImageBrush.cs).

## 5. Vector graphics

Vector art scales with DPI, can adapt to theme colors, and stays crisp.

### Inline geometry

```xml
<Path Data="M2 12 L9 19 L22 4"
      Stroke="{DynamicResource AccentBrush}"
      StrokeThickness="3"
      StrokeLineCap="Round" StrokeLineJoin="Round"/>
```

Store geometry in resources for reuse:

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui">
  <Geometry x:Key="IconCheck">M2 12 L9 19 L22 4</Geometry>
</ResourceDictionary>
```

Vector classes live under [`Avalonia.Media`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Media).

### SVG support

Use the `Avalonia.Svg` community library or convert simple SVG paths manually. For production, bundling vector icons as XAML ensures theme compatibility.

## 6. Fonts and typography

Place fonts in `Assets/Fonts`. Register them in `App.axaml` via `Global::Avalonia` URI and specify the font face after `#`:

```xml
<Application.Resources>
  <FontFamily x:Key="HeadingFont">avares://AssetsDemo/Assets/Fonts/Inter.ttf#Inter</FontFamily>
</Application.Resources>
```

Use the font in styles:

```xml
<Application.Styles>
  <Style Selector="TextBlock.h1">
    <Setter Property="FontFamily" Value="{StaticResource HeadingFont}"/>
    <Setter Property="FontSize" Value="28"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
  </Style>
</Application.Styles>
```

### FontManager options

Configure global font settings in `AppBuilder`:

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .With(new FontManagerOptions
    {
        DefaultFamilyName = "avares://AssetsDemo/Assets/Fonts/Inter.ttf#Inter",
        FontFallbacks = new[] { new FontFallback { Family = "Segoe UI" }, new FontFallback { Family = "Roboto" } }
    })
    .StartWithClassicDesktopLifetime(args);
```

`FontManagerOptions` lives in [`FontManagerOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/FontManagerOptions.cs).

### Multi-weight fonts

If fonts include multiple weights, specify them with `FontWeight`. If you ship multiple font files (Regular, Bold), ensure the `#Family` name is consistent.

## 7. DPI scaling, caching, and performance

Avalonia measures layout in DIPs (1 DIP = 1/96 inch). High DPI monitors scale automatically.

- Prefer vector assets or high-resolution bitmaps.
- Use `RenderOptions.BitmapInterpolationMode="None"` for pixel art.
- For expensive bitmaps (charts) consider caching via `RenderTargetBitmap` or `WriteableBitmap`.

`RenderTargetBitmap` and `WriteableBitmap` under [`Avalonia.Media.Imaging`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Media/Imaging).

## 8. Linking assets into themes

Bind brushes via `DynamicResource` so assets respond to theme changes:

```xml
<Application.Resources>
  <SolidColorBrush x:Key="AvatarFallbackBrush" Color="#1F2937"/>
</Application.Resources>

<Ellipse Fill="{DynamicResource AvatarFallbackBrush}"/>
```

Switch resources in theme dictionaries (Chapter 7). Example: lighten icons for Dark theme.

## 9. Diagnostics

- DevTools -> Resources shows resolved resources.
- Missing asset? Check the output logs (`RenderOptions` area) for "not found" messages.
- Use `AssetLoader.Exists(uri)` to verify at runtime:

```csharp
if (!AssetLoader.Exists(uri))
    throw new FileNotFoundException($"Asset {uri} not found");
```

## 10. Sample "asset gallery"

```xml
<Grid ColumnDefinitions="Auto,24,Auto" RowDefinitions="Auto,12,Auto">

  <Image Width="160" Height="80" Stretch="Uniform"
         Source="avares://AssetsDemo/Assets/Images/logo.png"/>

  <Rectangle Grid.Column="1" Grid.RowSpan="3" Width="24"/>


  <Ellipse Grid.Column="2" Width="96" Height="96">
    <Ellipse.Fill>
      <ImageBrush Source="avares://AssetsDemo/Assets/Images/avatar.png" Stretch="UniformToFill"/>
    </Ellipse.Fill>
  </Ellipse>

  <Rectangle Grid.Row="1" Grid.ColumnSpan="3" Height="12"/>


  <Canvas Grid.Row="2" Grid.Column="0" Width="28" Height="28">
    <Path Data="M2 14 L10 22 L26 6"
          Stroke="{DynamicResource AccentBrush}"
          StrokeThickness="3" StrokeLineCap="Round" StrokeLineJoin="Round"/>
  </Canvas>

  <TextBlock Grid.Row="2" Grid.Column="2" Classes="h1" Text="Asset gallery"/>
</Grid>
```

## 11. Practice exercises

1. Package a second font family (italic) and create a style for quotes.
2. Load a user-selected image from disk using `OpenFileDialog` (Chapter 16) and display it via `Bitmap` and `ImageBrush`.
3. Add a vector icon that swaps color based on `ThemeVariant` (use `DynamicResource` to map theme brushes).
4. Experiment with `RenderOptions.BitmapInterpolationMode` to compare pixelated vs crisp scaling.
5. Create a sprite sheet (single PNG) and display multiple sub-regions using `ImageBrush.SourceRect`.

## Look under the hood (source bookmarks)
- Asset loader and URIs: [`AssetLoader.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/AssetLoader.cs)
- Bitmap and imaging: [`Bitmap.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/Imaging/Bitmap.cs)
- Brushes: [`ImageBrush.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/ImageBrush.cs)
- Fonts & text formatting: [`FontManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/FontManager.cs), [`TextLayout.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/TextFormatting/TextLayout.cs)
- Render options and DPI: [`RenderOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs)

## Check yourself
- How do you ensure assets are embedded and addressable with `avares://` URIs?
- When would you use `Image` vs `ImageBrush` vs `Path`?
- What steps configure a custom font and fallback chain across platforms?
- How can `RenderOptions.BitmapInterpolationMode` improve image quality at different scales?
- Which tools help verify resources (DevTools, AssetLoader.Exists)?

What's next
- Next: [Chapter 11](Chapter11.md)
