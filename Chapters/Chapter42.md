# 42. CI pipelines, diagnostics, and troubleshooting

Goal
- Run Avalonia headless and automation suites reliably in CI across Windows, macOS, and Linux agents.
- Capture logs, screenshots, and diagnostics artifacts so UI regressions are easy to triage.
- Detect hangs or ordering issues proactively and keep runs deterministic even under heavy concurrency.

Why this matters
- UI regressions usually surface first in automation—if the pipeline flakes, the team stops trusting the signal.
- Headless tests rely on the dispatcher and render loop; CI environments with limited GPUs or desktops need deliberate setup.
- Rich artifacts (logs, videos, dumps) turn red builds into actionable bug reports instead of mystery failures.

Prerequisites
- Chapter 38 for configuring `UseHeadless` and driving the dispatcher.
- Chapter 39 for integrating the headless test session into xUnit or NUnit.
- Chapter 41 for scripting complex input sequences that your pipeline will exercise.

## 1. Pick a CI host and bootstrap prerequisites

Avalonia’s own integration pipeline (see `external/Avalonia/azure-pipelines-integrationtests.yml:1`) demonstrates the moving parts for Appium + headless test runs:

- Install the correct .NET runtimes/SDKs via `UseDotNet@2`.
- Prepare platform dependencies (e.g., select Xcode, kill stray `node` processes, start Appium on macOS; start WinAppDriver on Windows).
- Build the test app and run `dotnet test` against `Avalonia.IntegrationTests.Appium.csproj`.
- Publish artifacts—`appium.out` on failure and TRX results on all outcomes.

For GitHub Actions, mirror that setup with runner-specific steps:

```yaml
jobs:
  ui-tests:
    strategy:
      matrix:
        os: [windows-latest, macos-13]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v3
        with:
          global-json-file: global.json
      - name: Start WinAppDriver
        if: runner.os == 'Windows'
        run: Start-Process -FilePath 'C:\\Program Files (x86)\\Windows Application Driver\\WinAppDriver.exe'
      - name: Restore
        run: dotnet restore tests/Avalonia.Headless.UnitTests
      - name: Test headless suite
        run: dotnet test tests/Avalonia.Headless.UnitTests --logger "trx;LogFileName=headless.trx" --blame-hang-timeout 5m
      - name: Publish results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: headless-results
          path: '**/*.trx'
```

Adjust the matrix for Linux when you only need headless tests (no Appium). Use the same `dotnet test` command locally to validate pipeline scripts.

## 2. Configure deterministic test execution

Headless suites should run with parallelism disabled unless every fixture is isolation-safe. xUnit supports assembly-level configuration:

```csharp
// AssemblyInfo.cs
[assembly: CollectionBehavior(DisableTestParallelization = true)]
[assembly: AvaloniaTestFramework]
```

Pair the attribute with `AvaloniaTestApplication` so a single `HeadlessUnitTestSession` drives the whole assembly. For NUnit, launch the test runner with `--workers=1` or mark fixtures `[NonParallelizable]`. This avoids fighting over the singleton dispatcher and ensures actions happen in the same order on developer machines and CI bots.

Within tests, drain work deterministically. `HeadlessWindowExtensions` already wraps each gesture with `Dispatcher.UIThread.RunJobs()` and `AvaloniaHeadlessPlatform.ForceRenderTimerTick()`; call those directly from helpers when you schedule background tasks outside the provided wrappers.

## 3. Capture logs, screenshots, and videos

Collect evidence automatically so failing builds are actionable:

- Turn on Avalonia’s trace logging by chaining `.LogToTrace()` in your `AppBuilder`. Redirect stderr to a file in CI (`dotnet test … 2> headless.log`) and upload it as an artifact.
- Use `CaptureRenderedFrame` (Chapter 40) to grab before/after bitmaps on failure. Save them with a timestamp inside `TestContext.CurrentContext.WorkDirectory` (NUnit) or `ITestOutputHelper` attachments (xUnit).
- On Windows, record screen captures with MSTest data collectors. Avalonia ships `record-video.runsettings` (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/record-video.runsettings:1`) to capture Appium sessions; reuse it by passing `/Settings:record-video.runsettings` to VSTest or `--settings` to `dotnet test`.
- For Appium runs, write driver logs to disk. The macOS pipeline publishes `appium.out` when a job fails (`external/Avalonia/azure-pipelines-integrationtests.yml:27`).

## 4. Diagnose hangs and deadlocks

UI tests occasionally hang because outstanding work blocks the dispatcher. Harden your pipeline with diagnosis options:

- Use `dotnet test --blame-hang-timeout 5m --blame-hang-dump-type full` to trigger crash dumps when a test exceeds the timeout.
- Wrap long-running awaits inside `HeadlessUnitTestSession.Dispatch` so the framework can pump the dispatcher (`external/Avalonia/src/Headless/Avalonia.Headless/HeadlessUnitTestSession.cs:54`).
- Expose a helper that runs `Dispatcher.UIThread.RunJobs()` and `AvaloniaHeadlessPlatform.ForceRenderTimerTick()` in a loop until a condition is met. Fail the test if the condition never becomes true to avoid infinite waits.
- When debugging locally, attach a logger to `DispatcherTimer` callbacks or set `DispatcherTimer.Tag` to identify timers causing hangs; the headless render timer is labeled `HeadlessRenderTimer` (`external/Avalonia/src/Headless/Avalonia.Headless/AvaloniaHeadlessPlatform.cs:21`).

Analyze captured dumps with `dotnet-dump analyze` to inspect managed thread stacks and spot blocked tasks.

## 5. Environment hygiene on shared agents

CI agents often reuse workspaces. Add cleanup steps before running UI automation:

- Kill straggling processes (`pkill IntegrationTestApp`, `pkill node`) as the macOS pipeline does (`external/Avalonia/azure-pipelines-integrationtests.yml:21`).
- Remove stale app bundles or temporary data to guarantee a clean run.
- Reset environment variables that influence Avalonia behavior (e.g., `AVALONIA_RENDERER` overrides). Keep your scripts explicit to avoid surprises when infra engineers tweak images.

For cross-platform Appium tests, encapsulate capability setup in fixtures. `DefaultAppFixture` (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/DefaultAppFixture.cs:9`) configures Windows and macOS sessions differently while exposing a consistent driver to tests.

## 6. Build health dashboards and alerts

Publish TRX or NUnit XML outputs to your CI system so failures appear in dashboards. Azure Pipelines uses `PublishTestResults@2` to ingest xUnit results even when the job succeeds with warnings (`external/Avalonia/azure-pipelines-integrationtests.yml:67`). GitHub Actions can read TRX via `dorny/test-reporter` or similar actions.

Send critical logs to observability tools if your team maintains telemetry infrastructure. A simple approach is to push structured log lines to stdout in JSON—CI services preserve the console by default.

## 7. Troubleshooting checklist

- **Tests fail only on CI** – compare fonts, localization, and DPI. Ensure custom fonts are deployed with the test app and `CultureInfo.DefaultThreadCurrentUICulture` is set for deterministic layouts.
- **Intermittent hangs** – add `--blame` dumps, then review stuck threads. Often a test awaited `Task.Delay` without advancing the render timer; replace with deterministic loops.
- **Missing screenshots** – confirm Skia is enabled (`UseHeadlessDrawing = false`) so `CaptureRenderedFrame` works in pipelines.
- **Appium session errors** – verify the automation server is running (WinAppDriver/Appium) before tests start, and stop it in a final step to avoid port conflicts next run.
- **Resource leaks across tests** – always close windows (`window.Close()`), dispose `CompositeDisposable`, and tear down Appium sessions in `Dispose`. Lingering windows keep the dispatcher alive and can cause later tests to inherit state.

## Practice lab

1. **Pipeline parity** – Create a local script that mirrors your CI job (`dotnet restore`, `dotnet test`, artifact copy). Run it before pushing so pipeline failures never surprise you.
2. **Hang detector** – Wire `dotnet test --blame` into your CI job and practice analyzing the generated dumps for a deliberately hung test.
3. **Artifact triage** – Extend your test harness to save headless screenshots and logs into an output directory, then configure your pipeline to upload them on failure.
4. **Parallelism audit** – Temporarily enable test parallelization to identify fixtures that rely on global state. Fix the offenders or permanently disable parallel runs via assembly attributes.
5. **Cross-platform dry run** – Use a GitHub Actions matrix or Azure multi-job pipeline to run headless tests on Windows and Linux simultaneously, comparing logs for environment-specific quirks.

What's next
- Next: [Chapter43](Chapter43.md)
