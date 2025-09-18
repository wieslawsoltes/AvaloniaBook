# 23. Custom drawing and custom controls

Goal
- Decide when to custom draw (override `Render`) versus build templated controls (pure XAML).
- Master `DrawingContext`, invalidation (`AffectsRender`, `InvalidateVisual`), and caching for performance.
- Structure a restylable `TemplatedControl`, expose properties, and support theming/accessibility.

Why this matters
- Charts, gauges, and other visuals often need custom drawing. Understanding rendering and templating keeps your controls fast and customizable.
- Well-structured controls enable reuse and consistent theming.

Prerequisites
- Chapter 22 (rendering pipeline), Chapter 15 (accessibility), Chapter 16 (storage for exporting images if needed).

## 1. Choosing an approach

| Scenario | Draw (override `Render`) | Template (`ControlTemplate`) |
| --- | --- | --- |
| Pixel-perfect graphics, charts | [x] | |
| Animations driven by drawing primitives | [x] | |
| Standard widgets composed of existing controls | | [x] |
| Consumer needs to restyle via XAML | | [x] |
| Complex interaction per element (buttons in control) | | [x] |

Hybrid: templated control containing a custom-drawn child for performance-critical surface.

## 2. Invalidation basics

- `InvalidateVisual()` schedules redraw.
- Register property changes via `AffectsRender<TControl>(property1, ...)` in static constructor to auto-invalidate on property change.
- For layout changes, use `InvalidateMeasure` similarly (handled automatically for `StyledProperty`s registered with `AffectsMeasure`).

## 3. DrawingContext essentials

`DrawingContext` primitives:
- `DrawGeometry(brush, pen, geometry)`
- `DrawRectangle`/`DrawEllipse`
- `DrawImage(image, sourceRect, destRect)`
- `DrawText(formattedText, origin)`
- `PushClip`, `PushOpacity`, `PushOpacityMask`, `PushTransform` -- use in `using` blocks to auto-pop state.

Example pattern:

```csharp
public override void Render(DrawingContext ctx)
{
    base.Render(ctx);
    using (ctx.PushClip(new Rect(Bounds.Size)))
    {
        ctx.DrawRectangle(Brushes.Black, null, Bounds);
        ctx.DrawText(_formattedText, new Point(10, 10));
    }
}
```

## 4. Example: Sparkline (custom draw)

```csharp
public sealed class Sparkline : Control
{
    public static readonly StyledProperty<IReadOnlyList<double>?> ValuesProperty =
        AvaloniaProperty.Register<Sparkline, IReadOnlyList<double>?>(nameof(Values));

    public static readonly StyledProperty<IBrush> StrokeProperty =
        AvaloniaProperty.Register<Sparkline, IBrush>(nameof(Stroke), Brushes.DeepSkyBlue);

    public static readonly StyledProperty<double> StrokeThicknessProperty =
        AvaloniaProperty.Register<Sparkline, double>(nameof(StrokeThickness), 2.0);

    static Sparkline()
    {
        AffectsRender<Sparkline>(ValuesProperty, StrokeProperty, StrokeThicknessProperty);
    }

    public IReadOnlyList<double>? Values
    {
        get => GetValue(ValuesProperty);
        set => SetValue(ValuesProperty, value);
    }

    public IBrush Stroke
    {
        get => GetValue(StrokeProperty);
        set => SetValue(StrokeProperty, value);
    }

    public double StrokeThickness
    {
        get => GetValue(StrokeThicknessProperty);
        set => SetValue(StrokeThicknessProperty, value);
    }

    public override void Render(DrawingContext ctx)
    {
        base.Render(ctx);
        var values = Values;
        var bounds = Bounds;
        if (values is null || values.Count < 2 || bounds.Width <= 0 || bounds.Height <= 0)
            return;

        double min = values.Min();
        double max = values.Max();
        double range = Math.Max(1e-9, max - min);

        using var geometry = new StreamGeometry();
        using (var gctx = geometry.Open())
        {
            for (int i = 0; i < values.Count; i++)
            {
                double t = i / (double)(values.Count - 1);
                double x = bounds.X + t * bounds.Width;
                double yNorm = (values[i] - min) / range;
                double y = bounds.Y + (1 - yNorm) * bounds.Height;
                if (i == 0)
                    gctx.BeginFigure(new Point(x, y), isFilled: false);
                else
                    gctx.LineTo(new Point(x, y));
            }
            gctx.EndFigure(false);
        }

        var pen = new Pen(Stroke, StrokeThickness);
        ctx.DrawGeometry(null, pen, geometry);
    }
}
```

Usage:

```xml
<local:Sparkline Width="160" Height="36" Values="3,7,4,8,12" StrokeThickness="2"/>
```

### Performance tips
- Avoid allocations inside `Render`. Cache `Pen`, `FormattedText` when possible.
- Use `StreamGeometry` and reuse if values rarely change (rebuild when invalidated).

## 5. Templated control example: Badge

Create `Badge : TemplatedControl` with properties (`Content`, `Background`, `Foreground`, `CornerRadius`, `MaxWidth`, etc.). Default style in `Styles.axaml`:

