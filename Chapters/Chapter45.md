# 45. Element discovery, selectors, and PageObjects

Goal
- Locate Avalonia controls reliably through Appium’s accessibility surface, even when templates or virtualization hide elements.
- Encapsulate selectors and interactions in reusable PageObjects so suites stay maintainable as the UI grows.
- Combine waits, retries, and platform-aware helpers to avoid brittle tests across Windows, macOS, and remote hosts.

Why this matters
- Avalonia templates can reshape automation trees; hard-coded XPath falls apart when themes change.
- Virtualized lists only materialize visible items—selectors must cope with dynamic children.
- Cross-platform automation surfaces expose different attributes; centralizing logic keeps suites portable.

Prerequisites
- Chapter 43 for harness fundamentals.
- Chapter 44 for environment setup and driver configuration.
- Familiarity with Avalonia accessibility APIs (`AutomationProperties`).

## 1. Build selectors on accessibility IDs first

Avalonia maps `AutomationProperties.AutomationId` and control `Name` directly into Appium selectors. Tests such as `AutomationTests.AutomationId` rely on `FindElementByAccessibilityId` (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/AutomationTests.cs:12`). Adopt this priority order:

1. `FindElementByAccessibilityId` for IDs you own.
2. `FindElementByName` for localized labels (`ElementExtensions.GetName`) or menu items.
3. `FindElementByXPath` as a last resort for structure-dependent lookups (e.g., tray icons on Windows).

Annotate controls in XAML with both `x:Name` and `AutomationProperties.AutomationId` to keep selectors stable. For templated controls, expose IDs through template parts so they enter the automation tree.

## 2. Reuse PageObject-style wrappers

Avalonia’s Appium harness centralizes navigation in `TestBase`. Each test class inherits and passes the page name, letting `TestBase` click through the pager with retries (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/TestBase.cs:6`). Mirror this structure:

```csharp
public abstract class CatalogPage : TestBase
{
    protected CatalogPage(DefaultAppFixture fixture, string pageName)
        : base(fixture, pageName) { }

    protected AppiumWebElement Control(string automationId)
        => Session.FindElementByAccessibilityId(automationId);
}

public sealed class WindowPage : CatalogPage
{
    public WindowPage(DefaultAppFixture fixture) : base(fixture, "Window") { }

    public AppiumWebElement WindowState => Control("CurrentWindowState");
    public void SelectState(string id) => Control(id).SendClick();
}
```

Wrap gestures (click, double-click, modifier shortcuts) in extension methods rather than duplicating `Actions` blocks. Avalonia’s `ElementExtensions.SendClick` simulates physical clicks to accommodate controls that resist `element.Click()` (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:235`).

## 3. Handle virtualization and dynamic children

Virtualized lists only generate visible items. `ListBoxTests.Is_Virtualized` counts visual children returned by `GetChildren` to prove virtualization is active (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ListBoxTests.cs:52`).

Techniques:
- Scroll or page through lists via keyboard (`Keys.PageDown`) or pointer wheel to materialize items lazily.
- Query container children each time rather than caching stale `AppiumWebElement` references.
- Use sentinel elements (e.g., “Loading…” items) to detect asynchronous population and wait before asserting.

```csharp
public IReadOnlyList<AppiumWebElement> VisibleRows()
    => Session.FindElementByAccessibilityId("BasicListBox").GetChildren();
```

Combine with helper waits to poll until a desired item appears instead of assuming immediate materialization.

## 4. Account for platform differences in selectors

Avalonia ships cross-platform helpers that encapsulate OS-specific attribute quirks:

- `ElementExtensions.GetComboBoxValue` chooses `Text` on Windows and `value` on macOS (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:34`).
- `GetCurrentSingleWindow` navigates macOS’s duplicated window hierarchy by using a parent XPath (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:60`).
- `TrayIconTests` opens nested sessions to access Windows taskbar automation IDs, while macOS uses generic status item XPath (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/TrayIconTests.cs:13`).

Keep such logic in dedicated helpers; PageObjects should consume a single API regardless of platform. Provide capabilities (e.g., `UseOverlayPopups`) through fixtures so tests stay declarative (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/OverlayPopupsAppFixture.cs:4`).

