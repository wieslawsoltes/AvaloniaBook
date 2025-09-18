# 11. MVVM in depth (with or without ReactiveUI)

Goal
- Build production-ready MVVM layers using classic `INotifyPropertyChanged`, CommunityToolkit.Mvvm helpers, or ReactiveUI.
- Map view models to views with data templates, view locator patterns, and dependency injection.
- Compose complex state using property change notifications, derived properties, async commands, and navigation stacks.
- Test view models and reactive flows confidently.

Why this matters
- MVVM separates concerns so you can scale UI complexity, swap views, and run automated tests.
- Avalonia supports multiple MVVM toolkits; understanding their trade-offs lets you choose the right fit per feature.

Prerequisites
- Binding basics (Chapter 8) and commands/input (Chapter 9).
- Familiarity with resource organization (Chapter 7) for styles and data templates.

## 1. MVVM recap

| Layer | Role | Contains |
| --- | --- | --- |
| Model | Core data/domain logic | POCOs, validation, persistence models |
| ViewModel | Bindable state, commands | `INotifyPropertyChanged`, `ICommand`, services |
| View | XAML + minimal code-behind | DataTemplates, layout, visuals |

Focus on keeping business logic in view models/models; views remain thin.

## 2. Classic MVVM (manual or CommunityToolkit.Mvvm)

### 2.1 Property change base class

```csharp
using System.ComponentModel;
using System.Runtime.CompilerServices;

public abstract class ObservableObject : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    protected bool SetProperty<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (Equals(field, value))
            return false;

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        return true;
    }
}
```

CommunityToolkit.Mvvm offers `ObservableObject`, `ObservableProperty` attribute, and `RelayCommand` out of the box. If you prefer built-in solutions, install `CommunityToolkit.Mvvm` and inherit from `ObservableObject` there.

### 2.2 Commands (`RelayCommand`)

```csharp
public sealed class RelayCommand : ICommand
{
    private readonly Action<object?> _execute;
    private readonly Func<object?, bool>? _canExecute;

    public RelayCommand(Action<object?> execute, Func<object?, bool>? canExecute = null)
    {
        _execute = execute ?? throw new ArgumentNullException(nameof(execute));
        _canExecute = canExecute;
    }

    public bool CanExecute(object? parameter) => _canExecute?.Invoke(parameter) ?? true;
    public void Execute(object? parameter) => _execute(parameter);

    public event EventHandler? CanExecuteChanged;
    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}
```

### 2.3 Sample: People view model

```csharp
using System.Collections.ObjectModel;

public sealed class Person : ObservableObject
{
    private string _firstName;
    private string _lastName;

    public Person(string first, string last)
    {
        _firstName = first;
        _lastName = last;
    }

    public string FirstName
    {
        get => _firstName;
        set => SetProperty(ref _firstName, value);
    }

    public string LastName
    {
        get => _lastName;
        set => SetProperty(ref _lastName, value);
    }

    public override string ToString() => $"{FirstName} {LastName}";
}

public sealed class PeopleViewModel : ObservableObject
{
    private Person? _selected;
    private readonly IPersonService _personService;

    public ObservableCollection<Person> People { get; } = new();
    public RelayCommand AddCommand { get; }
    public RelayCommand RemoveCommand { get; }

    public PeopleViewModel(IPersonService personService)
    {
        _personService = personService;
        AddCommand = new RelayCommand(_ => AddPerson());
        RemoveCommand = new RelayCommand(_ => RemovePerson(), _ => Selected is not null);

        LoadInitialPeople();
    }

    public Person? Selected
    {
        get => _selected;
        set
        {
            if (SetProperty(ref _selected, value))
                RemoveCommand.RaiseCanExecuteChanged();
        }
    }

    private void LoadInitialPeople()
    {
        foreach (var person in _personService.GetInitialPeople())
            People.Add(person);
    }

    private void AddPerson()
    {
        var newPerson = _personService.CreateNewPerson();
        People.Add(newPerson);
        Selected = newPerson;
    }

    private void RemovePerson()
    {
        if (Selected is null)
            return;

        _personService.DeletePerson(Selected);
        People.Remove(Selected);
        Selected = null;
    }
}
```

`IPersonService` represents data access. Inject it via DI in `App.axaml.cs` (see Section 4).

### 2.4 Mapping view models to views via DataTemplates

```xml

<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:views="clr-namespace:MyApp.Views"
             xmlns:viewmodels="clr-namespace:MyApp.ViewModels"
             x:Class="MyApp.App">
  <Application.DataTemplates>
    <DataTemplate DataType="{x:Type viewmodels:PeopleViewModel}">
      <views:PeopleView />
    </DataTemplate>
  </Application.DataTemplates>
</Application>
```

In `MainWindow.axaml`:

```xml
<ContentControl Content="{Binding CurrentViewModel}"/>
```

`CurrentViewModel` property determines which view to display. This is the ViewModel-first approach: DataTemplates map VM types to Views automatically.

### 2.5 Navigation service (classic MVVM)

