# 31. Extended control modules and component gallery

Goal
- Master specialized Avalonia controls that sit outside the "common controls" set: color pickers, pull-to-refresh, notifications, date/time inputs, split buttons, and more.
- Understand how these modules are organized, what platform behaviours they rely on, and how to style or automate them.
- Build a reusable component gallery to showcase advanced controls with theming and accessibility baked in.

Why this matters
- These controls unlock polished, production-ready experiences (dashboards, media apps, mobile refresh gestures) without reinventing UI plumbing.
- Many live in separate namespaces such as `Avalonia.Controls.ColorPicker` or `Avalonia.Controls.Notifications`; knowing what ships in the box saves time.
- Styling, automation, and platform quirks differ from core controls—you need dedicated recipes to avoid regressions.

Prerequisites
- Chapter 06 (controls tour) and Chapter 07 (styling) for basic control usage.
- Chapter 09 (input) and Chapter 15 (accessibility) to reason about interactions.
- Chapter 29 (animations) for transitional polish.

## 1. Survey of extended control namespaces

Avalonia groups advanced controls into focused namespaces:

| Module | Namespace | Highlights |
| --- | --- | --- |
| Color editing | `Avalonia.Controls.ColorPicker` | `ColorPicker`, `ColorView`, palette data, HSV/RGB components |
| Refresh gestures | `Avalonia.Controls.PullToRefresh` | `RefreshContainer`, `RefreshVisualizer`, `RefreshInfoProvider` |
| Notifications | `Avalonia.Controls.Notifications` | `WindowNotificationManager`, `NotificationCard`, `INotification` |
| Date & time | `Avalonia.Controls.DateTimePickers` | `DatePicker`, `TimePicker`, presenters, culture support |
| Interactive navigation | `Avalonia.Controls.SplitView`, `Avalonia.Controls.SplitButton` | Collapsible panes, hybrid buttons |
| Document text | `Avalonia.Controls.Documents` | Inline elements (`Run`, `Bold`, `InlineUIContainer`) |
| Misc UX | `Avalonia.Controls.TransitioningContentControl`, `Avalonia.Controls.Notifications.ReversibleStackPanel`, `Avalonia.Controls.Primitives` helpers |

Each module ships styles in Fluent/Simple theme dictionaries. Include the relevant `.axaml` resource dictionaries when building custom themes.

## 2. ColorPicker and color workflows

`ColorPicker` extends `ColorView` by providing a preview area and flyout editing UI (`ColorPicker.cs`). Key elements:
- Preview content via `Content`/`ContentTemplate` (defaults to swatch + ARGB string).
- Editing flyout hosts `ColorSpectrum`, sliders, and palette pickers.
- Palettes live in `ColorPalettes/*`—you can supply custom palettes or localize names.

Usage snippet:

```xml
<ColorPicker SelectedColor="{Binding AccentColor, Mode=TwoWay}">
  <ColorPicker.ContentTemplate>
    <DataTemplate>
      <StackPanel Orientation="Horizontal" Spacing="8">
        <Border Width="24" Height="24" Background="{Binding}" CornerRadius="4"/>
        <TextBlock Text="{Binding Converter={StaticResource RgbFormatter}}"/>
      </StackPanel>
    </DataTemplate>
  </ColorPicker.ContentTemplate>
</ColorPicker>
```

Tips:
- Set `ColorPicker.FlyoutPlacement` (via template) to adapt for touch vs desktop usage.
- Hook `ColorView.ColorChanged` to react immediately to slider changes (e.g., update live preview alt text).
- Add automation peers (`ColorPickerAutomationPeer`) if you expose color selection to screen readers.

## 3. Pull-to-refresh infrastructure

`RefreshContainer` wraps scrollable content and coordinates `RefreshVisualizer` animations (`RefreshContainer.cs`). Concepts:
- `PullDirection` (top/bottom/left/right) chooses gesture direction.
- `RefreshRequested` event fires when the user crosses the threshold. Use `RefreshCompletionDeferral` to await async work.
- `RefreshInfoProviderAdapter` adapts `ScrollViewer` offsets to the visualizer; you can replace it for custom panels.

