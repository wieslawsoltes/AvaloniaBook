# 30. Markup, XAML compiler, and extensibility

Goal
- Understand how Avalonia turns `.axaml` files into IL, resources, and runtime objects.
- Choose between compiled and runtime XAML loading, and configure each for trimming, design-time, and diagnostics.
- Extend the markup language with custom namespaces, markup extensions, and services without breaking tooling.

Why this matters
- XAML is your declarative UI language; mastering its toolchain keeps builds fast and error messages actionable.
- Compiled XAML (XamlIl) affects startup time, binary size, trimming, and hot reload behaviour.
- Custom markup extensions, namespace maps, and runtime loaders enable reusable component libraries and advanced scenarios (dynamic schemas, plug-ins).

Prerequisites
- Chapter 02 (project setup) for templates and build targets.
- Chapter 07 (styles and selectors) and Chapter 10 (resources) for consuming XAML assets.
- Chapter 08 (bindings) for compiled binding references.

## 1. The XAML asset pipeline

When you add `.axaml` files, the SDK-driven build uses two MSBuild tasks from `Avalonia.Build.Tasks`:

1. **`GenerateAvaloniaResources`** (`external/Avalonia/src/Avalonia.Build.Tasks/GenerateAvaloniaResourcesTask.cs`)
   - Runs before compilation. Packs every `AvaloniaResource` item into the `*.axaml` resource bundle (`avares://`).
   - Parses each XAML file with `XamlFileInfo.Parse`, records `x:Class` entries, and writes `/!AvaloniaResourceXamlInfo` metadata so runtime lookups can map CLR types to resource URIs.
   - Emits MSBuild diagnostics (`BuildEngine.LogError`) if it sees invalid XML or duplicate `x:Class` declarations.
2. **`CompileAvaloniaXaml`** (`external/Avalonia/src/Avalonia.Build.Tasks/CompileAvaloniaXamlTask.cs`)
   - Executes after C# compilation. Loads the produced assembly and references via Mono.Cecil.
   - Invokes `XamlCompilerTaskExecutor.Compile`, which runs the XamlIl compiler over each XAML resource, generates partial classes, compiled bindings, and lookup stubs under the `CompiledAvaloniaXaml` namespace, then rewrites the IL in-place.
   - Writes the updated assembly (and optional reference assembly) to `$(IntermediateOutputPath)`.

Key metadata:
- `AvaloniaResource` item group entries exist by default in SDK templates; make sure custom build steps preserve the `AvaloniaCompileOutput` metadata so incremental builds work.
- Set `<VerifyXamlIl>true</VerifyXamlIl>` to enable IL verification after compilation; this slows builds slightly but catches invalid IL earlier.
- `<AvaloniaUseCompiledBindingsByDefault>true</AvaloniaUseCompiledBindingsByDefault>` opts every binding into compiled bindings unless opted out per markup (see Chapter 08).

## 2. Inside the XamlIl compiler

XamlIl is Avalonia's LLVM-style pipeline built on XamlX:

1. **Parsing** (`XamlX.Parsers`) transforms XAML into an AST (`XamlDocument`).
2. **Transform passes** (`Avalonia.Markup.Xaml.XamlIl.CompilerExtensions`) rewrite the tree, resolve namespaces (`XmlnsDefinitionAttribute`), expand markup extensions, and inline templates.
3. **IL emission** (`XamlCompilerTaskExecutor`) creates classes such as `CompiledAvaloniaXaml.!XamlLoader`, `CompiledAvaloniaXaml.!AvaloniaResources`, and compiled binding factories.
4. **Runtime helpers** (`external/Avalonia/src/Markup/Avalonia.Markup.Xaml/XamlIl/Runtime/XamlIlRuntimeHelpers.cs`) provide services for deferred templates, parent stacks, and resource resolution at runtime.

Every `.axaml` file with `x:Class="Namespace.View"` yields:
- A partial class initializer calling `AvaloniaXamlIlRuntimeXamlLoader`. This ensures your code-behind `InitializeComponent()` wires the compiled tree.
- Registration in the resource map so `AvaloniaXamlLoader.Load(new Uri("avares://..."))` can find the compiled loader.

If you set `<SkipXamlCompilation>true</SkipXamlCompilation>`, the compiler bypasses IL generation; `AvaloniaXamlLoader` then falls back to runtime parsing for each load (slower and reflection-heavy, but useful during prototyping).

## 3. Runtime loading and hot reload

