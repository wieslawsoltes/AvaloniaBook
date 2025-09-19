# 29. Animations, transitions, and composition

Goal
- Shape motion with Avalonia's keyframe animations, property transitions, and composition effects.
- Decide when to stay in the styling layer versus dropping to the compositor for GPU-driven effects.
- Orchestrate smooth navigation and reactive UI feedback without sacrificing performance.

Why this matters
- Motion guides attention, expresses hierarchy, and communicates state changes; Avalonia gives you several layers to accomplish that.
- Choosing the right animation surface (XAML, transitions, or composition) avoids wasted CPU, jank, and hard-to-maintain code.
- Composition unlocks scenarios—material blurs, connected animations, fluid navigation—that are hard to express with traditional rendering.

Prerequisites
- Chapter 22 (Rendering pipeline) for the frame loop and renderer semantics.
- Chapter 23 (Custom drawing) for custom visuals that you might animate.
- Chapter 8 (Data binding) for reactive triggers, and Chapter 24 (Diagnostics) for measuring performance.

## 1. Keyframe animation building blocks

Avalonia's declarative animation stack lives in `Avalonia.Animation.Animation` and friends. Every control derives from `Animatable`, so you can plug animations into styles or run them directly in code.

| Concept | Type | Highlights |
| --- | --- | --- |
| Timeline | `Animation` (`Animation.cs`) | `Duration`, `Delay`, `IterationCount`, `PlaybackDirection`, `FillMode`, `SpeedRatio` |
| Track | `KeyFrame` (`KeyFrames.cs`) | Specifies a cue (`0%`..`100%`) with one or more `Setter`s |
| Interpolation | `Animator<T>` (`Animators/DoubleAnimator.cs`, etc.) | Avalonia ships animators for primitives, transforms, brushes, shadows |
| Easing | `Easing` (`Animation/Easings/*`) | Over 30 easing curves, plus `SplineEasing` for custom cubic Bezier |
| Clock | `IClock` / `Clock` (`Clock.cs`) | Drives animations, default is the global clock |

A minimal style animation:

```xml
<Window xmlns="https://github.com/avaloniaui">
  <Window.Styles>
    <Style Selector="Rectangle.alert">
      <Setter Property="Fill" Value="Red"/>
      <Style.Animations>
        <Animation Duration="0:0:0.6"
                   IterationCount="INFINITE"
                   PlaybackDirection="Alternate">
          <KeyFrame Cue="0%">
            <Setter Property="Opacity" Value="0.4"/>
            <Setter Property="RenderTransform.ScaleX" Value="1"/>
            <Setter Property="RenderTransform.ScaleY" Value="1"/>
          </KeyFrame>
          <KeyFrame Cue="100%">
            <Setter Property="Opacity" Value="1"/>
            <Setter Property="RenderTransform.ScaleX" Value="1.05"/>
            <Setter Property="RenderTransform.ScaleY" Value="1.05"/>
          </KeyFrame>
        </Animation>
      </Style.Animations>
    </Style>
  </Window.Styles>
</Window>
```

Key points:
- `Animation.IterationCount="INFINITE"` loops forever; avoid pairing with `Animation.RunAsync` (throws by design).
- `FillMode` controls which keyframe value sticks before/after the timeline. Use `FillMode="Both"` for a resting value.
- You can scope animations to a resource dictionary and reference them by `{StaticResource}` from templates or code.

## 2. Controlling playback from code

`Animation.RunAsync` and `Animation.Apply` let you start, await, or conditionally run animations from code-behind or view models (`Animation.cs`, `RunAsync`).

```csharp
public class ToastController
{
    private readonly Animation _slideIn;
    private readonly Animation _slideOut;
    private readonly Border _host;

    public ToastController(Border host, Animation slideIn, Animation slideOut)
    {
        _host = host;
        _slideIn = slideIn;
        _slideOut = slideOut;
    }

    public async Task ShowAsync(CancellationToken token)
    {
        await _slideIn.RunAsync(_host, token); // awaits completion
        await Task.Delay(TimeSpan.FromSeconds(3), token);
        await _slideOut.RunAsync(_host, token); // reuse the same host, different cues
    }
}
```

Behind the scenes `RunAsync` applies the animation with an `IClock` (defaults to `Clock.GlobalClock`) and completes when the last animator reports completion. Create the `_slideOut` animation by cloning `_slideIn`, switching its cues, or temporarily setting `PlaybackDirection = PlaybackDirection.Reverse` before calling `RunAsync`.

