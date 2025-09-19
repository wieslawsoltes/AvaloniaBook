# 10. Working with resources, images, and fonts

Goal
- Master `avares://` URIs, `AssetLoader`/`IAssetLoader`, and `ResourceDictionary` lookup so you can bundle assets cleanly.
- Display raster and vector images, control caching/interpolation, and brush surfaces with images (including SVG pipelines).
- Load custom fonts, configure `FontManagerOptions`, and swap font families at runtime.
- Understand resource fallback order, dynamic `ResourceDictionary` updates, and diagnostics when a lookup fails.
- Tune DPI scaling, bitmap interpolation, and responsive asset strategies that scale across devices.

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

## 2. Resource dictionaries and lookup order

`ResourceDictionary` derives from [`ResourceProvider`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Controls/ResourceProvider.cs) and implements [`IResourceProvider`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Controls/IResourceProvider.cs). When you request `{StaticResource}` or call `TryGetResource`, Avalonia walks this chain:

1. The requesting `IResourceHost` (control, style, or application).
2. Parent styles (`<Style.Resources>`), control templates, and data templates.
3. Theme dictionaries (`ThemeVariantScope`, `Application.Styles`, `Application.Resources`).
4. Merged dictionaries (`<ResourceDictionary.MergedDictionaries>` or `<ResourceInclude>`).
5. Global application resources and finally platform defaults (`SystemResources`).

`ResourceDictionary.cs` and `ResourceNode.cs` coordinate this traversal. Use `TryGetResource` when retrieving values from code:

```csharp
if (control.TryGetResource("AccentBrush", ThemeVariant.Dark, out var value) && value is IBrush brush)
{
    control.Background = brush;
}
```

`ThemeVariant` lets you request a variant-specific value; pass `ThemeVariant.Default` to follow the same logic as `{DynamicResource}`.

Merge dictionaries to break assets into reusable packs:

```xml
<ResourceDictionary>
  <ResourceDictionary.MergedDictionaries>
    <ResourceInclude Source="avares://AssetsDemo/Assets/Colors.axaml"/>
    <ResourceInclude Source="avares://AssetsDemo/Assets/Icons.axaml"/>
  </ResourceDictionary.MergedDictionaries>
</ResourceDictionary>
```

Each merged dictionary is loaded lazily via `IAssetLoader`, so make sure the referenced file is marked as `AvaloniaResource`.

## 3. Loading assets in XAML and code

### XAML

```xml
<Image Source="avares://AssetsDemo/Assets/Images/logo.png"
       Stretch="Uniform" Width="160"/>
```

### Code using `AssetLoader`

```csharp
using Avalonia;
using Avalonia.Media.Imaging;
using Avalonia.Platform;

var uri = new Uri("avares://AssetsDemo/Assets/Images/logo.png");
var assetLoader = AvaloniaLocator.Current.GetRequiredService<IAssetLoader>();

await using var stream = assetLoader.Open(uri);
LogoImage.Source = new Bitmap(stream);
```

`AssetLoader` is a static helper over the same `IAssetLoader` service. Prefer the interface when unit testing or when you need to mock resource access. Both live in [`Avalonia.Platform`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/AssetLoader.cs).

Need to probe for optional assets? Use `assetLoader.TryOpen(uri)` or `AssetLoader.Exists(uri)` to avoid exceptions.

### Resource dictionaries

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui">
  <Bitmap x:Key="LogoBitmap">avares://AssetsDemo/Assets/Images/logo.png</Bitmap>
</ResourceDictionary>
```

You can then `StaticResource` expose `LogoBitmap`. Bitmaps created this way are cached.

## 4. Raster images, decoders, and caching

`Image` renders `Avalonia.Media.Imaging.Bitmap`. Decode streams once and keep the bitmap alive when the pixels are reused, instead of calling `new Bitmap(stream)` for every render. Performance tips:
- Set `Stretch` to avoid unexpected distortions (Uniform, UniformToFill, Fill, None).
- Use `RenderOptions.BitmapInterpolationMode` for scaling quality:

```xml
<Image Source="avares://AssetsDemo/Assets/Images/photo.jpg"
       Width="240" Height="160"
       RenderOptions.BitmapInterpolationMode="HighQuality"/>
```

Interpolation modes defined in [`RenderOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs).

Decode oversized images to a target width/height to save memory:

```csharp
await using var stream = assetLoader.Open(uri);
using var decoded = Bitmap.DecodeToWidth(stream, 512);
PhotoImage.Source = decoded;
```

`Bitmap` and decoder helpers live in [`Bitmap.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/Imaging/Bitmap.cs). Avalonia picks the right codec (PNG, JPEG, WebP, BMP, GIF) using Skia; for unsupported formats supply a custom `IBitmapDecoder`.

## 5. ImageBrush and tiled backgrounds

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

## 6. Vector graphics

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

### `StreamGeometryContext` for programmatic icons

Generate vector shapes in code when you need to compose icons dynamically or reuse geometry logic:

```csharp
var geometry = new StreamGeometry();

using (var ctx = geometry.Open())
{
    ctx.BeginFigure(new Point(2, 12), isFilled: false);
    ctx.LineTo(new Point(9, 19));
    ctx.LineTo(new Point(22, 4));
    ctx.EndFigure(isClosed: false);
}

IconPath.Data = geometry;
```

`StreamGeometry` and `StreamGeometryContext` live in [`StreamGeometryContext.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/StreamGeometryContext.cs). Remember to freeze geometry instances or share them via resources to reduce allocations.

### SVG support

Install the `Avalonia.Svg.Skia` package to render SVG assets natively:

```xml
<svg:SvgImage xmlns:svg="clr-namespace:Avalonia.Svg.Controls;assembly=Avalonia.Svg.Skia"
              Source="avares://AssetsDemo/Assets/Images/logo.svg"
              Stretch="Uniform" />
```

