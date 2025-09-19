# 39. Unit testing view-models and controls headlessly

Goal
- Exercise your UI and view-model logic inside real `Dispatcher` loops without opening desktop windows.
- Share fixtures and app configuration across xUnit and NUnit by wiring `AvaloniaHeadless` runners correctly.
- Simulate input, state changes, and async updates deterministically so assertions stay reliable in CI.

Why this matters
- Headless UI tests catch regressions that unit tests miss while remaining fast enough for continuous builds.
- Avalonia’s dispatcher and property system require a running application instance—adapters handle that for you.
- Framework-provided attributes eliminate flaky cross-thread failures and keep tests close to production startup paths.

Prerequisites
- Chapter 4 for lifetime selection and `AppBuilder` basics.
- Chapter 21 for the bird’s-eye view of headless testing capabilities.
- Chapter 38 for platform options, dispatcher control, and input helpers.

## 1. Pick the headless harness

Avalonia ships runner glue for xUnit and NUnit so your test bodies always execute on the UI dispatcher.

### xUnit: opt into the Avalonia test framework

Add the assembly-level attribute once and then decorate tests with `[AvaloniaFact]`/`[AvaloniaTheory]`.

```csharp
// AssemblyInfo.cs
using Avalonia.Headless;
using Avalonia.Headless.XUnit;

[assembly: AvaloniaTestApplication(typeof(TestApp))]
[assembly: AvaloniaTestFramework]
```

`AvaloniaTestFramework` (see `external/Avalonia/src/Headless/Avalonia.Headless.XUnit/AvaloniaTestFramework.cs`) installs a custom executor that spawns a `HeadlessUnitTestSession` for the assembly. Each `[AvaloniaFact]` routes through `AvaloniaTestCaseRunner`, ensuring awaited continuations re-enter the dispatcher thread.

### NUnit: wrap commands via `[AvaloniaTest]`

```csharp
using Avalonia.Headless;
using Avalonia.Headless.NUnit;

[assembly: AvaloniaTestApplication(typeof(TestApp))]

public class ButtonSpecs
{
    [SetUp]
    public void OpenApp() => Dispatcher.UIThread.VerifyAccess();

    [AvaloniaTest, Timeout(10000)]
    public void Click_updates_counter()
    {
        var window = new Window();
        // ...
    }
}
```

`AvaloniaTestAttribute` swaps NUnit’s command pipeline with `AvaloniaTestMethodCommand` (`external/Avalonia/src/Headless/Avalonia.Headless.NUnit/AvaloniaTestMethodCommand.cs`), capturing `SetUp`/`TearDown` delegates and executing them inside the shared dispatcher.

## 2. Bootstrap the application under test

The harness needs an entry point that mirrors production startup. Reuse your `BuildAvaloniaApp` method or author a lightweight test shell.

```csharp
public class TestApp : Application
{
    public override void OnFrameworkInitializationCompleted()
    {
        Styles.Add(new SimpleTheme());
        base.OnFrameworkInitializationCompleted();
    }

    public static AppBuilder BuildAvaloniaApp() =>
        AppBuilder.Configure<TestApp>()
            .UseSkia()
            .UseHeadless(new AvaloniaHeadlessPlatformOptions
            {
                UseHeadlessDrawing = false, // enable Skia-backed surfaces for rendering checks
                PreferDispatcherScheduling = true
            });
}
```

This pattern matches Avalonia’s own tests (`external/Avalonia/tests/Avalonia.Headless.UnitTests/TestApplication.cs`). When the runner detects `BuildAvaloniaApp`, it invokes it before each dispatch, so your services, themes, and dependency injection mirror the real app. If your production bootstrap already includes `UseHeadless`, the harness respects it; otherwise `HeadlessUnitTestSession.StartNew` injects defaults.

## 3. Understand session lifetime and dispatcher flow

