# 46. Cross-platform scenarios and advanced gestures

Goal
- Exercise Avalonia apps under platform-specific shells—window chrome, tray icons, menus—without duplicating logic per OS.
- Drive complex pointer and keyboard gestures (drag, multi-click, context tap) using Appium actions that map correctly on Windows and macOS.
- Validate multi-monitor layouts, fullscreen transitions, and system integrations while keeping selectors and waits resilient.

Why this matters
- Desktop affordances behave differently across Win32 and macOS accessibility stacks; tests must adapt or risk false negatives.
- Advanced gestures rely on low-level pointer semantics that Appium exposes inconsistently across drivers.
- Cross-platform consistency is a core Avalonia selling point—automated verification keeps regressions from sneaking in.

Prerequisites
- Chapter 43 for the foundational Appium harness.
- Chapter 45 for selector patterns and PageObject design.
- Familiarity with Avalonia windowing APIs (Chapters 12 and 18).

## 1. Split platform-specific coverage with fixtures and attributes

`PlatformFactAttribute` and `PlatformTheoryAttribute` skip tests on unsupported OSes (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/PlatformFactAttribute.cs:7`). Use them to branch behavior cleanly:

```csharp
[PlatformFact(TestPlatforms.MacOS)]
public void ThickTitleBar_Drag_Reports_Moves() { ... }
```

Group tests into collections bound to fixtures that configure capabilities. For example, `DefaultAppFixture` launches the stock ControlCatalog, while `OverlayPopupsAppFixture` adds `--overlayPopups` arguments to highlight overlay behavior (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/OverlayPopupsAppFixture.cs:4`).

## 2. Window management across platforms

### Windows

`WindowTests` (see `external/Avalonia/tests/Avalonia.IntegrationTests.Appium/WindowTests.cs`) verifies state transitions (Normal, Maximized, FullScreen), docked windows, and mode toggles. It uses `SendClick` on combo entries because native `Click()` is unreliable on certain automation peers (`ElementExtensions.SendClick`, `external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:235`).

### macOS

`WindowTests_MacOS` covers thick title bars, system chrome toggles, and fullscreen animations (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/WindowTests_MacOS.cs:19`). Tests depend on applying window decoration parameters via checkboxes exposed in the demo app.

**Tips**
- Normalize state by calling the same helper at test end; `PointerTests_MacOS.Dispose` resets window parameters before exiting (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/PointerTests_MacOS.cs:119`).
- When switching states that trigger animations, add intentional waits or `WebDriverWait` polling before grabbing the next snapshot.

## 3. Multi-window flows and dialogs

Use `ElementExtensions.OpenWindowWithClick` to encapsulate the logic of detecting new windows. It differentiates between top-level handles (Windows) and child windows (macOS) and returns an `IDisposable` that closes the window on teardown (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ElementExtensions.cs:86`).

```csharp
using (Control("OpenModal").OpenWindowWithClick())
{
    // Assert modal state
}
```

`PointerTests.Pointer_Capture_Is_Released_When_Showing_Dialog` relies on this helper to ensure capture is cleared when a dialog opens (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/PointerTests.cs:13`).

## 4. Tray icons and system menus

System integration differs dramatically:

