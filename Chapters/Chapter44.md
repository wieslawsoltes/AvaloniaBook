# 44. Environment setup, drivers, and device clouds

Goal
- Stand up reliable Appium infrastructure for Avalonia desktop automation on Windows and macOS.
- Package and register test apps so automation servers can launch them locally or on remote device clouds.
- Script build/start/stop flows that keep CI agents clean while preserving diagnostics.

Why this matters
- Incorrect driver versions or unregistered bundles are the top causes of flaky Appium runs.
- Avalonia apps often ship custom arguments (overlay popups, experimental features); tests need a repeatable way to pass them to the harness.
- Device-cloud execution magnifies small misconfigurations—locking your setup locally prevents expensive remote reruns.

Prerequisites
- Chapter 43 for the fundamentals of Avalonia’s Appium test harness.
- Chapter 42 for CI orchestration patterns and artifact capture.
- Base familiarity with platform build tooling (PowerShell, bash, Xcode command-line tools).

## 1. Install automation servers and drivers

### Windows

1. Install **WinAppDriver** (https://github.com/microsoft/WinAppDriver). It registers itself in the Start menu and listens on `http://127.0.0.1:4723`.
2. Ensure the machine is running in **desktop interactive** mode—WinAppDriver cannot interact with headless Windows Server sessions.
3. Optional: pin the service to auto-start via `schtasks` or a Windows Service wrapper so CI agents bring it up automatically.

### macOS

1. Install **Appium** (`npm install -g appium`). For Appium 1, the built-in mac driver is sufficient; for Appium 2 install the `mac2` driver (`appium driver install mac2`).
2. Grant Xcode helper the accessibility permissions required to drive UI (see harness readme at `external/Avalonia/tests/Avalonia.IntegrationTests.Appium/readme.md`).
3. Register your Avalonia app bundle so Appium can launch it by bundle ID. Avalonia’s script `samples/IntegrationTestApp/bundle.sh` builds and publishes the bundle.
4. Start Appium. For Appium 2 use a base path to maintain compatibility with existing clients: `appium --base-path=/wd/hub`.

The harness toggles between Appium 1 and 2 using the `IsRunningAppium2` property (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/Avalonia.IntegrationTests.Appium.csproj:5`). Set the property to `true` in `Directory.Build.props` or via `dotnet test -p:IsRunningAppium2=true` when running against Appium 2.

## 2. Package and register the test app

Appium launches desktop apps by path (Windows) or bundle identifier (macOS). The Avalonia sample uses `IntegrationTestApp` and rebuilds it before each run:

- macOS pipeline script (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/macos-clean-build-test.sh:1`) cleans the repo, compiles native dependencies, bundles the app, and opens it once to register Launch Services.
- Windows pipeline (`external/Avalonia/azure-pipelines-integrationtests.yml:42`) builds `IntegrationTestApp` and the test project before running `dotnet test`.

When testing your own app:

1. Provide a CLI or script (PowerShell/bbash) that packs the app and exposes the absolute path or bundle ID through environment variables (`TEST_APP_PATH`, `TEST_APP_BUNDLE`).
2. Inherit from `DefaultAppFixture` and override `ConfigureWin32Options` / `ConfigureMacOptions` to use those values. Example:

```csharp
protected override void ConfigureWin32Options(AppiumOptions options, string? app = null)
{
    base.ConfigureWin32Options(options, Environment.GetEnvironmentVariable("TEST_APP_PATH"));
}

protected override void ConfigureMacOptions(AppiumOptions options, string? app = null)
{
    base.ConfigureMacOptions(options, Environment.GetEnvironmentVariable("TEST_APP_BUNDLE"));
}
```

3. For variants (e.g., overlay popups), add command-line arguments via capabilities. `OverlayPopupsAppFixture` adds `--overlayPopups` on both platforms (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/OverlayPopupsAppFixture.cs:4`).

## 3. Start/stop lifecycle scripts

Automation servers must be running when tests start and shut down afterward. Avalonia’s pipelines demonstrate the sequence:

- **macOS job** kills stray processes (`pkill node`, `pkill IntegrationTestApp`), starts Appium in the background, bundles the app, launches it, runs `dotnet test`, then terminates Appium and the app again (`external/Avalonia/tests/Avalonia.IntegrationTests.Appium/macos-clean-build-test.sh:6`).
- **Windows job** uses Azure DevOps tasks to start/stop WinAppDriver (`external/Avalonia/azure-pipelines-integrationtests.yml:32`). When scripting locally, run `Start-Process "WinAppDriver.exe"` before tests and `Stop-Process -Name WinAppDriver` afterward.

General guidelines:

- Always clean up (`pkill`, `Stop-Process`) on both success and failure to keep subsequent runs deterministic.
- Redirect server logs to files (`appium > appium.out &`). Publish them when the job fails for easier triage (see pipeline’s `publish appium.out` step).

## 4. Device cloud configuration

Device clouds (BrowserStack App Automate, Sauce Labs, Azure-hosted desktops) require the same capabilities plus authentication tokens:

```csharp
options.AddAdditionalCapability("browserstack.user", Environment.GetEnvironmentVariable("BS_USER"));
options.AddAdditionalCapability("browserstack.key", Environment.GetEnvironmentVariable("BS_KEY"));
options.AddAdditionalCapability("appium:options", new Dictionary<string, object>
{
    ["osVersion"] = "11",
    ["deviceName"] = "Windows 11",
    ["appium:app"] = "bs://<uploaded-app-id>"
});
```

Upload your Avalonia app (packaged exe zipped, or macOS `.app` bundle) via the vendor’s CLI before tests run. On hosted Windows machines, ensure the automation provider exposes UI Automation trees—some locked-down images disable it.

When targeting clouds, keep these adjustments in fixtures:

```csharp
protected override void ConfigureWin32Options(AppiumOptions options, string? app = null)
{
    if (UseCloud)
    {
        options.AddAdditionalCapability("app", CloudAppId);
        options.AddAdditionalCapability("bstack:options", new { osVersion = "11", sessionName = TestContext.CurrentContext.Test.Name });
    }
    else
    {
        base.ConfigureWin32Options(options, app);
    }
}
```

Guard cloud-specific behavior using environment variables so local runs stay unchanged.

## 5. Managing driver compatibility

The harness conditionally compiles for Appium 1 vs. 2 via `APPIUM1`/`APPIUM2` constants (`AppiumDriverEx.cs`). Checklist:

- Run `dotnet test -p:IsRunningAppium2=true` when hitting Appium 2 endpoints. This updates `DefineConstants` and switches to the newer `Appium.WebDriver 5.x` client.
- Ensure the Appium server version matches the driver: Appium 2 + mac2 driver expect W3C protocol only.
- WinAppDriver currently supports only Appium 1, so keep a separate pipeline lane for Windows if you standardize on Appium 2 for macOS.

If you see protocol errors, print the server log (`appium.out`) and compare capability names. Appium 2 requires `appium:` prefixes for vendor-specific entries (already shown in `DefaultAppFixture.ConfigureMacOptions`).

## 6. Permissions and security prompts

Desktop automation breaks when the app lacks accessibility permissions:

- macOS: add the Appium binary, the terminal/agent, and Xcode helper to `System Settings → Privacy & Security → Accessibility`. The readme covers the exact steps.
- Windows: disable UAC prompts or run the agent as administrator. If UAC prompts appear, automation cannot interact with the foreground until dismissed.
- Device clouds: follow provider docs to grant persistent accessibility or run under pre-approved automation accounts.

Automate these steps where possible—on macOS you can pre-provision a profile or run a script to enable permissions via `tccutil`. For Windows, prefer an image with WinAppDriver pre-installed.

## 7. Logging and diagnostics

Augment your harness to collect evidence:

- Use `appium --log-level info --log appium.log` to write structured JSON logs.
- Forward driver logs to test output: `Session.Manage().Logs.GetLog("driver");` after a failure.
- For WinAppDriver, enable verbose logs via registry (`HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WinAppDriver\ConsoleLogging = 1`).
- Record video on Windows using the supplied `record-video.runsettings` file when executing through VSTest (Chapter 42).

## 8. Troubleshooting

- **`SessionNotCreatedException`** – Check that the app path/bundle exists and the process isn’t already running. On macOS, run `osascript` cleanup like the sample script to delete stale bundles.
- **`Could not find app`** – Re-run your packaging script; the bundle path changes when switching architectures (`osx-arm64` vs. `osx-x64`).
- **Authentication failures on clouds** – Ensure credentials are injected securely via pipeline secrets; log obfuscated values for debugging but never commit them to source.
- **Driver mismatch** – Align `IsRunningAppium2` with the server version. Appium 2 rejects legacy capability names like `bundleId` without the `appium:` prefix.
- **Resource leaks** – Always dispose fixtures, even in skipped tests. Wrap `Session` accesses in `try/finally` or use `IAsyncLifetime` to guarantee cleanup after each class.

## Practice lab

1. **Bootstrap script** – Create cross-platform scripts (`scripts/run-appium-tests.ps1` and `.sh`) that build your app, start/stop automation servers, and invoke `dotnet test`. Validate they leave no background processes.
2. **Configurable fixture** – Extend `DefaultAppFixture` to read capabilities from JSON (local vs. cloud). Add tests that assert the chosen configuration by inspecting `Session.Capabilities`.
3. **Permission audit** – Write a checklist or automated probe that verifies accessibility permissions before starting tests (e.g., attempt to focus a dummy window and fail fast with instructions).
4. **Driver matrix** – Run the same smoke suite against Appium 1 (WinAppDriver) and Appium 2 (mac2) by toggling `IsRunningAppium2`. Capture and compare server logs to understand protocol differences.
5. **CI integration** – Add jobs to your pipeline that call your bootstrap script on Windows and macOS runners. Upload Appium logs and test TRX files as artifacts, confirming cleanup occurs even when tests fail.

What's next
- Next: [Chapter45](Chapter45.md)