Reactive triggers map easily to animations by using `Apply(control, clock, IObservable<bool> match, Action onComplete)`:

```csharp
var animation = (Animation)Resources["HighlightAnimation"];
var match = viewModel.WhenAnyValue(vm => vm.IsDirty);
var subscription = animation.Apply(border, null, match, null);
_disposables.Add(subscription);
```

- The observable controls when the animation should run (`true` pulses start it, `false` cancels).
- Supply your own `Clock` to coordinate multiple animations (e.g., `new Clock(globalClock)` with `PlayState.Pause` to scrub).
- Use the cancellation overload to stop animating when the control unloads or the view model changes.

## 3. Implicit transitions and styling triggers

For property tweaks (hover states, theme switches) `Animatable.Transitions` (`Animatable.cs`) is lighter weight than keyframes. A `Transition<T>` blends from the old value to a new one automatically.

```xml
<Button Classes="primary">
  <Button.Transitions>
    <Transitions>
      <DoubleTransition Property="Opacity" Duration="0:0:0.150"/>
      <TransformOperationsTransition Property="RenderTransform" Duration="0:0:0.200"/>
    </Transitions>
  </Button.Transitions>
</Button>
```

Rules of thumb:
- Transitions cannot target direct properties (validation happens in `Transitions.cs`). Use styled properties or wrappers.
- Attach them at the control level (`Button.Transitions`) or in a style (`<Setter Property="Transitions">`).
- Combine with selectors to drive implicit animation from pseudo-classes:

```xml
<Style Selector="Button:pointerover">
  <Setter Property="Opacity" Value="1"/>
  <Setter Property="RenderTransform">
    <Setter.Value>
      <ScaleTransform ScaleX="1.02" ScaleY="1.02"/>
    </Setter.Value>
  </Setter>
</Style>
```

When the property switches, the matching `Transition<T>` eases between the two values. Avalonia ships transitions for numeric types, brushes, thickness, transforms, box shadows, and more (`Animation/Transitions/*.cs`).

### Animator-driven transitions

`AnimatorDrivenTransition` lets you reuse keyframe logic as an implicit transition. Add an `Animation` to `Transition` by setting `Property` and plugging a custom `Animator<T>` if you need non-linear interpolation or multi-stop blends.

## 4. Page transitions and content choreography

Navigation surfaces (`TransitioningContentControl`, `Frame`, `NavigationView`) rely on `IPageTransition` (`PageSlide.cs`, `CrossFade.cs`).

```xml
<TransitioningContentControl Content="{Binding CurrentPage}">
  <TransitioningContentControl.PageTransition>
    <CompositePageTransition>
      <CompositePageTransition.PageTransitions>
        <PageSlide Duration="0:0:0.25" Orientation="Horizontal" Offset="32"/>
        <CrossFade Duration="0:0:0.20"/>
      </CompositePageTransition.PageTransitions>
    </CompositePageTransition>
  </TransitioningContentControl.PageTransition>
</TransitioningContentControl>
```

- `PageSlide` shifts content in/out; set `Orientation` and `Offset` to control direction.
- `CrossFade` fades the outgoing and incoming visuals.
- Compose transitions with `CompositePageTransition` to layer multiple effects.
- Listen to `TransitioningContentControl.TransitionCompleted` to dispose view models or preload the next page.

For navigation stacks, pair page transitions with parameterized view-model lifetimes so you can cancel transitions on route changes (`TransitioningContentControl.cs`).

## 5. Reactive animation flows

Because each animation pipes through `IObservable<bool>` internally, you can stitch motion into reactive pipelines:

- `match` observables allow gating by business rules (focus state, validation errors, elapsed time).
- Use `Animation.Apply(control, clock, observable, onComplete)` to bind to `WhenAnyValue`, `Observable.Interval`, or custom subjects.
- Compose animations: the returned `IDisposable` unsubscribes transitions when your view deactivates (critical for `Animatable.DisableTransitions`).

Example: flash a text box when validation fails, but only once every second.

```csharp
var throttle = validationFailures
    .Select(_ => true)
    .Throttle(TimeSpan.FromSeconds(1))
    .StartWith(false);
animation.Apply(textBox, null, throttle, null);
```

## 6. Composition vs classic rendering

Avalonia's compositor (`Compositor.cs`) mirrors the Windows Composition model: a scene graph of `CompositionVisual` objects runs on a dedicated thread and talks directly to GPU backends. Advantages:

