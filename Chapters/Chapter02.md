# 2. Set up tools and build your first project

Goal
- Install the .NET SDK, Avalonia templates, and an IDE on your operating system of choice.
- Configure optional workloads (Android, iOS, WebAssembly) so you are ready for multi-target development.
- Create, build, and run a new Avalonia project from the command line and from your IDE.
- Understand the generated project structure and where startup, resources, and build targets live.
- Build the Avalonia framework from source when you need nightly features or to debug the platform.

Why this matters
- A confident setup avoids painful environment issues later when you add mobile or browser targets.
- Knowing where the generated files live prepares you for upcoming chapters on layout, lifetimes, and MVVM.
- Building the framework from source lets you test bug fixes, follow development, and debug into the toolkit.

## Prerequisites by operating system

### Windows
- Install the latest **.NET SDK** (x64) from <https://dotnet.microsoft.com/download>.
- Install **Visual Studio 2022** with the ".NET desktop development" workload; add ".NET Multi-platform App UI development" for mobile tooling.
- Optional: `winget install --id Microsoft.DotNet.SDK.8` (replace with the current LTS) and install the **Windows Subsystem for Linux** if you plan to test Linux packages.

### macOS
- Install the latest **.NET SDK (Arm64 or x64)** from Microsoft.
- Install **Xcode** (App Store) to satisfy iOS build prerequisites.
- Recommended IDEs: **JetBrains Rider**, **Visual Studio 2022 for Mac** (if installed), or **Visual Studio Code** with the C# Dev Kit.
- Optional: install **Homebrew** and use it for `brew install dotnet-sdk` to keep versions updated.

### Linux (Ubuntu/Debian example)
- Add the Microsoft package feed and install the latest **.NET SDK** (`sudo apt install dotnet-sdk-8.0`).
- Install an IDE: **Rider** or **Visual Studio Code** with the C# extension (OmniSharp or C# Dev Kit).
- Ensure GTK dependencies are present (`sudo apt install libgtk-3-0 libwebkit2gtk-4.1-0`) because the ControlCatalog sample relies on them.

> Verify your SDK installation:
>
> ```bash
> dotnet --version
> dotnet --list-sdks
> ```
>
> Make sure the Avalonia-supported SDK (currently .NET 8.x for Avalonia 11) appears in the list before moving on.

## Optional workloads for advanced targets

Run these commands only if you plan to target additional platforms soon (you can add them later):

```bash
dotnet workload install wasm-tools      # Browser (WebAssembly)
dotnet workload install android         # Android toolchain
dotnet workload install ios             # iOS/macOS Catalyst toolchain
```

If a workload fails, run `dotnet workload repair` and confirm your IDE also installed the Android/iOS dependencies (Android SDK Managers, Xcode command-line tools).

## Recommended IDE setup

### Visual Studio 2022 (Windows)
- Ensure the **Avalonia for Visual Studio** extension is installed (Marketplace) for XAML IntelliSense and the previewer.
- Enable **XAML Hot Reload** under Tools -> Options -> Debugging -> General.
- For Android/iOS, open Visual Studio Installer and add the corresponding mobile workloads.

### JetBrains Rider
- Install the **Avalonia plugin** (File -> Settings -> Plugins -> Marketplace -> search "Avalonia").
- Enable the built-in XAML previewer via `View -> Tool Windows -> Avalonia Previewer`.
- Configure Android SDKs under Preferences -> Build Tools if you plan to run Android projects.

### Visual Studio Code
- Install the **C# Dev Kit** or **C# (OmniSharp)** extension for IntelliSense and debugging.
- Add the **Avalonia for VS Code** extension for XAML tooling and preview.
- Configure `dotnet watch` tasks or use the Avalonia preview extension's Live Preview panel.

## Install Avalonia project templates

```bash
dotnet new install Avalonia.Templates
```

This adds templates such as `avalonia.app`, `avalonia.mvvm`, `avalonia.reactiveui`, and `avalonia.xplat`.

Verify installation:

```bash
dotnet new list avalonia
```

You should see a table of available Avalonia templates.

## Create and run your first project (CLI-first flow)

```bash
# Create a new solution folder
mkdir HelloAvalonia && cd HelloAvalonia

# Scaffold a desktop app template (code-behind pattern)
dotnet new avalonia.app -o HelloAvalonia.Desktop

cd HelloAvalonia.Desktop

# Restore packages and build
dotnet build

# Run the app
dotnet run
```

A starter window appears. Close it when done.

### Alternative templates
- `dotnet new avalonia.mvvm -o HelloAvalonia.Mvvm` -> includes a ViewModel base class and data-binding sample.
- `dotnet new avalonia.reactiveui -o HelloAvalonia.ReactiveUI` -> adds ReactiveUI integration out of the box.
- `dotnet new avalonia.app --multiplatform -o HelloAvalonia.Multi` -> single-project layout with mobile/browser heads.

## Open the project in your IDE

