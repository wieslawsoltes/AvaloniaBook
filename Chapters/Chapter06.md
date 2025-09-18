# 6. Controls tour you'll actually use

Goal
- Build confidence with Avalonia's everyday controls grouped by scenario: text input, selection, navigation, editing, and feedback.
- Learn how to bind controls to view models, template items, and customise interaction states.
- Discover specialised controls such as `NumericUpDown`, `MaskedTextBox`, `AutoCompleteBox`, `ColorPicker`, `TreeView`, `TabControl`, and `SplitView`.
- Understand selection models, virtualization, and templating so large lists stay responsive.
- Know where to find styles, templates, and extension points in the source code.

Why this matters
- Real apps mix many controls on the same screen. Understanding their behaviour and key properties saves time.
- Avalonia's control set is broad; learning the structure of templates and selection models prepares you for customisation later.

Prerequisites
- You have built layouts (Chapter 5) and can bind data (Chapter 3's data templates). Chapter 8 will deepen bindings further.

## 1. Set up a sample project

```bash
dotnet new avalonia.mvvm -o ControlsShowcase
cd ControlsShowcase
```

We will extend `Views/MainWindow.axaml` with multiple sections backed by `MainWindowViewModel`.

## 2. Form inputs and validation basics

```xml
<StackPanel Spacing="16">
  <TextBlock Classes="h1" Text="Customer profile"/>

  <Grid ColumnDefinitions="Auto,*" RowDefinitions="Auto,Auto,Auto" RowSpacing="8" ColumnSpacing="12">
    <TextBlock Text="Name:"/>
    <TextBox Grid.Column="1" Text="{Binding Customer.Name}" Watermark="Full name"/>

    <TextBlock Grid.Row="1" Text="Email:"/>
    <TextBox Grid.Row="1" Grid.Column="1" Text="{Binding Customer.Email}"/>

    <TextBlock Grid.Row="2" Text="Phone:"/>
    <MaskedTextBox Grid.Row="2" Grid.Column="1" Mask="(000) 000-0000" Value="{Binding Customer.Phone}"/>
  </Grid>

  <StackPanel Orientation="Horizontal" Spacing="12">
    <NumericUpDown Width="120" Minimum="0" Maximum="20" Value="{Binding Customer.Seats}" Header="Seats"/>
    <DatePicker SelectedDate="{Binding Customer.RenewalDate}" Header="Renewal"/>
  </StackPanel>
</StackPanel>
```

Notes:
- `MaskedTextBox` lives in `Avalonia.Controls` (see [`MaskedTextBox.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/MaskedTextBox/MaskedTextBox.cs)) and enforces input patterns.
- `NumericUpDown` (from [`NumericUpDown.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/NumericUpDown/NumericUpDown.cs)) provides spinner buttons and numeric formatting.

## 3. Toggles, options, and commands

```xml
<GroupBox Header="Plan options" Padding="12">
  <StackPanel Spacing="8">
    <ToggleSwitch Header="Enable auto-renew" IsChecked="{Binding Customer.AutoRenew}"/>

    <StackPanel Orientation="Horizontal" Spacing="12">
      <CheckBox Content="Include analytics" IsChecked="{Binding Customer.IncludeAnalytics}"/>
      <CheckBox Content="Priority support" IsChecked="{Binding Customer.IncludeSupport}"/>
    </StackPanel>

    <StackPanel Orientation="Horizontal" Spacing="12">
      <RadioButton GroupName="Plan" Content="Starter" IsChecked="{Binding Customer.IsStarter}"/>
      <RadioButton GroupName="Plan" Content="Growth" IsChecked="{Binding Customer.IsGrowth}"/>
      <RadioButton GroupName="Plan" Content="Enterprise" IsChecked="{Binding Customer.IsEnterprise}"/>
    </StackPanel>

    <Button Content="Save" HorizontalAlignment="Left" Command="{Binding SaveCommand}"/>
  </StackPanel>
</GroupBox>
```

- `ToggleSwitch` gives a Fluent-styled toggle. Implementation: [`ToggleSwitch.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ToggleSwitch.cs).
- RadioButtons share state via `GroupName` or `IsChecked` bindings.

## 4. Selection lists with templating

```xml
<GroupBox Header="Teams" Padding="12">
  <ListBox Items="{Binding Teams}" SelectedItem="{Binding SelectedTeam}" Height="160">
    <ListBox.ItemTemplate>
      <DataTemplate>
        <StackPanel Orientation="Horizontal" Spacing="12">
          <Ellipse Width="24" Height="24" Fill="{Binding Color}"/>
          <TextBlock Text="{Binding Name}" FontWeight="SemiBold"/>
        </StackPanel>
      </DataTemplate>
    </ListBox.ItemTemplate>
  </ListBox>
</GroupBox>
```

- `ListBox` supports selection out of the box. For custom selection logic, use `SelectionModel` (see [`SelectionModel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Selection/SelectionModel.cs)).
- Consider `ListBox.SelectionMode="Multiple"` for multi-select.