- Animations stay smooth even when the UI thread is busy.
- Effects (blur, shadows, opacity masks) render in hardware.
- You can build visuals that never appear in the standard logical tree (overlays, particles, diagnostics).

Getting the compositor:

```csharp
var elementVisual = ElementComposition.GetElementVisual(myControl);
var compositor = elementVisual?.Compositor;
```

You can inject custom visuals under an existing control:

```csharp
var compositor = ElementComposition.GetElementVisual(host)!.Compositor;
var root = ElementComposition.GetElementVisual(host) as CompositionContainerVisual;

var sprite = compositor.CreateSolidColorVisual();
sprite.Color = Colors.DeepSkyBlue;
sprite.Size = new Vector2((float)host.Bounds.Width, 4);
sprite.Offset = new Vector3(0, (float)host.Bounds.Height - 4, 0);
root!.Children.Add(sprite);
```

When mixing visuals, ensure they come from the same `Compositor` instance (`ElementCompositionPreview.cs`).

### Composition target and hit testing

`CompositionTarget` (`CompositionTarget.cs`) owns the visual tree that the compositor renders. It handles hit testing, coordinate transforms, and redraw scheduling. Most apps use the compositor implicitly via the built-in renderer, but custom hosts (e.g., embedding Avalonia) can create their own target (`Compositor.CreateCompositionTarget`).

### Composition brushes, effects, and materials

The compositor supports more than simple solids:

- `CompositionColorBrush` and `CompositionGradientBrush` mirror familiar WPF/UWP concepts and can be animated directly on the render thread.
- `CompositionEffectBrush` applies blend modes and image effects defined in `Composition.Effects`. Use it to build blur/glow pipelines without blocking the UI thread.
- `CompositionExperimentalAcrylicVisual` ships a ready-made fluent-style acrylic material. Combine it with backdrop animations for frosted surfaces.
- `CompositionDrawListVisual` lets you record drawing commands once and replay them efficiently; great for particle systems or dashboards.

Use `Compositor.TryCreateBlurEffect()` (platform-provided helpers) to probe support before enabling expensive effects. Not every backend exposes every effect type; guard features behind capability checks.

### Backend considerations

Composition runs on different engines per platform:

- **Windows** defaults to Direct3D via Angle; transparency and acrylic require desktop composition (check `DwmIsCompositionEnabled`).
- **macOS/iOS** lean on Metal; some blend modes fall back to software when Metal is unavailable.
- **Linux/X11** routes through OpenGL or Vulkan depending on the build; verify `TransparencyLevel` and composition availability via `X11Globals.IsCompositionEnabled`.
- **Browser** currently renders via WebGL and omits composition-only APIs. Always branch your motion layer so WebAssembly users still see essential transitions.

When features are missing, prefer classic transitions so the experience remains functional.

## 7. Composition animations and implicit animations

Composition animations live in `Avalonia.Rendering.Composition.Animations`:

- `ExpressionAnimation` lets you drive properties with formulas (e.g., parallax, inverse transforms).
- `KeyFrameAnimation` offers high-frequency GPU keyframes.
- `ImplicitAnimationCollection` attaches animations to property names and fires when the property changes (`CompositionObject.ImplicitAnimations`).

Example: create a parallax highlight that lags slightly behind its host.

```csharp
var compositor = ElementComposition.GetElementVisual(header)!.Compositor;
var hostVisual = ElementComposition.GetElementVisual(header)!;

var glow = compositor.CreateSolidColorVisual();
glow.Color = Colors.Gold;
glow.Size = new Vector2((float)header.Bounds.Width, 4);
ElementComposition.SetElementChildVisual(header, glow);

var parallax = compositor.CreateExpressionAnimation("Vector3(host.Offset.X * 0.05, host.Offset.Y * 0.05, 0)");
parallax.SetReferenceParameter("host", hostVisual);
parallax.Target = nameof(CompositionVisual.Offset);
glow.StartAnimation(nameof(CompositionVisual.Offset), parallax);
```

For property-driven motion, use implicit animations: create an `ImplicitAnimationCollection`, add an animation keyed by the composition property name (for example `nameof(CompositionVisual.Opacity)`), then assign the collection to `visual.ImplicitAnimations`. Each time that property changes, the compositor automatically plays the animation using `this.FinalValue` inside the expression to reference the target value (`ImplicitAnimationCollection.cs`).