Example:

```xml
<ptr:RefreshContainer RefreshRequested="OnRefresh">
  <ptr:RefreshContainer.Visualizer>
    <ptr:RefreshVisualizer Orientation="TopToBottom"
                            Content="{DynamicResource PullHintTemplate}"/>
  </ptr:RefreshContainer.Visualizer>
  <ScrollViewer>
    <ItemsControl ItemsSource="{Binding FeedItems}"/>
  </ScrollViewer>
</ptr:RefreshContainer>
```

```csharp
private async void OnRefresh(object? sender, RefreshRequestedEventArgs e)
{
    using var deferral = e.GetDeferral();
    await ViewModel.LoadLatestAsync();
}
```

Notes:
- On desktop, pull gestures require touchpad/touch screen; keep a manual refresh fallback (button) for mouse-only setups.
- Provide localized feedback via `RefreshVisualizer.StateChanged` (show "Release to refresh" vs "Refreshing...").
- For virtualization, ensure the underlying `ItemsControl` defers updates until after refresh completes so the visualizer can retract smoothly.

## 4. Notifications and toast UIs

`WindowNotificationManager` hosts toast-like notifications overlaying a `TopLevel` (`WindowNotificationManager.cs`).
- Set `Position` (TopRight, BottomCenter, etc.) and `MaxItems`.
- Call `Show(INotification)` or `Show(object)`; the manager wraps content in a `NotificationCard` with pseudo-classes per `NotificationType`.
- Attach `WindowNotificationManager` to your main window (`new WindowNotificationManager(this)` or via XAML `NotificationLayer`).

Custom template example:

```xml
<Style Selector="NotificationCard">
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="NotificationCard">
        <Border Classes="toast" CornerRadius="6" Background="{ThemeResource SurfaceBrush}">
          <StackPanel Orientation="Vertical" Margin="12">
            <TextBlock Text="{Binding Content.Title}" FontWeight="SemiBold"/>
            <TextBlock Text="{Binding Content.Message}" TextWrapping="Wrap"/>
            <Button Content="Dismiss" Classes="subtle"
                    notifications:NotificationCard.CloseOnClick="True"/>
          </StackPanel>
        </Border>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
```

Considerations:
- Provide keyboard dismissal: map `Esc` to close the newest notification.
- For MVVM, store `INotificationManager` in DI so view models can raise toasts without referencing the view.
- On future platforms (mobile), swap to platform notification managers when available.

## 5. DatePicker/TimePicker for forms

`DatePicker` and `TimePicker` share presenters and respect culture-specific formats (`DatePicker.cs`, `TimePicker.cs`).
- Properties: `SelectedDate`, `MinYear`, `MaxYear`, `DayVisible`, `MonthFormat`, `YearFormat`.
- Template parts expose text blocks and a popup presenter; override the template to customize layout.
- Two-way binding uses `DateTimeOffset?` (stay mindful of time zones).

Validation strategies:
- Use `Binding` with data annotations or manual rules to block invalid ranges.
- For forms, show hint text using pseudo-class `:hasnodate` when `SelectedDate` is null.
- Provide automation names for the button and popup to assist screen readers.

### Calendar control for planners

`Calendar` gives you a full month or decade view without the flyout wrapper.
- `DisplayMode` toggles Month, Year, or Decade views—useful for date pickers embedded in dashboards.
- `SelectedDates` supports multi-selection when `SelectionMode` is `MultipleRange`; bind it to a collection for booking scenarios.
- Handle `DisplayDateChanged` to lazy-load data (appointments, deadlines) as the user browses months.
- Customize the template to expose additional adorners (badges, tooltips). Keep `PART_DaysPanel` and related names intact so the control keeps functioning.

