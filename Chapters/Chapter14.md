# 14. Lists, virtualization, and performance

Goal
- Choose the right items control (`ItemsControl`, `ListBox`, `TreeView`, `DataGrid`, `ItemsRepeater`) for the data shape and user interactions you need.
- Understand the `ItemsControl` pipeline (`ItemsSourceView`, item container generator, `ItemsPresenter`) and how virtualization keeps UIs responsive.
- Apply virtualization techniques (`VirtualizingStackPanel`, `ItemsRepeater` layouts) alongside incremental loading and selection synchronization with `SelectionModel`.
- Diagnose virtualization regressions using DevTools, logging, and layout instrumentation.

Why this matters
- Lists power dashboards, log viewers, chat apps, and tables; poorly configured lists can freeze your UI.
- Virtualization keeps memory and CPU usage manageable even with hundreds of thousands of rows.
- Knowing the pipeline lets you extend list controls, add grouping, or inject placeholders without breaking performance.

Prerequisites
- Binding and commands (Chapters 8–9), MVVM patterns (Chapter 11), styling and resources (Chapter 10).

Key namespaces
- [`ItemsControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ItemsControl.cs)
- [`ItemsSourceView.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ItemsSourceView.cs)
- [`ItemContainerGenerator.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Generators/ItemContainerGenerator.cs)
- [`VirtualizingStackPanel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/VirtualizingStackPanel.cs)
- [`ItemsPresenter.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Primitives/ItemsPresenter.cs)
- [`SelectionModel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Selection/SelectionModel.cs)
- [`ItemsRepeater`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls/ItemsRepeater)

## 1. ItemsControl pipeline overview

Every items control follows the same data flow:

1. `Items`/`ItemsSource` is wrapped in an `ItemsSourceView` that projects the data as `IReadOnlyList<object?>`, tracks the current item, and provides grouping hooks.
2. `ItemContainerGenerator` materializes containers (`ListBoxItem`, `TreeViewItem`, etc.) for realized indices and recycles them when virtualization is enabled.
3. `ItemsPresenter` hosts the actual panel (by default `StackPanel` or `VirtualizingStackPanel`) and plugs into `ScrollViewer` to handle scrolling.
4. Templates render your view models inside each container.

Inspecting the view and generator helps when debugging:

```csharp
var view = MyListBox.ItemsSourceView;
var current = view?.CurrentItem;

MyListBox.ItemContainerGenerator.Materialized += (_, e) =>
    Debug.WriteLine($"Realized range {e.StartIndex}..{e.StartIndex + e.Count - 1}");

MyListBox.ItemContainerGenerator.Dematerialized += (_, e) =>
    Debug.WriteLine($"Recycled {e.Count} containers");
```

Customize the items presenter when you need a different panel:

```xml
<ListBox Items="{Binding Orders}">
  <ListBox.ItemsPanel>
    <ItemsPanelTemplate>
      <VirtualizingStackPanel Orientation="Vertical"/>
    </ItemsPanelTemplate>
  </ListBox.ItemsPanel>
</ListBox>
```

`ItemsPresenter` can also be styled to add headers, footers, or empty-state placeholders while still respecting virtualization.

## 2. VirtualizingStackPanel in practice

`VirtualizingStackPanel` implements `ILogicalScrollable`, creating visuals only for the viewport (plus a configurable buffer). Keep virtualization intact by:

- Hosting the items panel directly inside a `ScrollViewer` (no extra wrappers between them).
- Avoiding nested `ScrollViewer`s inside item templates.
- Preferring fixed or predictable item sizes so layout calculations are cheap.

