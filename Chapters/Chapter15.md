# 15. Accessibility and internationalization

Goal
- Deliver interfaces that are usable with keyboard, screen readers, and high-contrast themes.
- Localize content, formats, and layout direction for multiple cultures.
- Implement automation metadata (AutomationProperties, custom peers) and test accessibility.

Why this matters
- Accessibility ensures compliance (WCAG/ADA) and a better experience for keyboard and assistive technology users.
- Internationalization widens reach and avoids culture-specific bugs.

Prerequisites
- Keyboard/commands (Chapter 9), resources (Chapter 10), MVVM (Chapter 11), navigation (Chapter 12).

## 1. Keyboard accessibility

### 1.1 Focus order and tab stops

```xml
<StackPanel Spacing="8" KeyboardNavigation.TabNavigation="Cycle">
  <TextBlock Text="_User name" RecognizesAccessKey="True"/>
  <TextBox x:Name="UserName" TabIndex="0"/>

  <TextBlock Text="_Password" RecognizesAccessKey="True"/>
  <PasswordBox x:Name="Password" TabIndex="1"/>

  <CheckBox TabIndex="2" Content="_Remember me"/>

  <StackPanel Orientation="Horizontal" Spacing="8">
    <Button TabIndex="3">
      <AccessText Text="_Sign in"/>
    </Button>
    <Button TabIndex="4">
      <AccessText Text="_Cancel"/>
    </Button>
  </StackPanel>
</StackPanel>
```

- `KeyboardNavigation.TabNavigation="Cycle"` wraps focus within container.
- Use `IsTabStop="False"` or `Focusable="False"` for decorative elements.
- Access keys (underscore) require `AccessText` or `RecognizesAccessKey="True"`.

### 1.2 Keyboard navigation helpers

`KeyboardNavigation` class (source: [`KeyboardNavigation.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyboardNavigation.cs)) supports:
- `DirectionalNavigation="Cycle"` for arrow-key traversal (menus, grids).
- `TabNavigation` modes: `Continue`, `Once`, `Local`, `Cycle`, `None`.

## 2. Screen reader semantics

### 2.1 AutomationProperties essentials

```xml
<StackPanel Spacing="10">
  <TextBlock x:Name="EmailLabel" Text="Email"/>
  <TextBox Text="{Binding Email}" AutomationProperties.LabeledBy="{Binding #EmailLabel}"/>

  <TextBlock x:Name="StatusLabel" Text="Status"/>
  <TextBlock AutomationProperties.LabeledBy="{Binding #StatusLabel}"
             AutomationProperties.LiveSetting="Polite"
             Text="Ready"/>
</StackPanel>
```

Properties:
- `AutomationProperties.Name`: accessible label if no visible label exists.
- `AutomationProperties.HelpText`: extra instructions.
- `AutomationProperties.AutomationId`: stable ID for UI tests.
- `AutomationProperties.ControlType`: override role in rare cases.
- `AutomationProperties.LabeledBy`: link to label element.

### 2.2 Announcing updates

For live regions (status bars, chat messages):

```xml
<TextBlock AutomationProperties.LiveSetting="Polite" Text="{Binding Status}"/>
```

`Polite` vs `Assertive` determines urgency.

### 2.3 Custom automation peers

When creating custom controls, override `OnCreateAutomationPeer` (source: [`ControlAutomationPeer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/Peers/ControlAutomationPeer.cs)):

```csharp
public class ProgressBadge : TemplatedControl
{
    protected override AutomationPeer? OnCreateAutomationPeer()
        => new ProgressBadgeAutomationPeer(this);
}

public sealed class ProgressBadgeAutomationPeer : ControlAutomationPeer
{
    public ProgressBadgeAutomationPeer(ProgressBadge owner) : base(owner) { }

    protected override string? GetNameCore()
        => (Owner as ProgressBadge)?.Text;

    protected override AutomationControlType GetAutomationControlTypeCore()
        => AutomationControlType.Text;
}
```

Register peers for custom controls to describe their role/names to screen readers.

## 3. High contrast & color considerations

- Provide sufficient contrast (WCAG 2.1 suggests 4.5:1 for text).
- Use theme resources instead of hard-coded colors. For high contrast, include variant dictionaries:

```xml
<ResourceDictionary ThemeVariant="HighContrast">
  <SolidColorBrush x:Key="AccentBrush" Color="#00FF00"/>
</ResourceDictionary>
```

Test high contrast by toggling `RequestedThemeVariant` (Chapter 7) and using OS settings.

## 4. Internationalization (i18n)

### 4.1 Resource management with RESX

Create `Resources.resx` (default) and `Resources.{culture}.resx`. Example localizer:

```csharp
public sealed class Loc : INotifyPropertyChanged
{
    private CultureInfo _culture = CultureInfo.CurrentUICulture;
    private readonly ResourceManager _resources = Resources.ResourceManager;

    public string this[string key] => _resources.GetString(key, _culture) ?? key;

    public void SetCulture(CultureInfo culture)
    {
        if (!_culture.Equals(culture))
        {
            _culture = culture;
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(null));
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}
```

Register in `App.axaml`:

```xml
<Application.Resources>
  <local:Loc x:Key="Loc"/>
</Application.Resources>
```

Use in XAML via indexer binding:

