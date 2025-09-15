# 23. Custom drawing and custom controls

In this chapter you’ll learn when to draw by hand and when to build a templated control, what the DrawingContext can do, how invalidation works, and how to structure a simple custom control that is easy to style and fast to render.

What you’ll build
- A minimal custom‑drawn control that renders a sparkline from numbers
- A templated Badge control that can be restyled in XAML without code changes

When should you draw vs template?
- Custom drawing (override Render) is great when:
  - You need pixel‑level control (charts/graphs/special effects)
  - You want maximum performance and minimum visual tree overhead
  - The visuals don’t need to be deeply interactive or individually templated
- Templated control (XAML ControlTemplate) is great when:
  - You want consumers to restyle with pure XAML
  - The control is composed from existing primitives (Border, Grid, Path, TextBlock)
  - You prefer layout flexibility over raw drawing performance

Your rendering hook: override Render
- Every Visual has a virtual Render(DrawingContext) you can override to draw.
- Call InvalidateVisual() whenever something changes that affects the output so the renderer repaints.
- For properties that affect rendering, register AffectsRender in the static constructor so changes auto‑invalidate.

DrawingContext in 5 minutes
- Primitives you’ll use most:
  - DrawGeometry(brush, pen, geometry) — fill/stroke arbitrary shapes (use StreamGeometry to build paths)
  - DrawImage(image, sourceRect, destRect) — draw bitmaps or render targets
  - DrawText(formattedText, origin) — draw measured text
- State stack (always use using):
  - PushClip(Rect or RoundedRect)
  - PushOpacity(value[, bounds]) and PushOpacityMask(brush, bounds)
  - PushTransform(Matrix)
  These return a disposable “pushed state”; dispose in reverse order (the using pattern makes this automatic).

Minimal custom‑drawn control: Sparkline
Goal: render a small polyline from a sequence of doubles.

Steps
1) Create a class Sparkline : Control with a Numbers property and a Stroke property.
2) In the static ctor, call AffectsRender<Sparkline>(NumbersProperty, StrokeProperty) so changes trigger redraw.
3) Override Render and draw using StreamGeometry + DrawGeometry.

Example (C#)

```csharp
public class Sparkline : Control
{
    public static readonly StyledProperty<IReadOnlyList<double>?> NumbersProperty =
        AvaloniaProperty.Register<Sparkline, IReadOnlyList<double>?>(nameof(Numbers));

    public static readonly StyledProperty<IBrush?> StrokeProperty =
        AvaloniaProperty.Register<Sparkline, IBrush?>(nameof(Stroke), Brushes.CornflowerBlue);

    static Sparkline()
    {
        AffectsRender<Sparkline>(NumbersProperty, StrokeProperty);
    }

    public IReadOnlyList<double>? Numbers
    {
        get => GetValue(NumbersProperty);
        set => SetValue(NumbersProperty, value);
    }

    public IBrush? Stroke
    {
        get => GetValue(StrokeProperty);
        set => SetValue(StrokeProperty, value);
    }

    public override void Render(DrawingContext ctx)
    {
        base.Render(ctx);
        var data = Numbers;
        if (data is null || data.Count < 2)
            return;

        var bounds = Bounds;
        if (bounds.Width <= 0 || bounds.Height <= 0)
            return;

        // Normalize values into [0..1]
        double min = data.Min();
        double max = data.Max();
        double range = Math.Max(1e-9, max - min);

        using var geo = new StreamGeometry();
        using (var gctx = geo.Open())
        {
            for (int i = 0; i < data.Count; i++)
            {
                double t = (double)i / (data.Count - 1);
                double x = bounds.X + t * bounds.Width;
                double yNorm = (data[i] - min) / range;
                double y = bounds.Y + (1 - yNorm) * bounds.Height;
                if (i == 0)
                    gctx.BeginFigure(new Point(x, y), isFilled: false);
                else
                    gctx.LineTo(new Point(x, y));
            }
            gctx.EndFigure(isClosed: false);
        }

        var pen = new Pen(Stroke, thickness: 1.5);
        ctx.DrawGeometry(null, pen, geo);
    }
}
```

Usage (XAML)

```xml
<local:Sparkline Width="120" Height="24"
                Stroke="DeepSkyBlue"
                Numbers="3,5,4,6,9,8,12,7,6"/>
```

Notes and tips
- Do not allocate in Render if you can avoid it. Cache immutable pens/brushes if they depend on rarely changing properties.
- Use AffectsRender to auto‑invalidate on property changes, and call InvalidateVisual() for imperative invalidation.
- Use PushClip for rounded corners or to avoid overdrawing outside Bounds.
- Measure/arrange still apply. Your control’s layout is separate from drawing; override MeasureOverride/ArrangeOverride for custom sizing behavior.

Templated control: Badge
Goal: a restylable badge that supports content and themeable colors.

Steps
1) Create Badge : TemplatedControl with StyledProperties: Content, Background, Foreground, CornerRadius.
2) Provide a default theme style with ControlTemplate composed from Border + ContentPresenter.
3) Consumers can restyle by replacing the template in XAML without touching your C#.

Example default style (XAML)

```xml
<Style Selector="local|Badge">
  <Setter Property="Template">
    <ControlTemplate TargetType="local:Badge">
      <Border Background="{TemplateBinding Background}"
              CornerRadius="{TemplateBinding CornerRadius}"
              Padding="4,0"
              MinWidth="16" Height="16"
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
  <Setter Property="FontSize" Value="11"/>
</Style>
```

When to pick which approach
- Pick drawing (override Render) when visuals are algorithmic or heavy and don’t need nested controls.
- Pick templating when the control is a composition of existing elements and must be easily restyled.
- You can combine both: a templated control that contains a light custom‑drawn child for a specific part.

Invalidation that “just works”
- AffectsRender ties StyledProperty changes to InvalidateVisual. Put it in your static ctor.
- For dependent caches (e.g., a geometry built from multiple properties), rebuild lazily on next Render after invalidation.

Text and images
- DrawText: format once, reuse many times. For dynamic text, rebuild only on changes.
- DrawImage: prefer the overload with source/dest rectangles for atlases; set RenderOptions.BitmapInterpolationMode as needed per visual.

Accessibility and input
- If your control is purely drawn, make sure it’s focusable when needed and expose AutomationProperties.Name/HelpText.
- For hit testing (e.g., series selection in a chart), map pointer positions into your geometry space and handle PointerPressed/Released.

Troubleshooting
- Nothing draws: ensure your control has non‑zero size and your Render override actually draws inside Bounds.
- Flicker or jank: avoid per‑frame allocations; cache pens/brushes/geometries; prefer using statements for Push* calls.
- Blurry output: check transforms and DPI scaling; for fine lines, align to device pixels when needed.

Look under the hood (source links)
- Visual.Render and invalidation: [Avalonia.Base/Visual.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Visual.cs)
- DrawingContext API: [Avalonia.Base/Media/DrawingContext.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/DrawingContext.cs)
- IDrawingContextImpl (platform bridge): [Avalonia.Base/Platform/IDrawingContextImpl.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/IDrawingContextImpl.cs)
- Skia DrawingContext implementation: [Skia/Avalonia.Skia/DrawingContextImpl.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Skia/Avalonia.Skia/DrawingContextImpl.cs)

Practice
- Implement a simple BarGauge control that draws N vertical bars from an array of values with colors derived from thresholds. Add a Templated header above it. Ensure value and color property changes trigger redraw using AffectsRender.

What’s next
- Next: [Chapter 24](Chapter24.md)
