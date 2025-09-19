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

## 2. Control overview matrix

| Scenario | Key controls | Highlights | Source snapshot |
| --- | --- | --- | --- |
| Text & numeric input | `TextBox`, `MaskedTextBox`, `NumericUpDown`, `DatePicker` | Validation-friendly inputs with watermarks, masks, spinner buttons, culture-aware dates | [`TextBox.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TextBox.cs), [`MaskedTextBox`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/MaskedTextBox/MaskedTextBox.cs), [`NumericUpDown`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/NumericUpDown/NumericUpDown.cs), [`DatePicker`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/DateTimePickers/DatePicker.cs) |
| Toggles & commands | `ToggleSwitch`, `CheckBox`, `RadioButton`, `Button` | MVVM-friendly toggles and grouped options with automation peers | [`ToggleSwitch.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ToggleSwitch.cs) |
| Lists & selection | `ListBox`, `TreeView`, `SelectionModel`, `ItemsRepeater` | Single/multi-select, hierarchical data, virtualization | [`SelectionModel`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Selection/SelectionModel.cs), [`TreeView`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TreeView.cs) |
| Navigation surfaces | `TabControl`, `SplitView`, `Expander`, `TransitioningContentControl` | Tabbed pages, collapsible panes, animated transitions | [`SplitView`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/SplitView/SplitView.cs), [`TransitioningContentControl`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TransitioningContentControl.cs) |
| Search & pickers | `AutoCompleteBox`, `ComboBox`, `ColorPicker`, `FilePicker` dialogs | Suggest-as-you-type, palette pickers, storage providers | [`AutoCompleteBox`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/AutoCompleteBox/AutoCompleteBox.cs), [`ColorPicker`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls.ColorPicker/ColorPicker/ColorPicker.cs) |
| Command surfaces | `SplitButton`, `Menu`, `ContextMenu`, `Toolbar` | Primary/secondary actions, keyboard shortcuts, flyouts | [`SplitButton`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/SplitButton/SplitButton.cs), [`Menu`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Menu.cs) |
| Refresh & feedback | `RefreshContainer`, `RefreshVisualizer`, `WindowNotificationManager`, `StatusBar`, `NotificationCard` | Pull-to-refresh gestures, toast notifications, status indicators | [`RefreshContainer`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/PullToRefresh/RefreshContainer.cs), [`WindowNotificationManager`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Notifications/WindowNotificationManager.cs) |

Use this table as a map while exploring ControlCatalog; each section below dives into exemplars from these categories.

## 3. Form inputs and validation basics

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
- Accessibility: provide spoken labels via `AutomationProperties.Name` or `HelpText` on inputs so screen readers identify the fields correctly.

## 4. Toggles, options, and commands

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

## 5. Selection lists with templating

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

## 6. Hierarchical data with `TreeView`

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

## 7. Navigation controls (`TabControl`, `SplitView`, `Expander`)

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

## 8. Auto-complete, pickers, and dialogs
## 9. Command surfaces and flyouts

```xml
<StackPanel Spacing="12">
  <SplitButton Content="Export" Command="{Binding ExportAllCommand}">
    <SplitButton.Flyout>
      <MenuFlyout>
        <MenuItem Header="Export CSV" Command="{Binding ExportCsvCommand}"/>
        <MenuItem Header="Export JSON" Command="{Binding ExportJsonCommand}"/>
        <MenuItem Header="Export PDF" Command="{Binding ExportPdfCommand}"/>
      </MenuFlyout>
    </SplitButton.Flyout>
  </SplitButton>

  <Menu>
    <MenuItem Header="File">
      <MenuItem Header="New" Command="{Binding NewCommand}"/>
      <MenuItem Header="Open..." Command="{Binding OpenCommand}"/>
      <Separator/>
      <MenuItem Header="Exit" Command="{Binding ExitCommand}"/>
    </MenuItem>
    <MenuItem Header="Help" Command="{Binding ShowHelpCommand}"/>
  </Menu>

  <StackPanel Orientation="Horizontal" Spacing="8">
    <Button Content="Copy" Command="{Binding CopyCommand}" HotKey="Ctrl+C"/>
    <Button Content="Paste" Command="{Binding PasteCommand}" HotKey="Ctrl+V"/>
  </StackPanel>
</StackPanel>
```

Notes:
- `SplitButton` exposes a primary command and a flyout for secondary options. Automation peers surface both the button and flyout; see [`SplitButton.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/SplitButton/SplitButton.cs).
- `Menu`/`ContextMenu` support keyboard navigation and `AutomationProperties.AcceleratorKey` so shortcuts are announced to assistive tech. Implementation: [`Menu.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Menu.cs).
- Flyouts can host any control (`MenuFlyout`, `Popup`, `FlyoutBase`). Use `FlyoutBase.ShowAttachedFlyout` to open context actions from command handlers.


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

