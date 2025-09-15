# 17. Background work and networking

Goal
- Run long operations without freezing the UI using async/await
- Report progress and support cancel for a great UX
- Make simple and reliable HTTP calls (GET/POST) and download files with progress

Why this matters
- Real apps load data, process files, and talk to web services
- Users expect responsive UIs with a spinner or progress, and the option to cancel
- Async-first code is simpler, safer, and scales across desktop, mobile, and browser

Understand the UI thread
- Avalonia has a UI thread that must update visuals and properties for UI elements
- Keep the UI thread free: use async I/O or move CPU-heavy work to a background thread
- Use Dispatcher.UIThread to marshal back to UI when you need to update visuals from background code

Quick start: run background work safely
C#
```csharp
using Avalonia.Threading;

private async Task<int> CountToAsync(int limit, CancellationToken ct)
{
    var count = 0;
    // Simulate CPU-bound work; for real CPU-heavy tasks, consider Task.Run
    for (int i = 0; i < limit; i++)
    {
        ct.ThrowIfCancellationRequested();
        await Task.Delay(1, ct); // non-blocking wait
        count++;
        if (i % 100 == 0)
        {
            // Update the UI safely
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                StatusText = $"Working... {i}/{limit}"; // assume a property that notifies
            });
        }
    }
    return count;
}
```

Progress reporting with IProgress<T>
- Prefer IProgress<T> to decouple work from UI
- Updates are automatically marshaled to the captured context when created on UI thread

```csharp
public async Task ProcessAsync(IProgress<double> progress, CancellationToken ct)
{
    var total = 1000;
    for (int i = 0; i < total; i++)
    {
        ct.ThrowIfCancellationRequested();
        await Task.Delay(1, ct);
        progress.Report((double)i / total);
    }
}

// Usage from UI (e.g., ViewModel or code-behind)
var cts = new CancellationTokenSource();
var progress = new Progress<double>(p =>
{
    ProgressValue = p * 100; // 0..100 for ProgressBar
});
await ProcessAsync(progress, cts.Token);
```

Bind a ProgressBar
XAML
```xml
<StackPanel Spacing="8">
  <ProgressBar Minimum="0" Maximum="100" Value="{Binding ProgressValue}" IsIndeterminate="{Binding IsBusy}"/>
  <TextBlock Text="{Binding StatusText}"/>
  <StackPanel Orientation="Horizontal" Spacing="8">
    <Button Content="Start" Command="{Binding StartCommand}"/>
    <Button Content="Cancel" Command="{Binding CancelCommand}"/>
  </StackPanel>
</StackPanel>
```

ViewModel (simplified)
```csharp
public class WorkViewModel : INotifyPropertyChanged
{
    private double _progressValue;
    private bool _isBusy;
    private string? _statusText;
    private CancellationTokenSource? _cts;

    public double ProgressValue { get => _progressValue; set { _progressValue = value; OnPropertyChanged(); } }
    public bool IsBusy { get => _isBusy; set { _isBusy = value; OnPropertyChanged(); } }
    public string? StatusText { get => _statusText; set { _statusText = value; OnPropertyChanged(); } }

    public ICommand StartCommand => new RelayCommand(async _ => await StartAsync(), _ => !IsBusy);
    public ICommand CancelCommand => new RelayCommand(_ => _cts?.Cancel(), _ => IsBusy);

    private async Task StartAsync()
    {
        IsBusy = true;
        _cts = new CancellationTokenSource();
        var progress = new Progress<double>(p => ProgressValue = p * 100);
        try
        {
            StatusText = "Starting...";
            await ProcessAsync(progress, _cts.Token);
            StatusText = "Done";
        }
        catch (OperationCanceledException)
        {
            StatusText = "Canceled";
        }
        finally
        {
            IsBusy = false;
            _cts = null;
        }
    }

    // Example background work
    private static async Task ProcessAsync(IProgress<double> progress, CancellationToken ct)
    {
        const int total = 1000;
        for (int i = 0; i < total; i++)
        {
            ct.ThrowIfCancellationRequested();
            await Task.Delay(2, ct);
            progress.Report((double)(i + 1) / total);
        }
    }

    // INotifyPropertyChanged helper omitted for brevity
}
```