### Visual Studio
1. File -> Open -> Project/Solution -> select `HelloAvalonia.Desktop.csproj`.
2. Press **F5** (or the green Run arrow) to launch with the debugger.
3. Verify XAML Hot Reload by editing `MainWindow.axaml` while the app runs.

### Rider
1. File -> Open -> choose the solution folder.
2. Use the top-right run configuration to run/debug.
3. Open the Avalonia Previewer tool window to see live XAML updates.

### VS Code
1. `code .` inside the project directory.
2. Accept the prompt to add build/debug assets; VS Code generates `launch.json` and `.vscode/tasks.json`.
3. Use the Run and Debug panel (F5) and the Avalonia preview extension for live previews.

## Generated project tour (why each file matters)
- `HelloAvalonia.Desktop.csproj`: project metadata--target frameworks, NuGet packages, Avalonia build tasks (`Avalonia.Build.Tasks` compiles XAML to BAML-like assets; see [CompileAvaloniaXamlTask.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Build.Tasks/CompileAvaloniaXamlTask.cs)).
- `Program.cs`: entry point returning `BuildAvaloniaApp()`. Calls `UsePlatformDetect`, `UseSkia`, `LogToTrace`, and starts the classic desktop lifetime (definition in [AppBuilderDesktopExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs)).
- `App.axaml` / `App.axaml.cs`: global resources and startup logic. `App.OnFrameworkInitializationCompleted` creates and shows `MainWindow` (implementation defined in [Application.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Application.cs)).
- `MainWindow.axaml` / `.axaml.cs`: your initial view. XAML is loaded by [AvaloniaXamlLoader](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs).
- `Assets/` and `Styles/`: sample resource dictionaries you can expand later.

## Make a visible change and rerun

```xml

<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="HelloAvalonia.MainWindow"
        Width="400" Height="260"
        Title="Hello Avalonia!">
  <StackPanel Margin="16" Spacing="12">
    <TextBlock Text="It works!" FontSize="24"/>
    <Button Content="Click me" HorizontalAlignment="Left"/>
  </StackPanel>
</Window>
```

Rebuild and run (`dotnet run` or IDE Run) to confirm the change.

## Troubleshooting checklist
- **`dotnet` command missing**: reinstall the .NET SDK and restart the terminal/IDE. Confirm environment variables (`PATH`) include the dotnet installation path.
- **Template not found**: rerun `dotnet new install Avalonia.Templates` or remove outdated versions with `dotnet new uninstall Avalonia.Templates`.
- **NuGet restore issues**: clear caches (`dotnet nuget locals all --clear`), ensure internet access or configure an offline mirror, then rerun `dotnet restore`.
- **Workload errors**: run `dotnet workload repair`. Ensure Visual Studio or Xcode installed the matching tooling.
- **IDE previewer fails**: confirm the Avalonia extension/plugin is installed, build the project once, and check the Output window for loader errors.
- **Runtime missing native dependencies** (Linux): install GTK, Skia, and OpenGL packages (`libmesa`, `libx11-dev`).

## Build Avalonia from source (optional but recommended once)
- Clone the framework: `git clone https://github.com/AvaloniaUI/Avalonia.git`.
- Initialise submodules if prompted: `git submodule update --init --recursive`.
- On Windows: run `.\build.ps1 -Target Build`.
- On macOS/Linux: run `./build.sh --target=Build`.
- Docs reference: [docs/build.md](https://github.com/AvaloniaUI/Avalonia/blob/master/docs/build.md).
- Launch the ControlCatalog from source: `dotnet run --project samples/ControlCatalog.Desktop/ControlCatalog.Desktop.csproj`.

Building from source gives you binaries with the latest commits, useful for testing fixes or contributing.

## Practice and validation
1. Confirm your environment with `dotnet --list-sdks` and `dotnet workload list`.
2. Install the Avalonia templates and scaffold a new project.
3. Run the app from the CLI and from your IDE, verifying hot reload or the previewer works.
4. Clone the Avalonia repo, build it, and run the ControlCatalog sample.
5. Set a breakpoint in `App.axaml.cs` (`OnFrameworkInitializationCompleted`) and step through startup to watch the lifetime initialise.

## Look under the hood (source bookmarks)
- Build pipeline tasks: [src/Avalonia.Build.Tasks](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Build.Tasks).
- Desktop lifetime helpers: [src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Desktop/AppBuilderDesktopExtensions.cs).
- ControlCatalog project: [samples/ControlCatalog/ControlCatalog.csproj](https://github.com/AvaloniaUI/Avalonia/blob/master/samples/ControlCatalog/ControlCatalog.csproj).
- Framework application startup: [src/Avalonia.Controls/Application.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Application.cs).

## Check yourself
- Which command installs Avalonia templates and how do you verify the install?
- How do you list installed .NET SDKs and workloads?
- Where does `App.OnFrameworkInitializationCompleted` live and what does it do?
- Which files control project startup, resources, and views in a new template?
- What steps are required to build Avalonia from source on your OS?

What's next
- Next: [Chapter 3](Chapter03.md)
