# 16. Files, storage, drag/drop, and clipboard

Goal
- Learn how to open/save files and pick folders using the platform Storage Provider
- Learn safe patterns for reading and writing files asynchronously
- Add drag-and-drop support to accept files and text, and to start a drag from your app
- Use the clipboard to copy, cut, and paste text and richer data

Why this matters
- Every real app moves data in and out: import/export, user selections, assets, logs
- Users expect familiar OS-native pickers, drag-and-drop, and clipboard behavior
- Avalonia provides a single API that works across Windows, macOS, Linux, Android, iOS, and the Browser

Quick start: pick a file and read text
1) Get the storage provider from a TopLevel (Window, control, etc.)
2) Show the Open File Picker
3) Read the selected file using a stream

C#
```csharp
using Avalonia;
using Avalonia.Controls;
using Avalonia.Platform.Storage;
using System.IO;
using System.Text;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private async void OnOpenTextFile(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var sp = this.StorageProvider; // same as TopLevel.GetTopLevel(this)!.StorageProvider

        var files = await sp.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "Open a text file",
            AllowMultiple = false,
            FileTypeFilter = new[]
            {
                new FilePickerFileType("Text files") { Patterns = new [] { "*.txt", "*.log" } },
                FilePickerFileTypes.All
            }
        });

        var file = files?.Count > 0 ? files[0] : null;
        if (file is null)
            return;

        // Safe async read
        await using var stream = await file.OpenReadAsync();
        using var reader = new StreamReader(stream, Encoding.UTF8, leaveOpen: false);
        var text = await reader.ReadToEndAsync();
        // TODO: show text in your UI
    }
}
```

Saving a file
- Use SaveFilePickerAsync to ask for the target path and name
- You can suggest a default file name and extension

```csharp
var sp = this.StorageProvider;
var sf = await sp.SaveFilePickerAsync(new FilePickerSaveOptions
{
    Title = "Save report",
    SuggestedFileName = "report.txt",
    DefaultExtension = "txt",
    FileTypeChoices = new[]
    {
        new FilePickerFileType("Text") { Patterns = new[] { "*.txt" } },
        new FilePickerFileType("Markdown") { Patterns = new[] { "*.md" } }
    }
});
if (sf is not null)
{
    await using var dst = await sf.OpenWriteAsync();
    await using var writer = new StreamWriter(dst, Encoding.UTF8, leaveOpen: false);
    await writer.WriteAsync("Hello from Avalonia!\n");
}
```

Pick multiple files
- Set AllowMultiple = true
- You’ll get IReadOnlyList<IStorageFile>

```csharp
var files = await this.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
{
    Title = "Pick images",
    AllowMultiple = true,
    FileTypeFilter = new[]
    {
        new FilePickerFileType("Images") { Patterns = new [] { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp" } }
    }
});
```

Pick a folder and enumerate items
- Use OpenFolderPickerAsync to choose one or more folders
- Enumerate files/folders via IStorageFolder.GetItemsAsync

```csharp
var folders = await this.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
{
    Title = "Pick a folder",
    AllowMultiple = false
});
var folder = folders?.Count > 0 ? folders[0] : null;
if (folder is not null)
{
    var items = await folder.GetItemsAsync(); // files and subfolders
    foreach (var item in items)
    {
        // item is IStorageItem; you can check if it’s a file or folder
        if (item is IStorageFile f)
        {
            // use f.OpenReadAsync / OpenWriteAsync
        }
        else if (item is IStorageFolder d)
        {
            // recurse or display
        }
    }
}
```

Access well-known folders
- Some platforms expose Desktop, Documents, Downloads, Music, Pictures, Videos
- Ask via TryGetWellKnownFolderAsync; it returns null if not available

```csharp
var pictures = await this.StorageProvider.TryGetWellKnownFolderAsync(WellKnownFolder.Pictures);
if (pictures is not null)
{
    var items = await pictures.GetItemsAsync();
    // …
}
```

Safe file IO patterns
- Always use async APIs (OpenReadAsync/OpenWriteAsync) to avoid blocking the UI thread
- Wrap streams in using/await using to ensure disposal
- Prefer UTF-8 unless you must match a specific encoding
- Consider cancellation (pass CancellationToken if available in your app flow)

Drag-and-drop: accept files and text
1) Enable AllowDrop on the target control or container
2) Handle DragOver to indicate allowed effects
3) Handle Drop to read IDataObject content

XAML
```xml
<Border AllowDrop="True"
        DragOver="OnDragOver"
        Drop="OnDrop"
        BorderThickness="2" BorderBrush="Gray" Padding="16">
    <TextBlock Text="Drop files or text here"/>
</Border>
```

C#
```csharp
using Avalonia.Input;
using Avalonia.Platform.Storage;

private void OnDragOver(object? sender, DragEventArgs e)
{
    // Advertise the effect based on available data
    if (e.Data.Contains(DataFormats.Files) || e.Data.Contains(DataFormats.Text))
        e.DragEffects = DragDropEffects.Copy;
    else
        e.DragEffects = DragDropEffects.None;
}

private async void OnDrop(object? sender, DragEventArgs e)
{
    // Files (as IStorageItem list)
    var storageItems = await e.Data.GetFilesAsync();
    if (storageItems is not null)
    {
        foreach (var item in storageItems)
        {
            if (item is IStorageFile file)
            {
                await using var s = await file.OpenReadAsync();
                // read or import
            }
        }
        return;
    }

    // Or plain text
    if (e.Data.Contains(DataFormats.Text))
    {
        var text = await e.Data.GetTextAsync();
        // use text
    }
}
```

