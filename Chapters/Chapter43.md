# 43. Appium fundamentals for Avalonia apps

Goal
- Stand up Appium-based UI tests that drive Avalonia desktop apps on Windows and macOS.
- Reuse the built-in integration harness (`Avalonia.IntegrationTests.Appium`) to spin sessions, navigate the sample app, and locate controls reliably.
- Understand the accessibility surface Avalonia exposes so selectors stay stable across platforms and Appium versions.

Why this matters
- End-to-end coverage validates window chrome, dialogs, and platform behaviors that headless tests can’t touch.
- Appium works with the same accessibility tree users rely on—tests that pass here give confidence in automation readiness.
- A disciplined harness keeps session setup, synchronization, and cleanup consistent across operating systems.

Prerequisites
- Chapter 12 for windowing concepts referenced by Appium tests.
- Chapter 13 for menus/dialogs—the automation harness exercises them heavily.
- Chapter 42 for CI orchestration once your Appium suite is green locally.

## 1. Anatomy of the Avalonia Appium harness

Avalonia ships an Appium test suite in `external/Avalonia/tests/Avalonia.IntegrationTests.Appium`. Key parts:

- `DefaultAppFixture` builds and launches the sample `IntegrationTestApp`, creating an `AppiumDriver` for Windows or macOS sessions (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/DefaultAppFixture.cs:9`).
- `TestBase` accepts the fixture and navigates the ControlCatalog-style pager. It retries the navigation click to absorb macOS animations (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/TestBase.cs:6`).
- `CollectionDefinitions` wires fixtures into xUnit collections so sessions are shared per test class (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/CollectionDefinitions.cs:4`).

Reuse this structure in your own project: create a fixture that launches your app (packaged exe/bundle), expose the `AppiumDriver`, and derive page-specific test classes from a `TestBase` that performs navigation.

## 2. Configure sessions per platform

`DefaultAppFixture` populates capability sets tailored to each OS:

```csharp
var options = new AppiumOptions();
if (OperatingSystem.IsWindows())
{
    options.AddAdditionalCapability(MobileCapabilityType.App, TestAppPath);
    options.AddAdditionalCapability(MobileCapabilityType.PlatformName, MobilePlatform.Windows);
    options.AddAdditionalCapability(MobileCapabilityType.DeviceName, "WindowsPC");
    Session = new WindowsDriver(new Uri("http://127.0.0.1:4723"), options);
}
else if (OperatingSystem.IsMacOS())
{
    options.AddAdditionalCapability("appium:bundleId", "net.avaloniaui.avalonia.integrationtestapp");
    options.AddAdditionalCapability(MobileCapabilityType.PlatformName, MobilePlatform.MacOS);
    options.AddAdditionalCapability(MobileCapabilityType.AutomationName, "mac2");
    Session = new MacDriver(new Uri("http://127.0.0.1:4723/wd/hub"), options);
}
```

The fixture also foregrounds the window on Windows via `SetForegroundWindow` to avoid focus issues. Always close the session in `Dispose` even if Appium errors—macOS’ `mac2` driver may throw on shutdown, so wrap in try/catch like the sample.

TIP: keep Appium/WAD endpoints configurable via environment variables so your CI scripts can point to remote device clouds.

## 3. Navigating the sample app

`TestBase` selects a page by finding the pager control and clicking the relevant button. The same pattern applies to your app:

```csharp
public class WindowTests : TestBase
{
    public WindowTests(DefaultAppFixture fixture) : base(fixture, "Window") { }

    [Fact]
    public void Can_toggle_window_state()
    {
        var windowStateCombo = Session.FindElementByAccessibilityId("CurrentWindowState");
        windowStateCombo.Click();
        Session.FindElementByAccessibilityId("WindowStateMaximized").SendClick();
        Assert.Equal("Maximized", windowStateCombo.GetComboBoxValue());
    }
}
```

The `pageName` passed to `TestBase` must match the accessible name exposed by the pager button. Avalonia’s sample ControlCatalog sets these via `AutomationProperties.Name`, so always annotate navigation controls in your app for consistent selectors.

## 4. Element discovery and helper APIs

Selectors vary subtly across platforms. Avalonia’s helpers hide those differences:

- `AppiumDriverEx` defines `FindElementByAccessibilityId`, `FindElementByName`, and other convenience methods to work with both Appium 1 and 2 (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/AppiumDriverEx.cs:1`).
- `ElementExtensions` centralizes common queries such as chrome buttons and combo box value extraction. For example, `GetComboBoxValue` uses `Text` on Windows and `value` attributes elsewhere (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:34`).
- `GetCurrentSingleWindow` hides the extra wrapper window present in macOS accessibility trees (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:60`).

When building your suite, add similar extension methods instead of hard-coding XPath per test. Keep selectors rooted in `AutomationId` or names you control via `AutomationProperties.AutomationId` and `Name` to minimize brittleness.

