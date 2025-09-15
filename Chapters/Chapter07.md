# 7. Fluent theming and styles made simple

Goal
- Understand Avalonia’s Fluent theme, light/dark variants, resources, and styles.
- Learn how to create global and local styles, use StaticResource vs DynamicResource, and switch themes at runtime.

What you’ll build
- A small app that:
  - Uses Fluent theme.
  - Defines shared colors/brushes in resources.
  - Styles buttons globally and locally (implicit and keyed styles).
  - Adds a simple theme switch (Light/Dark) at runtime.

Prerequisites
- You can run a basic Avalonia app (Ch. 2–4).
- You are comfortable editing App.axaml and a Window/UserControl (Ch. 3–6).

1) Meet FluentTheme and theme variants
- Avalonia ships with FluentTheme. Add it to App.axaml if your template didn’t already:

```xml
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="MyApp.App"
             RequestedThemeVariant="Light">
  <Application.Styles>
    <FluentTheme />
  </Application.Styles>
</Application>
```
- RequestedThemeVariant can be Light or Dark on Application, a Window, or any ThemeVariantScope. Start with Light.
- FluentTheme picks resources (brushes, etc.) appropriate for the active theme variant.

2) Resources: colors, brushes, and where to put them
- Resources are key/value objects you can reference from XAML. Put app‑wide resources in App.axaml:

```xml
<Application ...>
  <Application.Resources>
    <SolidColorBrush x:Key="AccentBrush" Color="#2563EB"/>
    <SolidColorBrush x:Key="AccentBrushHover" Color="#1D4ED8"/>
    <Thickness x:Key="ControlCornerRadius">6</Thickness>
  </Application.Resources>
  <Application.Styles>
    <FluentTheme />
  </Application.Styles>
</Application>
```
- Referencing resources:
  - StaticResource resolves once at load time (faster): Background="{StaticResource AccentBrush}"
  - DynamicResource updates if the resource changes at runtime: Background="{DynamicResource AccentBrush}"
- Resource lookup walks upward: control → parent → Window → Application. App resources are global.

3) Global styles (implicit) vs local styles (keyed)
- A style sets properties for a target control. Put global styles in Application.Styles:

```xml
<Application.Styles>
  <FluentTheme />
  <!-- Implicit (applies to all Buttons) -->
  <Style Selector="Button">
    <Setter Property="CornerRadius" Value="{StaticResource ControlCornerRadius}"/>
    <Setter Property="Padding" Value="12,8"/>
  </Style>

  <!-- Hover visual (pseudo-class) -->
  <Style Selector="Button:pointerover">
    <Setter Property="Background" Value="{DynamicResource AccentBrushHover}"/>
  </Style>
</Application.Styles>
```
- A local, keyed style only applies when you opt in:

```xml
<StackPanel>
  <StackPanel.Resources>
    <Style x:Key="PrimaryButtonStyle" Selector="Button">
      <Setter Property="Background" Value="{DynamicResource AccentBrush}"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
  </StackPanel.Resources>

  <Button Content="OK" Classes="primary" Style="{StaticResource PrimaryButtonStyle}"/>
  <Button Content="Cancel"/>
</StackPanel>
```
- Tip: You can combine implicit styles (for consistent baselines) with keyed styles (for special cases).

4) Selectors and pseudo-classes you’ll actually use
- Selector="Button" targets all Buttons.
- You can target by name (#[Name]), class (.danger), and state pseudo‑classes like :pointerover, :pressed, :disabled, :focus.
- Example:

```xml
<Application.Styles>
  <Style Selector="Button.danger">
    <Setter Property="Background" Value="#B91C1C"/>
  </Style>
  <Style Selector="Button.danger:pointerover">
    <Setter Property="Background" Value="#991B1B"/>
  </Style>
</Application.Styles>
```

5) Switching Light/Dark at runtime
- You can switch theme variants in code behind. For example, add a ToggleSwitch to your MainView and handle its change:

```xml
<ToggleSwitch x:Name="ThemeSwitch" Content="Dark mode"/>
```

```csharp
using Avalonia;
using Avalonia.Styling; // ThemeVariant

private void ThemeSwitch_PropertyChanged(object? sender, AvaloniaPropertyChangedEventArgs e)
{
    if (e.Property == ToggleSwitch.IsCheckedProperty)
    {
        var dark = ThemeSwitch.IsChecked == true;
        Application.Current!.RequestedThemeVariant = dark ? ThemeVariant.Dark : ThemeVariant.Light;
    }
}
```
- Hook this handler once in your view’s constructor (after InitializeComponent) and subscribe to ThemeSwitch.PropertyChanged.
- Because you used DynamicResource for color brushes, your UI reacts to theme‑driven resource changes automatically.
- Scope theme changes: set RequestedThemeVariant on a specific Window or container (ThemeVariantScope) to localize the effect.

6) Organizing styles and resources into files
- Keep App.axaml readable by moving big sections into separate XAML files and merge them:

```xml
<Application ...>
  <Application.Resources>
    <ResourceInclude Source="avares://MyApp/Styles/Colors.axaml"/>
  </Application.Resources>
  <Application.Styles>
    <FluentTheme />
    <StyleInclude Source="avares://MyApp/Styles/Controls.axaml"/>
  </Application.Styles>
</Application>
```
- Use ResourceInclude for resources and StyleInclude for styles. Each file should have a root ResourceDictionary or Styles element accordingly.

7) StaticResource vs DynamicResource in practice
- Use StaticResource for values that won’t change (e.g., Thickness, FontSize constants).
- Use DynamicResource when the value should update at runtime (e.g., theme‑dependent brushes, app accent color).

Check yourself
- Can you explain the difference between implicit and keyed styles?
- Where does Avalonia look for resources when resolving a key?
- Which binding updates at runtime: StaticResource or DynamicResource?
- How do you switch theme variant from code?

Look under the hood (repo reading list)
- Styles and selectors: src/Avalonia.Styling
- FluentTheme implementation and resources: src/Avalonia.Themes.Fluent
- ThemeVariant enum and theme scoping: src/Avalonia.Styling

Extra practice
- Create a secondary accent (e.g., SuccessBrush) and use it for positive actions.
- Add a named class (e.g., .danger) and adjust background/foreground/hover/pressed styles.
- Split your styles/resources into separate axaml files and include them from App.axaml.
- Try setting RequestedThemeVariant on just one panel to create a light “sheet” in a dark window.

What’s next
- Next: [Chapter 8](Chapter08.md)
