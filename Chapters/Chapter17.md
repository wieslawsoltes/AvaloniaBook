# 17. Background work and networking

Goal
- Keep the UI responsive while doing heavy or long-running tasks using async/await, Task.Run, and progress reporting.
- Surface status, progress, and cancellation to users.
- Call web APIs with HttpClient, handle retries/timeouts, and stream downloads/upload.
- Respond to connectivity changes and test background logic predictably.

Why this matters
- Real apps load data, crunch files, and hit APIs. Blocking the UI thread ruins UX.
- Async-first code scales across desktop, mobile, and browser with minimal changes.

Prerequisites
- Chapters 8-9 (binding & commands), Chapter 11 (MVVM), Chapter 16 (file IO).

## 1. The UI thread and Dispatcher

Avalonia has a single UI thread managed by `Dispatcher.UIThread`. UI elements and bound properties must be updated on this thread.

Rules of thumb:
- Prefer async I/O (await network/file operations).
- For CPU-bound work, use `Task.Run` to offload to a thread pool thread.
- Use `Dispatcher.UIThread.Post/InvokeAsync` to marshal back to the UI thread if needed (though `Progress<T>` usually keeps you on the UI thread).

```csharp
await Dispatcher.UIThread.InvokeAsync(() => Status = "Ready");
```

## 2. Async workflow pattern (ViewModel)

```csharp
public sealed class WorkViewModel : ObservableObject
{
    private CancellationTokenSource? _cts;
    private double _progress;
    private string _status = "Idle";
    private bool _isBusy;

    public double Progress { get => _progress; set => SetProperty(ref _progress, value); }
    public string Status { get => _status; set => SetProperty(ref _status, value); }
    public bool IsBusy { get => _isBusy; set => SetProperty(ref _isBusy, value); }

    public RelayCommand StartCommand { get; }
    public RelayCommand CancelCommand { get; }

    public WorkViewModel()
    {
        StartCommand = new RelayCommand(async _ => await StartAsync(), _ => !IsBusy);
        CancelCommand = new RelayCommand(_ => _cts?.Cancel(), _ => IsBusy);
    }

    private async Task StartAsync()
    {
        IsBusy = true;
        _cts = new CancellationTokenSource();
        var progress = new Progress<double>(value => Progress = value * 100);

        try
        {
            Status = "Processing...";
            await FakeWorkAsync(progress, _cts.Token);
            Status = "Completed";
        }
        catch (OperationCanceledException)
        {
            Status = "Canceled";
        }
        catch (Exception ex)
        {
            Status = $"Error: {ex.Message}";
        }
        finally
        {
            IsBusy = false;
            _cts = null;
        }
    }

    private static async Task FakeWorkAsync(IProgress<double> progress, CancellationToken ct)
    {
        const int total = 1000;
        await Task.Run(async () =>
        {
            for (int i = 0; i < total; i++)
            {
                ct.ThrowIfCancellationRequested();
                await Task.Delay(2, ct).ConfigureAwait(false);
                progress.Report((i + 1) / (double)total);
            }
        }, ct);
    }
}
```

`Task.Run` offloads CPU work to the thread pool; `ConfigureAwait(false)` keeps the inner loop on the background thread. `Progress<T>` marshals results back to UI thread automatically.

## 3. UI binding (XAML)

```xml
<StackPanel Spacing="12">
  <ProgressBar Minimum="0" Maximum="100" Value="{Binding Progress}" IsIndeterminate="{Binding IsBusy}"/>
  <TextBlock Text="{Binding Status}"/>
  <StackPanel Orientation="Horizontal" Spacing="8">
    <Button Content="Start" Command="{Binding StartCommand}"/>
    <Button Content="Cancel" Command="{Binding CancelCommand}"/>
  </StackPanel>
</StackPanel>
```

## 4. HTTP networking patterns

### 4.1 HttpClient lifetime

Reuse HttpClient (per host/service) to avoid socket exhaustion. Inject or hold static instance.

```csharp
public static class ApiClient
{
    public static HttpClient Instance { get; } = new HttpClient
    {
        Timeout = TimeSpan.FromSeconds(30)
    };
}
```

### 4.2 GET + JSON

```csharp
public async Task<T?> GetJsonAsync<T>(string url, CancellationToken ct)
{
    using var resp = await ApiClient.Instance.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct);
    resp.EnsureSuccessStatusCode();
    await using var stream = await resp.Content.ReadAsStreamAsync(ct);
    return await JsonSerializer.DeserializeAsync<T>(stream, cancellationToken: ct);
}
```