## 10. Refresh gestures and feedback

```xml
<Window xmlns:ptr="clr-namespace:Avalonia.Controls;assembly=Avalonia.Controls"
        xmlns:notifications="clr-namespace:Avalonia.Controls.Notifications;assembly=Avalonia.Controls"
        ...>
  <Grid>
    <ptr:RefreshContainer RefreshRequested="OnRefreshRequested">
      <ptr:RefreshContainer.Visualizer>
        <ptr:RefreshVisualizer Orientation="TopToBottom"
                                Content="Pull to refresh"/>
      </ptr:RefreshContainer.Visualizer>
      <ScrollViewer>
        <ItemsControl Items="{Binding Orders}"/>
      </ScrollViewer>
    </ptr:RefreshContainer>
  </Grid>
</Window>
```

```csharp
private async void OnRefreshRequested(object? sender, RefreshRequestedEventArgs e)
{
    using var deferral = e.GetDeferral();
    await ViewModel.ReloadAsync();
}
```

- `RefreshContainer` + `RefreshVisualizer` implement pull-to-refresh on any scrollable surface. Source: [`RefreshContainer`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/PullToRefresh/RefreshContainer.cs).
- Always provide an alternate refresh action (button, keyboard) for desktop scenarios.

```csharp
var notifications = new WindowNotificationManager(this)
{
    Position = NotificationPosition.TopRight,
    MaxItems = 3
};
notifications.Show(new Notification("Update available", "Restart to apply updates.", NotificationType.Success));
```

- `WindowNotificationManager` displays toast notifications layered over the current window; combine with inline `NotificationCard` or `InfoBar` for longer-lived messages. Sources: [`WindowNotificationManager`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Notifications/WindowNotificationManager.cs), [`NotificationCard`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Notifications/NotificationCard.cs).
- Mark status changes with `AutomationProperties.LiveSetting="Polite"` so assistive technologies announce them.

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
```

- `StatusBar` hosts persistent indicators (connection status, progress). Implementation: [`StatusBar`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/StatusBar/StatusBar.cs).

## 11. Styling, classes, and visual states

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

## 12. ControlCatalog treasure hunt

1. Clone the Avalonia repository and run the ControlCatalog (Desktop) sample: `dotnet run --project samples/ControlCatalog.Desktop/ControlCatalog.Desktop.csproj`.
2. Use the built-in search to find controls. Explore the `Source` tab to jump to relevant XAML or C# files.
3. Compare ControlCatalog pages with the source directory structure:
   - Text input demos map to [`src/Avalonia.Controls/TextBox.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TextBox.cs).
   - Collections and virtualization demos map to [`VirtualizingStackPanel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/VirtualizingStackPanel.cs).
   - Navigation samples map to [`SplitView.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/SplitView/SplitView.cs) and `TabControl` templates.

## 13. Practice exercises

1. Create a "dashboard" page mixing text input, selection lists, tabs, a `SplitButton`, and a collapsible filter panel. Bind every control to a view model.
2. Add an `AutoCompleteBox` that filters as you type. Use DevTools to inspect the generated `ListBox` inside the control and verify automation names.
3. Replace the `ListBox` with a `TreeView` for hierarchical data; add an `Expander` per root item.
4. Wire up a `RefreshContainer` around a scrollable list and implement the `RefreshRequested` deferal pattern. Provide a fallback refresh button for keyboard users.
5. Register a singleton `WindowNotificationManager`, show a toast when the refresh completes, and style inline `NotificationCard` messages for success and error states.
6. Customise button states by adding pseudo-class styles and confirm they match the ControlCatalog defaults.
7. Swap the `WrapPanel` for an `ItemsRepeater` (Chapter 14) to prepare for virtualization scenarios.

## Look under the hood (source bookmarks)
- Core controls: [`src/Avalonia.Controls`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls)
- Specialized controls: [`src/Avalonia.Controls.ColorPicker`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls.ColorPicker), [`src/Avalonia.Controls.NumericUpDown`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/NumericUpDown), [`src/Avalonia.Controls.AutoCompleteBox`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/AutoCompleteBox)
- Command & navigation surfaces: [`src/Avalonia.Controls/SplitButton`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/SplitButton), [`src/Avalonia.Controls/SplitView`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/SplitView)
- Refresh & notifications: [`src/Avalonia.Controls/PullToRefresh`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/PullToRefresh), [`src/Avalonia.Controls/Notifications`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/Notifications)
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