`AvaloniaXamlLoader` (`external/Avalonia/src/Markup/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs`) chooses between:
- **Compiled XAML** – looks for `CompiledAvaloniaXaml.!XamlLoader.TryLoad(string)` in the owning assembly and instantiates the pre-generated tree.
- **Runtime loader** – if no compiled loader exists or when you invoke `AvaloniaLocator.CurrentMutable.Register<IRuntimeXamlLoader>(...)`. This constructs a `RuntimeXamlLoaderDocument` with your stream or string, applies `RuntimeXamlLoaderConfiguration`, and parses with PortableXaml + XamlIl runtime.

Runtime configuration knobs:
- `UseCompiledBindingsByDefault` toggles compiled binding behaviour when parsing at runtime.
- `DiagnosticHandler` lets you downgrade/upgrade runtime warnings or feed them into telemetry.
- `DesignMode` ensures design-time services (`Design.IsDesignMode`, previews) do not execute app logic.

Use cases for runtime loading:
- Live preview / hot reload (IDE hosts register their own `IRuntimeXamlLoader`).
- Pluggable modules that ship XAML as data (load from database, theme packages).
- Unit tests where compiling all XAML would slow loops; the headless test adapters provide a runtime loader.

## 4. Namespaces, schemas, and lookup

Avalonia uses `XmlnsDefinitionAttribute` (`external/Avalonia/src/Avalonia.Base/Metadata/XmlnsDefinitionAttribute.cs`) to map XML namespaces to CLR namespaces. Assemblies such as `Avalonia.Markup.Xaml` declare:

```csharp
[assembly: XmlnsDefinition("https://github.com/avaloniaui", "Avalonia.Markup.Xaml.MarkupExtensions")]
```

Guidelines:
- Add your own `[assembly: XmlnsDefinition]` for component libraries so users can `xmlns:controls="clr-namespace:MyApp.Controls"` or reuse the default Avalonia URI.
- Use `[assembly: XmlnsPrefix]` (also in `Avalonia.Metadata`) to suggest a prefix for tooling.
- Custom types must be public and reside in an assembly referenced by the consuming project; otherwise XamlIl will emit a type resolution error.

`IXamlTypeResolver` is available through the service provider (`Extensions.ResolveType`). When you write custom markup extensions, you can resolve types that respect `XmlnsDefinition` mappings.

## 5. Markup extensions and service providers

All markup extensions inherit from `Avalonia.Markup.Xaml.MarkupExtension` (`MarkupExtension.cs`) and implement `ProvideValue(IServiceProvider serviceProvider)`.

Avalonia supplies extensions such as `StaticResourceExtension`, `DynamicResourceExtension`, `CompiledBindingExtension`, and `OnPlatformExtension` (`external/Avalonia/src/Markup/Avalonia.Markup.Xaml/MarkupExtensions/*`). The service provider gives access to:
- `INameScope` for named elements.
- `IAvaloniaXamlIlParentStackProvider` for parent stacks (`Extensions.GetParents<T>()`).
- `IRootObjectProvider`, `IUriContext`, and design-time services.

Custom markup extension example:

```csharp
public class UppercaseExtension : MarkupExtension
{
    public string? Text { get; set; }

    public override object ProvideValue(IServiceProvider serviceProvider)
    {
        var source = Text ?? serviceProvider.GetDefaultAnchor() as TextBlock;
        return source switch
        {
            string s => s.ToUpperInvariant(),
            TextBlock block => block.Text?.ToUpperInvariant() ?? string.Empty,
            _ => string.Empty
        };
    }
}
```

Usage in XAML:

```xml
<TextBlock Text="{local:Uppercase Text=hello}"/>
```

Tips:
- Always guard against null `Text`; the extension may be instantiated at parse time without parameters.
- Use services (e.g., `serviceProvider.GetService<IServiceProvider>`) sparingly; they run on every instantiation.
- For asynchronous or deferred value creation, return a delegate implementing `IProvideValueTarget` or use `XamlIlRuntimeHelpers.DeferredTransformationFactoryV2`.

## 6. Custom templates, resources, and compiled bindings

XamlIl optimises templates and bindings when you:
- Declare controls with `x:Class` so partial classes can inject compiled fields (`InitializeComponent`).
- Use `x:DataType` on `DataTemplates` to enable compiled bindings with compile-time type checking.
- Add `x:CompileBindings="False"` on a scope if you need fallback to classic binding for dynamic paths.

The compiler hoists resource dictionaries and template bodies into factory methods, reducing runtime allocations. When you inspect generated IL (use `ilspy`), you'll see `new Func<IServiceProvider, object>(...)` wrappers for control templates referencing `XamlIlRuntimeHelpers.DeferredTransformationFactoryV2`.

## 7. Debugging and diagnostics