## 5. Synchronize with the UI deliberately

Animations and popups require waits. The harness uses:

- Retries in `TestBase` navigation with `Thread.Sleep(1000)` between attempts to allow fullscreen transitions (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/TestBase.cs:12`).
- Looped polling in `ElementExtensions.OpenWindowWithClick` to detect new window handles or child windows, retrying up to ten times (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:86`).
- Explicit sleeps after context menu or tray interactions when platform APIs lag (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/TrayIconTests.cs:33`).

Upgrade these patterns using `WebDriverWait` to poll until predicates succeed:

```csharp
public static AppiumWebElement WaitForElement(AppiumDriver session, By by, TimeSpan timeout)
{
    return new WebDriverWait(session, timeout).Until(driver =>
    {
        var element = driver.FindElement(by);
        return element.Displayed ? element : null;
    });
}
```

Centralize waits so adjustments (timeouts, polling intervals) propagate across the suite.

## 6. Model complex selectors as queries

Large UIs often require multi-step discovery:

- Menus: `MenuTests` clicks through root, child, and grandchild items using accessibility IDs and names (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/MenuTests.cs:25`). Wrap this into helper methods like `OpenMenu("Root", "Child", "Grandchild")`.
- Tray icons: `GetTrayIconButton` first attempts to find the icon, then expands the overflow flyout if absent, handling whitespace quirks in names (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/TrayIconTests.cs:62`).
- Windows: `OpenWindowWithClick` tracks new handles or titles, accommodating macOS fullscreen behavior by ignoring untitled intermediate nodes (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:200`).

Treat these as queries, not static selectors. Accept parameters (icon name, menu path) and apply consistent error messaging when assertions fail.

## 7. Use test attributes to scope runs

Selectors often depend on platform capabilities. Decorate tests with `[PlatformFact]` / `[PlatformTheory]` to skip unsupported scenarios (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/PlatformFactAttribute.cs:7`). This prevents PageObjects from needing conditionals inside every method and ensures pipelines stay green when features diverge.

Group tests requiring special fixtures (e.g., overlay popups) via xUnit collections (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/CollectionDefinitions.cs:4`). PageObjects then request the appropriate fixture type through constructor injection.

## 8. Troubleshooting selectors

- **Elements disappear mid-test** – virtualization recycled them; retrieve fresh references after scrolling.
- **Click no-ops** – switch to `SendClick` actions; some controls ignore `element.Click()` on macOS.
- **Wrong element chosen** – qualify by automation ID before falling back to names. Names may change with localization.
- **Popups not found** – ensure you expanded parent menus or overflow trays first. Add logging describing the hierarchy you traversed for easier debugging.
- **Timeouts** – adopt structured waits instead of arbitrary sleeps; log the search strategy (selector type, fallback attempts) on failure.

## Practice lab

1. **PageObject refactor** – Extract a PageObject for a complex page (e.g., ComboBox) that exposes strongly-typed actions and returns typed results (`GetSelectedValue`). Replace direct selector usage in tests.
2. **Selector fallback** – Implement a helper that tries `AutomationId`, then `Name`, then a custom XPath, logging each attempt. Use it to locate menu items with localized labels.
3. **Virtualized scrolling** – Write a test that scrolls through a long `ListBox`, verifying virtualization by checking `GetChildren().Count` stays below a threshold while confirming a distant item becomes Selected.
4. **Wait utility** – Replace `Thread.Sleep` in one test with a reusable `WaitFor` method leveraging `WebDriverWait`. Confirm the test still passes under slower animations by injecting artificial delays.
5. **Cross-platform assertions** – Add assertions that rely on windows or tray icons, guarding them with `[PlatformFact]`. Implement helper methods that throw informative exceptions when run on unsupported platforms.

What's next
- Next: [Chapter46](Chapter46.md)
