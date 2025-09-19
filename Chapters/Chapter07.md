# 7. Fluent theming and styles made simple

Goal
- Understand Avalonia's Fluent theme architecture, theme variants, and how theme resources flow through your app.
- Organise resources and styles with `ResourceInclude`, `StyleInclude`, `ThemeVariantScope`, and `ControlTheme` for clean reuse.
- Override control templates, use pseudo-classes, and scope theme changes to specific regions.
- Support runtime theme switching (light/dark/high contrast) and accessibility requirements.
- Map the styles you edit to the Fluent source files so you can explore defaults and extend them safely.

Why this matters
- Styling controls consistently is the difference between a polished UI and visual chaos.
- Avalonia's Fluent theme ships with rich resources; knowing how to extend them keeps your design system maintainable.
- Accessibility requirements (contrast, theming per surface) are easier when you understand theme scoping and dynamic resources.

Prerequisites
- Comfort editing `App.axaml`, windows, and user controls (Chapters 3-6).
- Basic understanding of data binding and commands (Chapters 3, 6).

## 1. Fluent theme in a nutshell

Avalonia ships with Fluent 2 based resources and templates. The theme lives under [`src/Avalonia.Themes.Fluent`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent). Templates reference resource keys (brushes, thicknesses, typography) that resolve per theme variant.

`App.axaml` typically looks like this:

```xml
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="ThemePlayground.App"
             RequestedThemeVariant="Light">
  <Application.Styles>
    <FluentTheme Mode="Light"/>
  </Application.Styles>
</Application>
```