`HeadlessUnitTestSession` (`external/Avalonia/src/Headless/Avalonia.Headless/HeadlessUnitTestSession.cs`) is the engine behind both harnesses. Highlights:

- `GetOrStartForAssembly` caches a session per test assembly, honoring `[AvaloniaTestApplication]`.
- `Dispatch`/`Dispatch<TResult>` queue work onto the UI thread while keeping NUnit/xUnit’s thread blocked until completion.
- `EnsureApplication()` recreates the `AppBuilder` scope for every dispatched action, resetting `Dispatcher` state so tests remain isolated.

You can opt into manual session control when writing custom runners or diagnostics:

```csharp
using var session = HeadlessUnitTestSession.StartNew(typeof(TestApp));
await session.Dispatch(async () =>
{
    var window = new Window();
    window.Show();
    await Dispatcher.UIThread.InvokeAsync(() => window.Close());
}, CancellationToken.None);
```

Dispose the session at the end of a run to stop the dispatcher loop and release the blocking queue.

## 4. Mount controls and bind view-models

With the dispatcher in place, tests can instantiate real controls, establish bindings, and observe Avalonia’s property system.

```csharp
public class CounterTests
{
    [AvaloniaFact]
    public void Button_click_updates_label()
    {
        var vm = new CounterViewModel();
        var window = new Window
        {
            DataContext = vm,
            Content = new StackPanel
            {
                Children =
                {
                    new Button { Name = "IncrementButton", Command = vm.IncrementCommand },
                    new TextBlock { Name = "CounterLabel", [!TextBlock.TextProperty] = vm.CounterBinding }
                }
            }
        };

        window.Show();
        window.MouseDown(new Point(20, 20), MouseButton.Left);
        window.MouseUp(new Point(20, 20), MouseButton.Left);

        window.FindControl<TextBlock>("CounterLabel")!.Text.Should().Be("1");
        window.Close();
    }
}
```

The mouse helpers come from `HeadlessWindowExtensions` (`external/Avalonia/src/Headless/Avalonia.Headless/HeadlessWindowExtensions.cs`). They flush pending dispatcher work before delivering input, then run jobs again afterward so bindings update before the assertion. Always `Close()` windows when you finish to keep the session clean.

## 5. Share fixtures with setup/teardown hooks

Both frameworks let you prepare windows or services per test while staying on the UI thread.

```csharp
public class InputHarness
#if XUNIT
    : IDisposable
#endif
{
    private readonly Window _window;

#if NUNIT
    [SetUp]
    public void SetUp()
#elif XUNIT
    public InputHarness()
#endif
    {
        Dispatcher.UIThread.VerifyAccess();
        _window = new Window { Width = 100, Height = 100 };
    }

#if NUNIT
    [AvaloniaTest]
#elif XUNIT
    [AvaloniaFact]
#endif
    public void Drag_updates_position()
    {
        _window.Show();
        _window.MouseDown(new Point(10, 10), MouseButton.Left);
        _window.MouseMove(new Point(60, 40));
        _window.MouseUp(new Point(60, 40), MouseButton.Left);
        _window.Position.Should().Be(new PixelPoint(0, 0)); // headless doesn’t move windows automatically
    }

#if NUNIT
    [TearDown]
    public void TearDown()
#elif XUNIT
    public void Dispose()
#endif
    {
        Dispatcher.UIThread.VerifyAccess();
        _window.Close();
    }
}
```

The sample mirrors Avalonia’s own `InputTests` (`external/Avalonia/tests/Avalonia.Headless.UnitTests/InputTests.cs`). Use preprocessor guards if you cross-compile the same tests between xUnit and NUnit packages.

## 6. Keep async work deterministic

Headless tests still depend on Avalonia’s dispatcher and timers. Prefer structured helpers over `Task.Delay`.

