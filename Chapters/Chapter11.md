# 11. MVVM in depth (with or without ReactiveUI)

Goal
- Go beyond the basics of MVVM and learn two practical ways to structure real apps in Avalonia: classic MVVM with INotifyPropertyChanged and commands, and MVVM powered by ReactiveUI with reactive properties, commands, and routing.

Why this matters
- Clear separation of responsibilities keeps your app easy to reason about, test, and extend.
- A consistent MVVM approach enables reuse across desktop, mobile, and the browser.
- Reactive patterns make complex UI state and async flows easier to compose and test.

Prerequisites
- Basic C# classes and properties
- Basic XAML and bindings (Chapter 8)
- Commands and input (Chapter 9)

What you’ll build
- A tiny “People” example twice:
  1) Classic MVVM: a PeopleViewModel exposes a list, selection, and commands.
  2) ReactiveUI: the same features using ReactiveObject and ReactiveCommand.
- You’ll also see two navigation approaches: a simple view-model-first pattern and ReactiveUI routing.

1) MVVM responsibilities in plain words
- Model: Your data shapes (e.g., Person), plus domain logic. No Avalonia types here.
- ViewModel: UI-facing state and commands. Translates domain into bindable properties. No visual logic or control references.
- View: XAML + code-behind for layout and visuals. No business logic; bindings connect to the ViewModel.

2) Classic MVVM you can ship today

2.1 A minimal base for property change notification
```csharp
using System.ComponentModel;
using System.Runtime.CompilerServices;

public abstract class ObservableObject : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    protected bool SetProperty<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (Equals(field, value)) return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        return true;
    }
}
```

2.2 A simple ICommand implementation
```csharp
using System;
using System.Windows.Input;

public sealed class RelayCommand : ICommand
{
    private readonly Action<object?> _execute;
    private readonly Func<object?, bool>? _canExecute;

    public RelayCommand(Action<object?> execute, Func<object?, bool>? canExecute = null)
    {
        _execute = execute;
        _canExecute = canExecute;
    }

    public bool CanExecute(object? parameter) => _canExecute?.Invoke(parameter) ?? true;
    public void Execute(object? parameter) => _execute(parameter);

    public event EventHandler? CanExecuteChanged;
    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}
```

2.3 ViewModels for the People screen
```csharp
using System.Collections.ObjectModel;

public sealed class Person
{
    public string FirstName { get; }
    public string LastName { get; }
    public Person(string first, string last) { FirstName = first; LastName = last; }
    public override string ToString() => $"{FirstName} {LastName}";
}

public sealed class PeopleViewModel : ObservableObject
{
    private Person? _selected;

    public ObservableCollection<Person> People { get; } = new()
    {
        new("Ada", "Lovelace"),
        new("Alan", "Turing"),
        new("Grace", "Hopper")
    };

    public Person? Selected
    {
        get => _selected;
        set
        {
            if (SetProperty(ref _selected, value))
                RemovePersonCommand.RaiseCanExecuteChanged();
        }
    }

    public RelayCommand AddPersonCommand { get; }
    public RelayCommand RemovePersonCommand { get; }

    public PeopleViewModel()
    {
        AddPersonCommand = new RelayCommand(_ => People.Add(new Person("New", "Person")));
        RemovePersonCommand = new RelayCommand(_ =>
        {
            if (Selected is not null)
                People.Remove(Selected);
        }, _ => Selected is not null);
    }
}
```

2.4 View and DataTemplates (ViewModel-first)
```xml
<!-- App.axaml -->
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="MyApp.App">
  <Application.DataTemplates>
    <!-- Map a ViewModel type to a View -->
    <DataTemplate DataType="{x:Type vm:PeopleViewModel}" xmlns:vm="clr-namespace:MyApp.ViewModels" xmlns:v="clr-namespace:MyApp.Views">
      <v:PeopleView/>
    </DataTemplate>
  </Application.DataTemplates>
</Application>
```

```xml
<!-- PeopleView.axaml -->
<UserControl xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             x:Class="MyApp.Views.PeopleView">
  <DockPanel Margin="12">
    <StackPanel Orientation="Horizontal" Spacing="8" DockPanel.Dock="Top">
      <Button Content="Add" Command="{Binding AddPersonCommand}"/>
      <Button Content="Remove" Command="{Binding RemovePersonCommand}"/>
    </StackPanel>
    <ListBox Items="{Binding People}" SelectedItem="{Binding Selected}"/>
  </DockPanel>
</UserControl>
```

```csharp
// MainWindow.axaml.cs — set the DataContext to the top-level VM
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        DataContext = new PeopleViewModel();
    }
}
```

