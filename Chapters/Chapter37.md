# 37. Reactive patterns, helpers, and tooling for code-first teams

Goal
- Combine Avalonia’s property system with reactive libraries (ReactiveUI, DynamicData) entirely from C#.
- Build helper extensions for behaviours, pseudo-classes, transitions, and animation triggers without XAML.
- Integrate diagnostics and hot-reload-style tooling that keeps developer loops tight in code-first workflows.

Why this matters
- Code-first projects often favour reactive patterns to keep UI logic composable and testable.
- Avalonia exposes rich helper APIs (`Classes`, `PseudoClasses`, `Transitions`, `Interaction`) that work perfectly in C# once you know where to look.
- Tooling such as DevTools, live reload, and logging remain essential even without XAML; wiring them programmatically ensures parity with markup-heavy projects.

Prerequisites
- Chapter 33–36 for code-first startup, layouts, bindings, and templates.
- Chapter 29 (animations) and Chapter 24 (DevTools) for background on transitions and diagnostics.
- Working familiarity with ReactiveUI/DynamicData if you plan to reuse those patterns.

## 1. Reactive building blocks in Avalonia

Avalonia’s property system already supports observables. `AvaloniaObject` exposes `GetObservable` and `GetPropertyChangedObservable` so you can build reactive pipelines without XAML triggers.

```csharp
var textBox = new TextBox();
textBox.GetObservable(TextBox.TextProperty)
    .Throttle(TimeSpan.FromMilliseconds(250), RxApp.MainThreadScheduler)
    .DistinctUntilChanged()
    .Subscribe(text => _search.Execute(text));
```

Use `ObserveOn(RxApp.MainThreadScheduler)` to marshal onto the UI thread when subscribing. For non-ReactiveUI projects, use `DispatcherScheduler.Current` (from `Avalonia.Reactive`) or `Dispatcher.UIThread.InvokeAsync` inside the observer.

### Connecting to ReactiveUI view-models

ReactiveUI view-models usually expose `ReactiveCommand` and `ObservableAsPropertyHelper`. Bind them as usual, but you can also subscribe directly:

```csharp
var vm = new DashboardViewModel();
vm.WhenAnyValue(x => x.IsLoading)
  .ObserveOn(RxApp.MainThreadScheduler)
  .Subscribe(isLoading => spinner.IsVisible = isLoading);
```

`WhenAnyValue` is extension from `ReactiveUI`. For code-first views, you may bridge them via constructor injection, ensuring the view wires observable pipelines in its constructor or `OnAttachedToVisualTree` lifecycle methods.

### DynamicData for collections

DynamicData shines when projecting observable collections into UI-friendly lists.

```csharp
var source = new SourceList<ItemViewModel>();
var bindingList = source.Connect()
    .Filter(item => item.IsEnabled)
    .Sort(SortExpressionComparer<ItemViewModel>.Descending(x => x.CreatedAt))
    .ObserveOn(RxApp.MainThreadScheduler)
    .Bind(out var items)
    .Subscribe();

listBox.Items = items;
```

Dispose the subscription when the control unloads to prevent leaks (e.g., store `IDisposable` and dispose in `DetachedFromVisualTree`).

## 2. Working with `Classes` and `PseudoClasses`

`Classes` and `PseudoClasses` collections (defined in `Avalonia.Styling`) let you toggle CSS-like states entirely from C#.

```csharp
var panel = new Border();
panel.Classes.Add("card"); // corresponds to :class selectors in styles

panel.PseudoClasses.Set(":active", true);
```

Use helpers to line up state changes with view-model events:

```csharp
vm.WhenAnyValue(x => x.IsSelected)
  .Subscribe(selected => panel.Classes.Toggle("selected", selected));
```

`Toggle` is an extension you can write:

```csharp
public static class ClassExtensions
{
    public static void Toggle(this Classes classes, string name, bool add)
    {
        if (add)
            classes.Add(name);
        else
            classes.Remove(name);
    }
}
```

### Behaviours from `Avalonia.Interactivity`

`Interaction` (in `external/Avalonia/src/Avalonia.Interactivity/Interaction.cs`) provides behaviour collections similar to WPF. You can attach behaviours programmatically via `Interaction.SetBehaviors`.

```csharp
Interaction.SetBehaviors(listBox, new BehaviorCollection
{
    new SelectOnPointerOverBehavior()
});
```

Behaviours are regular classes implementing `IBehavior`. Author your own to encapsulate complex logic like drag-to-reorder.

## 3. Transitions, animations, and reactive triggers

`Transitions` collection (from `Avalonia.Animation`) lives on `Control`. Build transitions and hook them dynamically.

