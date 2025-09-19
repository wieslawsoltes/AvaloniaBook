# 15. Accessibility and internationalization

Goal
- Deliver interfaces that are usable with keyboard, screen readers, and high-contrast themes.
- Implement automation metadata (`AutomationProperties`, custom `AutomationPeer`s) so assistive technologies understand your UI.
- Localize content, formats, fonts, and layout direction for multiple cultures while supporting IME and text services.
- Build a repeatable accessibility testing loop that spans platform tooling and automated checks.

Why this matters
- Accessibility ensures compliance (WCAG/ADA) and a better experience for keyboard and assistive-technology users.
- Internationalization widens your reach and avoids locale-specific bugs in formatting or layout direction.
- Treating accessibility and localization as first-class requirements keeps your app portable across desktop, mobile, and browser targets.

Prerequisites
- Keyboard input and commands (Chapter 9), resources (Chapter 10), MVVM patterns (Chapter 11), navigation and lifetimes (Chapter 12).

Key namespaces
- [`AutomationProperties.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/AutomationProperties.cs)
- [`AutomationPeer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/Peers/AutomationPeer.cs)
- [`ControlAutomationPeer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/Peers/ControlAutomationPeer.cs)
- [`TextInputMethodClient.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputMethodClient.cs)
- [`TextInputOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputOptions.cs)
- [`FontManagerOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/FontManagerOptions.cs)
- [`FlowDirection.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Visuals/FlowDirection.cs)

## 1. Keyboard accessibility

### 1.1 Focus order and tab navigation

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

- `KeyboardNavigation.TabNavigation="Cycle"` keeps focus within the container, ideal for dialogs.
- Use `AccessText` or `RecognizesAccessKey="True"` to expose mnemonic keys.
- Disable focus for decorative elements via `IsTabStop="False"` or `Focusable="False"`.

### 1.2 Keyboard navigation helpers

`KeyboardNavigation` (source: [`KeyboardNavigation.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyboardNavigation.cs)) provides:
- `DirectionalNavigation="Cycle"` for arrow-key traversal in menus/panels.
- `TabNavigation` modes (`Continue`, `Once`, `Local`, `Cycle`, `None`).
- `Control.IsTabStop` per element when you need to skip items like labels or icons.

## 2. Screen reader semantics

Attach `AutomationProperties` to expose names, help text, and relationships:

```xml
<StackPanel Spacing="10">
  <TextBlock x:Name="EmailLabel" Text="Email"/>
  <TextBox Text="{Binding Email}"
           AutomationProperties.LabeledBy="{Binding #EmailLabel}"
           AutomationProperties.AutomationId="EmailInput"/>

  <TextBlock x:Name="StatusLabel" Text="Status"/>
  <TextBlock Text="{Binding Status}"
             AutomationProperties.LabeledBy="{Binding #StatusLabel}"
             AutomationProperties.LiveSetting="Polite"/>
</StackPanel>
```

- `AutomationProperties.Name` provides a fallback label when there is no visible text.
- `AutomationProperties.HelpText` supplies extra instructions for screen readers.
- `AutomationProperties.LiveSetting` (`Polite`, `Assertive`) controls how urgent announcements are.
- `AutomationProperties.ControlType` lets you override the role in edge cases (use sparingly).

`AutomationProperties` map to automation peers. The base `ControlAutomationPeer` inspects properties and pseudo-classes to expose state.

## 3. Custom automation peers

Create peers when you author custom controls so assistive technology can identify them correctly.

```csharp
public class ProgressBadge : TemplatedControl
{
    public static readonly StyledProperty<string?> TextProperty =
        AvaloniaProperty.Register<ProgressBadge, string?>(nameof(Text));

    public string? Text
    {
        get => GetValue(TextProperty);
        set => SetValue(TextProperty, value);
    }

    protected override AutomationPeer? OnCreateAutomationPeer()
        => new ProgressBadgeAutomationPeer(this);
}

public sealed class ProgressBadgeAutomationPeer : ControlAutomationPeer
{
    public ProgressBadgeAutomationPeer(ProgressBadge owner) : base(owner) { }

    protected override string? GetNameCore() => (Owner as ProgressBadge)?.Text;
    protected override AutomationControlType GetAutomationControlTypeCore() => AutomationControlType.Text;
    protected override AutomationLiveSetting GetLiveSettingCore() => AutomationLiveSetting.Polite;
}
```