### Virtualization tip

Large lists should virtualize. Use `ListBox` with the default `VirtualizingStackPanel` or switch panels:

```xml
<ListBox Items="{Binding ManyItems}" VirtualizingPanel.IsVirtualizing="True" VirtualizingPanel.CacheLength="2"/>
```

Controls for virtualization: [`VirtualizingStackPanel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/VirtualizingStackPanel.cs).

## 5. Hierarchical data with `TreeView`

```xml
<TreeView Items="{Binding Departments}" SelectedItems="{Binding SelectedDepartments}">
  <TreeView.ItemTemplate>
    <TreeDataTemplate ItemsSource="{Binding Teams}">
      <TextBlock Text="{Binding Name}" FontWeight="SemiBold"/>
      <TreeDataTemplate.ItemTemplate>
        <DataTemplate>
          <TextBlock Text="{Binding Name}" Margin="24,0,0,0"/>
        </DataTemplate>
      </TreeDataTemplate.ItemTemplate>
    </TreeDataTemplate>
  </TreeView.ItemTemplate>
</TreeView>
```

- `TreeView` uses `TreeDataTemplate` to describe hierarchical data. Each template can reference a property (`Teams`) for child items.
- Source implementation: [`TreeView.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TreeView.cs).

## 6. Navigation controls (`TabControl`, `SplitView`, `Expander`)

```xml
<TabControl SelectedIndex="{Binding SelectedTab}">
  <TabItem Header="Overview">
    <TextBlock Text="Overview content" Margin="12"/>
  </TabItem>
  <TabItem Header="Reports">
    <TextBlock Text="Reports content" Margin="12"/>
  </TabItem>
  <TabItem Header="Settings">
    <TextBlock Text="Settings content" Margin="12"/>
  </TabItem>
</TabControl>

<SplitView DisplayMode="CompactInline"
          IsPaneOpen="{Binding IsPaneOpen}"
          OpenPaneLength="240" CompactPaneLength="56">
  <SplitView.Pane>
    <NavigationViewContent/>
  </SplitView.Pane>
  <SplitView.Content>
    <Frame Content="{Binding ActivePage}"/>
  </SplitView.Content>
</SplitView>

<Expander Header="Advanced filters" IsExpanded="False">
  <StackPanel Margin="12" Spacing="8">
    <ComboBox Items="{Binding FilterSets}" SelectedItem="{Binding SelectedFilter}"/>
    <CheckBox Content="Include archived" IsChecked="{Binding IncludeArchived}"/>
  </StackPanel>
</Expander>
```

- `TabControl` enables tabbed navigation. Tab headers are content--you can template them via `TabControl.ItemTemplate`.
- `SplitView` (from [`SplitView.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/SplitView/SplitView.cs)) provides collapsible navigation, useful for sidebars.
- `Expander` collapses/expands content. Implementation: [`Expander.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Expander.cs).

## 7. Auto-complete, pickers, and dialogs

```xml
<StackPanel Spacing="12">
  <AutoCompleteBox Width="240"
                   Items="{Binding Suggestions}"
                   Text="{Binding Query, Mode=TwoWay}">
    <AutoCompleteBox.ItemTemplate>
      <DataTemplate>
        <StackPanel Orientation="Horizontal" Spacing="8">
          <TextBlock Text="{Binding Icon}"/>
          <TextBlock Text="{Binding Title}"/>
        </StackPanel>
      </DataTemplate>
    </AutoCompleteBox.ItemTemplate>
  </AutoCompleteBox>

  <ColorPicker SelectedColor="{Binding ThemeColor}"/>

  <Button Content="Choose files" Command="{Binding OpenFilesCommand}"/>
</StackPanel>
```

- `AutoCompleteBox` helps with large suggestion lists. Source: [`AutoCompleteBox.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/AutoCompleteBox/AutoCompleteBox.cs).
- `ColorPicker` shows palettes, sliders, and input fields (see [`ColorPicker.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls.ColorPicker/ColorPicker.cs)).
- File pickers will use `IStorageProvider` (Chapter 16).