- `Dispatcher.UIThread.RunJobs()` drains queued operations immediately.
- `AvaloniaHeadlessPlatform.ForceRenderTimerTick()` advances layout and render timers—pair it with `RunJobs()` when you expect visuals to update.
- `DispatcherTimer.RunOnce` works inside tests; the runner ensures the callback fires on the same thread, as shown in `ThreadingTests` (`external/Avalonia/tests/Avalonia.Headless.UnitTests/ThreadingTests.cs`).

```csharp
[AvaloniaFact]
public async Task Loader_raises_progress()
{
    var progress = 0;
    var loader = new AsyncLoader();

    await Dispatcher.UIThread.InvokeAsync(() => loader.Start());

    while (progress < 100)
    {
        AvaloniaHeadlessPlatform.ForceRenderTimerTick();
        Dispatcher.UIThread.RunJobs();
        progress = loader.Progress;
    }

    progress.Should().Be(100);
}
```

If your view-model uses `DispatcherTimer`, expose a hook that ticks manually so tests avoid clock-based flakiness.

## 7. Theories, collections, and parallelism

`[AvaloniaTheory]` supports data-driven tests while staying on the dispatcher. For xUnit, decorate a collection definition to run related fixtures sequentially:

```csharp
[AvaloniaCollection] // custom marker
public class DialogTests
{
    [AvaloniaTheory]
    [InlineData(false)]
    [InlineData(true)]
    public void Dialog_lifecycle(bool useAsync)
    {
        // ...
    }
}

[CollectionDefinition("AvaloniaCollection", DisableParallelization = true)]
public class AvaloniaCollection : ICollectionFixture<HeadlessFixture> { }
```

The custom fixture can preload services or share the `MainView`. NUnit users can rely on `[Apartment(ApartmentState.STA)]` plus `[AvaloniaTest]` when mixing with other UI frameworks, but remember Avalonia already enforces a single dispatcher thread.

## 8. Troubleshooting failures

- **Test never finishes** – ensure you awaited async work through `Dispatcher.UIThread` or `HeadlessUnitTestSession.Dispatch`. Background tasks without dispatcher access will hang because the harness blocks the originating test thread.
- **Missing services** – register substitutes in `Application.RegisterServices()` before calling base initialization. Clipboard, dialogs, or storage require headless-friendly implementations (see Chapter 38).
- **State bleed between tests** – close all `TopLevel`s, dispose `CompositeDisposable`s, and avoid static view-model singletons. Each dispatched action gets a fresh `Application` scope, but stray static caches persist.
- **Random `InvalidOperationException: VerifyAccess`** – a test ran code on a thread pool thread. Wrap the block in `Dispatcher.UIThread.InvokeAsync` or use `await session.Dispatch(...)` in custom helpers.
- **Parallel collection deadlocks** – turn off test parallelism when fixtures share windows. xUnit: `[assembly: CollectionBehavior(DisableTestParallelization = true)]`; NUnit: `--workers=1` or `[NonParallelizable]` per fixture.

## Practice lab

1. **Session helper** – Write a reusable `HeadlessTestSessionFixture` exposing `Dispatch(Func<Task>)` so plain unit tests can invoke dispatcher-bound code without attributes.
2. **View-model assertions** – Mount a form with compiled bindings, trigger `BindingOperations` updates, and assert validation errors surface via `DataValidationErrors.GetErrors`.
3. **Keyboard automation** – Use `HeadlessWindowExtensions.KeyPressQwerty` to simulate typing into a `TextBox`, verify selection state, then assert command execution when pressing Enter.
4. **Timer-driven UI** – Create a progress dialog using `DispatcherTimer`. In tests, tick the timer manually and assert the dialog closes itself at 100% without sleeping.
5. **Theory matrix** – Build a `[AvaloniaTheory]` test that runs the same control suite using Classic Desktop vs. Single View lifetimes by swapping `HeadlessLifetime.MainView`. Confirm both paths render identical text through `GetLastRenderedFrame()`.

What's next
- Next: [Chapter40](Chapter40.md)