2.5 Simple navigation without frameworks
- Define a ShellViewModel that holds the current page ViewModel.
- Expose commands to swap between page ViewModels.
- Use a ContentControl bound to Current in the shell view.

```csharp
public sealed class ShellViewModel : ObservableObject
{
    private object _current;
    public object Current
    {
        get => _current;
        set => SetProperty(ref _current, value);
    }

    public RelayCommand GoPeople { get; }
    public RelayCommand GoAbout { get; }

    public ShellViewModel()
    {
        var people = new PeopleViewModel();
        var about = new AboutViewModel();
        _current = people;
        GoPeople = new RelayCommand(_ => Current = people);
        GoAbout = new RelayCommand(_ => Current = about);
    }
}
```

```xml
<!-- ShellView.axaml -->
<UserControl xmlns="https://github.com/avaloniaui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <DockPanel>
    <StackPanel Orientation="Horizontal" Spacing="8" DockPanel.Dock="Top" Margin="8">
      <Button Content="People" Command="{Binding GoPeople}"/>
      <Button Content="About" Command="{Binding GoAbout}"/>
    </StackPanel>
    <ContentControl Content="{Binding Current}"/>
  </DockPanel>
</UserControl>
```

Notes and tips for classic MVVM
- Keep ViewModels free of Avalonia controls. Prefer services for IO, dialogs, and persistence.
- Raise CanExecuteChanged when state changes. Disable buttons by command state rather than manual IsEnabled.
- Use DataTemplates to map ViewModels to Views; keep View constructors empty of business logic.

3) ReactiveUI in Avalonia

When to consider ReactiveUI
- You want observable properties and derived values without boilerplate.
- You want commands that automatically manage async execution and can-execute.
- You want a simple, testable navigation story (routing) and observable composition.

3.1 Setup
- Add the Avalonia.ReactiveUI package to your project.
- In the app builder, enable ReactiveUI:
```csharp
AppBuilder.Configure<App>()
    .UsePlatformDetect()
    .UseSkia()
    .UseReactiveUI() // important
    .StartWithClassicDesktopLifetime(args);
```

3.2 ReactiveObject, [ObservableAsProperty] and WhenAnyValue
```csharp
using ReactiveUI;
using System.Reactive;
using System.Reactive.Linq;

public sealed class PersonRx : ReactiveObject
{
    private string _first = string.Empty;
    public string First
    {
        get => _first;
        set => this.RaiseAndSetIfChanged(ref _first, value);
    }

    private string _last = string.Empty;
    public string Last
    {
        get => _last;
        set => this.RaiseAndSetIfChanged(ref _last, value);
    }

    public string FullName => $"{First} {Last}";
}

public sealed class PeopleViewModelRx : ReactiveObject
{
    private PersonRx? _selected;
    public ObservableCollection<PersonRx> People { get; } = new();

    public PersonRx? Selected
    {
        get => _selected;
        set => this.RaiseAndSetIfChanged(ref _selected, value);
    }

    public ReactiveCommand<Unit, Unit> Add { get; }
    public ReactiveCommand<Unit, Unit> Remove { get; }

    public PeopleViewModelRx()
    {
        People.Add(new PersonRx { First = "Ada", Last = "Lovelace" });
        People.Add(new PersonRx { First = "Alan", Last = "Turing" });
        People.Add(new PersonRx { First = "Grace", Last = "Hopper" });

        var canRemove = this.WhenAnyValue(vm => vm.Selected).Select(sel => sel is not null);
        Add = ReactiveCommand.Create(() => People.Add(new PersonRx { First = "New", Last = "Person" }));
        Remove = ReactiveCommand.Create(() => { if (Selected is not null) People.Remove(Selected); }, canRemove);
    }
}
```

3.3 Binding in XAML is the same
```xml
<!-- PeopleViewRx.axaml -->
<UserControl xmlns="https://github.com/avaloniaui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <DockPanel Margin="12">
    <StackPanel Orientation="Horizontal" Spacing="8" DockPanel.Dock="Top">
      <Button Content="Add" Command="{Binding Add}"/>
      <Button Content="Remove" Command="{Binding Remove}"/>
    </StackPanel>
    <ListBox Items="{Binding People}" SelectedItem="{Binding Selected}"/>
  </DockPanel>
</UserControl>
```

3.4 ReactiveUI routing in one minute
- Define a host screen that owns a RoutingState.
- Expose commands that navigate by pushing new view models.
- Views can derive from ReactiveUserControl<TViewModel> for WhenActivated hooks, but standard UserControl works too.

