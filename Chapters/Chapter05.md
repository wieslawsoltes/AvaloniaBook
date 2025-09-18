# 5. Layout system without mystery

Goal
- Understand Avalonia's layout pass (`Measure` then `Arrange`) and how `Layoutable` and `LayoutManager` orchestrate it.
- Master the core panels (StackPanel, Grid, DockPanel, WrapPanel) plus advanced tools (`GridSplitter`, `Viewbox`, `LayoutTransformControl`, `SharedSizeGroup`).
- Learn when to create custom panels by overriding `MeasureOverride`/`ArrangeOverride`.
- Know how scrolling, virtualization, and `Panel.ZIndex` interact with layout.
- Practice diagnosing layout issues with DevTools overlays and logging.

Why this matters
- Layout defines the user experience: predictable resizing, adaptive forms, responsive dashboards.
- Panels are reusable building blocks. Understanding the underlying contract helps you read control templates and write your own.
- Troubleshooting layout without a plan wastes time; with DevTools and knowledge of the pass order, you debug confidently.

Prerequisites
- You can run a basic Avalonia app and edit XAML (Chapters 2-4).
- You have DevTools (F12) available to inspect layout rectangles.

## 1. Mental model: measure and arrange

Every control inherits from `Layoutable` ([Layoutable.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Layout/Layoutable.cs)). The layout pass runs in two stages:

1. **Measure**: Parent asks each child "How big would you like to be?" providing an available size. The child can respond with any size up to that constraint. Override `MeasureOverride` in panels to lay out children.
2. **Arrange**: Parent decides where to place each child within its final bounds. Override `ArrangeOverride` to position children based on the measured sizes.

The `LayoutManager` ([LayoutManager.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Layout/LayoutManager.cs)) schedules layout passes when controls invalidate measure or arrange (`InvalidateMeasure`, `InvalidateArrange`).

## 2. Start a layout playground project

```bash
dotnet new avalonia.app -o LayoutPlayground
cd LayoutPlayground
```

Replace `MainWindow.axaml` with an experiment playground that demonstrates the core panels and alignment tools:

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="LayoutPlayground.MainWindow"
        Width="880" Height="560"
        Title="Layout Playground">
  <Grid ColumnDefinitions="*,*" RowDefinitions="Auto,*" Padding="16" RowSpacing="16" ColumnSpacing="16">
    <TextBlock Grid.ColumnSpan="2" Classes="h1" Text="Layout system without mystery"/>

    <StackPanel Grid.Row="1" Spacing="12">
      <TextBlock Classes="h2" Text="StackPanel"/>
      <Border BorderBrush="#CCC" BorderThickness="1" Padding="8">
        <StackPanel Spacing="6">
          <Button Content="Top"/>
          <Button Content="Middle"/>
          <Button Content="Bottom"/>
          <Button Content="Stretch me" HorizontalAlignment="Stretch"/>
        </StackPanel>
      </Border>

      <TextBlock Classes="h2" Text="DockPanel"/>
      <Border BorderBrush="#CCC" BorderThickness="1" Padding="8">
        <DockPanel LastChildFill="True">
          <TextBlock DockPanel.Dock="Top" Text="Top bar"/>
          <TextBlock DockPanel.Dock="Left" Text="Left" Margin="0,4,8,0"/>
          <Border Background="#F0F6FF" CornerRadius="4" Padding="8">
            <TextBlock Text="Last child fills remaining space"/>
          </Border>
        </DockPanel>
      </Border>
    </StackPanel>

    <StackPanel Grid.Column="1" Grid.Row="1" Spacing="12">
      <TextBlock Classes="h2" Text="Grid + WrapPanel"/>
      <Border BorderBrush="#CCC" BorderThickness="1" Padding="8">
        <Grid ColumnDefinitions="Auto,*" RowDefinitions="Auto,Auto,Auto" ColumnSpacing="8" RowSpacing="8">
          <TextBlock Text="Name:"/>
          <TextBox Grid.Column="1" MinWidth="200"/>

          <TextBlock Grid.Row="1" Text="Email:"/>
          <TextBox Grid.Row="1" Grid.Column="1"/>

          <TextBlock Grid.Row="2" Text="Notes:" VerticalAlignment="Top"/>
          <TextBox Grid.Row="2" Grid.Column="1" Height="80" AcceptsReturn="True" TextWrapping="Wrap"/>
        </Grid>
      </Border>

      <Border BorderBrush="#CCC" BorderThickness="1" Padding="8">
        <WrapPanel ItemHeight="32" MinWidth="200" ItemWidth="100" HorizontalAlignment="Left">
          <Button Content="One"/>
          <Button Content="Two"/>
          <Button Content="Three"/>
          <Button Content="Four"/>
          <Button Content="Five"/>
          <Button Content="Six"/>
        </WrapPanel>
      </Border>
    </StackPanel>
  </Grid>
