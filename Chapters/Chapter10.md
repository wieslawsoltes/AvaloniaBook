# 10. Working with resources, images, and fonts

Goal
- Know how to package and reference app assets with avares URIs.
- Display raster images (PNG/JPG) and prefer vector for icons where possible.
- Bundle and use custom fonts; understand FontFamily and the “#FaceName” syntax.
- Understand DPI scaling in Avalonia and how to keep images/text crisp.

What you’ll build
- A small gallery view that shows:
  - A raster logo with Image.
  - A circular avatar using ImageBrush.
  - A vector icon drawn with Path.
  - Headings styled with a bundled custom font.

Prerequisites
- You can edit App.axaml and a Window/UserControl (Ch. 3–7).
- Basic XAML and binding familiarity (Ch. 5–9).

1) Project assets and avares URIs
- Avalonia embeds UI assets as AvaloniaResource and addresses them using the avares:// URI scheme.
- Start by organizing files under an Assets folder:

Assets/
- Images/
  - logo.png
  - avatar.png
- Fonts/
  - Inter.ttf

- Ensure your project includes these as AvaloniaResource. Most templates already include a wildcard. If not, add:

```xml
<ItemGroup>
  <AvaloniaResource Include="Assets/**" />
</ItemGroup>
```

- Referencing an embedded asset uses the assembly name and path:
  - avares://MyApp/Assets/Images/logo.png
  - If you’re referencing within the same assembly, still include the assembly segment for clarity and portability.

2) Show an image in XAML (raster)
- The Image control displays bitmaps. Use Stretch to control scaling.

```xml
<Image Source="avares://MyApp/Assets/Images/logo.png"
       Stretch="Uniform" Width="160"/>
```

- In code-behind you can load from the same URI using AssetLoader:

```csharp
using System;
using Avalonia.Media.Imaging;
using Avalonia.Platform; // AssetLoader

var uri = new Uri("avares://MyApp/Assets/Images/logo.png");
using var stream = AssetLoader.Open(uri);
LogoImage.Source = new Bitmap(stream);
```

Tips
- Prefer PNG for UI assets with transparency (icons, logos). JPG is fine for photos.
- Keep the source image reasonably large so downscaling on high‑DPI looks sharp.

3) Use ImageBrush for backgrounds, shapes, and masks
- ImageBrush paints with an image anywhere a Brush is expected. Common uses: avatar circles, card covers, tiled backgrounds.

```xml
<Ellipse Width="80" Height="80">
  <Ellipse.Fill>
    <ImageBrush Source="avares://MyApp/Assets/Images/avatar.png"
                Stretch="UniformToFill" AlignmentX="Center" AlignmentY="Center"/>
  </Ellipse.Fill>
</Ellipse>
```

- Other knobs:
  - TileMode="Tile" to repeat an image.
  - SourceRect to select a sub‑region.
  - Stretch determines how the image fits: None, Fill, Uniform, UniformToFill.

4) Prefer vector icons when you can
- Vector art scales perfectly at any DPI and is theme‑friendly (you can recolor it with brushes).
- A simple way to draw a vector icon is with Path (Data is a geometry string):

```xml
<Path Data="M 10 2 L 20 22 L 0 22 Z"
      Fill="#2563EB" Width="20" Height="20"/>
```

- You can also keep geometry in a resource:

```xml
<Window.Resources>
  <Geometry x:Key="IconCheck">M2 10 L8 16 L18 4</Geometry>
</Window.Resources>
<Canvas>
  <Path Data="{StaticResource IconCheck}"
        Stroke="#16A34A" StrokeThickness="2" StrokeLineCap="Round" StrokeLineJoin="Round"/>
</Canvas>
```

Notes
- Vector assets are often provided as SVG. You can either convert small SVG paths to Path Data, or use an SVG package if you need full SVG support.

5) Bundle and use custom fonts
- Put your TTF/OTF files under Assets/Fonts and include them as AvaloniaResource.
- Use FontFamily with an avares URI plus the internal face name after #. The part after # must match the font’s family name (not the file name).