```xml
<Style Selector="local|Badge">
  <Setter Property="Template">
    <ControlTemplate TargetType="local:Badge">
      <Border Background="{TemplateBinding Background}"
              CornerRadius="{TemplateBinding CornerRadius}"
              Padding="6,0"
              MinHeight="16" MinWidth="20"
              HorizontalAlignment="Left"
              VerticalAlignment="Top">
        <ContentPresenter Content="{TemplateBinding Content}"
                          HorizontalAlignment="Center"
                          VerticalAlignment="Center"
                          Foreground="{TemplateBinding Foreground}"/>
      </Border>
    </ControlTemplate>
  </Setter>
  <Setter Property="Background" Value="#E53935"/>
  <Setter Property="Foreground" Value="White"/>
  <Setter Property="CornerRadius" Value="8"/>
  <Setter Property="FontSize" Value="12"/>
  <Setter Property="HorizontalAlignment" Value="Left"/>
</Style>
```

Consumers can override the template for custom visuals without editing C#.

### Control class

```csharp
public sealed class Badge : TemplatedControl
{
    public static readonly StyledProperty<object?> ContentProperty =
        AvaloniaProperty.Register<Badge, object?>(nameof(Content));

    public object? Content
    {
        get => GetValue(ContentProperty);
        set => SetValue(ContentProperty, value);
    }
}
```

Additional properties (e.g., `CornerRadius`, `Background`) are inherited from `TemplatedControl` base properties or newly registered as needed.

## 6. Accessibility & input

- Set `Focusable` as appropriate; override `OnPointerPressed`/`OnKeyDown` for interaction.
- Expose automation metadata via `AutomationProperties.Name`, `HelpText`, or custom `AutomationPeer` for drawn controls.
- Implement `OnCreateAutomationPeer` when your control represents a unique semantic (`ProgressBadgeAutomationPeer`).

## 7. Measure/arrange

Custom controls should override `MeasureOverride`/`ArrangeOverride` when size depends on content/drawing.

```csharp
protected override Size MeasureOverride(Size availableSize)
{
    var values = Values;
    if (values is null || values.Count == 0)
        return Size.Empty;
    return new Size(Math.Min(availableSize.Width, 120), Math.Min(availableSize.Height, 36));
}
```

`TemplatedControl` handles measurement via its template (border + content). For custom-drawn controls, define desired size heuristics.

## 8. Rendering to bitmaps / exporting

Use `RenderTargetBitmap` for saving custom visuals:

```csharp
var rtb = new RenderTargetBitmap(new PixelSize(200, 100), new Vector(96, 96));
await rtb.RenderAsync(sparkline);
await using var stream = File.OpenWrite("spark.png");
await rtb.SaveAsync(stream);
```

Use `RenderOptions` to adjust interpolation for exported graphics if needed.

## 9. Combining drawing & template (hybrid)

Example: `ChartControl` template contains toolbar (Buttons, ComboBox) and a custom `ChartCanvas` child that handles drawing/selection.
- Template XAML composes layout.
- Drawn child handles heavy rendering & direct pointer handling.
- Chart exposes data/selection via view models.

## 10. Troubleshooting & best practices

- Flickering or wrong clip: ensure you clip to `Bounds` using `PushClip` when necessary.
- Aliasing issues: adjust `RenderOptions.SetEdgeMode` and align lines to device pixels (e.g., `Math.Round(x) + 0.5` for 1px strokes at 1.0 scale).
- Performance: profile by measuring allocations, consider caching `StreamGeometry`/`FormattedText`.
- Template issues: ensure template names line up with `TemplateBinding`; use DevTools -> `Style Inspector` to check which template applies.

## 11. Practice exercises

1. Build a `BarGauge` control: custom draw N vertical bars, exposing properties for values/brushes/thickness.
2. Create a `Badge` templated control with alternative styles (e.g., success/warning) using style classes.
3. Add an accessibility peer for `Sparkline` that reports summary (min/max/average) via `AutomationProperties.HelpText`.
4. Export your custom drawing to a PNG using `RenderTargetBitmap` and verify output at multiple DPI.

## Look under the hood (source bookmarks)
- Visual/render infrastructure: [`Visual.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Visual.cs)
- DrawingContext API: [`DrawingContext.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/DrawingContext.cs)
- StreamGeometry: [`StreamGeometryContextImpl`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/Geometry/StreamGeometryContextImpl.cs)
- Templated control base: [`TemplatedControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Primitives/TemplatedControl.cs)
- Control theme infrastructure: [`ControlTheme.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/ControlTheme.cs)
- Automation peers: [`ControlAutomationPeer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/Peers/ControlAutomationPeer.cs)

## Check yourself
- When do you override `Render` versus `ControlTemplate`?
- How does `AffectsRender` simplify invalidation?
- What caches can you introduce to prevent allocations in `Render`?
- How do you expose accessibility information for drawn controls?
- How can consumers restyle your templated control without touching C#?

What's next
- Next: [Chapter 24](Chapter24.md)
