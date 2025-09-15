# 2. Set up tools and build your first project

Goal
- Install the tools you need.
- Create a new Avalonia app from a template.
- Build and run it on your machine.
- Understand the key files that were generated.

What you need (pick one IDE)
- Visual Studio (Windows) with “.NET desktop development” workload
- JetBrains Rider (Windows/macOS/Linux)
- Visual Studio Code (Windows/macOS/Linux) + C# extension

Also needed
- .NET SDK installed (use the latest stable SDK). If the “dotnet” command works in your terminal, you’re good.

Install Avalonia project templates
- This gives you “dotnet new” templates for Avalonia projects.

```bash
dotnet new install Avalonia.Templates
```

Create your first app
- We’ll use the basic desktop app template.

```bash
# Create a new folder with a project inside
dotnet new avalonia.app -o HelloAvalonia

# Go into the project folder
cd HelloAvalonia
```

Build and run
- These commands work on Windows, macOS, and Linux.

```bash
# Restore packages and build
dotnet build

# Run the app
dotnet run
```

You should see a window open with a simple UI. Close it when you are done.

Open the project in your IDE
- Open the HelloAvalonia folder in your IDE.
- You can also press the “Run” button in the IDE instead of using the terminal.

A quick tour of the files
- HelloAvalonia.csproj: the project file. It lists NuGet packages and target frameworks.
- Program.cs: the entry point. It configures Avalonia and starts the app.
- App.axaml and App.axaml.cs: application resources and startup setup.
- MainWindow.axaml and MainWindow.axaml.cs: your first window (the main View) and its code-behind.

Peek inside Program.cs (what it does)
- It creates an AppBuilder, sets up the platform and renderer, and starts a desktop lifetime with a main window.
- We will learn AppBuilder and lifetimes in Chapter 4. For now, just know: this is where the app starts.

Make a tiny change (to see it’s real)
- Open MainWindow.axaml.
- Change the Title attribute and add a TextBlock inside the layout.

Example
```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="HelloAvalonia.MainWindow"
        Title="Hello Avalonia!">
  <StackPanel Margin="16">
    <TextBlock Text="It works!" FontSize="24"/>
    <Button Content="Click me" Margin="0,12,0,0"/>
  </StackPanel>
</Window>
```

Run again
```bash
dotnet run
```
- You should see the new title and the text/button you added.

Common template choices (for later)
- avalonia.app: minimal app, code-behind pattern (what we used).
- avalonia.mvvm: MVVM-friendly skeleton without ReactiveUI.
- avalonia.reactiveui: MVVM with ReactiveUI helpers.

Troubleshooting
- “dotnet” not found: install the .NET SDK and restart your terminal/IDE.
- Restore/build errors: run “dotnet restore” then “dotnet build” to see details.
- Window doesn’t show: ensure you ran from inside the project folder; check the terminal output for errors.

Check yourself
- Can you create a new Avalonia app with one command?
- Do you know what Program.cs and App.axaml are responsible for?
- Can you change a window title in XAML and see the change when you run?

Extra practice
- Add another TextBlock and change its FontSize and Foreground.
- Add a second Button. Try changing Margin and Padding to see layout effects.

What’s next
- Next: [Chapter 3](Chapter03.md)
