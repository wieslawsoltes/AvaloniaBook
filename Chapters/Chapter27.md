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

Avalonia repo:
- Core source: [`src/`](https://github.com/AvaloniaUI/Avalonia/tree/master/src)
  - `Avalonia.Base`, `Avalonia.Controls`, `Avalonia.Markup.Xaml`, `Avalonia.Diagnostics`, platform folders (`Android`, `iOS`, `Browser`, `Skia`).
- Tests: [`tests/`](https://github.com/AvaloniaUI/Avalonia/tree/master/tests)
  - Unit/integration/headless tests. Read tests to understand expected behavior and edge cases.
- Samples: [`samples/`](https://github.com/AvaloniaUI/Avalonia/tree/master/samples)
  - ControlCatalog, BindingDemo, ReactiveUIDemo, etc. Useful for debugging/regressions.
- Docs: [`docs/`](https://github.com/AvaloniaUI/Avalonia/tree/master/docs) coupled with the [avalonia-docs](https://github.com/AvaloniaUI/avalonia-docs) site.
- Contribution guidelines: [`CONTRIBUTING.md`](https://github.com/AvaloniaUI/Avalonia/blob/master/CONTRIBUTING.md), [`CODE_OF_CONDUCT.md`](https://github.com/AvaloniaUI/Avalonia/blob/master/CODE_OF_CONDUCT.md).

## 2. Building the framework locally

Scripts in repo root:
- `build.ps1` (Windows), `build.sh` (Unix), `build.cmd`.
- These restore NuGet packages, compile, run tests (optionally), and produce packages.

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

## 3. Reading source with purpose

Common entry points:
- Controls/styling: `src/Avalonia.Controls/` (Control classes, templates, themes).
- Layout: `src/Avalonia.Base/Layout/` (Measurement/arrange logic).
- Rendering: `src/Avalonia.Base/Rendering/`, `src/Skia/Avalonia.Skia/`.
- Input: `src/Avalonia.Base/Input/` (Pointer, keyboard, gesture recognizers).

Use IDE features (Go to Definition, Find Usages) to jump between user code and framework internals.

## 4. Debugging into Avalonia

- Enable symbol loading for Avalonia assemblies (packaged symbols or local build).
- In Visual Studio/Rider: enable "Allow step into external code". Add `src` folder as source path.
- Set breakpoints in your app, step into framework code to inspect layout/renderer behavior.
- Combine with DevTools overlays to correlate visual state with code paths.

## 5. Filing issues

Best practice checklist:
- Minimal reproducible sample (GitHub repo, .zip, or steps to recreate with ControlCatalog).
- Include platform(s), .NET version, Avalonia version, self-contained vs framework-dependent.
- Summarize expected vs actual behavior. Provide logs (Binding/Layout/Render) or screenshot/video when relevant.
- Tag regression vs new bug; mention if release-only or debug-only.

## 6. Contributing pull requests

Steps:
1. Check CONTRIBUTING.md for branching/style.
2. Fork repo, create feature branch.
3. Implement change (small, focused scope).
4. Add/update tests under `tests/` (headless tests for controls, unit tests for logic).
5. Run `dotnet build` and `dotnet test` (possibly `build.ps1 -Target Test`).
6. Update docs/samples if behavior changed.
7. Submit PR with clear description, referencing issue IDs/sites.
8. Respond to feedback promptly.

### Writing tests
- Use headless tests for visual/interaction behavior (Chapter 21 covers pattern).
- Add regression tests for fixed bugs to prevent future breakage.
- Consider measuring performance (BenchmarkDotNet) if change affects rendering/layout.

## 7. Docs & sample contributions

- Docs source: [avalonia-docs repository](https://github.com/AvaloniaUI/avalonia-docs).
  - Submit PRs with improved content/instructions/examples.
- Samples: add new sample to `samples/` illustrating advanced patterns or new controls.
- Keep docs in sync with code changes for features/bug fixes.

## 8. Community & learning

- GitHub discussions: [AvaloniaUI discussions](https://github.com/AvaloniaUI/Avalonia/discussions).
- Discord community: link in README.
- Follow release notes and blog posts for new features (subscribe to repo releases).
- Speak at meetups, write blog posts, or answer questions to grow visibility and knowledge.

## 9. Sustainable contribution workflow

Checklist before submitting work:
- [ ] Reproduced issue with minimal sample.
- [ ] Wrote or updated tests covering change.
- [ ] Verified on all affected platforms (Windows/macOS/Linux/Mobile/Browser where applicable).
- [ ] Performance measured if relevant.
- [ ] Docs/samples updated.

## 10. Practice exercises

1. Clone Avalonia repo, run `build.ps1` (or `build.sh`), and launch ControlCatalog. Inspect the code for one control you use frequently.
2. Set up symbol/source mapping in your IDE and step into `TextBlock` rendering while running ControlCatalog.
3. File a sample issue in a sandbox repo (practice minimal repro). Outline expected vs actual behavior clearly.
4. Write a headless unit test for a simple control (e.g., verifying a custom control draws expected output) and run it locally.
5. Pick an area of docs that needs improvement (e.g., design-time tooling) and draft a doc update in the avalonia-docs repo.

## Look under the hood (source bookmarks)
- Repo root: [github.com/AvaloniaUI/Avalonia](https://github.com/AvaloniaUI/Avalonia)
- Build scripts: [`build.ps1`](https://github.com/AvaloniaUI/Avalonia/blob/master/build.ps1), [`build.sh`](https://github.com/AvaloniaUI/Avalonia/blob/master/build.sh)
- Issue templates: `.github/ISSUE_TEMPLATE` directory (bug/feature request).
- PR template: `.github/pull_request_template.md`.

## Check yourself
- Where do you find tests or samples relevant to a control you're debugging?
- How do you step into Avalonia sources from your app?
- What makes a strong issue/PR description?
- How can you contribute documentation or samples beyond code?
- Which community channels help you stay informed about releases and roadmap?

What's next
- Next: [Chapter28](Chapter28.md)
