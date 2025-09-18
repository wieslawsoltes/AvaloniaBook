# 26. Build, publish, and deploy

Goal
- Produce distributable builds for every platform Avalonia supports (desktop, mobile, browser).
- Understand .NET publish options (framework-dependent vs self-contained, single-file, ReadyToRun, trimming).
- Package and ship your app (MSIX, DMG, AppImage, AAB/IPA, browser bundles) and automate via CI/CD.

Why this matters
- Reliable builds avoid "works on my machine" syndrome.
- Choosing the right publish options balances size, startup time, and compatibility.

Prerequisites
- Chapters 18-20 for platform nuances, Chapter 17 for async/networking (relevant to release builds).

## 1. Build vs publish

- `dotnet build`: compiles assemblies, typically run for local development.
- `dotnet publish`: creates a self-contained folder/app ready to run on target machines (Optionally includes .NET runtime).
- Always test in `Release` configuration: `dotnet publish -c Release`.

## 2. Runtime identifiers (RIDs)

Common RIDs:
- Windows: `win-x64`, `win-arm64`.
- macOS: `osx-x64` (Intel), `osx-arm64` (Apple Silicon), `osx.12-arm64` (specific OS version), etc.
- Linux: `linux-x64`, `linux-arm64` (distribution-neutral), or distro-specific RIDs (`linux-musl-x64`).
- Android: `android-arm64`, `android-x86`, etc. (handled in platform head).
- iOS: `ios-arm64`, `iossimulator-x64`.
- Browser (WASM): `browser-wasm` (handled by browser head).

## 3. Publish configurations

### Framework-dependent (requires installed .NET runtime)

```bash
dotnet publish -c Release -r win-x64 --self-contained false
```

Smaller download; target machine must have matching .NET runtime. Good for enterprise scenarios.

### Self-contained (bundled runtime)

```bash
dotnet publish -c Release -r osx-arm64 --self-contained true
```

Larger download; runs on machines without .NET. Standard for consumer apps.

### Single-file

```bash
dotnet publish -c Release -r linux-x64 /p:SelfContained=true /p:PublishSingleFile=true
```

Creates one executable (plus a few native libraries depending on platform). Avalonia may extract resources native libs to temp; test startup.

### ReadyToRun

```bash
dotnet publish -c Release -r win-x64 /p:SelfContained=true /p:PublishReadyToRun=true
```

Precompiles IL to native code; faster cold start at cost of larger size. Measure before deciding.

### Trimming (advanced)

```bash
dotnet publish -c Release -r osx-arm64 /p:SelfContained=true /p:PublishTrimmed=true
```

Aggressive size reduction; risky because Avalonia/XAML relies on reflection. Requires careful annotation/preservation with `DynamicDependency` or `ILLinkTrim` files. Start without trimming; enable later with thorough testing.

### Publish options matrix (example)

| Option | Pros | Cons |
| --- | --- | --- |
| Framework-dependent | Small | Requires runtime install |
| Self-contained | Runs anywhere | Larger downloads |
| Single-file | Simple distribution | Extracts natives; more memory | 
| ReadyToRun | Faster cold start | Larger size | 
| Trimmed | Smaller | Risk of missing types |

## 4. Output directories

Publish outputs to `bin/Release/<TFramework>/<RID>/publish`.

Examples:
- `bin/Release/net8.0/win-x64/publish`
- `bin/Release/net8.0/linux-x64/publish`
- `bin/Release/net8.0/osx-arm64/publish`

Verify resources (images, fonts) present; confirm `AvaloniaResource` includes them (check `.csproj`).

## 5. Platform packaging

### Windows

- Basic distribution: zip the publish folder or single-file EXE.
- MSIX: use `dotnet publish /p:WindowsPackageType=msix` or MSIX packaging tool. Enables automatic updates, store distribution.
- MSI/Wix: for enterprise installs.
- Code signing recommended (Authenticode certificate) to avoid SmartScreen warnings.

### macOS

- Create `.app` bundle with `Avalonia.DesktopRuntime.MacOS` packaging scripts.
- Code sign and notarize: use Apple Developer ID certificate, `codesign`, `xcrun altool`/`notarytool`.
- Provide DMG for distribution.

### Linux

