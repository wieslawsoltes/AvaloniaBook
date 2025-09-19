# 47. Stabilizing suites, reporting, and best practices

Goal
- Keep Appium-based Avalonia suites reliable on developer machines and CI by isolating flakiness causes.
- Capture meaningful diagnostics (logs, videos, artifacts) that accelerate investigation when tests fail.
- Scale coverage with retry, quarantine, and reporting strategies that protect signal quality.

Why this matters
- Cross-platform automation is sensitive to timing, focus, and OS updates—without discipline the suite becomes noisy.
- Fast feedback requires structured artifacts; otherwise failures devolve into manual repro marathons.
- Stakeholders need trend visibility: which areas flake, which platforms lag, and where to invest engineering effort.

Prerequisites
- Chapter 43–46 for harness setup, selectors, and advanced scenarios.
- Chapter 42 for CI pipeline integration basics.

## 1. Triage flakiness with classification

Begin every investigation by tagging failures:
- **Timing** (animations, virtualization) – resolved with better waits (`WebDriverWait`, dispatcher polling).
- **Environment** (permissions, display scaling) – addressed by setup scripts or platform skips.
- **Driver quirks** (WinAppDriver Ctrl-click) – documented with `[Fact(Skip="...")]` like `ListBoxTests.Can_Select_Items_By_Ctrl_Clicking` (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/ListBoxTests.cs:36`).
- **App bugs** – file issues with automation evidence attached.

Maintain a living flake log referencing test name, platform, root cause, and remediation. Automate updates by pushing annotations into test reporters (Azure Pipelines, GitHub Actions).

## 2. Quarantine and retries without hiding real bugs

Retries buy time but can mask regressions. Strategies:

- Implement targeted retries via xUnit ordering or `[RetryFact]` equivalents. Avalonia currently handles retries manually by skipping unstable tests with reason strings (e.g., `TrayIconTests.Should_Handle_Left_Click` is marked `[PlatformFact(..., Skip = "Flaky test")]`, `external/Avalonia/tests/Avalonia.IntegrationTests.Appium/TrayIconTests.cs:29`).
- Prefer **automatic quarantine**: tag flaky tests and run them in a separate lane, keeping main suites failure-free. Example: use xUnit traits or custom attributes to filter (`dotnet test --filter "TestCategory!=Quarantine"`).
- Combine retries with diagnostics: on the last retry failure, dump Appium logs and take screenshots before failing.

## 3. Capture rich diagnostics

For every critical failure, collect:

- **Appium server logs** (`appium.out` in the macOS script) and publish them via CI artifacts (`external/Avalonia/azure-pipelines-integrationtests.yml:27`).
- **Driver logs**: `Session.Manage().Logs.GetLog("driver")` after catch blocks to capture protocol exchanges.
- **Screenshots**: call `Session.GetScreenshot().SaveAsFile(...)` on failure; stash path in test output.
- **Videos**: on Windows, VSTest runsettings `record-video.runsettings` records screen output (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/record-video.runsettings`).
- **Headless imagery**: pair Appium runs with headless captures (Chapter 40) to highlight visual state at failure.

Build helper methods so tests simply call `ArtifactCollector.Capture(context);`. Ensure cleanup occurs even when assertions throw (use `try/finally`).

## 4. Standardize waiting and polling policies

Enforce consistent defaults:

- Set a global implicit wait (short, e.g., 1s) and rely on explicit waits for complex states. Too-long implicit waits slow down failure discovery.
- Provide `WaitForElement` and `WaitForCondition` helpers with logging. Use them instead of ad-hoc `Thread.Sleep`.
- For dispatcher-driven state, expose instrumentation in the app (text fields reporting counters like `GetMoveCount` in `PointerTests_MacOS`, `external/Avalonia/tests/Avalonia.IntegrationTests.Appium/PointerTests_MacOS.cs:86`). Poll those values to assert behavior deterministically.

Document wait policies in CONTRIBUTING guidelines to onboard new contributors.

## 5. Structure reports for quick scanning

### Azure Pipelines / GitHub Actions

- Publish TRX results with names that encode platform, driver, and suite (e.g., `Appium-macOS-Appium2.trx`).
- Upload log bundles (`logs/appium.log`, `screenshots/*.png`). Provide clickable links in summary markdown.
- Add summary steps that print failing test names grouped by category (flaky, new regression, quarantined).

### Local development

- Provide a script (Chapter 44) that mirrors CI output directories so developers can inspect logs locally.
- Encourage use of `dotnet test --logger "trx;LogFileName=local.trx"` + `reportgenerator` for HTML summaries.

## 6. Enforce coding standards in tests

- **Selectors**: centralize in PageObjects. No raw XPath in tests.
- **Waits**: ban `Thread.Sleep` in code review; insist on helper usage.
- **Cleanup**: always dispose windows/sessions (`using` pattern with `OpenWindowWithClick`). Review tests that skip cleanup (they often cause downstream failures).
- **Platform gating**: pair every platform-specific assertion with `[PlatformFact]`/`[PlatformTheory]` to avoid accidental runs on unsupported OSes.

Add lint tooling (Roslyn analyzers or custom scripts) to scan for banned patterns (e.g., `Thread.Sleep(`) in test projects.

## 7. Monitor and alert on trends

- Track success rate per platform, per suite. Configure dashboards (Azure Analytics, GitHub Insights) to display pass percentages over time.
- Emit custom metrics (e.g., number of retries) to a time-series store. If retries spike, alert engineers before builds start failing.
- Rotate flake triage duty; publish weekly summaries identifying top offenders and assigned owners.

## 8. Troubleshooting checklist

- **Frequent timeouts** – confirm Appium server stability, check CPU usage on agents, review wait durations.
- **Intermittent focus issues** – ensure tests foreground windows (`SetForegroundWindow` on Windows) or click background-free zones before interacting.
- **Driver crashes** – update Appium/WinAppDriver, capture crash dumps, and reference known issues (e.g., mac2 driver close-session crash handled in `DefaultAppFixture.Dispose`).
- **Artifacts missing** – verify CI scripts always run artifact upload steps with `condition: always()`.
- **Quarantine drift** – periodic reviews to reinstate fixed tests; failing to do so erodes coverage.

## Practice lab

1. **Artifact collector** – Implement a helper that captures Appium logs, driver logs, screenshots, and optional videos when a test fails. Wire it into an xUnit `IAsyncLifetime` fixture so it runs automatically.
2. **Wait audit** – Write an analyzer or script that flags `Thread.Sleep` usages in the Appium test project. Replace them with explicit waits and document the change.
3. **Quarantine lane** – Configure your CI pipeline with two jobs: stable and quarantine (`dotnet test --filter "Category!=Quarantine"` vs. `Category=Quarantine`). Move a flaky test into the quarantine lane and verify reporting highlights it separately.
4. **Trend dashboard** – Export TRX results for the past week and build a simple dashboard (Power BI, Grafana) showing pass/fail counts per platform. Identify top flaky tests.
5. **Regression template** – Create an issue template that captures test name, platform, driver version, app commit, and links to artifacts. Use it when logging Appium regressions to standardize triage information.

What's next
- Return to [Index](../Index.md) for appendices, publishing checklists, or future updates.
