# 5. Layout system without mystery

Goal
- Understand how Avalonia’s layout works in plain words (measure and arrange).
- Get comfortable with the core panels: StackPanel, Grid, DockPanel, WrapPanel.
- Learn practical sizing: star sizing, Auto, alignment, Margin vs Padding, Min/Max.

Why this matters
- Layout is the backbone of every UI; once clear, everything else is simpler.
- A small set of panels covers most real apps — you’ll combine them confidently.

Prerequisites
- You can run a basic Avalonia app and edit MainWindow.axaml (Chapters 2–3).

Mental model (no jargon)
- Parents lay out children. First, measure: the parent asks each child, “how big would you like to be within this space?” Then, arrange: the parent gives each child a final rectangle to live in.
- Content sizes to its content by default. Alignment controls how leftover space is used.
- Grid gives structure; StackPanel flows; DockPanel pins to edges; WrapPanel flows and wraps.

Step-by-step layout tour
1) Start a fresh page
- Open MainWindow.axaml and replace the inner content of <Window> with:

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="LayoutPlayground.MainWindow"
        Width="800" Height="520"
        Title="Layout Playground">
  <Grid ColumnDefinitions="*,*" RowDefinitions="Auto,*" Padding="16" RowSpacing="12" ColumnSpacing="12">
    <TextBlock Grid.ColumnSpan="2" Classes="h1" Text="Layout system without mystery"/>

    <!-- Left: StackPanel + DockPanel samples -->
    <StackPanel Grid.Row="1" Spacing="8">
      <TextBlock Classes="h2" Text="StackPanel"/>
      <Border BorderBrush="#CCC" BorderThickness="1" Padding="8">
        <StackPanel Spacing="6">
          <Button Content="Top"/>
          <Button Content="Middle"/>
          <Button Content="Bottom"/>
          <!-- Stretch the next one across -->
          <Button Content="Stretch me" HorizontalAlignment="Stretch"/>
        </StackPanel>
      </Border>

      <TextBlock Classes="h2" Text="DockPanel"/>
      <Border BorderBrush="#CCC" BorderThickness="1" Padding="8">
        <DockPanel LastChildFill="True">
          <TextBlock DockPanel.Dock="Top" Text="Top bar"/>
          <TextBlock DockPanel.Dock="Left" Text="Left" Margin="0,4,8,0"/>
          <Border Background="#F0F6FF" CornerRadius="4" Padding="8">
            <TextBlock Text="The last child fills the remaining space"/>
          </Border>
        </DockPanel>
      </Border>
    </StackPanel>

    <!-- Right: Grid + WrapPanel samples -->
    <StackPanel Grid.Column="1" Grid.Row="1" Spacing="8">
      <TextBlock Classes="h2" Text="Grid"/>
      <Border BorderBrush="#CCC" BorderThickness="1" Padding="8">
        <!-- 2 columns: label column Auto sizes to content, value column takes the rest (*) -->
        <Grid ColumnDefinitions="Auto,*" RowDefinitions="Auto,Auto,Auto" ColumnSpacing="8" RowSpacing="8">
          <TextBlock Text="Name:"/>
          <TextBox Grid.Column="1"/>

          <TextBlock Grid.Row="1" Text="Email:"/>
          <TextBox Grid.Row="1" Grid.Column="1"/>

          <!-- Proportional star sizing example: make a tall row using 2* vs * -->
          <TextBlock Grid.Row="2" Text="About:" VerticalAlignment="Top"/>
          <TextBox Grid.Row="2" Grid.Column="1" Height="80" AcceptsReturn="True"/>
        </Grid>
      </Border>

      <TextBlock Classes="h2" Text="WrapPanel"/>
      <Border BorderBrush="#CCC" BorderThickness="1" Padding="8">
        <WrapPanel ItemWidth="100" ItemHeight="32" HorizontalAlignment="Left">
          <Button Content="One"/>
          <Button Content="Two"/>
          <Button Content="Three"/>
          <Button Content="Four"/>
          <Button Content="Five"/>
          <Button Content="Six"/>
        </WrapPanel>
      </Border>
    </StackPanel>
  </Grid>
</Window>
```

- Run and resize the window. Watch StackPanel keep items in a column, DockPanel pin edges and let the last child fill, Grid align labels and stretch inputs, and WrapPanel wrap buttons to new rows when needed.

2) Alignment and sizing toolkit
- Margin vs Padding: Margin adds space outside a control; Padding adds space inside containers like Border.
- HorizontalAlignment/VerticalAlignment: Start, Center, End, Stretch. Most inputs stretch in Grid’s star column.
- Width/Height vs Min/Max: Prefer Min/Max to keep flexibility; fixed sizes can fight responsiveness.
- In Grid, Auto means “size to content.” * means “take remaining space.” 2* means “take twice the share.”

3) Common patterns
- Forms: Grid with Auto label column and * input column; use RowSpacing/ColumnSpacing for clean gaps.
- Toolbars: DockPanel with Top bar and LastChildFill content; or a Grid with star rows.
- Responsive groups: WrapPanel for chips/tags/buttons that naturally reflow.

Check yourself
- Can you swap the left/right columns by changing Grid.Column on the StackPanels?
- Can you add a third Grid column for an “Edit” button and keep inputs stretching?
- Can you make the DockPanel’s Left area wider by wrapping it in a Border with Width set?
- Can you make WrapPanel items equal width using ItemWidth, and let text wrap inside a Button?

Look under the hood (optional)
- Controls and panels live here: [Avalonia.Controls](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- Explore layout samples in ControlCatalog: [samples/ControlCatalog](https://github.com/AvaloniaUI/Avalonia/tree/master/samples/ControlCatalog)
- Styling and theme resources used by controls: [Avalonia.Themes.Fluent](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent)

Extra practice
- Rebuild the entire right-hand column using only Grid (no nested StackPanels).
- Create a two‑pane layout: DockPanel with a fixed left navigation (Width=220) and content filling the rest.
- Add MinWidth to text inputs to keep them readable when the window gets small.

```tip
When layouts get tricky, add Borders with different background colors briefly to see the rectangles each panel assigns.
```

What’s next
- Next: [Chapter 6](Chapter06.md)