When you need both `Calendar` and `DatePicker`, reuse the same `CalendarDatePicker` styles so typography and spacing stay consistent.

## 6. SplitView and navigation panes

`SplitView` builds side drawers with flexible display modes (`SplitView.cs`).
- `DisplayMode`: Overlay, Inline, CompactOverlay, CompactInline.
- `IsPaneOpen` toggles state; handle `PaneOpening/PaneClosing` to intercept.
- `UseLightDismissOverlayMode` enables auto-dismiss when the user clicks outside.

Usage example:

```xml
<SplitView IsPaneOpen="{Binding IsMenuOpen, Mode=TwoWay}"
           DisplayMode="CompactOverlay"
           PanePlacement="Left"
           CompactPaneLength="56"
           OpenPaneLength="240">
  <SplitView.Pane>
    <StackPanel>
      <Button Content="Dashboard" Command="{Binding GoHome}"/>
      <Button Content="Reports" Command="{Binding GoReports}"/>
    </StackPanel>
  </SplitView.Pane>
  <Frame Content="{Binding CurrentPage}"/>
</SplitView>
```

Tips:
- On desktop, use keyboard shortcuts to toggle the pane (e.g., assign `HotKey` to `SplitButton` or global command).
- Manage focus: when the pane opens via keyboard, move focus to the first focusable element; when closing, restore focus to the toggle.
- Combine with `TransitioningContentControl` (Chapter 29) for smooth page transitions.

### TransitioningContentControl for dynamic views

`TransitioningContentControl` wraps a content presenter with `IPageTransition` support.
- Assign `PageTransition` in XAML (slide, cross-fade, custom transitions) to animate view-model swaps.
- Hook `TransitionCompleted` to dispose old view models or trigger analytics when navigation ends.
- Pair with `SplitView` or navigation shells to animate content panes independently of the chrome.

For component galleries, use it to showcase before/after states or responsive layouts without writing manual animation plumbing.

## 7. SplitButton and ToggleSplitButton

`SplitButton` provides a main action plus a secondary flyout (`SplitButton.cs`).
- Primary click raises `Click`/`Command`; the secondary button shows `Flyout`.
- Pseudo-classes `:flyout-open`, `:pressed`, `:checked` (for `ToggleSplitButton`).
- Works nicely with `MenuFlyout` for command lists or settings.

Example:

```xml
<SplitButton Content="Export"
             Command="{Binding ExportAll}">
  <SplitButton.Flyout>
    <MenuFlyout>
      <MenuItem Header="Export CSV" Command="{Binding ExportCsv}"/>
      <MenuItem Header="Export JSON" Command="{Binding ExportJson}"/>
    </MenuFlyout>
  </SplitButton.Flyout>
</SplitButton>
```

Ensure `Command.CanExecute` updates by binding to view model state; `SplitButton` listens for `CanExecuteChanged` and toggles `IsEnabled` accordingly.

## 8. Notifications, documents, and media surfaces

- `Inline`, `Run`, `Span`, and `InlineUIContainer` in `Avalonia.Controls.Documents` let you build rich text with embedded controls (useful for notifications or chat bubbles).
- Use `InlineUIContainer` sparingly; it affects layout performance.
- Combine `NotificationCard` with document inlines to highlight formatted content (bold text, links).

`MediaPlayerElement` (available when you reference the media package) embeds audio/video playback with transport controls.
- Bind `Source` to URIs or streams; the element manages decoding via platform backends (`Windows` uses Angle/DX, `Linux` goes through FFmpeg when available).
- Toggle `AreTransportControlsEnabled` to show built-in play/pause UI; for custom chrome, bind to `MediaPlayer` and drive commands yourself.
- Handle `MediaOpened`/`MediaEnded` to chain playlists or update state.
- On platforms without native codecs, surface fallbacks (download prompts, external players) so the UI stays predictable.

## 9. Building a component gallery

Create a `ComponentGalleryWindow` that showcases each control with explanations and theme toggles:

