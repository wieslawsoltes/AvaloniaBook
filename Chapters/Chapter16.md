# 16. Files, storage, drag/drop, and clipboard

Goal
- Use Avalonia's storage provider to open, save, and enumerate files/folders across desktop, mobile, and browser.
- Abstract file dialogs behind services so MVVM view models remain testable.
- Handle drag-and-drop data (files, text, custom formats) and initiate drags from your app.
- Work with the clipboard safely, including multi-format payloads.

Why this matters
- Users expect native pickers, drag/drop, and clipboard support. Implementing them well keeps experiences consistent across platforms.
- Proper abstractions keep storage logic off the UI thread and ready for unit testing.

Prerequisites
- Chapter 9 (commands/input), Chapter 11 (MVVM), Chapter 12 (TopLevel services).

## 1. Storage provider fundamentals

All pickers live on `TopLevel.StorageProvider` (Window, control, etc.). The storage provider is an abstraction over native dialogs and sandbox rules.

```csharp
var topLevel = TopLevel.GetTopLevel(control);
if (topLevel?.StorageProvider is { } storage)
{
    // storage.OpenFilePickerAsync(...)
}
```

If `StorageProvider` is null, ensure the control is attached (e.g., call after `Loaded`/`Opened`).

`IStorageProvider` exposes capability flags such as `CanOpen`, `CanSave`, and `CanPickFolder`. Check them before presenting commands so sandboxed targets (browser/mobile) can hide unsupported options. Dialog methods accept option records (`FilePickerOpenOptions`, `FolderPickerOpenOptions`, etc.) that describe filters, suggested locations, and tokens for continuing previous sessions.

### 1.1 Service abstraction for MVVM

```csharp
public interface IFileDialogService
{
    Task<IReadOnlyList<IStorageFile>> OpenFilesAsync(FilePickerOpenOptions options);
    Task<IStorageFile?> SaveFileAsync(FilePickerSaveOptions options);
    Task<IStorageFolder?> PickFolderAsync(FolderPickerOpenOptions options);
}

public sealed class FileDialogService : IFileDialogService
{
    private readonly TopLevel _topLevel;
    public FileDialogService(TopLevel topLevel) => _topLevel = topLevel;

    public Task<IReadOnlyList<IStorageFile>> OpenFilesAsync(FilePickerOpenOptions options)
        => _topLevel.StorageProvider?.OpenFilePickerAsync(options) ?? Task.FromResult<IReadOnlyList<IStorageFile>>(Array.Empty<IStorageFile>());

    public Task<IStorageFile?> SaveFileAsync(FilePickerSaveOptions options)
        => _topLevel.StorageProvider?.SaveFilePickerAsync(options) ?? Task.FromResult<IStorageFile?>(null);

    public async Task<IStorageFolder?> PickFolderAsync(FolderPickerOpenOptions options)
    {
        if (_topLevel.StorageProvider is null)
            return null;
        var folders = await _topLevel.StorageProvider.OpenFolderPickerAsync(options);
        return folders.FirstOrDefault();
    }
}
```

Register the service per window (in DI) so view models request dialogs via `IFileDialogService` without touching UI types.

### 1.2 Launching files and URIs

`TopLevel.Launcher` gives access to `ILauncher`, which opens files, folders, or URIs using the platform shell (Finder, Explorer, default browser, etc.). Combine it with storage results to let users reveal files after saving.

```csharp
var topLevel = TopLevel.GetTopLevel(control);
if (topLevel?.Launcher is { } launcher && file is not null)
{
    await launcher.LaunchFileAsync(file);
    await launcher.LaunchUriAsync(new Uri("https://docs.avaloniaui.net"));
}
```

Return values indicate whether the launch succeeded; fall back to in-app viewers when it returns false.

## 2. Opening files (async streams)

```csharp
public async Task<string?> ReadTextFileAsync(IStorageFile file, CancellationToken ct)
{
    await using var stream = await file.OpenReadAsync();
    using var reader = new StreamReader(stream, Encoding.UTF8, detectEncodingFromByteOrderMarks: true);
    return await reader.ReadToEndAsync(ct);
}
```

- Always wrap streams in `using`/`await using`.
- Pass `CancellationToken` to long operations.
- For binary files, use `BinaryReader` or direct `Stream` APIs.

### 2.1 Remote or sandboxed locations

On Android/iOS/Browser the returned stream might be virtual (no direct file path). Always rely on stream APIs; avoid `LocalPath` if `Path` is null.

### 2.2 File type filters

```csharp
var options = new FilePickerOpenOptions
{
    Title = "Open images",
    AllowMultiple = true,
    SuggestedStartLocation = await storage.TryGetWellKnownFolderAsync(WellKnownFolder.Pictures),
    FileTypeFilter = new[]
    {
        new FilePickerFileType("Images")
        {
            Patterns = new[] { "*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif" }
        }
    }
};
```