## 8. Feedback and status

```xml
<StatusBar>
  <StatusBarItem>
    <StackPanel Orientation="Horizontal" Spacing="8">
      <TextBlock Text="Ready"/>
      <ProgressBar Width="120" IsIndeterminate="{Binding IsBusy}"/>
    </StackPanel>
  </StatusBarItem>
  <StatusBarItem HorizontalAlignment="Right">
    <TextBlock Text="v1.2.0"/>
  </StatusBarItem>
</StatusBar>

<NotificationCard Width="320" IsOpen="{Binding ShowNotification}" Title="Update available" Description="Restart to apply updates."/>
```

- `StatusBar` and `NotificationCard` (Fluent template) provide feedback surfaces.

## 9. Styling, classes, and visual states

Use classes (`Classes="primary"`) or pseudo-classes (`:pointerover`, `:pressed`, `:checked`) to style stateful controls:

```xml
<Button Content="Primary" Classes="primary"/>
```

```xml
<Style Selector="Button.primary">
  <Setter Property="Background" Value="{DynamicResource AccentBrush}"/>
  <Setter Property="Foreground" Value="White"/>
</Style>

<Style Selector="Button.primary:pointerover">
  <Setter Property="Background" Value="{DynamicResource AccentBrush2}"/>
</Style>
```

Styles live in `App.axaml` or separate resource dictionaries. Control templates are defined under [`src/Avalonia.Themes.Fluent`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent/Controls). Inspect `Button.xaml`, `ListBox.xaml`, etc., to understand structure and visual states.

## 10. ControlCatalog treasure hunt

1. Clone the Avalonia repository and run the ControlCatalog (Desktop) sample: `dotnet run --project samples/ControlCatalog.Desktop/ControlCatalog.Desktop.csproj`.
2. Use the built-in search to find controls. Explore the `Source` tab to jump to relevant XAML or C# files.
3. Compare ControlCatalog pages with the source directory structure:
   - Text input demos map to [`src/Avalonia.Controls/TextBox.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TextBox.cs).
   - Collections and virtualization demos map to [`VirtualizingStackPanel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/VirtualizingStackPanel.cs).
   - Navigation samples map to [`SplitView.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/SplitView/SplitView.cs) and `TabControl` templates.

## 11. Practice exercises

1. Create a "dashboard" page mixing text input, selection lists, tabs, and a collapsible filter panel. Bind every control to a view model.
2. Add an `AutoCompleteBox` that filters as you type. Use DevTools to inspect the generated `ListBox` inside the control.
3. Replace the `ListBox` with a `TreeView` for hierarchical data; add an `Expander` per root item.
4. Customise button states by adding pseudo-class styles. Confirm they match the ControlCatalog defaults.
5. Swap the `WrapPanel` for an `ItemsRepeater` (Chapter 14) to prepare for virtualization scenarios.

## Look under the hood (source bookmarks)
- Core controls: [`src/Avalonia.Controls`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- Specialized controls: [`src/Avalonia.Controls.ColorPicker`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls.ColorPicker), [`src/Avalonia.Controls.NumericUpDown`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/NumericUpDown), [`src/Avalonia.Controls.AutoCompleteBox`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/AutoCompleteBox)
- Selection framework: [`src/Avalonia.Controls/Selection`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/Selection)
- Styles and templates: [`src/Avalonia.Themes.Fluent/Controls`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent/Controls)

## Check yourself
- Which controls would you choose for numeric input, masked input, and auto-completion?
- How do you template `ListBox` items and enable virtualization for large datasets?
- Where do you look to customise the appearance of a `ToggleSwitch`?
- What role does `SelectionModel` play for advanced selection scenarios?
- How can ControlCatalog help you explore a control's API and default styles?

What's next
- Next: [Chapter 7](Chapter07.md)