- Build errors referencing `AvaloniaXamlDiagnosticCodes` include the original file path; MSBuild surfaces them in IDEs with line/column.
- Runtime `XamlLoadException` (`XamlLoadException.cs`) indicates missing compiled loaders or invalid markup; the message suggests ensuring `x:Class` and `AvaloniaResource` build actions.
- Enable verbose compiler exceptions with `<AvaloniaXamlIlVerboseOutput>true</AvaloniaXamlIlVerboseOutput>` to print stack traces from the XamlIl pipeline.
- Use `avalonia-preview` (design-time host) to spot issues with namespace resolution; the previewer logs originate from the runtime loader and respect `RuntimeXamlLoaderConfiguration.DiagnosticHandler`.

## 8. Authoring workflow checklist

1. **Project file** – confirm `<UseCompiledBindingsByDefault>` and `<VerifyXamlIl>` match your requirements.
2. **Namespaces** – add `[assembly: XmlnsDefinition]` for every exported namespace; document the suggested prefix.
3. **Resources** – place `.axaml` under the project root or set `Link` metadata so `GenerateAvaloniaResources` records the intended resource URI.
4. **InitializeComponent** – always call it in partial classes; otherwise the compiled loader is never invoked.
5. **Testing** – run unit tests with `AvaloniaHeadless` (Chapter 21) to exercise runtime loader paths without the full compositor.

## 9. Practice lab: extending the markup toolchain

1. **Inspect build output** – build your project with `dotnet build /bl`. Open the MSBuild log and confirm `GenerateAvaloniaResources` and `CompileAvaloniaXaml` run with the expected inputs.
2. **Add XML namespace mappings** – create a component library, decorate it with `[assembly: XmlnsDefinition("https://schemas.myapp.com/ui", "MyApp.Controls")]`, and consume it from a separate app.
3. **Create a markup extension** – implement `{local:Uppercase}` as above, inject `IServiceProvider` utilities, and write tests that call `ProvideValue` with a fake service provider.
4. **Toggle compiled bindings** – set `<AvaloniaUseCompiledBindingsByDefault>false>`, then selectively enable compiled bindings in XAML with `{x:CompileBindings}` and observe the generated IL (via dotnet-monitor or ILSpy).
5. **Runtime loader experiment** – register a custom `IRuntimeXamlLoader` in a test harness to load XAML from strings, flip `UseCompiledBindingsByDefault`, and log diagnostics through `RuntimeXamlLoaderConfiguration.DiagnosticHandler`.

## 10. Troubleshooting & best practices

- Build succeeds but UI is blank? Check that your `.axaml` file still has `x:Class` and `InitializeComponent` is called. Without it, the compiled loader never runs.
- Duplicate `x:Class` errors: two XAML files declare the same CLR type; rename one or adjust the namespace. The compiler stops on duplicates to avoid ambiguous partial classes.
- `XamlTypeResolutionException`: ensure the target assembly references the library exposing the type and that you provided an `XmlnsDefinition` mapping.
- Missing resources at runtime (`avares://` fails): verify `AvaloniaResource` items exist and the resource path matches the URI (case-sensitive on Linux/macOS).
- Large diff after build: compiled XAML rewrites the primary assembly; add `obj/*.dll` to `.gitignore` and avoid checking in intermediate outputs.
- Hot reload issues: if you disable compiled XAML for faster iteration, remember to re-enable it before shipping to restore startup performance.

## Look under the hood (source bookmarks)
- Resource packer: `external/Avalonia/src/Avalonia.Build.Tasks/GenerateAvaloniaResourcesTask.cs`
- XamlIl compiler driver: `external/Avalonia/src/Avalonia.Build.Tasks/CompileAvaloniaXamlTask.cs`, `external/Avalonia/src/Avalonia.Build.Tasks/XamlCompilerTaskExecutor.cs`
- Runtime loader: `external/Avalonia/src/Markup/Avalonia.Markup.Xaml/AvaloniaXamlLoader.cs`, `RuntimeXamlLoaderDocument.cs`
- Runtime helpers: `external/Avalonia/src/Markup/Avalonia.Markup.Xaml/XamlIl/Runtime/XamlIlRuntimeHelpers.cs`
- Extensions & services: `external/Avalonia/src/Markup/Avalonia.Markup.Xaml/Extensions.cs`

## Check yourself
- What MSBuild tasks touch `.axaml` files, and what metadata do they emit?
- How does XamlIl decide between compiled and runtime loading for a given URI?
- Where would you place `[XmlnsDefinition]` attributes when publishing a control library?
- How do you access the root object or parent stack from inside a markup extension?
- What steps enable you to load XAML from a raw string while still using compiled bindings?

What's next
- Next: [Chapter31](Chapter31.md)