</Window>
```

Run the app and resize the window. Observe how StackPanel, DockPanel, Grid, and WrapPanel distribute space.

## 3. Alignment and sizing toolkit recap

- `Margin` vs `Padding`: Margin adds space around a control; Padding adds space inside a container.
- `HorizontalAlignment`/`VerticalAlignment`: `Stretch` makes controls fill available space; `Center`, `Start`, `End` align within the assigned slot.
- `Width`/`Height`: fixed sizes; use sparingly. Prefer `MinWidth`, `MaxWidth`, `MinHeight`, `MaxHeight` for adaptive layouts.
- Grid sizing: `Auto` (size to content), `*` (take remaining space), `2*` (take twice the share). Column/row definitions can mix Auto, star, and pixel values.

## 4. Advanced layout tools

### Grid with `SharedSizeGroup`

`SharedSizeGroup` lets multiple grids share sizes within a scope. Mark the parent with `Grid.IsSharedSizeScope="True"`:

```xml
<Grid ColumnDefinitions="Auto,*" RowDefinitions="Auto,Auto" Grid.IsSharedSizeScope="True">
  <Grid.ColumnDefinitions>
    <ColumnDefinition SharedSizeGroup="Label"/>
    <ColumnDefinition Width="*"/>
  </Grid.ColumnDefinitions>
  <Grid RowDefinitions="Auto,Auto" ColumnDefinitions="Auto,*">
    <TextBlock Text="First" Grid.Column="0"/>
    <TextBox Grid.Column="1" MinWidth="200"/>
  </Grid>
  <Grid Grid.Row="1" ColumnDefinitions="Auto,*">
    <TextBlock Text="Second" Grid.Column="0"/>
    <TextBox Grid.Column="1" MinWidth="200"/>
  </Grid>
</Grid>
```

All label columns share the same width. Source: [`Grid.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Grid.cs) and [`DefinitionBase.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/DefinitionBase.cs).

### `GridSplitter`

```xml
<Grid ColumnDefinitions="3*,Auto,2*">
  <StackPanel Grid.Column="0">...</StackPanel>
  <GridSplitter Grid.Column="1" Width="6" ShowsPreview="True" Background="#DDD"/>
  <StackPanel Grid.Column="2">...</StackPanel>
</Grid>
```

`GridSplitter` lets users resize star-sized columns/rows. Implementation: [`GridSplitter.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/GridSplitter.cs).

### `Viewbox` and `LayoutTransformControl`

- `Viewbox` scales its child proportionally to fit the available space.
- `LayoutTransformControl` applies transforms (rotate, scale, skew) while preserving layout.

```xml
<Viewbox Stretch="Uniform" Width="200" Height="200">
  <TextBlock Text="Scaled" FontSize="24"/>
</Viewbox>

<LayoutTransformControl>
  <LayoutTransformControl.LayoutTransform>
    <RotateTransform Angle="-10"/>
  </LayoutTransformControl.LayoutTransform>
  <Border Padding="12" Background="#E7F1FF">
    <TextBlock Text="Rotated layout"/>
  </Border>
</LayoutTransformControl>
```

Sources: [`Viewbox.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Viewbox.cs), [`LayoutTransformControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/LayoutTransformControl.cs).

### `Panel.ZIndex`

Controls inside the same panel respect `Panel.ZIndex` for stacking order. Higher ZIndex renders above lower values.

```xml
<Canvas>
  <Rectangle Width="100" Height="80" Fill="#60FF0000" Panel.ZIndex="1"/>
  <Rectangle Width="120" Height="60" Fill="#6000FF00" Panel.ZIndex="2" Margin="20,10,0,0"/>
</Canvas>
```

## 5. Scrolling and LogicalScroll

`ScrollViewer` wraps content to provide scrolling. When the child implements `ILogicalScrollable` (e.g., `ItemsPresenter` with virtualization), the scrolling is smoother and can skip measurement of offscreen content.

