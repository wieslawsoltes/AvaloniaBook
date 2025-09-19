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

## 4. Template lifecycle, presenters, and template results

- `TemplatedControl` raises `TemplateApplied` when the `ControlTemplate` is inflated. Override `OnApplyTemplate(TemplateAppliedEventArgs e)` to wire named parts via `e.NameScope`.
- Templates compiled from XAML return a `TemplateResult<Control>` behind the scenes (`ControlTemplate.Build`). It carries a `NameScope` so you can fetch presenters (`e.NameScope.Find<ContentPresenter>("PART_Content")`).
- Common presenters include `ContentPresenter`, `ItemsPresenter`, `ScrollContentPresenter`, and `ToggleSwitchPresenter`. They bridge templated surfaces with logical children (content, items, scrollable regions).
- Use `TemplateApplied` to subscribe to events on named parts, but always detach previous handlers before attaching new ones to prevent leaks.

Example:

```csharp
protected override void OnApplyTemplate(TemplateAppliedEventArgs e)
{
    base.OnApplyTemplate(e);
    _toggleRoot?.PointerPressed -= OnToggle;
    _toggleRoot = e.NameScope.Find<Border>("PART_ToggleRoot");
    _toggleRoot?.PointerPressed += OnToggle;
}
```

For library-ready controls publish a `ControlTheme` default template so consumers can restyle without copying large XAML fragments.

## 5. Example: Sparkline (custom draw)

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

## 6. Templated control example: Badge

Create `Badge : TemplatedControl` with properties (`Content`, `Background`, `Foreground`, `CornerRadius`, `MaxWidth`, etc.). Default style in `Styles.axaml`:

```xml
<ControlTheme TargetType="local:Badge">
  <Setter Property="Template">
    <ControlTemplate TargetType="local:Badge">
      <Border x:Name="PART_Border"
              Background="{TemplateBinding Background}"
              CornerRadius="{TemplateBinding CornerRadius}"
              Padding="6,0"
              MinHeight="16" MinWidth="20"
              HorizontalAlignment="Left"
              VerticalAlignment="Top">
        <ContentPresenter x:Name="PART_Content"
                          Content="{TemplateBinding Content}"
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
</ControlTheme>
```

In code, capture named parts once the template applies:

```csharp
public sealed class Badge : TemplatedControl
{
    public static readonly StyledProperty<object?> ContentProperty =
        AvaloniaProperty.Register<Badge, object?>(nameof(Content));

    Border? _border;

    public object? Content
    {
        get => GetValue(ContentProperty);
        set => SetValue(ContentProperty, value);
    }

    protected override void OnApplyTemplate(TemplateAppliedEventArgs e)
    {
        base.OnApplyTemplate(e);
        _border = e.NameScope.Find<Border>("PART_Border");
    }
}
```

Expose additional state through `StyledProperty`s so themes and animations can target them.

## 7. Visual states and control themes

- Use `PseudoClasses` (e.g., `PseudoClasses.Set(":badge-has-content", true)`) to signal template states that styles can observe.
- Combine `PseudoClasses` with `Transitions` or `Animations` to create hover/pressed effects without rewriting templates.
- Ship alternate appearances via additional `ControlTheme` resources referencing the same `TemplatedControl` type.
- For re-usable primitive parts, create internal `Visual` subclasses (e.g., `BadgeGlyph`) and expose them as named template parts.

## 8. Accessibility & input

- Set `Focusable` as appropriate; override `OnPointerPressed`/`OnKeyDown` for interaction or to update pseudo classes.
- Expose automation metadata via `AutomationProperties.Name`, `HelpText`, or custom `AutomationPeer` for drawn controls.
- Override `OnCreateAutomationPeer` when your control represents a unique semantic (`BadgeAutomationPeer` describing count, severity).

## 9. Measure/arrange

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

## 10. Rendering to bitmaps / exporting

Use `RenderTargetBitmap` for saving custom visuals:

```csharp
var rtb = new RenderTargetBitmap(new PixelSize(200, 100), new Vector(96, 96));
await rtb.RenderAsync(sparkline);
await using var stream = File.OpenWrite("spark.png");
await rtb.SaveAsync(stream);
```

Use `RenderOptions` to adjust interpolation for exported graphics if needed.

## 11. Combining drawing & template (hybrid)

Example: `ChartControl` template contains toolbar (Buttons, ComboBox) and a custom `ChartCanvas` child that handles drawing/selection.
- Template XAML composes layout.
- Drawn child handles heavy rendering & direct pointer handling.
- Chart exposes data/selection via view models.

## 12. Troubleshooting & best practices

- Flickering or wrong clip: ensure you clip to `Bounds` using `PushClip` when necessary.
- Aliasing issues: adjust `RenderOptions.SetEdgeMode` and align lines to device pixels (e.g., `Math.Round(x) + 0.5` for 1px strokes at 1.0 scale).
- Performance: profile by measuring allocations, consider caching `StreamGeometry`/`FormattedText`.
- Template issues: ensure template names line up with `TemplateBinding`; use DevTools -> `Style Inspector` to check which template applies.

## 13. Practice exercises

1. Build a templated notification badge that swaps between "pill" and "dot" visuals by toggling `PseudoClasses` within `OnApplyTemplate`.
2. Embed a custom drawn sparkline into that badge (composed via `RenderTargetBitmap` or direct drawing) and expose it as a named part in the template.
3. Implement `OnCreateAutomationPeer` so assistive tech can report badge count and severity; verify with the accessibility tree in DevTools.
4. Use DevTools `Logical Tree` to confirm your presenter hierarchy (content vs drawn part) matches expectations and retains bindings when themes change.

## Look under the hood (source bookmarks)
- Visual/render infrastructure: [`Visual.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Visual.cs)
- DrawingContext API: [`DrawingContext.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/DrawingContext.cs)
- StreamGeometry: [`StreamGeometryContextImpl`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/Geometry/StreamGeometryContextImpl.cs)
- Template loading: [`ControlTemplate.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml/Templates/ControlTemplate.cs)
- Template applied hook: [`TemplateAppliedEventArgs.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Primitives/TemplateAppliedEventArgs.cs)
- Name scopes: [`NameScope.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/NameScope.cs)
- Templated control base: [`TemplatedControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Primitives/TemplatedControl.cs)
- Control theme infrastructure: [`ControlTheme.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/ControlTheme.cs)
- Pseudo classes: [`StyledElement.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/StyledElement.cs)
- Automation peers: [`ControlAutomationPeer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/Peers/ControlAutomationPeer.cs)

## Check yourself
- When do you override `Render` versus `ControlTemplate`?
- How does `AffectsRender` simplify invalidation?
- What caches can you introduce to prevent allocations in `Render`?
- How do you expose accessibility information for drawn controls?
- How can consumers restyle your templated control without touching C#?

What's next
- Next: [Chapter 24](Chapter24.md)
