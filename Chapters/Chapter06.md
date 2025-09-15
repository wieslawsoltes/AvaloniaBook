# 6. Controls tour you’ll actually use

Goal
- Get comfortable with everyday controls: TextBlock/TextBox, Button, CheckBox/RadioButton, ComboBox, ListBox, Slider, ProgressBar, DatePicker, and more.
- Learn simple properties that make them useful right away.
- Explore ControlCatalog to see each control in action.

Why this matters
- You’ll use these controls constantly; knowing their basics speeds up every screen you build.

Prerequisites
- You’ve built small UIs from Chapters 3–5 and can run your app.

Quick tour by example
1) Text and inputs

```xml
<StackPanel Spacing="8">
  <TextBlock Classes="h1" Text="Controls tour"/>
  <TextBlock Text="TextBlock shows read‑only text"/>
  <TextBox Watermark="Type here..."/>
  <PasswordBox PasswordChar="•"/>
</StackPanel>
```

- TextBlock is for read-only text; TextBox for text input. Watermark shows a hint when empty.
- PasswordBox masks input. Use bindings later for MVVM.

2) Buttons and toggles

```xml
<StackPanel Orientation="Horizontal" Spacing="8">
  <Button Content="Primary"/>
  <ToggleButton Content="Toggle me"/>
  <CheckBox Content="I agree"/>
  <StackPanel DataContext="{x:Static Enum:MyEnum}">
    <!-- RadioButtons are typically grouped by container and bound to a value -->
    <RadioButton Content="Option A" GroupName="Choice"/>
    <RadioButton Content="Option B" GroupName="Choice"/>
  </StackPanel>
</StackPanel>
```

- ToggleButton stays pressed when toggled. CheckBox is on/off. RadioButtons are mutually exclusive per GroupName.

3) Choices and lists

```xml
<StackPanel Spacing="8">
  <ComboBox PlaceholderText="Pick one">
    <ComboBoxItem Content="Red"/>
    <ComboBoxItem Content="Green"/>
    <ComboBoxItem Content="Blue"/>
  </ComboBox>

  <ListBox Height="120">
    <ListBoxItem Content="Item 1"/>
    <ListBoxItem Content="Item 2"/>
    <ListBoxItem Content="Item 3"/>
  </ListBox>
</StackPanel>
```

- ComboBox renders a dropdown; ListBox renders a vertical list. Later you’ll use ItemsSource and DataTemplates for real data.

4) Sliders, progress, and pickers

```xml
<StackPanel Spacing="8" Orientation="Horizontal" VerticalAlignment="Center">
  <TextBlock Text="Volume" Margin="0,0,8,0"/>
  <Slider Width="180" Minimum="0" Maximum="100" Value="50"/>
  <ProgressBar Width="160" IsIndeterminate="True"/>
</StackPanel>

<DatePicker SelectedDate="2025-01-01"/>
```

- Slider is great for numeric ranges; ProgressBar shows progress or an indeterminate animation; DatePicker picks dates.

5) Menus, tooltips, and context menus

```xml
<DockPanel>
  <Menu DockPanel.Dock="Top">
    <MenuItem Header="File">
      <MenuItem Header="New"/>
      <MenuItem Header="Open"/>
    </MenuItem>
    <MenuItem Header="Help">
      <MenuItem Header="About"/>
    </MenuItem>
  </Menu>

  <Button Content="Right-click me" HorizontalAlignment="Center" VerticalAlignment="Center">
    <Button.ContextMenu>
      <ContextMenu>
        <MenuItem Header="Copy"/>
        <MenuItem Header="Paste"/>
      </ContextMenu>
    </Button.ContextMenu>
    <ToolTip.Tip>
      <ToolTip Content="I am a tooltip"/>
    </ToolTip.Tip>
  </Button>
</DockPanel>
```

- Menu sits at the top; ContextMenu opens on right-click; ToolTip appears on hover.

ControlCatalog tour
- Run the ControlCatalog sample to explore each control’s options and templates: [samples/ControlCatalog](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog)
- Look at XAML and toggle options to see how properties change behavior.

Check yourself
- Can you replace the ListBox with a ListBox bound to a simple list of strings (you’ll need ItemsSource and DataTemplate)?
- Can you add hotkeys to menu items (e.g., Header="_File" for mnemonic, InputGesture) and verify they work?
- Can you wire a Button Click handler to show a dialog (simple MessageBox from your IDE or custom Window)?

Look under the hood (optional)
- Controls live here: [Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- Fluent theme styles: [Avalonia.Themes.Fluent](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent)
- Input events and commands appear in later chapters; peek at RoutedCommand support in ControlCatalog.

Extra practice
- Build a small “settings” page with TextBox, CheckBox, ComboBox, and a Save button.
- Add a Slider that updates a TextBlock as you move it.
- Give the Button a ContextMenu and a ToolTip with helpful hints.

```tip
Don’t memorize every property — learn patterns. ControlCatalog is your friend when you need to explore.
```

What’s next
- Next: [Chapter 7](Chapter07.md)