Networking basics: HttpClient
- Use a single HttpClient for your app or feature area
- Prefer async methods: GetAsync, PostAsync, ReadAsStreamAsync, ReadFromJsonAsync
- Handle timeouts and cancellation; check IsSuccessStatusCode

Fetch JSON
```csharp
using System.Net.Http;
using System.Net.Http.Json;

private static readonly HttpClient _http = new HttpClient
{
    Timeout = TimeSpan.FromSeconds(30)
};

public async Task<MyDto?> LoadDataAsync(CancellationToken ct)
{
    using var resp = await _http.GetAsync("https://example.com/api/data", ct);
    resp.EnsureSuccessStatusCode();
    return await resp.Content.ReadFromJsonAsync<MyDto>(cancellationToken: ct);
}

public record MyDto(string Name, int Count);
```

Post JSON
```csharp
public async Task SaveDataAsync(MyDto dto, CancellationToken ct)
{
    using var resp = await _http.PostAsJsonAsync("https://example.com/api/data", dto, ct);
    resp.EnsureSuccessStatusCode();
}
```

Download a file with progress
```csharp
public async Task DownloadAsync(Uri url, IStorageFile destination, IProgress<double> progress, CancellationToken ct)
{
    using var resp = await _http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct);
    resp.EnsureSuccessStatusCode();

    var contentLength = resp.Content.Headers.ContentLength;
    await using var httpStream = await resp.Content.ReadAsStreamAsync(ct);
    await using var fileStream = await destination.OpenWriteAsync();

    var buffer = new byte[81920];
    long totalRead = 0;
    int read;
    while ((read = await httpStream.ReadAsync(buffer.AsMemory(0, buffer.Length), ct)) > 0)
    {
        await fileStream.WriteAsync(buffer.AsMemory(0, read), ct);
        totalRead += read;
        if (contentLength.HasValue)
        {
            progress.Report((double)totalRead / contentLength.Value);
        }
    }
}
```

UI threading tips
- Never block with .Result or .Wait() on async tasks; await them instead
- For CPU-heavy work, wrap synchronous code in Task.Run and report progress back via IProgress<T>
- Use Dispatcher.UIThread.InvokeAsync/Post to update UI from background threads if you didn’t use IProgress<T>

Cross-platform notes
- Desktop: Full threading available; async/await with HttpClient works as expected
- Mobile (Android/iOS): Add network permissions as required by the platform; background tasks may be throttled when app is suspended
- Browser (WebAssembly): HttpClient uses fetch under the hood; CORS applies; sockets and some protocols may not be available; avoid long blocking loops

Troubleshooting
- UI freeze? Look for synchronous waits (.Result/.Wait) or blocking I/O on UI thread
- Progress not updating? Ensure property change notifications fire and bindings are correct
- Networking errors? Check HTTPS, certificates, CORS (in browser), and timeouts
- Cancel not working? Pass the same CancellationToken to all async calls in the operation

Check yourself
- Add a Start button that runs a fake task for 5 seconds and updates a ProgressBar
- Add a Cancel button that stops the task midway and sets a status message
- Load a small JSON from a public API and show one field in the UI
- Download a file to disk and show progress from 0 to 100

Extra practice
- Wrap a CPU-intensive calculation with Task.Run and report progress
- Add retry with exponential backoff around a flaky HTTP call
- Let the user pick a destination file (using Chapter 16’s SaveFilePicker) for the downloader

Look under the hood
- Avalonia UI thread and dispatcher: [Avalonia.Base/Threading/Dispatcher.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Threading/Dispatcher.cs)
- ProgressBar control: [Avalonia.Controls/ProgressBar.cs](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/ProgressBar.cs)
- Binding basics (see binding implementation): [Markup/Avalonia.Markup](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Markup/Avalonia.Markup)

What’s next
- Next: [Chapter 18](Chapter18.md)