- Override `PatternInterfaces` (e.g., `IRangeValueProvider`, `IValueProvider`) when your control supports specific automation patterns.
- Use `AutomationProperties.AccessibilityView` to control whether a control appears in the content vs. control view.

## 4. High contrast and theme variants

Avalonia supports theme variants (`Light`, `Dark`, `HighContrast`). Bind colors to resources instead of hard-coding values.

```xml
<ResourceDictionary>
  <ResourceDictionary.ThemeDictionaries>
    <ResourceDictionary x:Key="Default">
      <SolidColorBrush x:Key="AccentBrush" Color="#2563EB"/>
    </ResourceDictionary>
    <ResourceDictionary x:Key="HighContrast">
      <SolidColorBrush x:Key="AccentBrush" Color="#00FF00"/>
    </ResourceDictionary>
  </ResourceDictionary.ThemeDictionaries>
</ResourceDictionary>
```

Switch variants for testing:

```csharp
Application.Current!.RequestedThemeVariant = ThemeVariant.HighContrast;
```

Provide clear focus visuals using pseudo-classes (`:focus`, `:pointerover`) and ensure contrast ratios meet WCAG (4.5:1 for body text). For Windows, respect system accent colors by reading `RequestedThemeVariant` and `SystemBarColor` (Chapter 7).

## 5. Text input, IME, and text services

IME support matters for CJK languages and handwriting. `TextInputMethodClient` is the bridge between your control and platform IME surfaces. Text controls in Avalonia already implement it; custom text editors should derive from `TextInputMethodClient` (or reuse `TextPresenter`).

```csharp
public sealed class CodeEditorTextInputClient : TextInputMethodClient
{
    private readonly CodeEditor _editor;

    public CodeEditorTextInputClient(CodeEditor editor) => _editor = editor;

    public override Visual TextViewVisual => _editor.TextLayer;
    public override bool SupportsPreedit => true;
    public override bool SupportsSurroundingText => true;
    public override string SurroundingText => _editor.Document.GetText();
    public override Rect CursorRectangle => _editor.GetCaretRect();
    public override TextSelection Selection
    {
        get => new(_editor.SelectionStart, _editor.SelectionEnd);
        set => _editor.SetSelection(value.Start, value.End);
    }

    public void UpdateCursor()
    {
        RaiseCursorRectangleChanged();
        RaiseSelectionChanged();
        RaiseSurroundingTextChanged();
    }
}
```

Configure text options with the attached `TextInputOptions` properties:

```xml
<TextBox Text="{Binding PhoneNumber}"
         InputMethod.TextInputOptions.ContentType="TelephoneNumber"
         InputMethod.TextInputOptions.ReturnKeyType="Done"
         InputMethod.TextInputOptions.IsCorrectionEnabled="False"/>
```

- On mobile, `ReturnKeyType` changes the soft keyboard button (e.g., “Go”, “Send”).
- `ContentType` hints at expected input, enabling numeric keyboards or email layouts.
- `IsContentPredictionEnabled`/`IsSpellCheckEnabled` toggle autocorrect.

When you detect IME-specific behaviour, test on Windows (IMM32), macOS, Linux (IBus/Fcitx), Android, and iOS — each backend surfaces slightly different capabilities.

## 6. Localization workflow

### 6.1 Resource management

Use RESX resources or a localization service that surfaces culture-specific strings.

```csharp
public sealed class Loc : INotifyPropertyChanged
{
    private CultureInfo _culture = CultureInfo.CurrentUICulture;
    public string this[string key] => Resources.ResourceManager.GetString(key, _culture) ?? key;

    public void SetCulture(CultureInfo culture)
    {
        if (_culture.Equals(culture))
            return;

        _culture = culture;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(null));
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}
```

Register in `App.axaml` and bind:

```xml
<Application.Resources>
  <local:Loc x:Key="Loc"/>
</Application.Resources>

<TextBlock Text="{Binding [Ready], Source={StaticResource Loc}}"/>
```

Switch culture at runtime:

```csharp
var culture = new CultureInfo("fr-FR");
CultureInfo.CurrentCulture = CultureInfo.CurrentUICulture = culture;
((Loc)Application.Current!.Resources["Loc"]).SetCulture(culture);
```

### 6.2 Formatting and layout direction

- Use binding `StringFormat` or `string.Format` with the current culture for dates, numbers, and currency.
- Set `FlowDirection="RightToLeft"` for RTL languages and override back to `LeftToRight` for controls that must remain LTR (e.g., numeric fields).
- Mirror icons and layout padding when mirrored (use `ScaleTransform` or `LayoutTransform`).

## 7. Fonts and fallbacks

Ensure glyph coverage with `FontManagerOptions`:

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
    .StartWithClassicDesktopLifetime(args);
```

- Ship branded fonts via `FontFamily="avares://MyApp/Assets/Fonts/Brand.ttf#Brand"`.
- Test scripts that require surrogate pairs (emoji, rare CJK ideographs) to ensure fallbacks load.
- On Windows, consider `TextRenderingMode` for clarity vs. smoothness.

## 8. Testing accessibility

Tips for a repeatable test loop:

- **Keyboard** – Tab through each screen, ensure focus indicators are visible, and verify shortcuts work.
- **Screen readers** – Use Narrator, NVDA, or JAWS on Windows; VoiceOver on macOS/iOS; TalkBack on Android; Orca on Linux. Confirm names, roles, and help text.
- **Automation tree** – Avalonia DevTools → **Automation** tab visualizes peers and properties.
- **Contrast** – Run `Accessibility Insights` (Windows), `Color Oracle`, or browser dev tools to verify contrast ratios.
- **Automated** – Combine `Avalonia.Headless` UI tests (Chapter 21) with assertions on `AutomationId` and localized content.

Document gaps (e.g., missing peers, insufficient contrast) and track them like any other defect.

## 9. Practice exercises

1. Annotate a settings page with `AutomationProperties.Name`, `HelpText`, and `AutomationId`; inspect the automation tree with DevTools and NVDA.
2. Derive a custom `AutomationPeer` for a progress pill control, exposing live updates and value patterns, then verify announcements in a screen reader.
3. Configure `TextInputOptions` for phone number input on Windows, Android, and iOS. Test with an IME (Japanese/Chinese) to ensure composition events render correctly.
4. Localize UI strings into two additional cultures (e.g., es-ES, ar-SA), toggle `FlowDirection`, and confirm mirrored layouts do not break focus order.
5. Set up `FontManagerOptions` with script-specific fallbacks and validate that Arabic, Cyrillic, and CJK text render without tofu glyphs.

## Look under the hood (source bookmarks)
- Keyboard navigation: [`KeyboardNavigation.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyboardNavigation.cs)
- Automation metadata: [`AutomationProperties.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/AutomationProperties.cs), [`ControlAutomationPeer.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/Peers/ControlAutomationPeer.cs)
- Text input & IME: [`TextInputMethodClient.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputMethodClient.cs), [`TextInputOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/TextInput/TextInputOptions.cs)
- Localization: [`CultureInfoExtensions`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Localization/CultureInfoExtensions.cs), [`RuntimePlatformServices`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Runtime/PlatformServices.cs)
- Font management: [`FontManagerOptions.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/FontManagerOptions.cs)
- Flow direction: [`FlowDirection.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Visuals/FlowDirection.cs)

## Check yourself
- How do `AutomationProperties.LabeledBy` and `AutomationId` improve automated testing and screen reader output?
- When should you implement a custom `AutomationPeer`, and which patterns do you need to expose for value-based controls?
- Which `TextInputOptions` settings influence IME behaviour and soft keyboard layouts across platforms?
- How do you switch UI language at runtime and ensure both text and layout update correctly?
- Where do you configure font fallbacks to cover multiple scripts without shipping duplicate glyphs?

What's next
- Next: [Chapter 16](Chapter16.md)