`TryGetWellKnownFolderAsync` returns common directories when supported (desktop/mobile). Source: [`WellKnownFolder.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/WellKnownFolder.cs).

## 3. Saving files

```csharp
var saveOptions = new FilePickerSaveOptions
{
    Title = "Export report",
    SuggestedFileName = $"report-{DateTime.UtcNow:yyyyMMdd}.csv",
    DefaultExtension = "csv",
    FileTypeChoices = new[]
    {
        new FilePickerFileType("CSV") { Patterns = new[] { "*.csv" } },
        new FilePickerFileType("All files") { Patterns = new[] { "*" } }
    }
};

var file = await _dialogService.SaveFileAsync(saveOptions);
if (file is not null)
{
    await using var stream = await file.OpenWriteAsync();
    await using var writer = new StreamWriter(stream, Encoding.UTF8, leaveOpen: false);
    await writer.WriteLineAsync("Id,Name,Email");
    foreach (var row in rows)
        await writer.WriteLineAsync($"{row.Id},{row.Name},{row.Email}");
}
```

- `OpenWriteAsync` truncates the existing file. Use `OpenReadWriteAsync` for editing.
- Some platforms prompt for confirmation when writing to previously granted locations.

## 4. Enumerating folders

```csharp
var folder = await storage.TryGetFolderFromPathAsync(new Uri("file:///C:/Logs"));
if (folder is not null)
{
    await foreach (var item in folder.GetItemsAsync())
    {
        switch (item)
        {
            case IStorageFile file:
                // Process file
                break;
            case IStorageFolder subfolder:
                // Recurse or display
                break;
        }
    }
}
```

`GetItemsAsync()` returns an async sequence; iterate with `await foreach` on .NET 7+. Use `GetFilesAsync`/`GetFoldersAsync` to filter.

## 5. Bookmarks and persisted access

Some platforms revoke file permissions when your app suspends. If an `IStorageItem` reports `CanBookmark`, call `SaveBookmarkAsync()` and store the returned string (e.g., in preferences). Later, reopen it via `IStorageProvider.OpenFileBookmarkAsync`/`OpenFolderBookmarkAsync`.

```csharp
var bookmarks = new Dictionary<string, string>();

if (file.CanBookmark)
{
    var bookmarkId = await file.SaveBookmarkAsync();
    if (!string.IsNullOrEmpty(bookmarkId))
        bookmarks[file.Path.ToString()] = bookmarkId;
}

var restored = await storage.OpenFileBookmarkAsync(bookmarkId);
```

Keep bookmarks updated when users revoke access. iOS and Android can throw when bookmarks expire—wrap calls in try/catch and ask users to reselect the folder. Desktop platforms typically return standard file paths, but bookmarks still help retain portal-granted access (e.g., Flatpak).

`IStorageItem.GetBasicPropertiesAsync()` exposes metadata (size, modified time) without opening streams—use it when building file browsers.

## 6. Platform notes

| Platform | Storage provider | Considerations |
| --- | --- | --- |
| Windows/macOS/Linux | Native dialogs; file system access | Standard read/write. Some Linux desktops require portals (Flatpak/Snap). |
| Android/iOS | Native pickers; sandboxed URIs | Streams may be content URIs; persist permissions if needed. |
| Browser (WASM) | File System Access API | Requires user gestures; may return handles that expire when page reloads. |

Wrap storage calls in try/catch to handle permission denials or canceled dialogs gracefully.

## 7. Drag-and-drop: receiving data

```xml
<Border AllowDrop="True"
        DragOver="OnDragOver"
        Drop="OnDrop"
        Background="#111827" Padding="12">
  <TextBlock Text="Drop files or text" Foreground="#CBD5F5"/>
</Border>
```

```csharp
private void OnDragOver(object? sender, DragEventArgs e)
{
    if (e.Data.Contains(DataFormats.Files) || e.Data.Contains(DataFormats.Text))
        e.DragEffects = DragDropEffects.Copy;
    else
        e.DragEffects = DragDropEffects.None;
}

private async void OnDrop(object? sender, DragEventArgs e)
{
    var files = await e.Data.GetFilesAsync();
    if (files is not null)
    {
        foreach (var item in files.OfType<IStorageFile>())
        {
            await using var stream = await item.OpenReadAsync();
            // import
        }
        return;
    }

    if (e.Data.Contains(DataFormats.Text))
    {
        var text = await e.Data.GetTextAsync();
        // handle text
    }
}
```

- `GetFilesAsync()` returns storage items; check for `IStorageFile`.
- Inspect `e.KeyModifiers` to adjust behavior (e.g., Ctrl for copy).

### 7.1 Initiating drag-and-drop

```csharp
private async void DragSource_PointerPressed(object? sender, PointerPressedEventArgs e)
{
    if (sender is not Control control)
        return;

    var data = new DataObject();
    data.Set(DataFormats.Text, "Example text");

    var effects = await DragDrop.DoDragDrop(e, data, DragDropEffects.Copy | DragDropEffects.Move);
    if (effects.HasFlag(DragDropEffects.Move))
    {
        // remove item
    }
}
```

`DataObject` supports multiple formats (text, files, custom types). For custom data, both source and target must agree on a format string.

### 7.2 Custom visuals and adorners

Wrap your layout in an `AdornerDecorator` and render drop cues while a drag is in progress. Toggle overlays in `DragEnter`/`DragLeave` handlers to show hit targets or counts.

```csharp
private void OnDragEnter(object? sender, DragEventArgs e)
{
    _dropOverlay.IsVisible = true;
}

private void OnDragLeave(object? sender, RoutedEventArgs e)
{
    _dropOverlay.IsVisible = false;
}
```

You can also inspect `e.DragEffects` to switch icons (copy vs move) or reject unsupported formats with a custom message. For complex scenarios create a lightweight `Window` as a drag adorner so the pointer stays responsive on multi-monitor setups.

## 8. Clipboard operations

```csharp
public interface IClipboardService
{
    Task SetTextAsync(string text);
    Task<string?> GetTextAsync();
    Task SetDataObjectAsync(IDataObject dataObject);
    Task<IReadOnlyList<string>> GetFormatsAsync();
}

public sealed class ClipboardService : IClipboardService
{
    private readonly TopLevel _topLevel;
    public ClipboardService(TopLevel topLevel) => _topLevel = topLevel;

    public Task SetTextAsync(string text) => _topLevel.Clipboard?.SetTextAsync(text) ?? Task.CompletedTask;
    public Task<string?> GetTextAsync() => _topLevel.Clipboard?.GetTextAsync() ?? Task.FromResult<string?>(null);
    public Task SetDataObjectAsync(IDataObject dataObject) => _topLevel.Clipboard?.SetDataObjectAsync(dataObject) ?? Task.CompletedTask;
    public Task<IReadOnlyList<string>> GetFormatsAsync() => _topLevel.Clipboard?.GetFormatsAsync() ?? Task.FromResult<IReadOnlyList<string>>(Array.Empty<string>());
}
```

### 8.1 Multi-format clipboard payload

```csharp
var dataObject = new DataObject();
dataObject.Set(DataFormats.Text, "Plain text");
dataObject.Set("text/html", "<strong>Bold</strong>");
dataObject.Set("application/x-myapp-item", myItemId);

await clipboardService.SetDataObjectAsync(dataObject);
var formats = await clipboardService.GetFormatsAsync();
```

Browser restrictions: clipboard APIs require user gesture and may only allow text formats.

## 9. Error handling & async patterns

- Wrap storage operations in try/catch for `IOException`, `UnauthorizedAccessException`.
- Offload heavy parsing to background threads with `Task.Run` (keep UI thread responsive).
- Use `Progress<T>` to report progress to view models.

```csharp
var progress = new Progress<int>(value => ImportProgress = value);
await _importService.ImportAsync(file, progress, cancellationToken);
```

## 10. Diagnostics

- Log storage/drag errors with `LogArea.Platform` or custom logger.
- DevTools -> Events tab shows drag/drop events.
- On Linux portals (Flatpak/Snap), check console logs for portal errors.

## 11. Practice exercises

1. Implement `IFileDialogService` and expose commands for Open, Save, and Pick Folder; update the UI with results.
2. Build a file manager pane that enumerates folders asynchronously, persists bookmarks for sandboxed platforms, and mirrors changes via drag/drop.
3. Create a clipboard history panel that stores the last N text snippets using the `IClipboard` service.
4. Add drag support from a list to the OS shell (export files) with a custom adorner overlay showing the item count.
5. Implement cancellation for long-running file imports and confirm resources are disposed when canceled.

## Look under the hood (source bookmarks)
- Storage provider: [`IStorageProvider`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/IStorageProvider.cs)
- File/folder abstractions: [`IStorageFile`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FileIO/IStorageFile.cs), [`IStorageFolder`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FileIO/IStorageFolder.cs)
- Bookmarks & metadata: [`IStorageItem`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/IStorageItem.cs)
- Picker options: [`FilePickerOpenOptions`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FilePickerOpenOptions.cs), [`FilePickerSaveOptions`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FilePickerSaveOptions.cs)
- Drag/drop: [`DragDrop.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/DragDrop.cs), [`DataObject.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/DataObject.cs)
- Clipboard: [`IClipboard`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/IClipboard.cs)
- Launcher: [`ILauncher`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/ILauncher.cs)

## Check yourself
- How do you obtain an `IStorageProvider` when you only have a view model?
- What are the advantages of using asynchronous streams (`await using`) when reading/writing files?
- How can you detect which drag/drop formats are available during a drop event?
- Which APIs let you enumerate well-known folders cross-platform?
- What restrictions exist for clipboard and storage operations on browser/mobile?

What's next
- Next: [Chapter 17](Chapter17.md)
