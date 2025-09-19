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

`IPersonService` represents data access. Inject it via DI in `App.axaml.cs` (see Section 3).

### 2.4 Binding notifications and validation

Bindings surface both conversion errors and validation failures through `BindingNotification` and the `DataValidationException` payload. Listening to those notifications helps you surface validation summaries in the UI and quickly diagnose binding issues during development.

```csharp
public sealed class AccountViewModel : ObservableValidator
{
    private string _email = string.Empty;
    public ObservableCollection<string> ValidationMessages { get; } = new();

    [Required(ErrorMessage = "Email is required")]
    [EmailAddress(ErrorMessage = "Enter a valid email address")]
    public string Email
    {
        get => _email;
        set => SetProperty(ref _email, value, true);
    }
}
```

`ObservableValidator` lives in CommunityToolkit.Mvvm and combines property change notification with `INotifyDataErrorInfo` support. Expose `ValidationMessages` (e.g., an `ObservableCollection<string>`) to feed summaries or inline hints.

```xml
<TextBox x:Name="EmailBox"
         Text="{Binding Email, Mode=TwoWay, ValidatesOnNotifyDataErrors=True, UpdateSourceTrigger=PropertyChanged}"/>
<ItemsControl ItemsSource="{Binding ValidationMessages}"/>
```

```csharp
var subscription = EmailBox.GetBindingObservable(TextBox.TextProperty)
    .Subscribe(result =>
    {
        if (result.HasError && result.Error is BindingNotification notification)
        {
            if (notification.Error is ValidationException validation)
                ValidationMessages.Add(validation.Message);
            else
                Logger.LogError(notification.Error, "Binding failure for Email");
        }
    });

DataValidationErrors.GetObservable(EmailBox)
    .Subscribe(args => ValidationMessages.Add(args.Error.Content?.ToString() ?? string.Empty));
```

`BindingNotification` distinguishes between binding errors and data validation errors (`BindingErrorType`). Validation failures arrive as `DataValidationException` instances on the notification, exposing the offending property and message. Use Avalonia's `DataValidationErrors` helper to observe validation changes and feed a summary control or toast.

### 2.5 Value converters and formatting

When view and view model types differ, implement `IValueConverter` or `IBindingTypeConverter` to keep view models POCO-friendly.

```csharp
public sealed class TimestampToLocalTimeConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value is DateTimeOffset dto ? dto.ToLocalTime().ToString("t", culture) : string.Empty;

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => DateTimeOffset.TryParse(value as string, culture, DateTimeStyles.AssumeLocal, out var dto) ? dto : BindingOperations.DoNothing;
}
```

Register converters in resources and reuse them across DataTemplates:

```xml
<Window.Resources>
  <local:TimestampToLocalTimeConverter x:Key="LocalTime"/>
</Window.Resources>

<TextBlock Text="{Binding LastSignIn, Converter={StaticResource LocalTime}}"/>
```

Converters keep view models focused on domain types while views shape presentation. For complex pipelines, combine converters with `Binding.ConverterParameter` or chained bindings.

### 2.6 Mapping view models to views via DataTemplates

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

`CurrentViewModel` property determines which view to display. This is the ViewModel-first approach: DataTemplates map VM types to Views automatically. For advanced scenarios, register an `IGlobalDataTemplates` implementation to provide templates at runtime (e.g., when view models live in feature modules).

```csharp
public sealed class AppDataTemplates : IGlobalDataTemplates
{
    private readonly IServiceProvider _services;

    public AppDataTemplates(IServiceProvider services) => _services = services;

    public bool Match(object? data) => data is ViewModelBase;

    public Control Build(object? data)
        => data switch
        {
            HomeViewModel => _services.GetRequiredService<HomeView>(),
            SettingsViewModel => _services.GetRequiredService<SettingsView>(),
            _ => new TextBlock { Text = "No view registered." }
        };
}
```

Register the implementation in `App` or DI container so Avalonia uses it when resolving content.

### 2.7 Navigation service (classic MVVM)

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

## 3. Composition and state management

### 3.1 Dependency injection and view model factories

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
        else if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            singleView.MainView = _services.GetRequiredService<ShellView>();
        }

        base.OnFrameworkInitializationCompleted();
    }

    private static IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();
        services.AddSingleton<MainWindow>();
        services.AddSingleton<ShellView>();
        services.AddSingleton<INavigationService, NavigationService>();
        services.AddTransient<PeopleViewModel>();
        services.AddTransient<HomeViewModel>();
        services.AddSingleton<IPersonService, PersonService>();
        services.AddSingleton<IGlobalDataTemplates, AppDataTemplates>();
        return services.BuildServiceProvider();
    }
}
```

Inject `INavigationService` (or a more opinionated router) into view models to drive navigation. Supplying `IGlobalDataTemplates` from the service provider keeps view discovery aligned with DI—views can request their own dependencies on construction.

### 3.2 State orchestration with observables

Centralize shared state in dedicated services so view models remain focused on UI coordination:

```csharp
public sealed class DocumentStore : ObservableObject
{
    private readonly ObservableCollection<DocumentViewModel> _documents = new();
    public ReadOnlyObservableCollection<DocumentViewModel> OpenDocuments { get; }

    public DocumentStore()
        => OpenDocuments = new ReadOnlyObservableCollection<DocumentViewModel>(_documents);

    public void Open(DocumentViewModel document)
    {
        if (!_documents.Contains(document))
            _documents.Add(document);
    }

