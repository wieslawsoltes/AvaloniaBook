# 1. Welcome to Avalonia and MVVM

Goal
- Understand what Avalonia is and why you might choose it.
- Learn the simple meanings of C#, XAML, and MVVM.
- Get a mental map of how an Avalonia app fits together.
- Know where to find things in the source code and samples.

Why this matters
- UI development is easier when you understand the main pieces. Avalonia uses C# for logic and XAML for UI markup. MVVM is the pattern that keeps your code clean and testable. Once you know these pieces, the rest of the book will feel natural.

What is Avalonia (in simple words)
- Avalonia is a cross‑platform UI framework. You write your app once, and run it on Windows, macOS, Linux, Android, iOS, and in the browser (WebAssembly).
- It is open source. It looks and feels modern. It has a wide set of controls, a Fluent theme, strong data binding, and great tooling.
- You use C# for code and XAML for the UI description. If you know WPF, you will feel at home. If you are new, you will learn with gentle steps.

Platforms you can target
- Desktop: Windows, macOS, Linux
- Mobile: Android, iOS
- Browser: WebAssembly (WASM)

What are C#, XAML, and MVVM
- C# (say “see sharp”) is the programming language you use for logic: data, commands, navigation, services, tests.
- XAML is a simple markup language for UI: you describe windows, pages, controls, layouts, and styles using readable tags.
- MVVM is a way to organize code:
  - Model: your data and core rules.
  - ViewModel: the “middle” object that exposes properties and commands for the UI.
  - View: the XAML that shows things on screen and binds to the ViewModel. The View contains no business rules.

How an Avalonia app is shaped
- App: a class that sets up your application (themes, resources, startup window).
- Views: XAML files that describe what users see (windows, pages, dialogs).
- ViewModels: C# classes that provide data and commands to the Views.
- Controls: ready‑made UI building blocks like Button, TextBox, DataGrid.
- Styles and theme: define how the app looks (colors, spacing, typography).
- Startup and lifetime: how the app starts and closes on each platform.

A simple mental picture
- App starts → sets up theme and services → opens a Window (View) → the View binds to a ViewModel → the ViewModel talks to Models/services → the UI updates automatically through bindings.

Repo and samples in this project
- Framework source (read‑only for learning): [src](https://github.com/AvaloniaUI/Avalonia/tree/master/src)
- Samples (you can run and explore): [samples](https://github.com/AvaloniaUI/Avalonia/tree/master/samples)
- Docs (build and contributor notes): [docs](https://github.com/AvaloniaUI/Avalonia/tree/master/docs)

Look inside (optional, just to get familiar)
- Controls live in: [src/Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- Fluent theme: [src/Avalonia.Themes.Fluent](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent)
- Rendering (Skia backend): [src/Skia/Avalonia.Skia](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Skia/Avalonia.Skia)
- ReactiveUI integration: [src/Avalonia.ReactiveUI](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.ReactiveUI)
- Browser target: [src/Browser](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Browser)
- Desktop helpers: [src/Avalonia.Desktop](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Desktop)

Your first “tour” (no coding yet)
1) Open the samples folder at [samples](https://github.com/AvaloniaUI/Avalonia/tree/master/samples).
2) Skim ControlCatalog projects (Desktop, Android, Browser, iOS) — see [samples/ControlCatalog](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog). These show most controls and styles. You don’t need to understand the code yet. Just remember: if you wonder “How does Button work?”, the Control Catalog shows it in action.
3) Skim [samples/BindingDemo](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/BindingDemo) and [samples/ReactiveUIDemo](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ReactiveUIDemo). These show how data binding and MVVM feel.

MVVM in plain English
- MVVM is about separation. The View is just visuals. The ViewModel exposes data (properties) and actions (commands). The Model holds your real data and rules. This separation makes testing easier and code easier to change.
- Example idea: A Counter app
  - ViewModel has a property Count and a command Increment.
  - View shows Count in a TextBlock and binds a Button to Increment.
  - When you click the Button, the ViewModel changes Count and the UI updates automatically.

About XAML (don’t worry, it’s friendly)
- XAML uses angle‑bracket tags like HTML, but it describes native controls, layout, and styles.
- You can nest panels and controls, and use attributes to set properties (like Width, Margin, Text, Items, etc.).
- With data binding, you connect XAML properties to ViewModel properties by name.

About data binding (a tiny preview)
- Binding is a link between a View property and a ViewModel property.
- If the ViewModel changes, the UI updates. If the user changes a control (like typing in a TextBox), the ViewModel can update too (depending on the binding mode).
- We will cover binding fully in Chapter 8.

Design and theming
- Avalonia ships with a Fluent theme that looks modern.
- You can tweak colors, spacing, corner radius, and styles.
- You can define reusable resources (colors, brushes, styles) and use them across the app.

Where “startup” happens (a gentle hint only)
- An Avalonia app configures itself in a builder (AppBuilder) and chooses a lifetime (desktop with windows, or single‑view for mobile).
- You’ll meet AppBuilder and lifetimes in Chapter 4. For now, just remember: that’s where the app decides what it runs on and how it opens windows.

Tooling you’ll meet later
- DevTools: inspect the visual tree and properties at runtime.
- XAML Previewer: see your UI as you type (in supported IDEs).
- Headless: run UI logic without a window for special testing scenarios.

Check yourself
- Can you explain in one sentence what Avalonia is?
- Can you name the three MVVM parts and what each one does?
- Do you know the difference between C# and XAML in an Avalonia app?
- Can you point to where controls and themes live in the repo?

Quick glossary
- App: the application entry point that configures theme, resources, and startup.
- View: the UI (XAML) that users see, such as a Window or a Page.
- ViewModel: the C# class the View binds to (data + commands, no UI code).
- Model: your domain data and rules.
- Binding: the connection between a View property and a ViewModel property.
- Command: an action you call from UI (e.g., when a Button is clicked).

Extra practice
- Explore the ControlCatalog in [samples/ControlCatalog](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog) (pick the Desktop one if unsure). Open it in your IDE, build, and run. Click around to see many controls and styles.
- Open [samples/BindingDemo](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/BindingDemo). Look for a binding in XAML and try to guess which ViewModel property it uses. You don’t need to change anything yet.

What’s next
- Next: [Chapter 2](Chapter02.md)