```xml
<ListBox Items="{Binding People}"
         SelectedItem="{Binding Selected}"
         Height="360"
         ScrollViewer.HorizontalScrollBarVisibility="Disabled">
  <ListBox.ItemsPanel>
    <ItemsPanelTemplate>
      <VirtualizingStackPanel Orientation="Vertical"
                              AreHorizontalSnapPointsRegular="True"
                              CacheLength="1"/>
    </ItemsPanelTemplate>
  </ListBox.ItemsPanel>
  <ListBox.ItemTemplate>
    <DataTemplate x:DataType="vm:PersonViewModel">
      <Grid ColumnDefinitions="Auto,*,Auto" Height="48" Margin="4">
        <TextBlock Grid.Column="0" Text="{CompiledBinding Id}" Width="56" HorizontalAlignment="Right"/>
        <StackPanel Grid.Column="1" Orientation="Vertical" Margin="12,0" Spacing="2">
          <TextBlock Text="{CompiledBinding FullName}" FontWeight="SemiBold"/>
          <TextBlock Text="{CompiledBinding Email}" FontSize="12" Foreground="#6B7280"/>
        </StackPanel>
        <Button Grid.Column="2"
                Content="Open"
                Command="{Binding DataContext.Open, RelativeSource={RelativeSource AncestorType=ListBox}}"
                CommandParameter="{Binding}"/>
      </Grid>
    </DataTemplate>
  </ListBox.ItemTemplate>
</ListBox>
```

- `CacheLength` retains extra realized rows before and after the viewport (measured in viewport heights) for smoother scrolling.
- `ItemContainerGenerator.Materialized` events confirm virtualization: the count should remain small even with large data sets.
- Use `CompiledBinding` to avoid runtime reflection overhead when recycling containers.

## 3. Optimising item containers

Container recycling reuses realized `ListBoxItem` instances. Keep containers lightweight:

- Offload expensive visuals into shared `ControlTheme` resources.
- Style containers instead of adding extra elements for selection/hover state.

```xml
<Style Selector="ListBoxItem:selected TextBlock.title">
  <Setter Property="Foreground" Value="{DynamicResource AccentBrush}"/>
</Style>
```

When you need to interact with containers manually, use `ItemContainerGenerator.ContainerFromIndex`/`IndexFromContainer` rather than walking the visual tree.

## 4. ItemsRepeater for custom layouts

`ItemsRepeater` separates data virtualization from layout so you can design custom grids or timelines.

```xml
<controls:ItemsRepeater Items="{Binding Photos}"
                        xmlns:controls="clr-namespace:Avalonia.Controls;assembly=Avalonia.Controls">
  <controls:ItemsRepeater.Layout>
    <controls:UniformGridLayout Orientation="Vertical" MinItemWidth="220" MinItemHeight="180"/>
  </controls:ItemsRepeater.Layout>
  <controls:ItemsRepeater.ItemTemplate>
    <DataTemplate x:DataType="vm:PhotoViewModel">
      <Border Margin="8" Padding="8" Background="#111827" CornerRadius="6">
        <StackPanel>
          <Image Source="{CompiledBinding Thumbnail}" Width="204" Height="128" Stretch="UniformToFill"/>
          <TextBlock Text="{CompiledBinding Title}" Margin="0,8,0,0"/>
        </StackPanel>
      </Border>
    </DataTemplate>
  </controls:ItemsRepeater.ItemTemplate>
</controls:ItemsRepeater>
```

- `ItemsRepeater.ItemsSourceView` exposes the same API as `ItemsControl`, so you can layer grouping or filtering on top.
- Implement a custom `VirtualizingLayout` when you need masonry or staggered layouts that still recycle elements.

## 5. Selection with `SelectionModel`

`SelectionModel<T>` tracks selection without relying on realized containers, making it virtualization-friendly.

```csharp
public SelectionModel<PersonViewModel> PeopleSelection { get; } =
    new() { SelectionMode = SelectionMode.Multiple };
```

Bind directly:

```xml
<ListBox Items="{Binding People}"
         Selection="{Binding PeopleSelection}"
         Height="360"/>
```

- `SelectionModel.SelectedItems` returns a snapshot of selected view models; use it for batch operations.
- Hook `SelectionModel.SelectionChanged` to synchronize selection with other views or persisted state.
- For custom surfaces (e.g., an `ItemsRepeater` dashboard), set `selectionModel.Source = repeater.ItemsSourceView` and drive selection manually.

## 6. Incremental loading patterns

Load data in pages to keep virtualization responsive. The view model owns the collection and exposes an async method that appends new items.

