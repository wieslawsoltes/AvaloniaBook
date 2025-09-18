# 27. Read the source, contribute, and grow

This final chapter is an invitation to go beyond this book. Reading real framework code deepens your understanding, contributing makes you a better engineer, and engaging with the community helps you stay current and grow.

What you’ll learn in this chapter
- How to navigate the Avalonia source tree and build it locally
- Where to look in the code when you want to understand a feature
- Practical tips for stepping into framework sources while debugging your app
- How to file great issues and contribute high‑quality pull requests
- How to contribute to documentation and samples
- Ways to stay involved and keep learning

Why read the source
- Solidify mental models: reading implementation details clarifies how layout, input, rendering, and styling actually work in practice.
- Improve debugging: once you know where code lives, you can step into it confidently and diagnose tricky problems.
- Contribute fixes and features: you’ll be able to propose targeted improvements with realistic scope.

Tour the repository (what to look for)
- Core sources and platform code
  - [src](https://github.com/AvaloniaUI/Avalonia/tree/master/src)
  - You’ll find core assemblies (e.g., Base, Controls, Diagnostics, Skia, etc.) here. Browse folders to see how subsystems are organized.
- Tests
  - [tests](https://github.com/AvaloniaUI/Avalonia/tree/master/tests)
  - Tests are a goldmine for learning: they capture expected behaviors and edge cases. When adding features or fixing bugs, add or update tests here.
- Samples
  - [samples](https://github.com/AvaloniaUI/Avalonia/tree/master/samples)
  - Run and read samples (like the Control Catalog) to see idiomatic patterns and verify changes.
- Project guidance
  - [CONTRIBUTING.md](https://github.com/AvaloniaUI/Avalonia/blob/master/CONTRIBUTING.md)
  - [CODE_OF_CONDUCT.md](https://github.com/AvaloniaUI/Avalonia/blob/master/CODE_OF_CONDUCT.md)
  - [readme.md](https://github.com/AvaloniaUI/Avalonia/blob/master/readme.md)
- Documentation site (source)
  - [avalonia-docs/docs](https://github.com/AvaloniaUI/avalonia-docs/tree/master/docs)
  - If you enjoy writing, this is where you can improve official docs, tutorials, and guides.

Build the framework locally
- Scripts for building on your OS are in the repo root:
  - [build.ps1](https://github.com/AvaloniaUI/Avalonia/blob/master/build.ps1)
  - [build.sh](https://github.com/AvaloniaUI/Avalonia/blob/master/build.sh)
  - [build.cmd](https://github.com/AvaloniaUI/Avalonia/blob/master/build.cmd)
- You can also open the solution to explore and build individual projects:
  - [Avalonia.sln](https://github.com/AvaloniaUI/Avalonia/blob/master/Avalonia.sln)
- Run a sample to verify your environment:
  - Control Catalog: [samples/ControlCatalog](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog)

Read with purpose: where to look for…
- Logging and diagnostics
  - [LoggingExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Logging/LoggingExtensions.cs)
  - [DevToolsExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/DevTools/DevToolsExtensions.cs)
  - [RendererDebugOverlays.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Rendering/RendererDebugOverlays.cs)
- Design mode and previewing
  - [Design.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Design/Design.cs)
- Rendering and options
  - Skia options and rendering backends live under Skia/ and platform rendering folders in [src](https://github.com/AvaloniaUI/Avalonia/tree/master/src).
- Controls and styling
  - Controls and styles are under Controls/ with templates/resources organized alongside. Tests illustrate expected styling behaviors in the tests tree.

Step into sources while debugging your app
- Enable stepping into external code and include debug symbols for framework assemblies when possible. This lets you follow execution into Avalonia internals.
- Start from your call site (e.g., a control event handler) and step forward to see how data flows through layout, rendering, or input.
- Keep the DevTools open during debugging to correlate what you see in the tree/overlays with the code paths you step through.

File great issues (and get faster resolutions)
- Always include a minimal repro: the smallest sample that demonstrates the bug. Link to a repository or attach a tiny project.
- Specify platform(s), .NET version, Avalonia version, and whether the problem reproduces in Release.
- Add screenshots or screen recordings when visual behavior is involved, and note any debug overlays or DevTools findings.
- Be precise about expected vs. actual behavior and list steps to reproduce.

Contribute high‑quality pull requests
- Keep scope focused and change sets small. Smaller PRs review faster and are easier to merge.
- Add tests in [tests](https://github.com/AvaloniaUI/Avalonia/tree/master/tests) that cover the fix or feature. Tests protect your change and prevent regressions.
- Follow project guidance:
- [CONTRIBUTING.md](https://github.com/AvaloniaUI/Avalonia/blob/master/CONTRIBUTING.md)
  - Match coding style and file organization used in neighboring files.
- Explain your approach in the PR description, reference related issues, and call out trade‑offs or follow‑ups.
- Be responsive to review feedback; maintainers and contributors are collaborators.

Contribute to documentation and samples
- Docs live in [avalonia-docs/docs](https://github.com/AvaloniaUI/avalonia-docs/tree/master/docs). Improvements to conceptual docs, guides, and API explanations are always valuable.
- Samples live in [samples](https://github.com/AvaloniaUI/Avalonia/tree/master/samples). New focused samples that illustrate tricky scenarios are welcomed.
- When you fix a bug or add a feature, consider also updating docs and adding a small sample demonstrating it.

Grow with the community
- Start by reading the project [readme.md](https://github.com/AvaloniaUI/Avalonia/blob/master/readme.md) and contribution docs to learn how the community organizes work.
- Look for labels like “good first issue” to find beginner‑friendly tasks. If you’re unsure, ask in the issue before starting.
- Share knowledge: blog, speak, or help answer questions in community channels listed in the repository’s README.

Checklist for sustainable contributions
- Can you reproduce the issue consistently with a minimal sample?
- Do tests cover your change, including edge cases?
- Did you benchmark or measure performance when relevant?
- Did you run samples across platforms that your change touches?
- Did you update docs and samples where appropriate?

Exercise: Follow a feature from UI to rendering
- Pick a simple visual element (e.g., Border, TextBlock) in the Control Catalog sample.
- Set a breakpoint in your app code where you configure it.
- Step into the framework source and trace how it measures, arranges, and renders.
- Locate associated tests and read their assertions.
- Make a tiny change locally (e.g., add a comment or an extra test) to practice the contribution workflow.

What’s next
- Back to [Table of Contents](../Index.md)