    public void Close(DocumentViewModel document) => _documents.Remove(document);
}
```

Expose commands that call into the store instead of duplicating logic across view models. For undo/redo, track a stack of undoable actions and leverage property observables to record mutations:

```csharp
public interface IUndoableAction
{
    void Execute();
    void Undo();
}

public sealed class UndoRedoManager
{
    private readonly Stack<IUndoableAction> _undo = new();
    private readonly Stack<IUndoableAction> _redo = new();

    public void Do(IUndoableAction action)
    {
        action.Execute();
        _undo.Push(action);
        _redo.Clear();
    }

    public void Undo() => Execute(_undo, _redo);
    public void Redo() => Execute(_redo, _undo);

    private static void Execute(Stack<IUndoableAction> source, Stack<IUndoableAction> target)
    {
        if (source.TryPop(out var action))
        {
            action.Undo();
            target.Push(action);
        }
    }
}
```

Subscribe to `INotifyPropertyChanged` or use `Observable.FromEventPattern` to capture state snapshots whenever important properties change. This approach works equally well for manual MVVM, CommunityToolkit, or ReactiveUI view models.

### 3.3 Bridging other MVVM frameworks

- **Prism**: Register `ViewModelLocator.AutoWireViewModel` in XAML and let Prism resolve view models via Avalonia DI. Use Prism's region navigation on top of `ContentControl`-based shells.
- **Caliburn.Micro / Stylet**: Hook their view locator into Avalonia by implementing `IGlobalDataTemplates` or setting `ViewLocator.LocateForModelType` to the framework's resolver.
- **PropertyChanged.Fody / FSharp.ViewModule**: Combine source generators with Avalonia bindings—`BindingNotification` still surfaces validation errors, so logging and diagnostics remain consistent.

The key is to treat Avalonia's property system as the integration point: as long as view models raise property change notifications, you can plug in different MVVM toolkits without rewriting view code.

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

### 5.6 Avalonia.ReactiveUI helpers

`Avalonia.ReactiveUI` ships opinionated base classes such as `ReactiveWindow<TViewModel>`, `ReactiveContentControl<TViewModel>`, and extension methods that bridge Avalonia's property system with ReactiveUI's `IObservable` pipelines.

```csharp
public partial class ShellWindow : ReactiveWindow<ShellViewModel>
{
    public ShellWindow()
    {
        InitializeComponent();

        this.WhenActivated(disposables =>
        {
            this.OneWayBind(ViewModel, vm => vm.Router, v => v.RouterHost.Router)
                .DisposeWith(disposables);
            this.BindCommand(ViewModel, vm => vm.ExitCommand, v => v.ExitMenuItem)
                .DisposeWith(disposables);
        });
    }
}
```

Activation hooks route `BindingNotification` instances through ReactiveUI's logging infrastructure, so binding failures show up in `RxApp.DefaultExceptionHandler`. Register `ActivationForViewFetcher` when hosting custom controls so ReactiveUI can discover activation semantics:

```csharp
Locator.CurrentMutable.Register(() => new ShellWindow(), typeof(IViewFor<ShellViewModel>));
Locator.CurrentMutable.RegisterConstant(new AvaloniaActivationForViewFetcher(), typeof(IActivationForViewFetcher));
```

These helpers keep Avalonia bindings, routing, and interactions in sync with ReactiveUI conventions.

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

1. Compose a multi-view shell that swaps `HomeViewModel`/`SettingsViewModel` via DI-backed `IGlobalDataTemplates` and an `INavigationService`.
2. Extend the account form to surface a validation summary by listening to `DataValidationErrors.GetObservable` and logging `BindingNotification` errors.
3. Author a currency `IValueConverter`, register it in resources, and verify formatting in both classic and ReactiveUI views.
4. Implement an async load pipeline with `ReactiveCommand`, binding `IsExecuting` to a progress indicator and asserting behaviour with `TestScheduler`.
5. Add undo/redo support to the People sample by capturing `INotifyPropertyChanged` via `Observable.FromEventPattern` and replaying changes.

## Look under the hood (source bookmarks)
- Binding diagnostics: [`BindingNotification.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Data/BindingNotification.cs)
- Data validation surfaces: [`DataValidationErrors.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/DataValidationErrors.cs)
- Avalonia + ReactiveUI integration: [`Avalonia.ReactiveUI`](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.ReactiveUI)
- Global templates: [`IGlobalDataTemplates.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Controls/IGlobalDataTemplates.cs)
- Value conversion defaults: [`DefaultValueConverter.cs`](https://github.com/AvaloniaUI/Avalonia/blob/master/src/Avalonia.Base/Data/Converters/DefaultValueConverter.cs)
- Reactive command implementation: [`ReactiveCommand.cs`](https://github.com/reactiveui/ReactiveUI/blob/main/src/ReactiveUI/ReactiveCommand.cs)
- Interaction pattern: [`Interaction.cs`](https://github.com/reactiveui/ReactiveUI/blob/main/src/ReactiveUI/Interaction.cs)

## Check yourself
- What benefits does a view locator provide compared to manual view creation?
- How do `BindingNotification` and `DataValidationErrors` help diagnose problems during binding?
- How do `ReactiveCommand` and classic `RelayCommand` differ in async handling?
- Why is DI helpful when constructing view models? How would you register services in Avalonia?
- Which scenarios justify ReactiveUI's routing over simple `ContentControl` swaps?
- What advantage does `IGlobalDataTemplates` offer over static XAML data templates?

What's next
- Next: [Chapter 12](Chapter12.md)