### 4.3 POST JSON with retry

```csharp
public async Task PostWithRetryAsync<T>(string url, T payload, CancellationToken ct)
{
    var policy = Policy
        .Handle<HttpRequestException>()
        .Or<TaskCanceledException>()
        .WaitAndRetryAsync(3, attempt => TimeSpan.FromSeconds(Math.Pow(2, attempt))); // exponential backoff

    await policy.ExecuteAsync(async token =>
    {
        using var response = await ApiClient.Instance.PostAsJsonAsync(url, payload, token);
        response.EnsureSuccessStatusCode();
    }, ct);
}
```

Use `Polly` or custom retry logic. Timeouts and cancellation tokens help stop hanging requests.

### 4.4 Download with progress

```csharp
public async Task DownloadAsync(Uri uri, IStorageFile destination, IProgress<double> progress, CancellationToken ct)
{
    using var response = await ApiClient.Instance.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, ct);
    response.EnsureSuccessStatusCode();

    var contentLength = response.Content.Headers.ContentLength;
    await using var httpStream = await response.Content.ReadAsStreamAsync(ct);
    await using var fileStream = await destination.OpenWriteAsync();

    var buffer = new byte[81920];
    long totalRead = 0;
    int read;
    while ((read = await httpStream.ReadAsync(buffer.AsMemory(0, buffer.Length), ct)) > 0)
    {
        await fileStream.WriteAsync(buffer.AsMemory(0, read), ct);
        totalRead += read;
        if (contentLength.HasValue)
            progress.Report(totalRead / (double)contentLength.Value);
    }
}
```

## 5. Connectivity awareness

Avalonia doesn't ship built-in connectivity events; rely on platform APIs or ping endpoints.

- Desktop: use `System.Net.NetworkInformation.NetworkChange` events.
- Mobile: Xamarin/MAUI style libraries or platform-specific checks.
- Browser: `navigator.onLine` via JS interop.

Expose a service to signal connectivity changes to view models; keep offline caching in mind.

## 6. Background services & scheduled work

For periodic tasks, use `DispatcherTimer` on UI thread or `Task.Run` loops with delays.

```csharp
var timer = new DispatcherTimer(TimeSpan.FromMinutes(5), DispatcherPriority.Background, (_, _) => RefreshCommand.Execute(null));
timer.Start();
```

Long-running background work should check `CancellationToken` frequently, especially when app might suspend (mobile).

## 7. Testing background code

Use `Task.Delay` injection or `ITestScheduler` (ReactiveUI) to control time. For plain async code, wrap delays in an interface to mock in tests.

```csharp
public interface IDelayProvider
{
    Task Delay(TimeSpan time, CancellationToken ct);
}

public sealed class DelayProvider : IDelayProvider
{
    public Task Delay(TimeSpan time, CancellationToken ct) => Task.Delay(time, ct);
}
```

Inject and replace with deterministic delays in tests.

## 8. Browser (WebAssembly) considerations

- HttpClient uses fetch; CORS applies.
- WebSockets available via `ClientWebSocket` when allowed by browser.
- Long-running loops should yield frequently (`await Task.Yield()`) to avoid blocking JS event loop.

## 9. Practice exercises

1. Build a data sync command that fetches JSON from an API, parses it, and updates view models without freezing UI.
2. Add cancellation and progress reporting to a file import feature (Chapter 16) using `IProgress<double>`.
3. Implement retry with exponential backoff around a flaky endpoint and show status messages when retries occur.
4. Detect connectivity loss and display an offline banner; queue commands to run when back online.
5. Write a unit test that confirms cancellation stops a long-running operation before completion.

## Look under the hood (source bookmarks)
- Dispatcher & UI thread: [`Dispatcher.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Threading/Dispatcher.cs)
- Progress reporting: [`Progress<T>`](https://learn.microsoft.com/dotnet/api/system.progress-1)
- HttpClient guidance: [.NET HttpClient docs](https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient)
- Cancellation tokens: [.NET cancellation docs](https://learn.microsoft.com/dotnet/standard/threading/cancellation-in-managed-threads)

## Check yourself
- Why does blocking the UI thread freeze the app? How do you keep it responsive?
- How do you propagate cancellation through nested async calls?
- Which HttpClient features help prevent hung requests?
- How can you provide progress updates without touching `Dispatcher.UIThread` manually?
- What adjustments are needed when running the same code on the browser?

What's next
- Next: [Chapter 18](Chapter18.md)