- `RequestedThemeVariant` controls the global variant (`ThemeVariant.Light`, `ThemeVariant.Dark`, `ThemeVariant.HighContrast`).
- `FluentTheme` can be configured with `Mode="Light"`, `Mode="Dark"`, or `Mode="Default"` (auto based on OS hints). Source: [`FluentTheme.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Themes.Fluent/FluentTheme.cs).

## 2. Structure resources into dictionaries

Split large resource sets into dedicated files. Create `Styles/Colors.axaml`:

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui">
  <Color x:Key="BrandPrimaryColor">#2563EB</Color>
  <Color x:Key="BrandPrimaryHover">#1D4ED8</Color>

  <SolidColorBrush x:Key="BrandPrimaryBrush"
                   Color="{DynamicResource BrandPrimaryColor}"/>
  <SolidColorBrush x:Key="BrandPrimaryHoverBrush"
                   Color="{DynamicResource BrandPrimaryHover}"/>
</ResourceDictionary>
```

Then create `Styles/Controls.axaml`:

```xml
<Styles xmlns="https://github.com/avaloniaui">
  <Style Selector="Button.primary">
    <Setter Property="Background" Value="{DynamicResource BrandPrimaryBrush}"/>
    <Setter Property="Foreground" Value="White"/>
    <Setter Property="Padding" Value="14,10"/>
    <Setter Property="CornerRadius" Value="6"/>
  </Style>

  <Style Selector="Button.primary:pointerover">
    <Setter Property="Background" Value="{DynamicResource BrandPrimaryHoverBrush}"/>
  </Style>
</Styles>
```

Include them in `App.axaml`:

```xml
<Application ...>
  <Application.Resources>
    <ResourceInclude Source="avares://ThemePlayground/Styles/Colors.axaml"/>
  </Application.Resources>
  <Application.Styles>
    <FluentTheme Mode="Default"/>
    <StyleInclude Source="avares://ThemePlayground/Styles/Controls.axaml"/>
  </Application.Styles>
</Application>
```

- `ResourceInclude` expects a `ResourceDictionary` root and merges it into the resource lookup chain. Use it for brushes, colors, converters, and typography resources.
- `StyleInclude` expects `Styles` (or a single `Style`) and registers selectors. Use `avares://Assembly/Path.axaml` URIs to include styles from other assemblies (for example, `avares://Avalonia.Themes.Fluent/Controls/Button.xaml`).
- When you rename assemblies or move resource files, update the `Source` URI; missing includes surface as `XamlLoadException` during startup.

## 3. Static vs dynamic resources

- `StaticResource` resolves once during load. Use it for values that never change (fonts, corner radius constants).
- `DynamicResource` re-evaluates when the resource is replaced at runtime--essential for theme switching.

```xml
<Border CornerRadius="{StaticResource CornerRadiusMedium}"
        Background="{DynamicResource BrandPrimaryBrush}"/>
```

Resource lookup order:
1. Control-local resources (`this.Resources`).
2. Logical tree parents (user controls, windows).
3. `Application.Resources`.
4. Theme dictionaries merged by `FluentTheme` (light/dark/high contrast).
5. System theme fallbacks.

The implementation lives in [`ResourceDictionary.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Resources/ResourceDictionary.cs). DevTools -> Resources panel shows the chain and which dictionary satisfied a lookup.

## 4. Theme variant scope (local theming)
## 5. Migrating and overriding Fluent resources

When you need to change Fluent defaults globally (for example, switch accent colors or typography), supply variant-specific dictionaries. Place these under `Application.Resources` with a `ThemeVariant` attribute so they override the theme-provided value only for matching variants.

```xml
<Application.Resources>
  <ResourceInclude Source="avares://ThemePlayground/Styles/Colors.axaml"/>
  <ResourceDictionary ThemeVariant="Light">
    <SolidColorBrush x:Key="SystemAccentColor" Color="#2563EB"/>
  </ResourceDictionary>
  <ResourceDictionary ThemeVariant="Dark">
    <SolidColorBrush x:Key="SystemAccentColor" Color="#60A5FA"/>
  </ResourceDictionary>
</Application.Resources>
```

- Keys that match Fluent resources (`SystemAccentColor`, `SystemControlBackgroundBaseLowBrush`, etc.) override the defaults only for the specified variant.
- Keep overrides minimal: inspect the Fluent source to copy exact keys. Replace `FluentTheme` with `SimpleTheme` if you want the simple default look.
- To migrate an existing design system, split colors/typography into `ResourceDictionary` files and create `ControlTheme` overrides for specific controls rather than editing Fluent templates in place.


`ThemeVariantScope` lets you apply a specific theme to part of the UI. Implementation: [`ThemeVariantScope.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ThemeVariantScope.cs).

```xml
<ThemeVariantScope RequestedThemeVariant="Dark">
  <Border Padding="16">
    <StackPanel>
      <TextBlock Classes="h2" Text="Dark section"/>
      <Button Content="Dark themed button" Classes="primary"/>
    </StackPanel>
  </Border>
</ThemeVariantScope>
```

Everything inside the scope resolves resources as if the app were using `ThemeVariant.Dark`. Useful for popovers or modal sheets.

## 6. Runtime theme switching

Add a toggle to your main view:

```xml
<ToggleSwitch Content="Dark mode" IsChecked="{Binding IsDark}"/>
```

In the view model:

```csharp
using Avalonia;
using Avalonia.Styling;

public sealed class ShellViewModel : ObservableObject
{
    private bool _isDark;
    public bool IsDark
    {
        get => _isDark;
        set
        {
            if (SetProperty(ref _isDark, value))
            {
                Application.Current!.RequestedThemeVariant = value ? ThemeVariant.Dark : ThemeVariant.Light;
            }
        }
    }
}
```

Because button styles use `DynamicResource`, they respond immediately. For per-window overrides set `RequestedThemeVariant` on the window itself or wrap content in `ThemeVariantScope`.

## 7. Customizing control templates with `ControlTheme`

`ControlTheme` lets you replace a control's default template and resources without subclassing. Source: [`ControlTheme.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/ControlTheme.cs).

Example: create a pill-shaped toggle button theme in `Styles/ToggleButton.axaml`:

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    xmlns:themes="clr-namespace:Avalonia.Themes.Fluent;assembly=Avalonia.Themes.Fluent">
  <ControlTheme x:Key="PillToggleTheme" TargetType="ToggleButton">
    <Setter Property="Template">
      <ControlTemplate>
        <Border x:Name="PART_Root"
                Background="{TemplateBinding Background}"
                CornerRadius="20"
                Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center"
                            VerticalAlignment="Center"
                            Content="{TemplateBinding Content}"/>
        </Border>
      </ControlTemplate>
    </Setter>
  </ControlTheme>
</ResourceDictionary>
```

Apply it:

```xml
<ToggleButton Content="Pill" Theme="{StaticResource PillToggleTheme}" padding="12,6"/>
```

To inherit Fluent visual states, you can base your theme on existing resources by referencing `themes:ToggleButtonTheme`. Inspect templates in [`src/Avalonia.Themes.Fluent/Controls`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent/Controls) for structure and named parts.

## 8. Working with pseudo-classes and classes

Use pseudo-classes to target interaction states. Example for `ToggleSwitch`:

```xml
<Style Selector="ToggleSwitch:checked">
  <Setter Property="ThumbBrush" Value="{DynamicResource BrandPrimaryBrush}"/>
</Style>

<Style Selector="ToggleSwitch:checked:focus">
  <Setter Property="BorderBrush" Value="{DynamicResource BrandPrimaryHoverBrush}"/>
</Style>
```

| Pseudo-class | Applies when |
| --- | --- |
| `:pointerover` | Pointer hovers over the control |
| `:pressed` | Pointer is pressed / command triggered |
| `:checked` | Toggleable control is on (`CheckBox`, `ToggleSwitch`, `RadioButton`) |
| `:focus` / `:focus-within` | Control (or a descendant) has keyboard focus |
| `:disabled` | `IsEnabled = false` |
| `:invalid` | A binding reports validation errors |

Pseudo-class documentation lives in [`Selectors.md`](https://github.com/AvaloniaUI/Avalonia/blob/master/docs/styles/selectors.md) and runtime code under [`Selector.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Styling/Selector.cs). Combine pseudo-classes with style classes (e.g., `Button.primary:pointerover`) to keep state-specific visuals consistent and accessible.

