# 14. Lists, virtualization, and performance

Goal
- Render thousands to millions of items smoothly by using the right control, lightweight templates, and UI virtualization.

Why this matters
- Lists are everywhere: mail, logs, search results, tables. Without virtualization, memory and CPU costs explode and scrolling stutters.
- Avalonia gives you the tools to keep UIs fast if you pick the right patterns.

Pick the right control
- ItemsControl: simplest items host; no selection or keyboard navigation built in. Good for read‑only, simple visuals.
- ListBox: adds selection (single/multiple), keyboard navigation, and item container generation. Good default for list UIs.
- DataGrid: tabular data with columns, sorting, editing, and virtualization; great for large datasets that fit a grid.
- TreeView: hierarchical lists; consider flattening + grouping if deep trees hurt performance.

Data and templates you’ll actually use
- Back your list with ObservableCollection<T> so add/remove updates are cheap and incremental.
- Provide ItemTemplate to render lightweight visuals:
  - Prefer a single panel (e.g., Grid with defined columns/rows) over nested StackPanels.
  - Minimize triggers/animations per item; avoid heavy effects and large images.
  - Do work in view models (pre‑format strings, compute colors) instead of costly converters per item.

UI virtualization: the mental model
- Only the items in (or near) the viewport have visual containers; off‑screen items are not realized.
- Recycling reuses containers as you scroll so the app avoids allocating/destroying many controls.
- Virtualization depends on the items panel and scroll host. Don’t accidentally disable it by changing panels.

Enable virtualization (ListBox and ItemsControl)
- Use a virtualizing panel for the items host. The common choice is VirtualizingStackPanel.

Example: ListBox with virtualization and a lightweight template

```xml
<ListBox Items="{Binding Items}" SelectedItem="{Binding Selected}">
  <ListBox.ItemsPanel>
    <ItemsPanelTemplate>
      <VirtualizingStackPanel/>
    </ItemsPanelTemplate>
  </ListBox.ItemsPanel>
  <ListBox.ItemTemplate>
    <DataTemplate>
      <Grid ColumnDefinitions="Auto,*,Auto" Margin="4" Height="32">
        <TextBlock Grid.Column="0" Text="{Binding Id}" Width="56" HorizontalAlignment="Right"/>
        <TextBlock Grid.Column="1" Text="{Binding Title}" Margin="8,0"/>
        <TextBlock Grid.Column="2" Text="{Binding Status}" Foreground="{Binding StatusColor}"/>
      </Grid>
    </DataTemplate>
  </ListBox.ItemTemplate>
</ListBox>
```

Notes
- Keep row Height fixed when possible for smoother virtualization.
- Avoid placing a ScrollViewer inside each item; the ListBox already scrolls.

ItemsControl with virtualization

```xml
<ItemsControl Items="{Binding Items}">
  <ItemsControl.ItemsPanel>
    <ItemsPanelTemplate>
      <VirtualizingStackPanel/>
    </ItemsPanelTemplate>
  </ItemsControl.ItemsPanel>
  <ItemsControl.ItemTemplate>
    <DataTemplate>
      <Border Margin="2" Padding="6">
        <TextBlock Text="{Binding}"/>
      </Border>
    </DataTemplate>
  </ItemsControl.ItemTemplate>
</ItemsControl>
```

Selection and commands without leaks
- Bind SelectedItem (or SelectedItems for multi‑select) to your view model.
- Prefer commands in the item view model (e.g., OpenCommand) instead of per‑item event handlers.

Incremental loading: load what you need when you need it
- Pattern: begin with the first N items, then append more when the user scrolls near the bottom.
- Keep an IsLoading flag and a cancellation token to avoid overlapping requests.

Simple pattern using a sentinel “Load more” item