Start a drag from your app
- Build an IDataObject and call DragDrop.DoDragDrop from a pointer event handler
- Choose the allowed effects (Copy/Move/Link)

```csharp
using Avalonia.Input;
using Avalonia;

private async void OnPointerPressed(object? sender, PointerPressedEventArgs e)
{
    var data = new DataObject();
    data.Set(DataFormats.Text, "Dragged text from my app");
    var result = await DragDrop.DoDragDrop(e, data, DragDropEffects.Copy | DragDropEffects.Move);
    // result tells you what happened
}
```

Notes on drag-and-drop
- Use e.KeyModifiers in DragOver to adjust effects (e.g., Ctrl for copy)
- IDataObject supports multiple formats; you can set text, files, custom types (within process)
- For file drags, many platforms supply virtual files that you read via IStorageFile stream APIs

Clipboard basics
- Access the clipboard via this.Clipboard or Application.Current.Clipboard from a TopLevel
- Get/Set text and richer data via IDataObject

```csharp
var clipboard = this.Clipboard; // TopLevel clipboard
await clipboard.SetTextAsync("Hello clipboard");
var text = await clipboard.GetTextAsync();
```

Advanced clipboard
- Set a full IDataObject (e.g., text + HTML + custom in-process data)
- List available formats with GetFormatsAsync
- Clear the clipboard with ClearAsync; use FlushAsync on platforms that support it to persist after exit

```csharp
var dobj = new DataObject();

dobj.Set(DataFormats.Text, "plain");
dobj.Set("text/html", "<b>bold</b>");

await this.Clipboard.SetDataObjectAsync(dobj);
var formats = await this.Clipboard.GetFormatsAsync();
```

Cross-platform notes and limitations
- Desktop (Windows/macOS/Linux): Full-featured pickers, drag-and-drop, and clipboard
- Mobile (Android/iOS): Pickers use native UI; file system sandboxes and permissions apply
- Browser (WASM): Pickers and clipboard require user gestures; not all formats are available; drag-and-drop limited to browser capabilities
- SystemDialog APIs are obsolete; use TopLevel.StorageProvider for dialogs

Troubleshooting
- If StorageProvider is null, ensure you’re calling it from a control attached to the visual tree (after the Window is opened)
- For drag-and-drop not firing, confirm AllowDrop=True and that handlers are attached on the element under the pointer
- Clipboard failures on the browser usually mean missing user gesture or permissions
- File filters are hints; some platforms may still let the user choose other files

Check yourself
- Add a button that opens a text file and displays its contents in a TextBox
- Add a Save button that writes the TextBox contents to a user-chosen file
- Enable drag-and-drop of one or more files; count them and list their names
- Add Copy/Paste buttons that use IClipboard to copy and paste TextBox text

Extra practice
- Add a filter to allow only “.csv” and “.xlsx” files
- Drag data from your app (text) into another app; observe the effect result
- Copy HTML to the clipboard and verify how different platforms paste it
- Use TryGetWellKnownFolderAsync to show user pictures and let them pick one

Look under the hood
- IStorageProvider interface (open/save/folder pickers): [Avalonia.Base/Platform/Storage/IStorageProvider.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/IStorageProvider.cs)
- File/folder items: IStorageFile, IStorageFolder: [Avalonia.Base/Platform/Storage/FileIO/IStorageFile.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FileIO/IStorageFile.cs) and [Avalonia.Base/Platform/Storage/FileIO/IStorageFolder.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FileIO/IStorageFolder.cs)
- Picker options and filters: FilePickerOpenOptions, FilePickerSaveOptions, FilePickerFileType, FilePickerFileTypes: [Avalonia.Base/Platform/Storage/FilePickerOpenOptions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FilePickerOpenOptions.cs) and [Avalonia.Base/Platform/Storage/FilePickerSaveOptions.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FilePickerSaveOptions.cs) and [Avalonia.Base/Platform/Storage/FilePickerFileType.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/FilePickerFileType.cs)
- WellKnownFolder enum: [Avalonia.Base/Platform/Storage/WellKnownFolder.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/Storage/WellKnownFolder.cs)
- DragDrop APIs and events: [Avalonia.Base/Input/DragDrop.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/DragDrop.cs)
- IDataObject and formats: [Avalonia.Base/Input/IDataObject.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/IDataObject.cs) and [Avalonia.Base/Input/DataFormats.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Input/DataFormats.cs)
- Clipboard interface: [Avalonia.Base/Platform/IClipboard.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Platform/IClipboard.cs)
- TextBox clipboard events (copy/cut/paste hooks): [Avalonia.Controls/TextBox.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/TextBox.cs)

What’s next
- Next: [Chapter 17](Chapter17.md)
