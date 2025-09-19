# 27. Read the source, contribute, and grow

Goal
- Navigate the Avalonia repo confidently, understand how to build/test locally, and contribute fixes, features, docs, or samples.
- Step into framework sources while debugging your app, and know how to file issues or PRs effectively.
- Stay engaged with the community to keep learning.

Why this matters
- Framework knowledge deepens your debugging skills and shapes better app architecture.
- Contributions improve the ecosystem and strengthen your expertise.

Prerequisites
- Familiarity with Git, .NET tooling (`dotnet build/publish/test`).

## 1. Repository tour

Avalonia repo highlights:
- Core source: [`src/`](https://github.com/AvaloniaUI/Avalonia/tree/master/src) contains assemblies such as `Avalonia.Base`, `Avalonia.Controls`, `Avalonia.Markup.Xaml`, platform heads, and backend integrations (`Skia`, `WinUI`, browser).
- Tests: [`tests/`](https://github.com/AvaloniaUI/Avalonia/tree/master/tests) mixes unit tests, headless UI tests, integration tests, and rendering verification harnesses. Tests often reveal intended behavior and edge cases.
- Samples: [`samples/`](https://github.com/AvaloniaUI/Avalonia/tree/master/samples) hosts ControlCatalog, BindingDemo, and scenario-driven apps. They double as regression repros.
- Tooling: [`build/`](https://github.com/AvaloniaUI/Avalonia/tree/master/build) and [`build/NukeBuild`](https://github.com/AvaloniaUI/Avalonia/tree/master/build/NukeBuild) power CI, packaging, and developer workflows.
- Docs: [`docs/`](https://github.com/AvaloniaUI/Avalonia/tree/master/docs) complements the separate [avalonia-docs](https://github.com/AvaloniaUI/avalonia-docs) site.
- Contributor policy: [`CONTRIBUTING.md`](https://github.com/AvaloniaUI/Avalonia/blob/master/CONTRIBUTING.md), coding conventions, and `.editorconfig` enforce consistent style (spacing, naming) across submissions.

## 2. Building the framework locally

Scripts in repo root:
- `build.ps1` (Windows), `build.sh` (Unix), `build.cmd`.
- These restore NuGet packages, compile, run tests (optionally), and produce packages.
- The repo also ships [`build/NukeBuild`](https://github.com/AvaloniaUI/Avalonia/tree/master/build/NukeBuild). Run `dotnet run --project build/NukeBuild` or `.uild.ps1 --target Test` to execute curated pipelines (`Compile`, `Test`, `Package`, etc.) identical to CI.

Manual build:

```bash
# Restore dependencies
dotnet restore Avalonia.sln

# Build core
cd src/Avalonia.Controls
dotnet build -c Debug

# Run tests
cd tests/Avalonia.Headless.UnitTests
dotnet test -c Release

# Run sample
cd samples/ControlCatalog
 dotnet run
```

Follow `docs/build.md` for environment requirements.

## 3. Testing strategy overview

Avalonia's quality gates rely on multiple test layers:
- Unit tests (`tests/Avalonia.Base.UnitTests`, etc.) validate core property system, styling, and helper utilities.
- Headless interaction tests (`tests/Avalonia.Headless.UnitTests`) simulate input/rendering without a visible window.
- Integration/UI tests leverage the `Avalonia.IntegrationTests.Appium` harness for cross-platform smoke tests.
- Performance benchmarks (look under `tests/Avalonia.Benchmarks`) measure layout, rendering, and binding regressions.

When contributing, prefer adding or updating the test nearest to the code you touch. For visual bugs, a headless interaction test plus a ControlCatalog sample usually gives maintainers confidence.

## 4. Reading source with purpose

Common entry points:
- Controls/styling: `src/Avalonia.Controls/` (Control classes, templates, themes).
- Layout: `src/Avalonia.Base/Layout/` (Measurement/arrange logic).
- Rendering: `src/Avalonia.Base/Rendering/`, `src/Skia/Avalonia.Skia/`.
- Input: `src/Avalonia.Base/Input/` (Pointer, keyboard, gesture recognizers).

Use IDE features (Go to Definition, Find Usages) to jump between user code and framework internals.

## 5. Debugging into Avalonia

- Enable symbol loading for Avalonia assemblies. NuGet packages ship SourceLink metadata—turn on "Load symbols from Microsoft symbol servers" (VS) or configure Rider's symbol caches so `.pdb` files download automatically.
- Add a fallback source path pointing at your local clone (`external/Avalonia/src`) to guarantee line numbers match when you build from source.
- Set breakpoints in your app, step into framework code to inspect layout/renderer behavior. Combine with DevTools overlays to correlate visual state with code paths.
- When debugging ControlCatalog or your own sample against a local build, reference the project outputs directly (`dotnet pack` + `nuget add source`) so you test the same bits you'll propose in a PR.

## 6. Filing issues

Best practice checklist:
- Minimal reproducible sample (GitHub repo, .zip, or steps to recreate with ControlCatalog).
- Include platform(s), .NET version, Avalonia version, self-contained vs framework-dependent.
- Summarize expected vs actual behavior. Provide logs (Binding/Layout/Render) or screenshot/video when relevant.
- Tag regression vs new bug; mention if release-only or debug-only.

## 7. Contributing pull requests

Steps:
1. Check CONTRIBUTING.md for branching/style.
2. Fork repo, create feature branch.
3. Implement change (small, focused scope).
4. Add/update tests under `tests/` (headless tests for controls, unit tests for logic).
5. Run `dotnet build` and `dotnet test` (or `.uild.ps1 --target Test` / `nuke Test`).
6. Update docs/samples if behavior changed.
7. Submit PR with clear description, referencing issue IDs/sites.
8. Respond to feedback promptly.

### Writing tests
- Use headless tests for visual/interaction behavior (Chapter 21 covers pattern).
- Add regression tests for fixed bugs to prevent future breakage.
- Consider measuring performance (BenchmarkDotNet) if change affects rendering/layout.

### Doc-only or sample-only PRs
- Target `avalonia-docs` or `docs/` when API behavior changes. Reference the code PR in your documentation PR so reviewers can coordinate releases.
- For book/doc updates that do not touch runtime code, label the PR `Documentation` and mention "no runtime changes" in the description; CI can skip heavy legs when reviewers apply the label.
- Keep screenshots or GIFs small and check them into `docs/images/` or the appropriate sample folder. Update markdown links accordingly.

## 8. Docs & sample contributions

- Docs source: [avalonia-docs repository](https://github.com/AvaloniaUI/avalonia-docs). Preview the site locally with `npm install` + `npm start` to validate links before submitting.
- In-repo docs under `docs/` explain build and architecture topics; align book/new content with these guides.
- Samples: add new sample to `samples/` illustrating advanced patterns or new controls. Update `samples/README.md` when you add something new.
- Keep docs in sync with code changes for features/bug fixes and cross-link PRs so reviewers merge them together.

## 9. Community & learning

- GitHub discussions: [AvaloniaUI discussions](https://github.com/AvaloniaUI/Avalonia/discussions).
- Discord community: link in README.
- Follow release notes and blog posts for new features (subscribe to repo releases).
- Speak at meetups, write blog posts, or answer questions to grow visibility and knowledge.

## 10. Sustainable contribution workflow

Checklist before submitting work:
- [ ] Reproduced issue with minimal sample.
- [ ] Wrote or updated tests covering change.
- [ ] Verified on all affected platforms (Windows/macOS/Linux/Mobile/Browser where applicable).
- [ ] Performance measured if relevant.
- [ ] Docs/samples updated.

## 11. Practice exercises

1. Clone the Avalonia repo and run `.uild.ps1 --target Compile` (or `dotnet run --project build/NukeBuild Compile`). Verify the build succeeds and inspect the generated artifacts.
2. Launch ControlCatalog from the sample folder, then step into the code for one control you use frequently.
3. Configure symbol/source mapping in your IDE and step into `TextBlock` rendering while running ControlCatalog.
4. File a sample issue in a sandbox repo (practice minimal repro). Outline expected vs actual behavior clearly.
5. Write a headless unit test for a simple control (e.g., verifying a custom control draws expected output) and run it locally.
6. Draft a doc-only PR in `avalonia-docs` describing a workflow you improved (link back to the code sample or issue).

## Look under the hood (source bookmarks)
- Repo root: [github.com/AvaloniaUI/Avalonia](https://github.com/AvaloniaUI/Avalonia)
- Build scripts: [`build.ps1`](https://github.com/AvaloniaUI/Avalonia/blob/master/build.ps1), [`build.sh`](https://github.com/AvaloniaUI/Avalonia/blob/master/build.sh)
- NUKE entry point: [`build/NukeBuild`](https://github.com/AvaloniaUI/Avalonia/tree/master/build/NukeBuild)
- Tests index: [`tests/`](https://github.com/AvaloniaUI/Avalonia/tree/master/tests)
- Sample gallery: [`samples/`](https://github.com/AvaloniaUI/Avalonia/tree/master/samples)
- Issue templates: `.github/ISSUE_TEMPLATE` directory (bug/feature request).
- PR template: `.github/pull_request_template.md`.

## Check yourself
- Where do you find tests or samples relevant to a control you're debugging?
- How do you step into Avalonia sources from your app?
- What makes a strong issue/PR description?
- How can you contribute documentation or samples beyond code?
- When would you reach for the NUKE build scripts instead of calling `dotnet build` directly?
- Which community channels help you stay informed about releases and roadmap?

What's next
- Next: [Chapter28](Chapter28.md)