```csharp
panel.Transitions = new Transitions
{
    new DoubleTransition
    {
        Property = Border.OpacityProperty,
        Duration = TimeSpan.FromMilliseconds(200),
        Easing = new CubicEaseOut()
    }
};
```

Activate transitions via property setters:

```csharp
vm.WhenAnyValue(x => x.ShowDetails)
  .Subscribe(show => panel.Opacity = show ? 1 : 0);
```

The change triggers the transition. Because transitions live on the control, you can swap them per theme or feature by replacing the `Transitions` collection at runtime.

### Animation helpers

`Animatable.BeginAnimation` (from `AnimationExtensions`) lets you trigger storyboards without styles:

```csharp
panel.BeginAnimation(Border.OpacityProperty, new Animation
{
    Duration = TimeSpan.FromMilliseconds(400),
    Easing = new SineEaseInOut(),
    Children =
    {
        new KeyFrames
        {
            new KeyFrame { Cue = new Cue(0d), Setters = { new Setter(Border.OpacityProperty, 0d) } },
            new KeyFrame { Cue = new Cue(1d), Setters = { new Setter(Border.OpacityProperty, 1d) } }
        }
    }
});
```

Encapsulate animations into factory methods for reuse across views.

## 4. Hot reload and state persistence helpers

While Avalonia’s XAML Previewer focuses on markup, code-first workflows can approximate hot reload using:
- **`DevTools`**: `AttachDevTools()` on the main window or `AppBuilder` (see `ApplicationLifetimes`).
- **`Avalonia.ReactiveUI` HotReload** packages or community tooling for reloading compiled assemblies.
- **State persistence**: store view-model state in services to rehydrate UI after code changes.

Enable DevTools programmatically in debug builds:

```csharp
if (Debugger.IsAttached)
{
    this.AttachDevTools();
}
```

For headless tests, log control trees after creation to confirm state without UI.

## 5. Diagnostics pipelines

Integrate logging by observing key properties and commands.

```csharp
var subscription = panel.GetPropertyChangedObservable(Border.OpacityProperty)
    .Subscribe(args => _logger.Debug("Opacity changed from {Old} to {New}", args.OldValue, args.NewValue));
```

Tie into Avalonia’s diagnostics overlays (Chapter 24) by enabling them in code-first startup:

```csharp
if (Debugger.IsAttached)
{
    RenderOptions.ProcessRenderOperations = true;
    RendererDiagnostics.DebugOverlays = RendererDebugOverlays.Fps | RendererDebugOverlays.Layout;
}
```

## 6. Putting it together: Building reusable helper libraries

Create a shared library of helpers tailored to your code-first patterns:

```csharp
public static class ReactiveControlHelpers
{
    public static IDisposable BindState<TViewModel>(this TViewModel vm, Control control,
        Expression<Func<TViewModel, bool>> property, string pseudoClass)
    {
        return vm.WhenAnyValue(property)
            .ObserveOn(RxApp.MainThreadScheduler)
            .Subscribe(value => control.PseudoClasses.Set(pseudoClass, value));
    }
}
```

Use it in views:

```csharp
_disposables.Add(vm.BindState(this, x => x.IsActive, ":active"));
```

Maintain a `CompositeDisposable` on the view to dispose subscriptions when the view unloads. Override `OnAttachedToVisualTree`/`OnDetachedFromVisualTree` to manage lifetime.

## 7. Practice lab

1. **Reactive state toggles** – Implement a helper that watches `WhenAnyValue` on a view-model and toggles `Classes` on a panel. Verify with headless tests that pseudo-class changes propagate to styles.
2. **Transition kit** – Build a factory returning `Transitions` configured per theme (e.g., fast vs. slow). Swap collections at runtime and instrument the effect with property observers.
3. **Behavior registry** – Create a behaviour that wires `PointerMoved` events into an observable stream. Use it to implement drag selection without code-behind duplication.
4. **Diagnostic dashboard** – Add DevTools and renderer overlays programmatically. Expose a keyboard shortcut (ReactiveCommand) that toggles them during development.
5. **Hot reload simulation** – Persist view-model state to a service, tear down the view, rebuild it from code, and reapply state to mimic live-edit workflows. Assert via unit test that state survives the rebuild.

Reactive helper patterns ensure code-first Avalonia apps stay expressive, maintainable, and observable. By leveraging observables, behaviours, transitions, and tooling APIs directly from C#, your team keeps the productivity of markup-driven workflows while embracing the flexibility of a single-language stack.

What's next
- Next: [Chapter38](Chapter38.md)