- **Windows**: `TrayIconTests` locates the shell tray window, handles overflow flyouts, and accounts for whitespace-prefixed icon names (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/TrayIconTests.cs:62`). It also opens a secondary “Root” session that targets the desktop to access the taskbar.
- **macOS**: tray icons appear as `XCUIElementTypeStatusItem` elements and menus are retrieved via `//XCUIElementTypeStatusItem/XCUIElementTypeMenu`.

Wrap this logic in helper methods and hide it behind PageObjects so tests merely call `TrayIcon().ShowMenu()` and assert resulting automation flags.

## 5. Advanced pointer gestures

### Gesture taxonomy

`GestureTests` demonstrates how to script taps, double-taps, drags, and right-clicks using Actions API (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/GestureTests.cs:16`). Examples:

- `new Actions(Session).DoubleClick(element).Perform();`
- Multi-step pointer sequences using `PointerInputDevice` for macOS-specific right-tap semantics (`GestureTests.RightTapped_Is_Raised_2`, line 139).

### Title bar drags on macOS

`PointerTests_MacOS.OSXThickTitleBar_Pointer_Events_Continue_Outside_Window_During_Drag` verifies pointer capture beyond window bounds while dragging the title bar (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/PointerTests_MacOS.cs:17`). It uses `DragAndDropToOffset` and reads automation counters from the secondary window.

**Practice**
- Always move the pointer onto the target before pressing: `new Actions(Session).MoveToElement(titleAreaControl).Perform();`
- After custom pointer sequences, release buttons even when assertions fail to leave the driver in a consistent state (`GestureTests.DoubleTapped_Is_Raised_2`, line 70).

## 6. Keyboard modifiers and selection semantics

`ListBoxTests` executes Shift-range selection and marks Ctrl-click tests as skipped due to driver limitations (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ListBoxTests.cs:36`). Document such constraints in your suite and apply `[Fact(Skip=...)]` with explanations for future debugging.

`ComboBoxTests` rely on keyboard shortcuts (`Keys.LeftAlt + Keys.ArrowDown`) and ensure wrapping behavior toggles via checkboxes before assertion (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ComboBoxTests.cs:41`). Keep these interactions in PageObjects so tests remain expressive (`ComboBoxPage.OpenDropdown()` vs. inline key sequences).

## 7. Multi-monitor and screen awareness

`ScreenTests` pulls current monitor data and asserts invariants around bounds, work area, and scaling (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ScreenTests.cs:12`). Use similar verifications when you need to assert window placement on multi-monitor setups.

For drag-to-monitor flows, record starting and ending positions via text fields surfaced in the app, then compare after applying pointer moves. Ensure tests reset state (move window back) when done to avoid cascading failures.

## 8. Troubleshooting cross-platform gestures

- **Stuck pointer buttons** – Ensure `PointerInputDevice` sequences end with `PointerUp`. If a test fails mid-action, add `try/finally` to release buttons.
- **Unexpected double-taps** – As shown in `PointerTests_MacOS.OSXThickTitleBar_Single_Click_Does_Not_Generate_DoubleTapped_Event`, add counters to your app to observe actual events and assert on them instead of stateful UI side effects.
- **Tray icon discovery failures** – Expand overflow menus explicitly on Windows; on macOS, allow for menu creation delays by polling after clicking the status item.
- **Localization differences** – Names of system menu items vary; rely on automation IDs when possible or provide fallback selectors.
- **Driver limitations** – Document known issues (e.g., WinAppDriver ctrl-click) with skip reasons so team members know why coverage is missing.

## Practice lab

1. **Window choreography** – Script a test that opens a secondary window, drags it to a new position, toggles fullscreen, and returns to normal. Assert pointer capture counts using automation counters exposed in the sample.
2. **Tray icon helper** – Build a PageObject with `ShowMenu()` and `ClickMenuItem(string text)` methods that handle Windows overflow and macOS status items automatically. Use it to verify a menu command toggles a checkbox in the main window.
3. **Gesture pipeline** – Implement a helper that performs a parameterized pointer gesture (`PointerSequence` builder). Use it to test tap, double-tap, drag, and right-tap on the same control, asserting the logged gesture text each time.
4. **Multi-monitor regression** – Extend the sample app to surface target screen IDs. Write a test that moves a window across monitors and verifies the reported screen changes, resetting to the primary display afterward.
5. **Platform matrix** – Create a theory that runs the same smoke scenario across Windows/Mac fixtures using `[PlatformTheory]`. Capture driver logs on failure and assert the test records which platform executed for easier triage.

What's next
- Next: [Chapter47](Chapter47.md)
