# 14. Lists, virtualization, and performance

Goal
- Choose the right list control (ItemsControl, ListBox, DataGrid, TreeView, ItemsRepeater) for large data sets.
- Understand virtualization internals (`VirtualizingStackPanel`, `ItemsPresenter`, recycling) and how to tune them.
- Implement incremental loading, selection patterns, and grouped/hierarchical lists efficiently.
- Diagnose list performance with DevTools, logging, and profiling.

Why this matters
- Lists power dashboards, log viewers, chat apps, tables, and trees. Poorly configured lists freeze apps.
- Virtualization keeps memory and CPU usage manageable even with hundreds of thousands of rows.

Prerequisites
- Binding/commands (Chapters 8-9), MVVM patterns (Chapter 11).

## 1. Choosing the right control

| Control | When to use | Notes |
| --- | --- | --- |
| `ItemsControl` | Simple, read-only lists with custom layout | No selection built in; good for dashboards/badges |
| `ListBox` | Lists with selection, keyboard navigation | Virtualizes by default when using `VirtualizingStackPanel` |
| `ItemsRepeater` | High-performance custom layouts, virtualization | Requires manual layout definition; power users only |
| `DataGrid` | Tabular data with columns, sorting, editing | Virtualizes rows; define columns explicitly |
| `TreeView` | Hierarchical data | Virtualizes expanded nodes; heavy trees need cautious design |

## 2. Virtualization internals

- `VirtualizingStackPanel` implements `ILogicalScrollable`. It creates visuals only for items near the viewport.
- `ItemsPresenter` hosts the items panel (`ItemsPanelTemplate`). Changing the panel can enable/disable virtualization.
- `ScrollViewer` orchestrates scroll offsets; virtualization works when `ScrollViewer` contains the items host directly.

Ensure virtualization stays active:
- Use `ItemsPanelTemplate` with `VirtualizingStackPanel` (or custom panel implementing `IVirtualizingPanel` soon).
- Avoid wrapping the items panel in another scroll viewer.
- Keep item visuals lightweight; container recycling reuses them to avoid allocations.

## 3. ListBox with virtualization

```xml
<ListBox Items="{Binding People}"
         SelectedItem="{Binding Selected}" Height="360">
  <ListBox.ItemsPanel>
    <ItemsPanelTemplate>
      <VirtualizingStackPanel IsVirtualizing="True"
                              Orientation="Vertical"
                              AreHorizontalSnapPointsRegular="True"/>
    </ItemsPanelTemplate>
  </ListBox.ItemsPanel>
  <ListBox.ItemTemplate>
    <DataTemplate x:DataType="vm:PersonViewModel">
      <Grid ColumnDefinitions="Auto,*,Auto" Height="40" Margin="2">
        <TextBlock Grid.Column="0" Text="{CompiledBinding Id}" Width="48" HorizontalAlignment="Right"/>
        <StackPanel Grid.Column="1" Orientation="Vertical" Spacing="2" Margin="8,0">
          <TextBlock Text="{CompiledBinding FullName}" FontWeight="SemiBold"/>
          <TextBlock Text="{CompiledBinding Email}" FontSize="12" Foreground="#6B7280"/>
        </StackPanel>
        <Button Grid.Column="2"
                Content="Open"
                Command="{Binding DataContext.OpenCommand, RelativeSource={RelativeSource AncestorType=ListBox}}"
                CommandParameter="{Binding}"/>
      </Grid>
    </DataTemplate>
  </ListBox.ItemTemplate>
</ListBox>
```

Tips:
- Fixed item height (40) helps virtualization predict layout quickly.
- Use `CompiledBinding` to avoid runtime reflection overhead.

## 4. ItemsRepeater for custom layouts

`ItemsRepeater` (namespace `Avalonia.Controls`) allows custom layout algorithms.

```xml
<ItemsRepeater Items="{Binding Photos}" xmlns:controls="clr-namespace:Avalonia.Controls;assembly=Avalonia.Controls">
  <ItemsRepeater.Layout>
    <controls:UniformGridLayout Orientation="Vertical" MinItemWidth="200"/>
  </ItemsRepeater.Layout>
  <ItemsRepeater.ItemTemplate>
    <DataTemplate x:DataType="vm:PhotoViewModel">
      <Border Margin="6" Padding="6" Background="#111827" CornerRadius="6">
        <StackPanel>
          <Image Source="{CompiledBinding ThumbnailSource}" Width="188" Height="120" Stretch="UniformToFill"/>
          <TextBlock Text="{CompiledBinding Title}" Margin="0,6,0,0"/>
        </StackPanel>
      </Border>
    </DataTemplate>
  </ItemsRepeater.ItemTemplate>
</ItemsRepeater>
```

`ItemsRepeater` virtualization is handled by the layout. Use `UniformGridLayout`, `StackLayout`, or custom layout.

## 5. SelectionModel for advanced scenarios

`SelectionModel<T>` enables multi-select, anchor selection, and virtualization-friendly selection.

```csharp
public SelectionModel<PersonViewModel> PeopleSelection { get; } = new() { SelectionMode = SelectionMode.Multiple };
```

Bind to `ListBox`:

```xml
<ListBox Items="{Binding People}" Selection="{Binding PeopleSelection}" Height="360"/>
```