```csharp
public sealed class LogViewModel : ObservableObject
{
    private readonly ILogService _service;
    private readonly ObservableCollection<LogEntryViewModel> _entries = new();
    private bool _isLoading;
    private int _pageIndex;
    private const int PageSize = 500;

    public LogViewModel(ILogService service)
    {
        _service = service;
        Entries = new ReadOnlyObservableCollection<LogEntryViewModel>(_entries);
        _ = LoadMoreAsync();
    }

    public ReadOnlyObservableCollection<LogEntryViewModel> Entries { get; }
    public bool HasMore { get; private set; } = true;

    public async Task LoadMoreAsync()
    {
        if (_isLoading || !HasMore)
            return;

        _isLoading = true;
        try
        {
            var batch = await _service.GetEntriesAsync(_pageIndex, PageSize);
            foreach (var entry in batch)
                _entries.Add(new LogEntryViewModel(entry));

            _pageIndex++;
            HasMore = batch.Count == PageSize;
        }
        finally
        {
            _isLoading = false;
        }
    }
}
```

Trigger loading when the user scrolls near the end:

```csharp
private async void OnScrollChanged(object? sender, ScrollChangedEventArgs e)
{
    if (DataContext is LogViewModel vm &&
        vm.HasMore &&
        e.Source is ScrollViewer scroll &&
        scroll.Offset.Y + scroll.Viewport.Height >= scroll.Extent.Height - 200)
    {
        await vm.LoadMoreAsync();
    }
}
```

While loading, display lightweight placeholders (e.g., skeleton rows) bound to `IsLoading` flags; keep them inside the same template so virtualization still applies.

## 7. Diagnosing virtualization issues

When scrolling stutters or memory spikes:

- **DevTools ➔ Visual Tree**: select the list and open the **Diagnostics** tab to inspect realized item counts and virtualization mode.
- Enable layout/render logging:

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .LogToTrace(LogEventLevel.Debug, new[] { LogArea.Layout, LogArea.Rendering, LogArea.Control })
    .StartWithClassicDesktopLifetime(args);
```

- Monitor `ItemContainerGenerator.Materialized`/`Dematerialized` events; if counts climb with scroll distance, virtualization is broken.
- Verify the scroll host is the list’s immediate parent; wrappers like `StackPanel` or `Grid` can disable virtualization.
- Profile templates with `dotnet-trace` or `dotnet-counters` to spot expensive bindings or allocations while scrolling.

## 8. Practice exercises

1. Inspect `ItemsControl.ItemsSourceView` for a dashboard list and log the current item index whenever selection changes. Explain how it differs from binding directly to `ItemsSource`.
2. Convert a slow `ItemsControl` to a virtualized `ListBox` with `VirtualizingStackPanel` and record container creation counts before/after.
3. Build an `ItemsRepeater` gallery with `UniformGridLayout` and compare realized item counts against a `WrapPanel` version.
4. Replace `SelectedItems` with `SelectionModel` in a multi-select list, then synchronize the selection with a detail pane while keeping virtualization intact.
5. Implement the incremental log viewer above, including skeleton placeholders during fetch, and capture frame-time metrics before and after the optimization.

## Look under the hood (source bookmarks)
- Pipeline internals: [`ItemsControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ItemsControl.cs), [`ItemContainerGenerator.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Generators/ItemContainerGenerator.cs)
- Data views: [`ItemsSourceView.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ItemsSourceView.cs), [`CollectionView.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Data/Core/CollectionView.cs)
- Virtualization core: [`VirtualizingStackPanel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/VirtualizingStackPanel.cs), [`VirtualizingLayout.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ItemsRepeater/Layout/VirtualizingLayout.cs)
- Selection infrastructure: [`SelectionModel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Selection/SelectionModel.cs)
- Diagnostics tooling: [`LayoutDiagnosticBridge.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Diagnostics/Diagnostics/LayoutDiagnosticBridge.cs)

## Check yourself
- What distinguishes `ItemsSource` from `ItemsSourceView`, and when would you inspect the latter?
- How does `VirtualizingStackPanel` decide which containers to recycle, and what breaks that logic?
- Why does `SelectionModel` survive virtualization better than `SelectedItems`?
- Which DevTools views help you confirm virtualization is active?
- How can incremental loading keep long lists responsive without overwhelming the UI thread?

What's next
- Next: [Chapter 15](Chapter15.md)
