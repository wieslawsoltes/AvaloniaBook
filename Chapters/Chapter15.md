# 15. Accessibility and internationalization

Goal
- Make your app usable by everyone, with keyboard, screen readers, and assistive tech. Localize your UI for different languages and regions.

Why it matters
- Accessibility is not optional: keyboard users, low‑vision users, and screen‑reader users should complete all key tasks.
- Internationalization (i18n) broadens your audience: localized strings, culture‑aware formatting, right‑to‑left (RTL) layouts, and font fallback ensure a first‑class experience worldwide.

What you’ll build in this chapter
- Keyboard‑friendly forms and menus with predictable tab order and access keys.
- Screen‑reader hints via AutomationProperties.
- A simple localization pipeline using .resx resources, a tiny Localizer helper, and runtime culture switching.
- RTL–aware layouts and a default font family that supports your target scripts.

1) Keyboard accessibility from the start
- Focus and Tab order
  - Every interactive control should be reachable with Tab/Shift+Tab.
  - Use IsTabStop and TabIndex on controls.
  - Use KeyboardNavigation.TabNavigation on containers to define how focus moves within them.

XAML example: predictable tab order in a form
```xml
<StackPanel Spacing="8" KeyboardNavigation.TabNavigation="Cycle">
  <TextBlock Text="_User name" RecognizesAccessKey="True"/>
  <TextBox TabIndex="0" Name="UserName"/>

  <TextBlock Text="_Password" RecognizesAccessKey="True"/>
  <TextBox TabIndex="1" Name="Password" PasswordChar="•"/>

  <CheckBox TabIndex="2" Content="_Remember me"/>

  <StackPanel Orientation="Horizontal" Spacing="8">
    <Button TabIndex="3">
      <ContentPresenter>
        <TextBlock Text="_Sign in" RecognizesAccessKey="True"/>
      </ContentPresenter>
    </Button>
    <Button TabIndex="4">
      <ContentPresenter>
        <TextBlock Text="_Cancel" RecognizesAccessKey="True"/>
      </ContentPresenter>
    </Button>
  </StackPanel>
</StackPanel>
```
Notes
- RecognizesAccessKey="True" lets the underscore (_) mark an access key; Alt+letter triggers the nearest logical action.
- KeyboardNavigation.TabNavigation:
  - Continue (default): tab moves into and then out of the container
  - Cycle: focus wraps inside the container
  - Once: the first Tab focuses the first child, the next Tab leaves the container
  - Local: Tab only moves inside the container
  - None: Tab does not move focus inside

2) Access keys that actually work
- Access keys let users activate commands using Alt+Letter. In Avalonia, you can:
  - Use AccessText around text that contains underscores.
  - Or set RecognizesAccessKey="True" on TextBlock within the content of Button/MenuItem.

XAML examples
```xml
<Button>
  <AccessText Text="_Open"/>
</Button>

<MenuItem>
  <MenuItem.Header>
    <AccessText Text="_File"/>
  </MenuItem.Header>
</MenuItem>
```

3) Screen reader semantics with AutomationProperties
- AutomationProperties is how you describe UI semantics for assistive technologies.
- Common attached properties:
  - AutomationProperties.Name: the accessible label (what the control is called)
  - AutomationProperties.HelpText: extra explanation or hint
  - AutomationProperties.AutomationId: stable ID used by UI tests and screen readers
  - AutomationProperties.LabeledBy: link a control to its visible label element
  - AutomationProperties.LiveSetting: announce dynamic updates (polite/assertive)

XAML examples
```xml
<StackPanel Spacing="8">
  <TextBlock x:Name="UserNameLabel" Text="User name"/>
  <TextBox Name="UserName"
           AutomationProperties.LabeledBy="{Binding #UserNameLabel}"
           AutomationProperties.HelpText="Enter your account name"/>

  <TextBlock x:Name="StatusLabel" Text="Status"/>
  <TextBlock Name="StatusText"
             AutomationProperties.LabeledBy="{Binding #StatusLabel}"
             AutomationProperties.LiveSetting="Polite"
             Text="Ready"/>
</StackPanel>
```
Tips
- Prefer visible labels connected with LabeledBy. If there’s no visible label, set AutomationProperties.Name.
- Keep HelpText short and specific (“Press Enter to search”).

4) Testing keyboard and screen readers
- Keyboard: Tab through every interactive element. Make sure focus is visible and the order is logical.
- Screen readers: Try Narrator (Windows), VoiceOver (macOS/iOS), Orca (Linux). Verify names, roles, states, and readout order.
- Menus and dialogs: Ensure access keys and Esc/Enter behave as expected.

5) Internationalization: the simplest path that scales
- Approach
  - Store localizable strings in .resx files (e.g., Properties/Resources.resx, plus Resources.fr.resx etc.).
  - Use a tiny Localizer that reads from ResourceManager and raises notifications when culture changes.
  - Bind to that Localizer from XAML using an indexer binding. No special XAML extension required.