## 9. Accessibility and high contrast themes

Fluent ships high contrast resources. Switch by setting `RequestedThemeVariant="HighContrast"`.

- Provide alternative color dictionaries with increased contrast ratios.
- Use `DynamicResource` for all brushes so high contrast palettes propagate automatically.
- Test with screen readers and OS high contrast modes; ensure custom colors respect `ThemeVariant.HighContrast`.

Example dictionary addition:

```xml
<ResourceDictionary ThemeVariant="HighContrast"
                    xmlns="https://github.com/avaloniaui">
  <SolidColorBrush x:Key="BrandPrimaryBrush" Color="#00AACC"/>
  <SolidColorBrush x:Key="BrandPrimaryHoverBrush" Color="#007C99"/>
</ResourceDictionary>
```

`ThemeVariant`-specific dictionaries override defaults when the variant matches.

## 10. Debugging styles with DevTools

Press **F12** to open DevTools -> Styles panel:
- Inspect applied styles, pseudo-classes, and resources.
- Use the palette to modify brushes live and copy the generated XAML.
- Toggle the `ThemeVariant` dropdown in DevTools (bottom) to preview Light/Dark/HighContrast variants.

Enable style diagnostics via logging:

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .LogToTrace(LogEventLevel.Debug, new[] { LogArea.Binding, LogArea.Styling })
    .StartWithClassicDesktopLifetime(args);
```

## 11. Practice exercises

1. **Create a brand palette**: define primary and secondary brushes with theme-specific overrides (light/dark/high contrast) and apply them to buttons and toggles.
2. **Scope a sub-view**: wrap a settings pane in `ThemeVariantScope RequestedThemeVariant="Dark"` to preview dual-theme experiences.
3. **Control template override**: create a `ControlTheme` for `Button` that changes the visual tree (e.g., adds an icon placeholder) and apply it selectively.
4. **Runtime theme switching**: wire a `ToggleSwitch` or menu command to flip between Light/Dark; ensure all custom brushes use `DynamicResource`.
5. **DevTools audit**: use DevTools to inspect pseudo-classes on a `ToggleSwitch` and verify your custom styles apply in `:checked` and `:focus` states.

## Look under the hood (source bookmarks)
- Theme variant scoping: [`ThemeVariantScope.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ThemeVariantScope.cs)
- Control themes and styles: [`ControlTheme.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/ControlTheme.cs), [`Style.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Styling/Style.cs)
- Selector engine & pseudo-classes: [`Selector.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Styling/Selector.cs)
- Fluent resources and templates: [`src/Avalonia.Themes.Fluent/Controls`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent/Controls)
- Theme variant definitions: [`ThemeVariant.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Styling/ThemeVariant.cs)

## Check yourself
- How do `ResourceInclude` and `StyleInclude` differ, and what root elements do they expect?
- When should you use `ThemeVariantScope` versus changing `RequestedThemeVariant` on the application?
- What advantages does `ControlTheme` give over subclassing a control?
- Why do you prefer `DynamicResource` for brushes that change with theme switches?
- Where would you inspect the default template for `ToggleSwitch` or `ComboBox`?

What's next
- Next: [Chapter 8](Chapter08.md)