```xml
<MenuItem Header="{Binding [File], Source={StaticResource Loc}}"/>
<TextBlock Text="{Binding [Ready], Source={StaticResource Loc}}"/>
```

Switch culture at runtime:

```csharp
var loc = (Loc)Application.Current!.Resources["Loc"];
loc.SetCulture(new CultureInfo("fr-FR"));
CultureInfo.CurrentCulture = CultureInfo.CurrentUICulture = new CultureInfo("fr-FR");
```

Reassigning `CurrentCulture` ensures format strings (`{0:C}`) use new culture.

### 4.2 Culture-aware formatting

```xml
<TextBlock Text="{Binding OrderTotal, StringFormat={}{0:C}}"/>
<TextBlock Text="{Binding OrderDate, StringFormat={}{0:D}}"/>
```

Round-trip parsing uses `CultureInfo.CurrentCulture`. For manual conversions, pass `CultureInfo.CurrentCulture` to `TryParse`.

### 4.3 FlowDirection for RTL languages

```xml
<Window FlowDirection="RightToLeft">
  <StackPanel>
    <TextBlock Text="{Binding [Hello], Source={StaticResource Loc}}"/>
    <TextBox FlowDirection="LeftToRight" Text="{Binding Input}"/>
  </StackPanel>
</Window>
```

- RTL flips layout for panels and default icons. Use `FlowDirection.LeftToRight` for controls that should remain LTR (e.g., numbers).
- `FlowDirection` is defined in [`Avalonia.Visuals/FlowDirection.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Visuals/FlowDirection.cs).

### 4.4 Input Method Editors (IME)

Text input (Asian languages) uses IME. Controls like `TextBox` handle IME automatically. When building custom text surfaces, implement `ITextInputMethodClient` (source: [`TextInputMethodClient.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputMethodClient.cs)).

## 5. Fonts and fallbacks

Use fonts with wide Unicode coverage (Noto Sans, Segoe UI, Roboto). Set defaults via `FontManagerOptions` (Chapter 7). For script-specific fonts, add fallback chain:

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .With(new FontManagerOptions
    {
        DefaultFamilyName = "Noto Sans",
        FontFallbacks = new[]
        {
            new FontFallback { Family = "Noto Sans Arabic" },
            new FontFallback { Family = "Noto Sans CJK SC" }
        }
    })
    .LogToTrace();
```

Embed fonts for branding or to ensure glyph coverage. Use `FontFamily="avares://MyApp/Assets/Fonts/NotoSans.ttf#Noto Sans"` in styles.

## 6. Testing accessibility

- Manual: Tab through UI, run screen reader (Narrator, VoiceOver, Orca).
- Automated: Use UI test frameworks (Avalonia.Headless, Chapter 21) combined with `AutomationId` to verify accessibility properties.
- Tools: Contrast analyzers (Color Oracle, Stark), `Accessibility Insights` for Windows to inspect accessibility tree.

### 6.1 Inspecting automation tree

Avalonia DevTools (F12) -> Automation tab displays automation peers and properties. Confirm names, roles, help text.

## 7. Accessibility checklist

Keyboard
- All interactive elements reachable via Tab/Shift+Tab.
- Visible focus indicator (use styles to highlight `:focus` pseudo-class).
- Access keys for primary commands.

Screen readers
- Provide `AutomationProperties.Name`/`LabeledBy` for inputs.
- Use `AutomationProperties.HelpText` for guidance.
- Broadcast status updates via `AutomationProperties.LiveSetting`.

High contrast
- Colors bound to theme resources; text meets contrast ratios.
- Check `RequestedThemeVariant=HighContrast` for readability.

Internationalization
- All strings from resources.
- `CultureInfo.CurrentCulture`/`CurrentUICulture` update when switching language.
- Layout supports `FlowDirection` changes.
- Fonts cover required scripts.

## 8. Practice exercises

1. Add access keys and keyboard navigation for a form; verify focus order matches the spec.
2. Add `AutomationProperties.Name`, `HelpText`, and `AutomationId` to controls in a settings screen and test with Narrator or VoiceOver.
3. Localize UI strings into two additional cultures (e.g., es-ES, ar-SA), provide culture switching, and confirm RTL layout in Arabic.
4. Configure a default font fallback chain and verify glyph rendering for accented Latin, Cyrillic, Arabic, and CJK text.
5. Build an automated test (Avalonia.Headless) that finds elements via `AutomationId` and asserts localized content changes with culture.

## Look under the hood (source bookmarks)
- Keyboard navigation: [`KeyboardNavigation.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyboardNavigation.cs)
- Access text: [`AccessText.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Primitives/AccessText.cs)
- Automation properties: [`AutomationProperties.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/AutomationProperties.cs)
- Automation peers: [`ControlAutomationPeer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/Peers/ControlAutomationPeer.cs)
- Flow direction: [`FlowDirection.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Visuals/FlowDirection.cs)
- Font manager options: [`FontManagerOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/FontManagerOptions.cs)

## Check yourself
- How do you connect a TextBox to its label so screen readers announce them together?
- Which property enables live region updates for status text?
- How do you switch UI language at runtime and refresh all localized bindings?
- Where do you configure font fallbacks to support multiple scripts?
- What steps ensure your UI handles high-contrast settings correctly?

What's next
- Next: [Chapter 16](Chapter16.md)