```xml
<ListBox Items="{Binding PagedItems}">
  <ListBox.ItemTemplate>
    <DataTemplate x:DataType="vm:ItemOrCommand">
      <ContentControl>
        <ContentControl.Styles>
          <Style Selector="ContentControl:has(^vm|LoadMore)">
            <Setter Property="ContentTemplate">
              <Setter.Value>
                <DataTemplate>
                  <Button Command="{Binding DataContext.LoadMoreCommand, RelativeSource={RelativeSource AncestorType=ListBox}}"
                          Content="Load more…"/>
                </DataTemplate>
              </Setter.Value>
            </Setter>
          </Style>
          <Style Selector="ContentControl:has(^vm|Item)">
            <Setter Property="ContentTemplate">
              <Setter.Value>
                <DataTemplate>
                  <TextBlock Text="{Binding Title}"/>
                </DataTemplate>
              </Setter.Value>
            </Setter>
          </Style>
        </ContentControl.Styles>
      </ContentControl>
    </DataTemplate>
  </ListBox.ItemTemplate>
</ListBox>
```

View model sketch

```csharp
public partial class ListPageViewModel
{
    public ObservableCollection<ItemOrCommand> PagedItems { get; } = new();
    public ICommand LoadMoreCommand { get; }
    private int _page = 0;
    private const int PageSize = 200;
    private bool _loading;

    public ListPageViewModel()
    {
        LoadMoreCommand = new RelayCommand(async () => await LoadPageAsync(), () => !_loading);
        _ = LoadPageAsync();
    }

    private async Task LoadPageAsync()
    {
        if (_loading) return;
        _loading = true;
        try
        {
            if (PagedItems.LastOrDefault() is LoadMore lm)
                PagedItems.Remove(lm);

            var next = await Repository.GetPageAsync(_page, PageSize);
            foreach (var item in next)
                PagedItems.Add(new Item(item));

            _page++;
            if (next.Count == PageSize)
                PagedItems.Add(new LoadMore());
        }
        finally
        {
            _loading = false;
            (LoadMoreCommand as RelayCommand)?.RaiseCanExecuteChanged();
        }
    }
}

public abstract record ItemOrCommand;
public record Item(Model Model) : ItemOrCommand { public string Title => Model.Title; }
public record LoadMore : ItemOrCommand;
```

DataGrid performance quick wins
- Define columns explicitly; avoid AutoGenerateColumns for huge datasets.
- Prefer TextBlock for display cells; use editing templates only when needed.
- Keep cell templates lean; avoid images/effects in cells unless necessary.
- Paging and server‑side filtering/sorting reduce memory and keep UI snappy.

TreeView tips
- Keep item visuals light and collapse subtrees not in view.
- If the tree is deep and wide, consider an alternative UX (search + flat list/grouping) for performance.

Scrolling smoothness and item size
- Fixed item heights help virtualization predict layout and reduce jank.
- If items vary, cap the maximum size and truncate/clip text rather than wrapping across many lines.

Avoid these pitfalls
- Nesting ScrollViewer inside each item: breaks virtualization and harms perf.
- Binding to huge images per row: use thumbnails or async image loading.
- Heavy converters per row: precompute in view models.
- Too many nested panels: flatten with Grid for fewer elements.
- Selecting all items frequently: track only what you need.

Hands‑on: build a fast log viewer
1) Create a ListBox with VirtualizingStackPanel and a fixed‑height row template.
2) Stream log lines into an ObservableCollection.
3) Add a Toggle to pause autoscroll when the user interacts.
4) Add a filter box that updates the source collection in batches to avoid UI thrash.

Look under the hood (browse the source)
- Controls & containers: src/Avalonia.Controls
- DataGrid: src/Avalonia.Controls.DataGrid
- Diagnostics/DevTools: src/Avalonia.Diagnostics

Self‑check
- What’s the difference between ItemsControl and ListBox?
- Why does a fixed item height help virtualization?
- How would you implement incremental loading for a remote API?
- Name three things that commonly break virtualization.

Extra practice
- Replace nested StackPanels in an item template with a single Grid and compare element counts.
- Add “Load more” to a list that currently fetches everything at once.
- Profile memory while scrolling 100k items with and without virtualization.

What’s next
- Next: [Chapter 15](Chapter15.md)