Localizer helper (C#)
```csharp
using System;
using System.ComponentModel;
using System.Globalization;
using System.Resources;

namespace MyApp.Localization;

public sealed class Loc : INotifyPropertyChanged
{
    private readonly ResourceManager _resources = Properties.Resources.ResourceManager;

    public string this[string key]
        => _resources.GetString(key, CultureInfo.CurrentUICulture) ?? key;

    public void SetCulture(CultureInfo culture)
    {
        CultureInfo.CurrentUICulture = culture;
        CultureInfo.CurrentCulture = culture;
        // Notify indexer bindings to refresh all strings
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs("Item[]"));
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}
```


Wiring it in XAML
- Put a Loc instance in resources you can reach from every view (e.g., App.Resources or a top‑level Window).

App.xaml (snippet)
```xml
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:local="using:MyApp.Localization">
  <Application.Resources>
    <local:Loc x:Key="Loc"/>
  </Application.Resources>
</Application>
```

Using localized strings
```xml
<Menu>
  <MenuItem Header="{Binding [File], Source={StaticResource Loc}}"/>
  <MenuItem Header="{Binding [Edit], Source={StaticResource Loc}}"/>
</Menu>

<TextBlock Text="{Binding [Ready], Source={StaticResource Loc}}"/>
```

Switching languages at runtime (C#)
```csharp
using System.Globalization;
using Avalonia;
using MyApp.Localization;

// For example, in a menu command or settings page:
var loc = (Loc)Application.Current!.Resources["Loc"];
loc.SetCulture(new CultureInfo("pl-PL"));
```

Formatting that respects culture
- .NET formatting uses CurrentCulture automatically.
```xml
<TextBlock Text="{Binding Price, StringFormat={}{0:C}}"/>
<TextBlock Text="{Binding Date, StringFormat={}{0:D}}"/>
```

6) Right‑to‑left (RTL) support with FlowDirection
- Some languages (Arabic, Hebrew, Farsi) require RTL text and mirrored layouts.
- Set FlowDirection on a Window or any container; children inherit unless overridden.

Examples
```xml
<Window FlowDirection="RightToLeft">
  <StackPanel>
    <TextBlock Text="{Binding [Hello], Source={StaticResource Loc}}"/>
    <!-- Controls mirror automatically when possible -->
  </StackPanel>
</Window>

<!-- Override for a specific control -->
<TextBox FlowDirection="LeftToRight"/>
```

7) Fonts and fallback: show all glyphs
- Pick a default font family that supports your target scripts, or bundle fonts with your app.
- Configure a default family with FontManagerOptions during app startup.

Program.cs (desktop)
```csharp
using Avalonia;
using Avalonia.Media;

BuildAvaloniaApp()
    .With(new FontManagerOptions
    {
        // A family with broad Unicode coverage
        DefaultFamilyName = "Noto Sans"
    });

static AppBuilder BuildAvaloniaApp()
    => AppBuilder.Configure<App>()
                 .UsePlatformDetect()
                 .LogToTrace();
```

Notes
- You can also embed font files as Avalonia resources and reference them in XAML with FontFamily.
- Test for glyph coverage (CJK, Arabic/Hebrew, emoji) on each platform.

8) Checklist you can actually use
- Keyboard
  - Every action reachable by keyboard (tab, access keys, shortcuts)
  - Visual focus indicator is always visible
- Screen reader
  - Important elements have clear Name and HelpText
  - Status updates use LiveSetting when appropriate
- Internationalization
  - All visible strings come from resources
  - Prices, dates, numbers show in the selected culture
  - Switching language at runtime refreshes UI text
- RTL and fonts
  - FlowDirection works as expected; icons look correct when mirrored
  - The chosen default font displays all required scripts

Common pitfalls to avoid
- Hard‑coded strings in XAML or code — put them in resources.
- Hidden controls that still receive focus — set IsTabStop="False" or remove from tab order.
- Relying only on icons or color — add text labels and sufficient contrast.

Look under the hood (source links)
- Access keys rendering: AccessText
  - [Avalonia.Controls/Primitives/AccessText.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Primitives/AccessText.cs)
- Access key routing and handling
  - [Avalonia.Base/Input/AccessKeyHandler.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/AccessKeyHandler.cs)
- Keyboard navigation (Tab/arrow movement)
  - [Avalonia.Base/Input/KeyboardNavigation.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/KeyboardNavigation.cs)
- Focusability and tabbing properties
  - [Avalonia.Base/Input/InputElement.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/InputElement.cs)
- Accessibility attached properties
  - [Avalonia.Controls/Automation/AutomationProperties.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Automation/AutomationProperties.cs)
- Right‑to‑left direction
  - [Avalonia.Visuals/FlowDirection.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Visuals/FlowDirection.cs)
- Default font configuration
  - [Avalonia.Base/Media/FontManagerOptions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Media/FontManagerOptions.cs)

Check yourself
- How do you link a TextBox to its visible label so a screen reader announces them together?
- What does KeyboardNavigation.TabNavigation="Cycle" change compared to the default?
- How do you update all localized strings when the user changes language at runtime?
- Where do you set a default font family that supports your target scripts?

Extra practice
- Add access keys to your app’s main menu and verify they work with Alt key.
- Add AutomationProperties.Name and HelpText to a form and test with a screen reader on your OS.
- Create Resources.es.resx and Resources.ar.resx, switch to Spanish and Arabic at runtime, enable RTL, and review layout.

What’s next
- Next: [Chapter 16](Chapter16.md)