```csharp
using ReactiveUI;
using System.Reactive;

public interface IAppScreen : IScreen { }

public sealed class ShellRxViewModel : ReactiveObject, IAppScreen
{
    public RoutingState Router { get; } = new();

    public ReactiveCommand<Unit, IRoutableViewModel> GoPeople { get; }
    public ReactiveCommand<Unit, IRoutableViewModel> GoAbout { get; }

    public ShellRxViewModel()
    {
        GoPeople = ReactiveCommand.CreateFromObservable(() => Router.Navigate.Execute(new PeopleRoutedViewModel(this)));
        GoAbout = ReactiveCommand.CreateFromObservable(() => Router.Navigate.Execute(new AboutRoutedViewModel(this)));
    }
}

public sealed class PeopleRoutedViewModel : ReactiveObject, IRoutableViewModel
{
    public string? UrlPathSegment => "people";
    public IScreen HostScreen { get; }
    public PeopleViewModelRx Inner { get; } = new();
    public PeopleRoutedViewModel(IScreen host) => HostScreen = host;
}

public sealed class AboutRoutedViewModel : ReactiveObject, IRoutableViewModel
{
    public string? UrlPathSegment => "about";
    public IScreen HostScreen { get; }
    public AboutRoutedViewModel(IScreen host) => HostScreen = host;
}
```

```xml
<!-- ShellRxView.axaml -->
<UserControl xmlns="https://github.com/avaloniaui" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <DockPanel>
    <StackPanel Orientation="Horizontal" Spacing="8" DockPanel.Dock="Top" Margin="8">
      <Button Content="People" Command="{Binding GoPeople}"/>
      <Button Content="About" Command="{Binding GoAbout}"/>
    </StackPanel>
    <!-- RoutedViewHost displays the View for the current IRoutableViewModel -->
    <rxui:RoutedViewHost Router="{Binding Router}" xmlns:rxui="clr-namespace:ReactiveUI;assembly=ReactiveUI"/>
  </DockPanel>
</UserControl>
```

3.5 Interactions (dialogs without coupling)
- ReactiveUI’s Interaction<TIn, TOut> lets ViewModels request UI work (like a file dialog) while remaining testable.
- Views subscribe to interactions and fulfill them at the edge.

```csharp
public sealed class SaveViewModel : ReactiveObject
{
    public Interaction<Unit, bool> ConfirmSave { get; } = new();
    public ReactiveCommand<Unit, Unit> Save { get; }

    public SaveViewModel()
    {
        Save = ReactiveCommand.CreateFromTask(async () =>
        {
            var ok = await ConfirmSave.Handle(Unit.Default);
            if (ok)
            {
                // perform save
            }
        });
    }
}
```

In the View (code-behind), subscribe when activated:
```csharp
this.WhenActivated(d =>
{
    d(ViewModel!.ConfirmSave.RegisterHandler(async ctx =>
    {
        var result = await ShowDialogAsync("Save?", "Do you want to save?", "Yes", "No");
        ctx.SetOutput(result);
    }));
});
```

4) Validation options that scale
- Minimal: manual validation in commands (already shown earlier).
- INotifyDataErrorInfo: push validation errors per property; Avalonia supports Validation styling and Adorners.
- ReactiveUI.Validation (optional package) offers fluent rules bound to reactive properties.

5) Testing your ViewModels
- Classic MVVM: instantiate the VM and test property changes and command behavior.
- ReactiveUI: use TestScheduler to verify reactive flows; test ReactiveCommand execution and can-execute.

6) Choosing your path
- Start with classic MVVM if you prefer straightforward classes and minimal dependencies.
- Choose ReactiveUI when you need complex async workflows, derived state, or built-in routing/interaction patterns.
- You can mix: classic VMs for simple pages; ReactiveUI for complex areas.

Look under the hood (source)
- Avalonia + ReactiveUI integration: [Avalonia.ReactiveUI](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.ReactiveUI)
- Validation styles: [Avalonia.Themes.Fluent](https://github.com/AvaloniaUI/Avalonia/tree/master/src/Avalonia.Themes.Fluent)

Check yourself
- What problems does MVVM solve in UI apps?
- How do DataTemplates map ViewModels to Views?
- When would you choose ReactiveCommand over a manual ICommand?
- What does Router.Navigate.Execute do in ReactiveUI routing?

Extra practice
- Convert the classic People example to ReactiveUI step by step. Keep behavior identical.
- Add a Save dialog using ReactiveUI’s Interaction pattern, and stub it out in tests.
- Add a third page and wire it into both the simple shell and the reactive router.

What’s next
- Next: [Chapter 12](Chapter12.md)