```xml
<ScrollViewer HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto">
  <StackPanel>

  </StackPanel>
</ScrollViewer>
```

- For virtualization, panels may implement `ILogicalScrollable` (see [`LogicalScroll.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/LogicalScroll.cs)).
- `ScrollViewer` triggers layout when viewports change.

## 6. Custom panels (when the built-ins aren't enough)

Derive from `Panel` and override `MeasureOverride`/`ArrangeOverride` to create custom layout logic. Example: a simplified `UniformGrid`:

```csharp
using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;

namespace LayoutPlayground.Controls;

public class UniformGridPanel : Panel
{
    public static readonly StyledProperty<int> ColumnsProperty =
        AvaloniaProperty.Register<UniformGridPanel, int>(nameof(Columns), 2);

    public int Columns
    {
        get => GetValue(ColumnsProperty);
        set => SetValue(ColumnsProperty, value);
    }

    protected override Size MeasureOverride(Size availableSize)
    {
        foreach (var child in Children)
        {
            child.Measure(Size.Infinity);
        }

        var rows = (int)Math.Ceiling(Children.Count / (double)Columns);
        var cellWidth = availableSize.Width / Columns;
        var cellHeight = availableSize.Height / rows;

        return new Size(cellWidth * Columns, cellHeight * rows);
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        var rows = (int)Math.Ceiling(Children.Count / (double)Columns);
        var cellWidth = finalSize.Width / Columns;
        var cellHeight = finalSize.Height / rows;

        for (var index = 0; index < Children.Count; index++)
        {
            var child = Children[index];
            var row = index / Columns;
            var column = index % Columns;
            var rect = new Rect(column * cellWidth, row * cellHeight, cellWidth, cellHeight);
            child.Arrange(rect);
        }

        return finalSize;
    }
}
```

- This panel ignores child desired sizes for simplicity; real panels usually respect `child.DesiredSize` from `Measure`.
- Read `Layoutable` and `Panel` sources to understand helper methods like `ArrangeRect`.

## 7. Layout diagnostics with DevTools

While running the app press **F12** -> Layout tab:
- Inspect the measurement and arrange rectangles for each control.
- Toggle the Layout Bounds overlay to visualise margins and paddings.
- Use the Render Options overlay to show dirty rectangles (requires enabling `RendererDebugOverlays` in code: see `RendererDebugOverlays.cs`).

You can also enable layout logging:

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .LogToTrace(LogEventLevel.Debug, new[] { LogArea.Layout })
    .StartWithClassicDesktopLifetime(args);
```

`LogArea.Layout` logs measure/arrange operations to the console.

## 8. Practice scenarios

1. **Shared field labels**: Use `Grid.IsSharedSizeScope` and `SharedSizeGroup` across multiple form sections so labels align perfectly, even when collapsed sections are toggled.
2. **Resizable master-detail**: Combine `GridSplitter` with a two-column layout; ensure minimum sizes keep content readable.
3. **Rotated card**: Wrap a Border in `LayoutTransformControl` to rotate it; evaluate how alignment behaves inside the transform.
4. **Custom panel**: Replace a WrapPanel with your `UniformGridPanel` and compare measurement behaviour in DevTools.
5. **Scroll diagnostics**: Place a long list inside `ScrollViewer`, enable DevTools Layout overlay, and observe how viewport size changes the arrange rectangles.

## Look under the hood (source bookmarks)
- Base layout contract: [`Layoutable.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Layout/Layoutable.cs)
- Layout manager: [`LayoutManager.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Layout/LayoutManager.cs)
- Grid + shared size: [`Grid.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Grid.cs), [`DefinitionBase.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/DefinitionBase.cs)
- Layout transforms: [`LayoutTransformControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/LayoutTransformControl.cs)
- Scroll infrastructure: [`ScrollViewer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ScrollViewer.cs), [`LogicalScroll.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/LogicalScroll.cs)
- Custom panels inspiration: [`VirtualizingStackPanel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/VirtualizingStackPanel.cs)

## Check yourself
- What two steps does the layout system run for every control, and which classes coordinate them?
- How does `SharedSizeGroup` influence multiple grids? What property enables shared sizing?
- When would you use `LayoutTransformControl` instead of a render transform?
- What happens if you change `Panel.ZIndex` for children inside the same panel?
- How can DevTools and logging help you diagnose a control that does not appear where expected?

What's next
- Next: [Chapter 6](Chapter06.md)