```csharp
public interface INavigationService
{
    void NavigateTo<TViewModel>() where TViewModel : class;
}

public sealed class NavigationService : ObservableObject, INavigationService
{
    private readonly IServiceProvider _services;
    private object? _currentViewModel;

    public object? CurrentViewModel
    {
        get => _currentViewModel;
        private set => SetProperty(ref _currentViewModel, value);
    }

    public NavigationService(IServiceProvider services)
    {
        _services = services;
    }

    public void NavigateTo<TViewModel>() where TViewModel : class
    {
        var vm = _services.GetRequiredService<TViewModel>();
        CurrentViewModel = vm;
    }
}
```

Register navigation service via dependency injection (next section). View models call `navigationService.NavigateTo<PeopleViewModel>()` to swap views.

## 3. Dependency injection and composition

Use your favorite DI container. Example with Microsoft.Extensions.DependencyInjection in `App.axaml.cs`:

```csharp
using Microsoft.Extensions.DependencyInjection;

public partial class App : Application
{
    private IServiceProvider? _services;

    public override void OnFrameworkInitializationCompleted()
    {
        _services = ConfigureServices();

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow = _services.GetRequiredService<MainWindow>();
        }

        base.OnFrameworkInitializationCompleted();
    }

    private static IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();
        services.AddSingleton<MainWindow>();
        services.AddSingleton<INavigationService, NavigationService>();
        services.AddTransient<PeopleViewModel>();
        services.AddTransient<HomeViewModel>();
        services.AddSingleton<IPersonService, PersonService>();
        return services.BuildServiceProvider();
    }
}
```

Inject `INavigationService` into view models to drive navigation.

## 4. Testing classic MVVM view models

A unit test using xUnit:

```csharp
[Fact]
public void RemovePerson_Disables_When_No_Selection()
{
    var service = Substitute.For<IPersonService>();
    var vm = new PeopleViewModel(service);

    vm.Selected = vm.People.First();
    Assert.True(vm.RemoveCommand.CanExecute(null));

    vm.Selected = null;
    Assert.False(vm.RemoveCommand.CanExecute(null));
}
```

Testing ensures command states and property changes behave correctly.

## 5. ReactiveUI approach

ReactiveUI provides `ReactiveObject`, `ReactiveCommand`, `WhenAnyValue`, and routing/interaction helpers. Source: [`Avalonia.ReactiveUI`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.ReactiveUI).

### 5.1 Reactive object and derived state

```csharp
using ReactiveUI;
using System.Reactive.Linq;

public sealed class PersonViewModelRx : ReactiveObject
{
    private string _firstName = "Ada";
    private string _lastName = "Lovelace";

    public string FirstName
    {
        get => _firstName;
        set => this.RaiseAndSetIfChanged(ref _firstName, value);
    }

    public string LastName
    {
        get => _lastName;
        set => this.RaiseAndSetIfChanged(ref _lastName, value);
    }

    public string FullName => $"{FirstName} {LastName}";

    public PersonViewModelRx()
    {
        this.WhenAnyValue(x => x.FirstName, x => x.LastName)
            .Select(_ => Unit.Default)
            .Subscribe(_ => this.RaisePropertyChanged(nameof(FullName)));
    }
}
```

`WhenAnyValue` observes properties and recomputes derived values.

### 5.2 ReactiveCommand and async workflows

```csharp
using System.Reactive;
using System.Reactive.Linq;

public sealed class PeopleViewModelRx : ReactiveObject
{
    private PersonViewModelRx? _selected;

    public ObservableCollection<PersonViewModelRx> People { get; } = new()
    {
        new PersonViewModelRx { FirstName = "Ada", LastName = "Lovelace" },
        new PersonViewModelRx { FirstName = "Grace", LastName = "Hopper" }
    };

    public PersonViewModelRx? Selected
    {
        get => _selected;
        set => this.RaiseAndSetIfChanged(ref _selected, value);
    }

    public ReactiveCommand<Unit, Unit> AddCommand { get; }
    public ReactiveCommand<PersonViewModelRx, Unit> RemoveCommand { get; }
    public ReactiveCommand<Unit, IReadOnlyList<PersonViewModelRx>> LoadCommand { get; }

    public PeopleViewModelRx(IPersonService service)
    {
        AddCommand = ReactiveCommand.Create(() =>
        {
            var vm = new PersonViewModelRx { FirstName = "New", LastName = "Person" };
            People.Add(vm);
            Selected = vm;
        });

        var canRemove = this.WhenAnyValue(x => x.Selected).Select(selected => selected is not null);
        RemoveCommand = ReactiveCommand.Create<PersonViewModelRx>(person => People.Remove(person), canRemove);

        LoadCommand = ReactiveCommand.CreateFromTask(async () =>
        {
            var people = await service.FetchPeopleAsync();
            People.Clear();
            foreach (var p in people)
                People.Add(new PersonViewModelRx { FirstName = p.FirstName, LastName = p.LastName });
            return People.ToList();
        });

        LoadCommand.ThrownExceptions.Subscribe(ex => {/* handle errors */});
    }
}
```

`ReactiveCommand` exposes `IsExecuting`, `ThrownExceptions`, and ensures asynchronous flows stay on the UI thread.