SVGs stay sharp at any DPI and can adapt colors if you parameterize them (e.g., replace fill attributes at build time). For simple icons, converting the path data into XAML keeps dependencies minimal.

## 7. Fonts and typography

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

### Runtime font swaps and custom collections

You can inject fonts at runtime without restarting the app. Register an embedded collection and update resources:

```csharp
using Avalonia.Media;
using Avalonia.Media.Fonts;

var baseUri = new Uri("avares://AssetsDemo/Assets/BrandFonts/");
var collection = new EmbeddedFontCollection(new Uri("fonts:brand"), baseUri);

FontManager.Current.AddFontCollection(collection);

Application.Current!.Resources["BodyFont"] = new FontFamily("fonts:brand#Brand Sans");
```

`EmbeddedFontCollection` pulls all font files under the provided URI using `IAssetLoader`. Removing the collection via `FontManager.Current.RemoveFontCollection(new Uri("fonts:brand"))` detaches it again.

## 8. DPI scaling, caching, and performance

Avalonia measures layout in DIPs (1 DIP = 1/96 inch). High DPI monitors scale automatically.

- Prefer vector assets or high-resolution bitmaps.
- Use `RenderOptions.BitmapInterpolationMode="None"` for pixel art.
- For expensive bitmaps (charts) consider caching via `RenderTargetBitmap` or `WriteableBitmap`.

`RenderTargetBitmap` and `WriteableBitmap` under [`Avalonia.Media.Imaging`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Base/Media/Imaging).

## 9. Dynamic resources, theme variants, and runtime updates

Bind brushes via `DynamicResource` so assets respond to theme changes. When a dictionary entry changes, `ResourceDictionary.ResourcesChanged` notifies every subscriber and controls update automatically:

```xml
<Application.Resources>
  <SolidColorBrush x:Key="AvatarFallbackBrush" Color="#1F2937"/>
</Application.Resources>

<Ellipse Fill="{DynamicResource AvatarFallbackBrush}"/>
```

At runtime you can swap assets:

```csharp
Application.Current!.Resources["AvatarFallbackBrush"] = new SolidColorBrush(Color.Parse("#3B82F6"));
```

To scope variants, wrap content in a `ThemeVariantScope` and supply dictionaries per variant:

```xml
<ThemeVariantScope RequestedThemeVariant="Dark">
  <ThemeVariantScope.Resources>
    <SolidColorBrush x:Key="AvatarFallbackBrush" Color="#E5E7EB"/>
  </ThemeVariantScope.Resources>
  <ContentPresenter Content="{Binding}"/>
</ThemeVariantScope>
```

`ThemeVariantScope` relies on `IResourceHost` to merge dictionaries in order (scope → parent scope → application). To inspect all merged resources in DevTools, open **Resources** and observe how `RequestedThemeVariant` switches dictionaries.

## 10. Diagnostics

- DevTools -> Resources shows resolved resources.
- Missing asset? Check the output logs (`RenderOptions` area) for "not found" messages.
- Use `AssetLoader.Exists(uri)` to verify at runtime:

```csharp
if (!AssetLoader.Exists(uri))
    throw new FileNotFoundException($"Asset {uri} not found");
```

- Subscribe to `Application.Current.Resources.ResourcesChanged` (or scope-specific hosts) to log when dictionaries update, especially when debugging `DynamicResource` refreshes.

## 11. Sample "asset gallery"

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

## 12. Practice exercises

1. Move brand colors into `Assets/Brand.axaml`, include it with `<ResourceInclude Source="avares://AssetsDemo/Assets/Brand.axaml"/>`, and verify lookups succeed from a control in another assembly.
2. Build an image component that prefers SVG (`SvgImage`) but falls back to a PNG `Bitmap` on platforms where the SVG package is missing.
3. Decode a high-resolution photo with `Bitmap.DecodeToWidth` and compare memory usage against eagerly loading the original stream.
4. Register an `EmbeddedFontCollection` at runtime and swap your typography resources by updating `Application.Current.Resources["BodyFont"]`.
5. Toggle `ThemeVariantScope.RequestedThemeVariant` at runtime and confirm `DynamicResource`-bound brushes and images update without recreating controls.

## Look under the hood (source bookmarks)
- Resource system: [`ResourceProvider.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Controls/ResourceProvider.cs), [`ResourceDictionary.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Controls/ResourceDictionary.cs)
- Asset loader and URIs: [`AssetLoader.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/AssetLoader.cs), [`ResourceInclude.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Markup/ResourceInclude.cs)
- Bitmap and imaging: [`Bitmap.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/Imaging/Bitmap.cs)
- Vector geometry: [`StreamGeometryContext.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/StreamGeometryContext.cs), [`Path.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Shapes/Path.cs)
- Fonts & text formatting: [`FontManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/FontManager.cs), [`EmbeddedFontCollection.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/Fonts/EmbeddedFontCollection.cs)
- Theme variants and resources: [`ThemeVariantScope.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/ThemeVariantScope.cs), [`ResourcesChangedHelper.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Controls/ResourcesChangedHelper.cs)
- Render options and DPI: [`RenderOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/RenderOptions.cs)

## Check yourself
- What order does Avalonia search when resolving `{StaticResource}` and `{DynamicResource}`?
- When do you reach for `IAssetLoader` instead of the static `AssetLoader` helper?
- How would you build a responsive icon pipeline that prefers `StreamGeometry`/SVG but falls back to a bitmap?
- Which APIs let you swap font families at runtime without restarting the app?
- How can you confirm that dynamic resource updates propagated after changing `Application.Current.Resources`?

What's next
- Next: [Chapter 11](Chapter11.md)
