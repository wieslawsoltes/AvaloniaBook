# 25. Design-time tooling and the XAML Previewer

Goal
- Use Avalonia's XAML Previewer (designer) effectively in VS, Rider, and VS Code.
- Feed realistic sample data and preview styles/resources without running your full backend.
- Understand design mode plumbing, avoid previewer crashes, and sharpen your design workflow.

Why this matters
- Fast iteration on UI keeps you productive. The previewer drastically reduces build/run cycles if you set it up correctly.
- Design-time data prevents "black boxes" in the previewer and reveals layout problems early.

Prerequisites
- Familiarity with XAML bindings (Chapter 8) and templates (Chapter 23).

## 1. How the previewer works

IDE hosts spawn a preview process that loads your view or resource dictionary. Avalonia signals design mode via `Design.IsDesignMode` and applies design-time properties (`Design.*`).

Key components (see [`Design.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Design.cs)):
- `Design.IsDesignMode`: true inside previewer; branch code to avoid real services.
- `Design.DataContext`, `Design.Width/Height`, `Design.DesignStyle`, `Design.PreviewWith`: attached properties injected at design time and removed from runtime.
- XAML transformer (`AvaloniaXamlIlDesignPropertiesTransformer`) strips `Design.*` in compiled output.

## 2. Design-time DataContext & sample data

Provide lightweight POCOs or design view models for preview.

Sample POCO:

```csharp
namespace MyApp.Design;

public sealed class SamplePerson
{
    public string Name { get; set; } = "Ada Lovelace";
    public string Email { get; set; } = "ada@example.com";
    public int Age { get; set; } = 37;
}
```

Usage in XAML:

```xml
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:design="clr-namespace:Avalonia.Controls;assembly=Avalonia.Controls"
             xmlns:samples="clr-namespace:MyApp.Design" x:Class="MyApp.Views.ProfileView">
  <design:Design.DataContext>
    <samples:SamplePerson/>
  </design:Design.DataContext>

  <StackPanel Spacing="12" Margin="16">
    <TextBlock Classes="h1" Text="{Binding Name}"/>
    <TextBlock Text="{Binding Email}"/>
    <TextBlock Text="Age: {Binding Age}"/>
  </StackPanel>
</UserControl>
```

At runtime the transformer removes `Design.DataContext`; real view models take over. For complex forms, expose design view models with stub services but avoid heavy logic.

### Design.IsDesignMode checks

Guard expensive operations:

```csharp
if (Design.IsDesignMode)
    return; // skip service setup, timers, network
```

Place guards in view constructors, `OnApplyTemplate`, or view model initialization.

## 3. Design.Width/Height & DesignStyle

Set design canvas size:

```xml
<StackPanel design:Design.Width="320"
            design:Design.Height="480"
            design:Design.DesignStyle="{StaticResource DesignOutlineStyle}">

</StackPanel>
```

`DesignStyle` can add dashed borders or backgrounds for preview only (define style in resources).

Example design style:

```xml
<Style x:Key="DesignOutlineStyle">
  <Setter Property="Border.BorderThickness" Value="1"/>
  <Setter Property="Border.BorderBrush" Value="#808080"/>
</Style>
```

## 4. Preview resource dictionaries with Design.PreviewWith

Previewing a dictionary or style requires a host control:

```xml
<ResourceDictionary xmlns="https://github.com/avaloniaui"
                    xmlns:design="clr-namespace:Avalonia.Controls;assembly=Avalonia.Controls"
                    xmlns:views="clr-namespace:MyApp.Views">
  <design:Design.PreviewWith>
    <Border Padding="16" Background="#1f2937">
      <StackPanel Spacing="8">
        <views:Badge Content="1" Classes="success"/>
        <views:Badge Content="Warning" Classes="warning"/>
      </StackPanel>
    </Border>
  </design:Design.PreviewWith>


</ResourceDictionary>
```

`PreviewWith` ensures the previewer renders the host when you open the dictionary alone.

## 5. IDE-specific tips

### Visual Studio
- Ensure "Avalonia Previewer" extension is installed.
- F12 toggles DevTools; `Alt+Space` opens previewer hotkeys.
- If previewer doesn't refresh, rebuild project; VS sometimes caches the design assembly.

### Rider
- Avalonia plugin required; previewer window shows automatically when editing XAML.
- Use the data context drop-down to quickly switch between sample contexts if multiple available.

### VS Code
- Avalonia `.vsix` extension supports previewer with dotnet CLI
driven host. Ensure `dotnet workload install wasm-tools` (previewer uses WASM).

General
- Keep constructors light; heavy constructors crash previewer.
- Use `Design.DataContext` to avoid hitting DI container or real services.
- Split complex layouts into smaller user controls and preview them individually.

## 6. Troubleshooting & best practices

| Issue | Fix |
| --- | --- |
| Previewer blank/crashes | Guard code with `Design.IsDesignMode`; simplify layout; ensure no blocking calls in constructor |
| Design-only styles appear at runtime | Remember `Design.*` stripped at runtime; if you see them, check build output or ensure property wired correctly |
| Resource dictionary preview fails | Add `Design.PreviewWith`; ensure resources compiled (check `AvaloniaResource` includes) |
| Sample data not showing | Confirm namespace mapping correct and sample object constructs without exceptions |
| Slow preview | Remove animations/effects temporarily; large data sets or virtualization can slow preview host |

## 7. Automation

- Document designer defaults using `README` for your UI project. Include instructions for sample data.&
- Use git hooks/CI to catch accidental runtime usages of `Design.*`. For instance, forbid `Design.IsDesignMode` checks in release-critical code by scanning for patterns if needed.

## 8. Practice exercises

1. Add `Design.DataContext` to a complex form, providing realistic sample data (names, email, totals). Ensure preview shows formatted values.
2. Set `Design.Width/Height` to 360x720 for a mobile view; use `Design.DesignStyle` to highlight layout boundaries.
3. Create a resource dictionary for badges; use `Design.PreviewWith` to render multiple badge variants side-by-side.
4. Guard service initialization with `if (Design.IsDesignMode)` and confirm preview load improves.
5. Bonus: create a `Design` namespace helper static class that exposes sample models for multiple views; reference it from XAML.

## Look under the hood (source bookmarks)
- Design property helpers: [`Design.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Design.cs)
- Previewer bootstrapping: [`RemoteDesignerEntryPoint.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/Remote/RemoteDesignerEntryPoint.cs)
- Design-time property transformer: [`AvaloniaXamlIlDesignPropertiesTransformer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml.Loader/CompilerExtensions/Transformers/AvaloniaXamlIlDesignPropertiesTransformer.cs)
- Previewer window implementation: [`PreviewerWindowImpl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/Remote/PreviewerWindowImpl.cs)
- Samples: ControlCatalog resources demonstrate `Design.PreviewWith` usage (`samples/ControlCatalog/Styles/...`)

## Check yourself
- How do you provide sample data without running production services?
- How do you prevent design-only code from running in production?
- When do you use `Design.PreviewWith`?
- What are the most common previewer crashes and how do you avoid them?

What's next
- Next: [Chapter 26](Chapter26.md)