`StartAnimation` pushes the animation to the render thread. Use `CompositionAnimationGroup` to start multiple animations atomically, and `Compositor.RequestCommitAsync()` to flush batched changes before measuring results.

## 8. Performance and diagnostics

- Prefer animating transforms (`RenderTransform`, `Opacity`) over layout-affecting properties (`Width`, `Height`). Layout invalidation happens on the UI thread and can stutter.
- Reuse animation instances; parsing keyframes or easings each time allocates. Store them as static resources.
- Disable transitions when loading data-heavy lists to avoid dozens of simultaneous animations (`Animatable.DisableTransitions`). Re-enable after the initial bind.
- For composition, batch changes and let `Compositor.RequestCommitAsync()` coalesce writes instead of spamming per-frame updates.
- Use `RendererDiagnostics` overlays (Chapter 24) to spot dropped frames and long render passes. Composition visuals show up as separate layers, so you can verify they batch correctly.
- Brush transitions fall back to discrete jumps for incompatible brush types (`BrushTransition.cs`). Verify gradients or image brushes blend the way you expect.

## 9. Practice lab: motion system

1. **Explicit keyframes** – Build a reusable animation resource that pulses a `NotificationBanner`, then start it from a view model with `RunAsync`. Add cancellation so repeated notifications restart smoothly.
2. **Implicit hover transitions** – Define a `Transitions` block for cards in a dashboard: fade elevation shadows, scale the card slightly, and update `TranslateTransform.Y`. Drive the transitions purely from pseudo-classes.
3. **Navigation choreography** – Wrap your page host in a `TransitioningContentControl`. Combine `PageSlide` with `CrossFade`, listen for `TransitionCompleted`, and cancel transitions when the navigation stack pops quickly.
4. **Composition parallax** – Build a composition child visual that lags behind its host using an expression animation, then snap it back with an implicit animation when pointer capture is lost.
5. **Diagnostics** – Toggle renderer diagnostics overlays, capture a short trace, and confirm that the animations remain smooth when background tasks run.

Document timing curves, easing choices, and any performance issues so the team can iterate on the experience.

## 10. Troubleshooting & best practices

- Animation not firing? Ensure the target property is styled (not direct) and the selector matches the control. For composition, check the animation `Target` matches the composition property name (case-sensitive).
- Looped animations via `RunAsync` throw—drive infinite loops with `Apply` or manual scheduler instead.
- Transitions chaining oddly? They trigger per property; animating both `RenderTransform` and its sub-properties simultaneously causes conflicts. Use a single `TransformOperationsTransition` to animate complex transforms.
- Composition visuals disappear after resizing? Update `Size` and `Offset` whenever the host control's bounds change, then call `Compositor.RequestCommitAsync()` to flush.
- Hot reload spawns multiple composition visuals? Remove the old child visual (`Children.Remove`) before adding a new one, or cache the sprite in the control instance.

## Look under the hood (source bookmarks)
- Animation timeline & playback: `external/Avalonia/src/Avalonia.Base/Animation/Animation.cs`
- Property transitions: `external/Avalonia/src/Avalonia.Base/Animation/Transitions.cs`
- Page transitions: `external/Avalonia/src/Avalonia.Base/Animation/PageSlide.cs`, `external/Avalonia/src/Avalonia.Base/Animation/CrossFade.cs`
- Composition gateway: `external/Avalonia/src/Avalonia.Base/Rendering/Composition/Compositor.cs`, `external/Avalonia/src/Avalonia.Base/Rendering/Composition/CompositionTarget.cs`
- Composition effects & materials: `external/Avalonia/src/Avalonia.Base/Rendering/Composition/CompositionDrawListVisual.cs`, `external/Avalonia/src/Avalonia.Base/Rendering/Composition/CompositionExperimentalAcrylicVisual.cs`, `external/Avalonia/src/Avalonia.Base/Rendering/Composition/Expressions/ExpressionAnimation.cs`
- Implicit composition animations: `external/Avalonia/src/Avalonia.Base/Rendering/Composition/CompositionObject.cs`

## Check yourself
- When would you pick a `DoubleTransition` over a keyframe animation, and why does that matter for layout cost?
- How do `IterationCount`, `FillMode`, and `PlaybackDirection` interact to determine an animation's resting value?
- What are the risks of animating direct properties, and how does Avalonia guard against them?
- How do you attach a composition child visual so it uses the same compositor as the host control?
- What steps ensure a navigation animation cancels cleanly when the route changes mid-flight?

What's next
- Next: [Chapter30](Chapter30.md)
