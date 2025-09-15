# 26. Build, publish, and deploy

In this chapter you’ll learn how to turn your Avalonia project into distributable builds for each platform. You’ll understand the difference between building and publishing, how to choose the right runtime identifier (RID), and how to ship self‑contained, single‑file, and trimmed builds responsibly.

What you’ll learn
- Build vs publish in .NET and why Release builds matter
- Runtime identifiers (RID) and cross‑platform publishing
- Framework‑dependent vs self‑contained builds
- Single‑file, ReadyToRun, and trimming options (and their trade‑offs)
- Where files land, how to run them, and what to test before shipping

Build vs publish (in plain words)
- Build compiles your project into assemblies for running from your dev box. Publish creates a folder you can copy to a target machine and run there (optionally without installing .NET).
- Always test performance and behavior with Release builds. Debug builds include extra checks and are slower.

Runtime identifiers (RIDs) you’ll actually use
- Windows: win‑x64, win‑arm64
- macOS: osx‑x64 (Intel), osx‑arm64 (Apple Silicon)
- Linux: linux‑x64, linux‑arm64
- Pick the RID(s) your users need. You can publish multiple variants.

Framework‑dependent vs self‑contained
- Framework‑dependent: smaller download; requires the correct .NET runtime to be installed on the target machine.
- Self‑contained: includes the .NET runtime; larger download; runs on machines without .NET installed. Recommended for consumer apps to reduce support friction.

Common publish layouts and options
- Minimal framework‑dependent build:
  - dotnet publish -c Release -r win-x64 --self-contained false
- Self‑contained build:
  - dotnet publish -c Release -r osx-arm64 --self-contained true
- Single‑file (packs your app into one executable and a few support files as needed):
  - dotnet publish -c Release -r linux-x64 /p:SelfContained=true /p:PublishSingleFile=true
- ReadyToRun (improves startup by precompiling IL to native code; increases size):
  - dotnet publish -c Release -r win-x64 /p:SelfContained=true /p:PublishReadyToRun=true
- Trimming (reduces size by removing unused code; use with care due to reflection and data binding):
  - dotnet publish -c Release -r osx-arm64 /p:SelfContained=true /p:PublishTrimmed=true

Trade‑offs and cautions
- Single‑file may still extract native libraries to a temp folder on first run; measure startup and disk impact.
- ReadyToRun boosts cold start but can make binaries larger; verify for your app size/benefit.
- Trimming can remove types used via reflection (including XAML/bindings). Test thoroughly; avoid trimming until you verify that everything works, or add preservation hints incrementally. Start without trimming, then iterate.

Where to find your output
- After publishing, look under bin/Release/<targetframework>/<rid>/publish. For example:
  - bin/Release/net8.0/win-x64/publish
  - bin/Release/net8.0/osx-arm64/publish
  - bin/Release/net8.0/linux-x64/publish
- Run your app directly from that publish folder on a matching OS/CPU.

Platform notes (high‑level)
- Windows: a signed self‑contained single‑file EXE is a simple way to distribute. For enterprise or store delivery, consider installer packages (MSIX/MSI) and code signing.
- macOS: you’ll likely want an app bundle (.app) and code signing/notarization for a smooth Gatekeeper experience. For development, you can run the published binary; for distribution, follow Apple’s signing guidance.
- Linux: many users are comfortable with a tar.gz of your publish folder. For a desktop‑native feel, consider packaging systems like AppImage, Flatpak, or Snap used by various distros.

Quality checklist before shipping
- Publish in Release for each RID you plan to support.
- Run the app on real target machines (or VMs) for each platform. Verify rendering, fonts, DPI, file dialogs, and hardware acceleration behave as expected.
- Check that resources (images, styles, fonts) load correctly from the publish folder.
- If you use single‑file or trimming, exercise all major screens and dynamic features (templates, reflection, localization).
- If you ship self‑contained, verify size is acceptable and startup times are reasonable.

Troubleshooting
- Missing dependencies on Linux: install common desktop libraries (font and ICU packages). If the app starts only from a terminal with errors, note missing libraries and install them via your distro’s package manager.
- Crashes only in Release: ensure you aren’t relying on Debug‑only conditions, and remove dev‑only code paths. Enable logging to a file during testing to capture issues.
- Graphics differences: different GPUs/drivers can affect performance. Test with integrated and discrete GPUs where possible.
- File associations and icons: packaging systems (MSIX, app bundles, AppImage/Flatpak) handle these better than raw folders. Plan packaging early if you need OS integration.

Look under the hood (docs and sources)
- Build and guidance in the Avalonia repo docs:
  - [docs/build.md](https://github.com/AvaloniaUI/Avalonia/blob/master/docs/build.md)
- Samples you can build and publish for reference:
   - [samples/ControlCatalog](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog)
   - [samples](https://github.com/AvaloniaUI/Avalonia/tree/master/samples)

Exercise: Publish and run your app
1) Publish a self‑contained build for your current OS RID with single‑file enabled. Locate the publish folder and run the app directly from there.
2) Repeat for a second RID (e.g., win‑x64 or linux‑x64). If you can’t run it locally, copy it to a matching machine/VM and test.
3) Note the publish size and startup time with and without PublishSingleFile/ReadyToRun. Keep the variant that best balances size and speed for your audience.

What’s next
- Next: [Chapter 27](Chapter27.md)
