# 3. Your first UI: layouts, controls, and XAML basics

Goal
- Build your first real window using common controls and two core layout panels.
- Learn the XAML you’ll write most often (attributes, nesting, simple resources).
- Run, resize, and understand how layout adapts.

What you’ll build
- A window with a title, some text, a button that updates text, and a simple form laid out with Grid.
- You’ll see how StackPanel and Grid work together and how controls size themselves.

Prerequisites
- You’ve completed Chapter 2 and can create and run a new Avalonia app.

Step-by-step
1) Create a new app
- In a terminal: dotnet new avalonia.app -o HelloLayouts
- Open the project in your IDE, then run it (dotnet run) to verify it starts.

2) Replace MainWindow content with basic UI
- Open MainWindow.axaml and replace the inner content of <Window> with this:

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="HelloLayouts.MainWindow"
        Width="500" Height="360"
        Title="Hello, Avalonia!">
  <StackPanel Margin="16" Spacing="12">
    <TextBlock Classes="h1" Text="Your first UI"/>

    <TextBlock x:Name="CounterText" Text="You clicked 0 times."/>
    <Button x:Name="CounterButton"
            Width="140"
            Content="Click me"
            Click="CounterButton_OnClick"/>

    <Border Background="{DynamicResource ThemeAccentBrush}"
            CornerRadius="6" Padding="12">
      <TextBlock Foreground="White" Text="Inside a Border"/>
    </Border>

    <Grid ColumnDefinitions="Auto,*" RowDefinitions="Auto,Auto" Margin="0,8,0,0">
      <TextBlock Text="Name:" Margin="0,0,8,8"/>
      <TextBox Grid.Column="1" Width="240"/>

      <TextBlock Grid.Row="1" Text="Email:" Margin="0,0,8,0"/>
      <TextBox Grid.Row="1" Grid.Column="1" Width="240"/>
    </Grid>
  </StackPanel>
</Window>
```

- Save. Your previewer (if enabled in your IDE) should refresh. Otherwise, run the app to see the layout.

3) Wire up a simple event in code-behind
- Open MainWindow.axaml.cs and add this method and field:

```csharp
using Avalonia.Controls;       // for TextBlock, Button
using Avalonia.Interactivity;  // for RoutedEventArgs

private int _count;
private TextBlock? _counterText;

public MainWindow()
{
    InitializeComponent();
    _counterText = this.FindControl<TextBlock>("CounterText");
}

private void CounterButton_OnClick(object? sender, RoutedEventArgs e)
{
    _count++;
    if (_counterText is not null)
        _counterText.Text = $"You clicked {_count} times.";
}
```

- Build and run. Click the button—your text updates. This is a tiny taste of events; MVVM and bindings come later.

4) XAML basics you just used
- Nesting: Panels (like StackPanel and Grid) contain other controls.
- Attributes: Properties like Margin, Spacing, Width are set as attributes.
- Attached properties: Grid.Row and Grid.Column are attached properties that apply to children inside a Grid.
- Resources: {DynamicResource ThemeAccentBrush} pulls a color from the current theme.

5) Layout in plain words
- StackPanel lays out children in a single line (vertical by default) and gives each its desired size.
- Grid gives you rows and columns. Use Auto for “size to content,” * for “take the rest,” and numbers like 2* for proportional sizing.
- Most controls size to their content by default. Add Margin for space around, and Padding for space inside containers.

6) Run and resize
- Resize the window. Notice TextBox stretches in the Grid’s second column while labels stay Auto-sized in the first column.

Check yourself
- Can you add another row to the Grid for a “Phone” field?
- Can you put the button above the Border by moving it earlier in the StackPanel?
- Can you make the button stretch horizontally (set HorizontalAlignment="Stretch")?
- Do Tab key presses move focus between fields in the expected order?

Look under the hood (optional)
- Controls live here: [Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- Themes (Fluent): [Avalonia.Themes.Fluent](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent)
- Explore the ControlCatalog sample: [samples/ControlCatalog](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog)

Extra practice
- Add a DockPanel with a top bar (a TextBlock) and the rest filled with your StackPanel using DockPanel.Dock.
- Replace StackPanel with a Grid-only layout: two rows (title on top, content below), and columns inside the content row.
- Try WrapPanel for a row of buttons that wrap on small widths.

```tip
If the Previewer isn’t available in your IDE, just build and run often. Fast feedback is what matters.
```

What’s next
- Next: [Chapter 4](Chapter04.md)