```xml
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="MyApp.App">
  <Application.Styles>
    <FluentTheme />
    <!-- Heading style using embedded font -->
    <Style Selector="TextBlock.h1">
      <Setter Property="FontFamily" Value="avares://MyApp/Assets/Fonts/Inter.ttf#Inter"/>
      <Setter Property="FontSize" Value="28"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
  </Application.Styles>
</Application>
```

- Use it in your views:

```xml
<TextBlock Classes="h1" Text="Resources, images, and fonts"/>
```

Font tips
- If the text doesn’t render with your font, check the family name embedded in the file (the # part).
- You can specify fallbacks: FontFamily="avares://MyApp/Assets/Fonts/Inter.ttf#Inter, Segoe UI, Roboto, Arial".

6) DPI scaling without mystery
- Avalonia measures sizes in device‑independent units (DIPs), where 1 unit = 1/96 inch. Your UI scales with monitor DPI.
- Bitmaps are scaled automatically by the composition system. To keep them crisp:
  - Prefer vector for icons and line art.
  - Use sufficiently large raster sources so downscaling looks good (avoid scaling up small images).
  - Use Stretch="Uniform" or "UniformToFill" to avoid distortion.
- Text is vector‑based and stays sharp; embedded fonts render through the GPU via the platform renderer.

7) Common pitfalls and how to fix them
- Wrong avares URI: include the correct assembly segment and exact path. Example: avares://MyApp/Assets/Images/logo.png
- Not included as AvaloniaResource: confirm your csproj has <AvaloniaResource Include="Assets/**" /> and the file exists under that path.
- Font family mismatch: the # part must match the font’s internal family name (use a font viewer to verify if needed).
- Theme‑unaware icons: prefer vector icons and bind Fill/Foreground to theme brushes (DynamicResource) so they adapt to light/dark.

8) A tiny “assets gallery” to try

```xml
<Grid ColumnDefinitions="Auto,12,Auto" RowDefinitions="Auto,12,Auto">
  <!-- Raster logo -->
  <Image Grid.Row="0" Grid.Column="0"
         Source="avares://MyApp/Assets/Images/logo.png"
         Width="160" Height="80" Stretch="Uniform"/>

  <!-- Spacer -->
  <Rectangle Grid.Row="0" Grid.Column="1" Width="12"/>

  <!-- Avatar circle from ImageBrush -->
  <Ellipse Grid.Row="0" Grid.Column="2" Width="80" Height="80">
    <Ellipse.Fill>
      <ImageBrush Source="avares://MyApp/Assets/Images/avatar.png"
                  Stretch="UniformToFill"/>
    </Ellipse.Fill>
  </Ellipse>

  <!-- Spacer row -->
  <Rectangle Grid.Row="1" Grid.ColumnSpan="3" Height="12"/>

  <!-- Vector icon (check mark) -->
  <Canvas Grid.Row="2" Grid.Column="0" Width="24" Height="24">
    <Path Data="M2 12 L9 19 L22 4"
          Stroke="#16A34A" StrokeThickness="3" StrokeLineCap="Round" StrokeLineJoin="Round"/>
  </Canvas>

  <!-- Heading with embedded font -->
  <TextBlock Grid.Row="2" Grid.Column="2" Classes="h1" Text="Asset gallery"/>
</Grid>
```

Check yourself
- What does the avares:// scheme point to, and why include the assembly segment?
- When would you choose Image vs ImageBrush?
- How do you reference a font file and its internal face name in FontFamily?
- Why do vector icons look better on very high‑DPI screens?

Look under the hood (repo reading list)
- Images and imaging: src/Avalonia.Media.Imaging, src/Avalonia.Controls (Image)
- Brushes and drawing primitives: src/Avalonia.Media
- Fonts and text: src/Avalonia.Media.TextFormatting
- Skia rendering backend: src/Skia/Avalonia.Skia

Extra practice
- Add a dark/light adaptive icon by binding a Path Fill to a DynamicResource brush.
- Create a tiled background with ImageBrush and TileMode="Tile".
- Add another font weight (e.g., Inter Bold) and make a .h1Bold style.
- Load a user‑picked image at runtime and display it with Image and ImageBrush variants.

What’s next
- Next: [Chapter 11](Chapter11.md)