## 5. Synchronization and retries

Appium commands are asynchronous relative to the app. Avalonia tests mix explicit waits, retries, and timeouts:

- `TestBase` retries page navigation three times with a 1s delay to survive macOS transitions.
- `ElementExtensions.OpenWindowWithClick` polls for either a new window handle or child window to appear, retrying up to ten times (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:86`).
- For transitions with animations (e.g., exiting full screen), tests call `Thread.Sleep` after sending commands—note the cleanup block in `WindowTests` that waits 1 second on macOS before asserting (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/WindowTests.cs:53`).

Wrap these patterns in helper methods so timing tweaks stay centralized. For more resilient waits, use Appium’s `WebDriverWait` with conditions such as `driver.FindElementByAccessibilityId(...)` or `element.Displayed`.

## 6. Cross-platform control with attributes and collections

Automation suites often need OS-specific assertions. Avalonia uses:

- `[PlatformFact]`/`[PlatformTheory]` to skip tests on unsupported OSes (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/PlatformFactAttribute.cs:7`).
- Collection definitions to isolate fixtures for specialized apps (e.g., overlay popups vs. default ControlCatalog) (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/CollectionDefinitions.cs:10`).

Follow suit by tagging tests with custom attributes that read environment variables or capability flags. This keeps your suite from failing on agents lacking certain features (e.g., Win32-only APIs).

## 7. Exposing automation IDs in Avalonia

Appium relies on the accessibility tree. Avalonia maps these properties as follows:

- `AutomationProperties.AutomationId` and control `Name` become accessibility IDs (`AutomationTests.AutomationId`, `external/Avalonia/tests/Avalonia.IntegrationTests.Appium/AutomationTests.cs:12`).
- `AutomationProperties.Name` populates the element name in both Windows UIA and macOS accessibility APIs.
- `AutomationProperties.LabeledBy` and other metadata surface via Appium attributes so you can assert associations (`AutomationTests.LabeledBy`).

Ensure the controls you interact with set both `AutomationId` and `Name`; for templated controls expose IDs through `x:Name` or `Automation.Id`. Without these properties, selectors fall back to fragile XPath queries.

## 8. Running the suite

### Windows

1. Install WinAppDriver (ships with Visual Studio workloads) and start it on port 4723.
2. Build your Avalonia app for `net8.0-windows` with `UseWindowsForms` disabled (the sample uses `IntegrationTestApp`).
3. Launch Appium tests: `dotnet test tests/Avalonia.IntegrationTests.Appium --logger "trx;LogFileName=appium.trx"`.

### macOS

1. Install Appium 2 with the `mac2` driver and run `appium --base-path /wd/hub`.
2. Ensure the test runner has accessibility permissions; the pipeline script resets them via `pkill` and `osascript` (`external/Avalonia/azure-pipelines-integrationtests.yml:17`).
3. Bundle the app (`samples/IntegrationTestApp/bundle.sh`) so Appium can reference it by bundle ID.

Use the provided `macos-clean-build-test.sh` as a reference for orchestrating builds locally or in CI.

## 9. Troubleshooting

- **Session fails to start** – Verify the Appium server is running and that the path/bundle ID is correct. On Windows, ensure the test app exists relative to the test project (`DefaultAppFixture.TestAppPath`).
- **Elements not found** – Inspect the accessibility tree with tools such as Windows Inspect or macOS Accessibility Inspector. Add missing `AutomationId` values to the Avalonia XAML.
- **Focus issues after fullscreen** – Mirror Avalonia’s retry `Thread.Sleep` or use explicit waits; macOS may animate transitions for up to a second.
- **Multiple windows** – Use `OpenWindowWithClick` helper to track handles. Remember to dispose the returned `IDisposable` so the new window closes after the test.
- **Driver shutdown crashes** – Wrap `Session.Close()` in try/catch like `DefaultAppFixture.Dispose` to shield flaky platform drivers.

## Practice lab

1. **Custom fixture** – Implement a fixture that launches your app under test, parameterized by environment variables for executable path and Appium endpoint.
2. **Navigation helper** – Create a `TestBase` that navigates your shell’s menu/pager via automation IDs, then write a smoke test asserting window title, version label, or status bar text.
3. **Selector audit** – Add `AutomationId` attributes to controls in a sample page, write tests that locate them by accessibility ID, and verify they remain stable after theme changes.
4. **Cross-platform skip logic** – Introduce `[PlatformFact]`-style attributes that read from `RuntimeInformation` and feature flags (e.g., skip tray icon tests on macOS), then apply them to OS-specific suites.
5. **Wait strategy** – Replace any `Thread.Sleep` in your tests with a reusable wait helper that polls for element state using Appium’s `WebDriverWait`, ensuring the helper raises descriptive timeout errors.

What's next
- Next: [Chapter44](Chapter44.md)
