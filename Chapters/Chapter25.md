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

## 1. Previewer pipeline and transport

IDE hosts spawn a preview process that loads your view or resource dictionary over the remote protocol. `DesignWindowLoader` spins up `RemoteDesignerEntryPoint`, which compiles your project with the design configuration, loads the control, then streams rendered frames back to the IDE through `Avalonia.Remote.Protocol.DesignMessages`.

Key components:
- [`Design.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Design.cs) toggles design mode (`Design.IsDesignMode`) and surfaces attached properties consumed only by the previewer.
- [`DesignWindowLoader`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/DesignWindowLoader.cs) boots the preview process, configures the runtime XAML loader, and registers services.
- [`PreviewerWindowImpl`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/PreviewerWindowImpl.cs) hosts the live surface, translating remote transport messages into frames.
- [`RemoteDesignerEntryPoint`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/Remote/RemoteDesignerEntryPoint.cs) sets up `RuntimeXamlLoader` and dependency injection so types resolve the same way they will at runtime.

Because the previewer compiles your project, build errors surface exactly as in `dotnet build`. Keep `AvaloniaResource` items and generated code in sync or the previewer will refuse to load.

## 2. Mock data with `Design.DataContext`

Provide lightweight POCOs or design view models for preview without touching production services.

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

At runtime the transformer removes `Design.DataContext`; real view models take over. For complex forms, expose design view models with stub services but avoid heavy logic. When you need multiple sample contexts, expose them as static properties on a design-time provider class and bind with `{x:Static}`.

### Design.IsDesignMode checks

Guard expensive operations:

```csharp
if (Design.IsDesignMode)
    return; // skip service setup, timers, network
```

Place guards in view constructors, `OnApplyTemplate`, or view model initialization.

## 3. Design.Width/Height & `DesignStyle`

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

## 4. Preview resource dictionaries with `Design.PreviewWith`

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

## 5. Inspect previewer logs and compilation errors

- Visual Studio and Rider show previewer logs in the dedicated "Avalonia Previewer" tool window; VS Code prints to the Output panel (`Avalonia Previewer` channel).
- Logs come from `DesignMessages`; look for `JsonRpcError` entries when bindings fail—those line numbers map to generated XAML.
- If compilation fails, open the temporary build directory path printed in the log. Running `dotnet build /p:Configuration=Design` replicates the preview build.
- Enable `Diagnostics -> Capture frames` to export a `.png` snapshot of the preview surface when you troubleshoot rendering glitches.

## 6. Extend design-time services

`RemoteDesignerEntryPoint` registers services in a tiny IoC container separate from your production DI. Override or extend them by wiring a helper that only executes when `Design.IsDesignMode` is true:

```csharp
using Avalonia;
using Avalonia.Controls;

public static class DesignTimeServices
{
    public static void Register()
    {
        if (!Design.IsDesignMode)
            return;

        AvaloniaLocator.CurrentMutable
            .Bind<INavigationService>()
            .ToConstant(new FakeNavigationService());
    }
}
```

Call `DesignTimeServices.Register();` inside `BuildAvaloniaApp().AfterSetup(...)` so the previewer receives the fake services without altering production setup. Use this pattern to swap HTTP clients, repositories, or configuration with in-memory fakes while keeping runtime untouched.

## 7. IDE-specific tips

### Visual Studio
- Ensure "Avalonia Previewer" extension is installed.
- F12 toggles DevTools; `Alt+Space` opens previewer hotkeys.
- If previewer doesn't refresh, rebuild project; VS sometimes caches the design assembly.
- Enable verbose logs via `Previewer -> Options -> Enable Diagnostics` to capture transport traces when the preview window stays blank.

### Rider
- Avalonia plugin required; previewer window shows automatically when editing XAML.
- Use the data context drop-down to quickly switch between sample contexts if multiple available.
- Rider caches preview assemblies under `%LOCALAPPDATA%/Avalonia`. Use "Invalidate caches" if you ship new resource dictionaries and the previewer shows stale data.

### VS Code
- Avalonia `.vsix` extension hosts the previewer through the dotnet CLI; keep the extension and SDK workloads in sync.
- Run `dotnet workload install wasm-tools` (previewer uses WASM-hosted renderer). Use the `Avalonia Previewer: Show Log` command if the embedded browser surface fails.

General
- Keep constructors light; heavy constructors crash previewer.
- Use `Design.DataContext` to avoid hitting DI container or real services.
- Split complex layouts into smaller user controls and preview them individually.

## 8. Troubleshooting & best practices

| Issue | Fix |
| --- | --- |
| Previewer blank/crashes | Guard code with `Design.IsDesignMode`; simplify layout; ensure no blocking calls in constructor |
| Design-only styles appear at runtime | `Design.*` stripped at runtime; if they leak, inspect generated `.g.cs` to confirm transformer ran |
| Resource dictionary preview fails | Add `Design.PreviewWith`; ensure resources compiled (check `AvaloniaResource` includes) |
| Sample data not showing | Confirm namespace mapping correct, sample object constructs without exceptions, and preview log shows `DataContext` attachment |
| Slow preview | Remove animations/effects temporarily; large data sets or virtualization can slow preview host |
| Transport errors (`SocketException`) | Restart previewer. Firewalls can block the loopback port used by `Avalonia.Remote.Protocol` |

## 9. Automation

- Document designer defaults using `README` for your UI project. Include instructions for sample data.
- Use git hooks/CI to catch accidental runtime usages of `Design.*`. For instance, forbid `Design.IsDesignMode` checks in release-critical code by scanning for patterns if needed.
- Add an automated smoke test that loads critical views with `Design.IsDesignModeProperty` set to true via `RuntimeXamlLoader` to detect regressions before IDE users do.

## 10. Practice exercises

1. Add `Design.DataContext` to a complex form, providing realistic sample data (names, email, totals). Ensure preview shows formatted values.
2. Set `Design.Width/Height` to 360x720 for a mobile view; use `Design.DesignStyle` to highlight layout boundaries.
3. Create a resource dictionary for badges; use `Design.PreviewWith` to render multiple badge variants side-by-side.
4. Open the previewer diagnostics window, reproduce a binding failure, and note how `DesignMessages` trace the failing binding path.
5. Guard service initialization with `if (Design.IsDesignMode)` and confirm preview load improves.
6. Bonus: implement a design-only service override and register it from `BuildAvaloniaApp().AfterSetup(...)`.

## Look under the hood (source bookmarks)
- Design property helpers: [`Design.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Design.cs)
- Preview transport wiring: [`DesignWindowLoader.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/DesignWindowLoader.cs)
- Previewer bootstrapping: [`RemoteDesignerEntryPoint.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/Remote/RemoteDesignerEntryPoint.cs)
- Design-time property transformer: [`AvaloniaXamlIlDesignPropertiesTransformer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml.Loader/CompilerExtensions/Transformers/AvaloniaXamlIlDesignPropertiesTransformer.cs)
- Previewer window implementation: [`PreviewerWindowImpl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.DesignerSupport/Remote/PreviewerWindowImpl.cs)
- Protocol messages: [`Avalonia.Remote.Protocol/DesignMessages.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Remote.Protocol/DesignMessages.cs)
- Samples: ControlCatalog resources demonstrate `Design.PreviewWith` usage (`samples/ControlCatalog/Styles/...`)

## Check yourself
- How do you provide sample data without running production services?
- How do you prevent design-only code from running in production?
- When do you use `Design.PreviewWith`?
- What are the most common previewer crashes and how do you avoid them?

What's next
- Next: [Chapter 26](Chapter26.md)