`SelectionModel` lives in [`Avalonia.Controls/Selection/SelectionModel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Selection/SelectionModel.cs).

## 6. Incremental loading pattern

### View model

```csharp
public sealed class LogViewModel : ObservableObject
{
    private readonly ILogService _service;
    private readonly ObservableCollection<LogEntryViewModel> _entries = new();
    private bool _isLoading;

    public ReadOnlyObservableCollection<LogEntryViewModel> Entries { get; }
    public RelayCommand LoadMoreCommand { get; }

    private int _pageIndex;
    private const int PageSize = 500;

    public LogViewModel(ILogService service)
    {
        _service = service;
        Entries = new ReadOnlyObservableCollection<LogEntryViewModel>(_entries);
        LoadMoreCommand = new RelayCommand(async () => await LoadMoreAsync(), () => !_isLoading);
        _ = LoadMoreAsync();
    }

    private async Task LoadMoreAsync()
    {
        if (_isLoading) return;
        _isLoading = true;
        LoadMoreCommand.RaiseCanExecuteChanged();
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
            LoadMoreCommand.RaiseCanExecuteChanged();
        }
    }

    public bool HasMore { get; private set; } = true;
}
```

### XAML

```xml
<ListBox Items="{Binding Entries}" Height="480" ScrollViewer.ScrollChanged="ListBox_ScrollChanged">
  <ListBox.ItemTemplate>
    <DataTemplate x:DataType="vm:LogEntryViewModel">
      <TextBlock Text="{CompiledBinding Message}" FontFamily="Consolas"/>
    </DataTemplate>
  </ListBox.ItemTemplate>
</ListBox>
```

In code-behind, trigger `LoadMoreCommand` near bottom:

```csharp
private void ListBox_ScrollChanged(object? sender, ScrollChangedEventArgs e)
{
    if (DataContext is LogViewModel vm && vm.HasMore)
    {
        var scroll = e.Source as ScrollViewer;
        if (scroll is not null && scroll.Offset.Y + scroll.Viewport.Height >= scroll.Extent.Height - 200)
        {
            if (vm.LoadMoreCommand.CanExecute(null))
                vm.LoadMoreCommand.Execute(null);
        }
    }
}
```

## 7. DataGrid performance

- Set `EnableRowVirtualization="True"` (default) and `EnableColumnVirtualization="True"` if width changes are minimal.
- Define columns manually:

```xml
<DataGrid Items="{Binding People}" AutoGenerateColumns="False" IsReadOnly="True">
  <DataGrid.Columns>
    <DataGridTextColumn Header="Name" Binding="{Binding FullName}" Width="*"/>
    <DataGridTextColumn Header="Email" Binding="{Binding Email}" Width="2*"/>
    <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="Auto"/>
  </DataGrid.Columns>
</DataGrid>
```

- Use `DataGridTemplateColumn` sparingly; prefer text columns for speed.
- For huge datasets, consider server-side paging and virtualization; DataGrid can handle ~100k rows efficiently with virtualization enabled.

## 8. Grouping and hierarchical data

### Grouping with `CollectionView`

```csharp
var collectionView = new CollectionViewSource(People)
{
    GroupDescriptions = { new PropertyGroupDescription("Department") }
}.View;
```

Bind to `ItemsControl` with `GroupStyle`. Group headers should be minimal to keep virtualization efficient.

### TreeView virtualization

- Virtualizes expanded nodes only.
- Keep templates thin; consider lazy loading children.

```xml
<TreeView Items="{Binding Departments}" SelectedItems="{Binding SelectedDepartments}">
  <TreeView.ItemTemplate>
    <TreeDataTemplate ItemsSource="{Binding Teams}" x:DataType="vm:DepartmentViewModel">
      <TextBlock Text="{CompiledBinding Name}" FontWeight="SemiBold"/>
      <TreeDataTemplate.ItemTemplate>
        <DataTemplate x:DataType="vm:TeamViewModel">
          <TextBlock Text="{CompiledBinding Name}" Margin="24,0,0,0"/>
        </DataTemplate>
      </TreeDataTemplate.ItemTemplate>
    </TreeDataTemplate>
  </TreeView.ItemTemplate>
</TreeView>
```

Defer loading large subtrees until expanded (bind to command that fetches children on demand).

## 9. Diagnostics and profiling

- DevTools -> **Visual Tree**: see realized items count.
- DevTools -> **Events**: watch scroll events and virtualization events.
- Enable layout/render logs:

```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .LogToTrace(LogEventLevel.Debug, new[] { LogArea.Layout, LogArea.Rendering })
    .StartWithClassicDesktopLifetime(args);
```

- Use .NET memory profilers or `dotnet-counters` to monitor GC activity while scrolling.

## 10. Practice exercises

1. Create a log viewer with `ListBox + VirtualizingStackPanel` that streams 100k log lines; ensure smooth scroll and provide "Pause autoscroll".
2. Replace an `ItemsControl` dashboard with `ItemsRepeater` using `UniformGridLayout` for better virtualization.
3. Implement `SelectionModel` for multi-select email list and bind to checkboxes inside the template.
4. Add grouping to a `CollectionView`, showing group headers while keeping virtualization intact.
5. Profile a virtualized vs non-virtualized DataGrid with 200k rows and report memory usage.

## Look under the hood (source bookmarks)
- Virtualizing panels: [`VirtualizingStackPanel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/VirtualizingStackPanel.cs)
- Selection model: [`SelectionModel.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/Selection/SelectionModel.cs)
- ItemsRepeater layouts: [`UniformGridLayout.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ItemsRepeater/Layout/UniformGridLayout.cs)
- DataGrid internals: [`Avalonia.Controls.DataGrid`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Controls.DataGrid)
- Tree virtualization: [`TreeView.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TreeView.cs)

## Check yourself
- Which panels support virtualization and how do you enable them in ListBox/ItemsControl?
- How does `SelectionModel` improve multi-select scenarios compared to `SelectedItems`?
- What strategies keep DataGrid fast with huge datasets?
- How can you detect when virtualization is broken?

What's next
- Next: [Chapter 15](Chapter15.md)