- Zip/tarball publish folder with run script.
- AppImage: use `Avalonia.AppTemplate.AppImage` or AppImage tooling to bundle.
- Flatpak: create manifest (flatpak-builder). Ensure dependencies included via `org.freedesktop.Platform` runtime.
- Snap: use `snapcraft.yaml` to bundle.

### Android

- Platform head (`MyApp.Android`) builds APK/AAB using Android tooling.
- Publish release AAB and sign with keystore (`./gradlew bundleRelease` or `dotnet publish` using .NET Android tooling).
- Upload to Google Play or sideload.

### iOS

- Platform head (`MyApp.iOS`) builds .ipa using Xcode or `dotnet publish -f net8.0-ios -c Release` with workload.
- Requires macOS, Xcode, signing certificates, provisioning profiles.
- Deploy to App Store via Transporter/Xcode.

### Browser (WASM)

- `dotnet publish -c Release` in browser head (`MyApp.Browser`). Output in `bin/Release/net8.0/browser-wasm/AppBundle`.
- Deploy to static host (GitHub Pages, S3, etc.). Use service worker for caching if desired.

## 6. Automation (CI/CD)

- Use GitHub Actions/Azure Pipelines/GitLab CI to run `dotnet publish` per target.
- Example GitHub Actions matrix:

```yaml
jobs:
  publish:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        include:
          - os: windows-latest
            rid: win-x64
          - os: macos-latest
            rid: osx-arm64
          - os: ubuntu-latest
            rid: linux-x64
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - run: dotnet publish src/MyApp/MyApp.csproj -c Release -r ${{ matrix.rid }} --self-contained true
      - uses: actions/upload-artifact@v4
        with:
          name: myapp-${{ matrix.rid }}
          path: src/MyApp/bin/Release/net8.0/${{ matrix.rid }}/publish
```

- Add packaging steps (MSIX, DMG) via platform-specific actions/tools.
- Sign artifacts in CI where possible (store certificates securely).

## 7. Verification checklist

- Run published app on real machines/VMs for each RID.
- Check fonts, DPI, plugins, network resources.
- Validate updates to config/resources; ensure relative paths work from publish folder.
- If using trimming, run automated UITests (Chapter 21) and manual smoke tests.
- Run `dotnet publish` with `--self-contained` false/true to compare sizes and startup times; pick best trade-off.

## 8. Troubleshooting

| Problem | Fix |
| --- | --- |
| Missing native libs on Linux | Install required packages (`libicu`, `fontconfig`, `libx11`, etc.). Document dependencies. |
| Startup crash only in Release | Enable logging to file; check for missing assets; ensure `AvaloniaResource` includes. |
| High CPU at startup | Investigate ReadyToRun vs normal build; pre-load data asynchronously vs synchronously. |
| Code signing errors (macOS/Windows) | Confirm certificates, entitlements, notarization steps. |
| Publisher mismatch (store upload) | Align package IDs, manifest metadata with store requirements. |

## 9. Practice exercises

1. Publish self-contained builds for `win-x64`, `osx-arm64`, `linux-x64`. Run each and note size/performance differences.
2. Enable `PublishSingleFile` and `PublishReadyToRun` for one target; compare startup time and size.
3. Experiment with trimming on a small sample; add `ILLink` attributes to preserve necessary types; test thoroughly.
4. Set up a GitHub Actions workflow to publish artifacts per RID and upload them as artifacts.
5. Optional: create MSIX (Windows) or DMG (macOS) packages and run locally to test installation/updates.

## Look under the hood (source & docs)
- Avalonia build docs: [`docs/build.md`](https://github.com/AvaloniaUI/Avalonia/blob/master/docs/build.md)
- Samples for reference packaging: [`samples/ControlCatalog`](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog)
- .NET publish docs: [dotnet publish reference](https://learn.microsoft.com/dotnet/core/tools/dotnet-publish)
- App packaging: Microsoft MSIX docs, Apple code signing docs, AppImage/Flatpak/Snap guidelines.

## Check yourself
- What's the difference between framework-dependent and self-contained publishes? When do you choose each?
- How do single-file, ReadyToRun, and trimming impact size/performance?
- Which RIDs are needed for your user base?
- What packaging format suits your distribution channel (installer, app store, raw executable)?
- How can CI/CD automate builds and packaging per platform?

What's next
- Next: [Chapter 27](Chapter27.md)