### 5.3 `ReactiveUserControl` and activation

```csharp
using ReactiveUI;
using System.Reactive.Disposables;

public partial class PeopleViewRx : ReactiveUserControl<PeopleViewModelRx>
{
    public PeopleViewRx()
    {
        InitializeComponent();

        this.WhenActivated(disposables =>
        {
            this.Bind(ViewModel, vm => vm.Selected, v => v.PersonList.SelectedItem)
                .DisposeWith(disposables);
            this.BindCommand(ViewModel, vm => vm.AddCommand, v => v.AddButton)
                .DisposeWith(disposables);
        });
    }
}
```

`WhenActivated` manages subscriptions. `Bind`/`BindCommand` reduce boilerplate. Source: [`ReactiveUserControl.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.ReactiveUI/ReactiveUserControl.cs).

### 5.4 View locator

ReactiveUI auto resolves views via naming conventions. Register `IViewLocator` in DI or implement your own to map view models to views. Avalonia.ReactiveUI includes `ViewLocator` class you can override.

```csharp
public class AppViewLocator : IViewLocator
{
    public IViewFor? ResolveView<T>(T viewModel, string? contract = null) where T : class
    {
        var name = viewModel.GetType().FullName.Replace("ViewModel", "View");
        var type = Type.GetType(name ?? string.Empty);
        return type is null ? null : (IViewFor?)Activator.CreateInstance(type);
    }
}
```

Register it:

```csharp
services.AddSingleton<IViewLocator, AppViewLocator>();
```

### 5.5 Routing and navigation

Routers manage stacks of `IRoutableViewModel` instances. Example shell view model shown earlier. Use `<rxui:RoutedViewHost Router="{Binding Router}"/>` to display the current view.

ReactiveUI navigation supports back/forward, parameter passing, and async transitions.

## 6. Interactions and dialogs

Use `Interaction<TInput,TOutput>` to request UI interactions from view models.

```csharp
public Interaction<string, bool> ConfirmDelete { get; } = new();

DeleteCommand = ReactiveCommand.CreateFromTask(async () =>
{
    if (Selected is null)
        return;

    var ok = await ConfirmDelete.Handle($"Delete {Selected.FullName}?");
    if (ok)
        People.Remove(Selected);
});
```

In the view:

```csharp
this.WhenActivated(d =>
{
    d(ViewModel!.ConfirmDelete.RegisterHandler(async ctx =>
    {
        var dialog = new ConfirmDialog(ctx.Input);
        var result = await dialog.ShowDialog<bool>(this);
        ctx.SetOutput(result);
    }));
});
```

## 7. Testing ReactiveUI view models

Use `TestScheduler` from `ReactiveUI.Testing` to control time:

```csharp
[Test]
public void LoadCommand_PopulatesPeople()
{
    var scheduler = new TestScheduler();
    var service = Substitute.For<IPersonService>();
    service.FetchPeopleAsync().Returns(Task.FromResult(new[] { new Person("Alan", "Turing") }));

    var vm = new PeopleViewModelRx(service);
    vm.LoadCommand.Execute().Subscribe();

    scheduler.Start();

    Assert.Single(vm.People);
}
```

## 8. Choosing between toolkits

| Toolkit | Pros | Cons |
| --- | --- | --- |
| Manual / CommunityToolkit.Mvvm | Minimal dependencies, familiar, great for straightforward forms | More boilerplate for async flows, manual derived state |
| ReactiveUI | Powerful reactive composition, built-in routing/interaction, great for complex async state | Learning curve, more dependencies |

Mixing is common: use classic MVVM for most pages; ReactiveUI for reactive-heavy screens.

## 9. Practice exercises

1. Convert the People example from classic to CommunityToolkit.Mvvm using `[ObservableProperty]` and `[RelayCommand]` attributes.
2. Add async loading with cancellation (Chapter 17) and unit-test cancellation for both MVVM styles.
3. Implement a view locator that resolves views via DI rather than naming convention.
4. Extend ReactiveUI routing with a modal dialog page and test navigation using `TestScheduler`.
5. Compare command implementations by profiling UI responsiveness when commands run long operations.

## Look under the hood (source bookmarks)
- Avalonia + ReactiveUI integration: [`Avalonia.ReactiveUI`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.ReactiveUI)
- Data templates & view mapping: [`DataTemplate.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Markup/Avalonia.Markup.Xaml/Templates/DataTemplate.cs)
- Reactive command implementation: [`ReactiveCommand.cs`](https://github.com/reactiveui/ReactiveUI/blob/main/src/ReactiveUI/ReactiveCommand.cs)
- Interaction pattern: [`Interaction.cs`](https://github.com/reactiveui/ReactiveUI/blob/main/src/ReactiveUI/Interaction.cs)

## Check yourself
- What benefits does a view locator provide compared to manual view creation?
- How do `ReactiveCommand` and classic `RelayCommand` differ in async handling?
- Why is DI helpful when constructing view models? How would you register services in Avalonia?
- Which scenarios justify ReactiveUI's routing over simple `ContentControl` swaps?

What's next
- Next: [Chapter 12](Chapter12.md)