```xml
<TabControl>
  <TabItem Header="Color">
    <StackPanel Spacing="16">
      <TextBlock Text="ColorPicker" FontWeight="SemiBold"/>
      <ColorPicker SelectedColor="{Binding ThemeColor}"/>
    </StackPanel>
  </TabItem>
  <TabItem Header="Refresh">
    <ptr:RefreshContainer RefreshRequested="OnRefreshRequested">
      <ListBox ItemsSource="{Binding Items}"/>
    </ptr:RefreshContainer>
  </TabItem>
  <TabItem Header="Notifications">
    <StackPanel>
      <Button Content="Show success" Click="OnShowSuccess"/>
      <TextBlock Text="Notifications appear top-right"/>
    </StackPanel>
  </TabItem>
</TabControl>
```

Best practices:
- Offer theme toggle (Fluent light/dark) to reveal styling differences.
- Surface accessibility guidance (keyboard shortcuts, screen reader notes) alongside each sample.
- Provide code snippets via `TextBlock` or copy buttons so teammates can reuse patterns.

## 10. Practice lab: responsibility matrix

1. **Color workflows** – Customize `ColorPicker` palettes, bind to view model state, and expose automation peers for UI tests.
2. **Mobile refresh** – Implement `RefreshContainer` in a list, test on touch-enabled hardware, and add fallback commands for desktop.
3. **Toast scenarios** – Build a notification service that queues messages and exposes dismissal commands, then craft styles for different severities.
4. **Dashboard shell** – Combine `SplitView`, `SplitButton`, and `TransitioningContentControl` to create a responsive navigation shell with keyboard and pointer parity.
5. **Component gallery** – Document each control with design notes, theming tweaks, and automation IDs; integrate into project documentation.

## Troubleshooting & best practices

- Many controls rely on template parts (`PART_*`). When restyling, preserve these names or update code-behind references.
- Notification overlays run on the UI thread; throttle or batch updates to avoid flooding `WindowNotificationManager` with dozens of toasts.
- `RefreshContainer` needs a `ScrollViewer` or adapter implementing `IRefreshInfoProvider`; custom panels must adapt to supply offset data.
- Date/time pickers use `DateTimeOffset`. When binding to `DateTime`, convert carefully to retain time zones.
- SplitView on compact widths: watch out for layout loops if your pane content uses `HorizontalAlignment.Stretch`; consider fixed width.

## Look under the hood (source bookmarks)
- Color picker foundation: `external/Avalonia/src/Avalonia.Controls.ColorPicker/ColorPicker/ColorPicker.cs`
- Pull-to-refresh: `external/Avalonia/src/Avalonia.Controls/PullToRefresh/RefreshContainer.cs`
- Notifications: `external/Avalonia/src/Avalonia.Controls/Notifications/WindowNotificationManager.cs`, `NotificationCard.cs`
- Calendar & date/time: `external/Avalonia/src/Avalonia.Controls/Calendar/Calendar.cs`, `external/Avalonia/src/Avalonia.Controls/DateTimePickers/DatePicker.cs`, `TimePicker.cs`
- Split view/button: `external/Avalonia/src/Avalonia.Controls/SplitView/SplitView.cs`, `external/Avalonia/src/Avalonia.Controls/SplitButton/SplitButton.cs`
- Documents: `external/Avalonia/src/Avalonia.Controls/Documents/*`
- Transitions host: `external/Avalonia/src/Avalonia.Controls/TransitioningContentControl.cs`

## Check yourself
- Which namespace hosts `RefreshContainer`, and why does it need a `RefreshVisualizer`?
- How does `WindowNotificationManager` limit concurrent notifications and close them programmatically?
- What steps keep `DatePicker` in sync with `DateTime` view-model properties?
- How do you style `SplitView` for light-dismiss overlay vs inline mode?
- What belongs in a component gallery to help teammates reuse advanced controls?

What's next
- Next: [Chapter32](Chapter32.md)
