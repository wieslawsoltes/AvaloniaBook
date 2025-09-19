# 40. Rendering verification and pixel assertions

Goal
- Capture deterministic frames from controls and windows so UI regressions show up as image diffs.
- Re-render visuals off-screen with `RenderTargetBitmap` for pipeline-level validation without a running window.
- Build comparison utilities that tolerate minor noise while still failing on real regressions.

Why this matters
- Visual bugs rarely surface through property assertions alone; pixel diffs make style and layout drift obvious.
- CI agents run headless—leveraging Avalonia’s off-screen renderers keeps comparison workflows portable.
- Consistent capture pipelines simplify storing baselines, reviewing diffs, and onboarding QA to UI automation.

Prerequisites
- Chapter 21 for the overview of headless testing options.
- Chapter 38 for dispatcher control and headless render ticks.
- Chapter 39 for running xUnit/NUnit fixtures on the Avalonia dispatcher.

## 1. Capture frames from headless top levels

`HeadlessWindowExtensions.CaptureRenderedFrame` (`external/Avalonia/src/Headless/Avalonia.Headless/HeadlessWindowExtensions.cs:20`) flushes the dispatcher, ticks the headless timer, and returns a `WriteableBitmap` of the latest frame. The helper delegates to `GetLastRenderedFrame`, which requires Skia-backed rendering—set `UseHeadlessDrawing = false` and `UseSkia = true` in your test app:

```csharp
public static AppBuilder BuildAvaloniaApp() =>
    AppBuilder.Configure<TestApp>()
        .UseHeadless(new AvaloniaHeadlessPlatformOptions
        {
            UseHeadlessDrawing = false,
            UseSkia = true,
            PreferDispatcherScheduling = true
        });
```

Once configured, capture snapshots straight from a headless window:

```csharp
var window = new Window
{
    Content = new ControlCatalogPage(),
    SizeToContent = SizeToContent.WidthAndHeight
};

window.Show();
var frame = window.CaptureRenderedFrame();
Assert.NotNull(frame);
```

Avalonia’s own regression tests follow this pattern (`external/Avalonia/tests/Avalonia.Headless.UnitTests/RenderingTests.cs:18`). Use `CaptureRenderedFrame` when you want the helper to tick timers for you; call `GetLastRenderedFrame` if you have already driven the dispatcher manually.

## 2. Render visuals off-screen with `RenderTargetBitmap`

To avoid constructing full windows, target the visual tree directly. `RenderTargetBitmap` uses `ImmediateRenderer.Render` under the hood (`external/Avalonia/src/Avalonia.Base/Media/Imaging/RenderTargetBitmap.cs:33`).

```csharp
var root = new Border
{
    Width = 200,
    Height = 120,
    Background = Brushes.CornflowerBlue,
    Child = new TextBlock
    {
        Text = "Hello Avalonia",
        FontSize = 24,
        HorizontalAlignment = HorizontalAlignment.Center,
        VerticalAlignment = VerticalAlignment.Center
    }
};

await Dispatcher.UIThread.InvokeAsync(() => root.Measure(new Size(double.PositiveInfinity, double.PositiveInfinity)));
root.Arrange(new Rect(root.DesiredSize));

using var rtb = new RenderTargetBitmap(new PixelSize(200, 120));
rtb.Render(root);
```

The bitmap implements `IBitmap`, so you can save it, compare pixels, or embed it in diagnostics emails. For complex compositions, grab a `DrawingContext` from `RenderTargetBitmap.CreateDrawingContext` to draw primitive overlays before comparison.

## 3. Compare pixels with configurable tolerances

Whether you use `CaptureRenderedFrame` or `RenderTargetBitmap`, lock the frame buffer to access raw bytes. `WriteableBitmap.Lock()` exposes an `ILockedFramebuffer` with stride, format, and a pointer into the pixel buffer (`external/Avalonia/src/Avalonia.Base/Media/Imaging/WriteableBitmap.cs:59`).

```csharp
public static PixelDiffResult CompareBitmaps(IBitmap expected, IBitmap actual, byte tolerance = 2)
{
    using var left = expected.Lock();
    using var right = actual.Lock();

    if (left.Size != right.Size)
        return PixelDiffResult.SizeMismatch(left.Size, right.Size);

    var failures = new List<PixelDiff>();

    unsafe
    {
        for (var y = 0; y < left.Size.Height; y++)
        {
            var pLeft = (byte*)left.Address + y * left.RowBytes;
            var pRight = (byte*)right.Address + y * right.RowBytes;

            for (var x = 0; x < left.Size.Width; x++)
            {
                var idx = x * 4; // BGRA
                var delta = Math.Max(
                    Math.Abs(pLeft[idx] - pRight[idx]),
                    Math.Max(Math.Abs(pLeft[idx + 1] - pRight[idx + 1]),
                             Math.Abs(pLeft[idx + 2] - pRight[idx + 2])));

                if (delta > tolerance)
                    failures.Add(new PixelDiff(x, y, delta));
            }
        }
    }

    return PixelDiffResult.FromList(failures);
}
```

Tune the tolerance to absorb small antialiasing differences. Consider summing absolute channel differences or using the Delta-E metric when gradients highlight sub-pixel drift.

### Produce diagnostic overlays

When differences occur, create an error bitmap that highlights only changed pixels:

```csharp
public static WriteableBitmap CreateDiffMask(IBitmap baseline, PixelDiffResult result)
{
    var size = baseline.PixelSize;
    var diff = new WriteableBitmap(size, baseline.Dpi); // default BGRA32

    using var target = diff.Lock();
    var buffer = new Span<byte>((void*)target.Address, target.RowBytes * size.Height);
    buffer.Clear();

    foreach (var pixel in result.Failures)
    {
        var idx = pixel.Y * target.RowBytes + pixel.X * 4;
        buffer[idx + 0] = 0;          // B
        buffer[idx + 1] = 0;          // G
        buffer[idx + 2] = 255;        // R highlights
        buffer[idx + 3] = 255;        // A
    }

    return diff;
}
```

Attach the original frame, baseline, and diff mask to CI artifacts so reviewers can inspect regressions quickly.

## 4. Manage baselines and golden images

Golden images can live alongside tests as embedded resources. Load them via `WriteableBitmap.Decode` and normalize configuration before comparison:

```csharp
await using var stream = manifestAssembly.GetManifestResourceStream("Tests.Baselines.Dialog.png");
var baseline = WriteableBitmap.Decode(stream!);
```

When baselines must be refreshed, capture a new frame and save it to disk using `frame.Save(fileStream)`. Normalize DPI and render scaling so new baselines remain cross-platform:

```csharp
var normalized = new RenderTargetBitmap(new PixelSize(800, 600), new Vector(96, 96));
normalized.Render(window);
await using var file = File.Create("Baselines/Dialog.png");
normalized.Save(file);
```

`RenderTargetBitmapImpl` uses Skia surfaces (`external/Avalonia/src/Skia/Avalonia.Skia/RenderTargetBitmapImpl.cs:8`), so CI agents must have the Skia native bundle available. If you target platforms without GPU support, stick to headless captures with `UseHeadlessDrawing = true` and fall back to `WriteableBitmap` comparisons.

## 5. Handle DPI, alpha, and layout variability

Visual tests are sensitive to device-independent rounding. Lock down inputs:

- Set explicit window sizes and call `SizeToContent = WidthAndHeight` to avoid layout fluctuations.
- Fix `RenderScaling` by pinning `UseHeadlessDrawing` and Skia DPI to 96.
- Strip alpha when comparing controls that rely on transparency to avoid background differences. Copy pixels into a new bitmap with an opaque fill before diffing.

For dynamic content (animations, timers), tick the dispatcher deterministically: call `AvaloniaHeadlessPlatform.ForceRenderTimerTick()` between each capture, and pause transitions via `IClock` injection so frames stay stable.

Leverage composition snapshots when you need sub-tree captures: `Compositor.CreateCompositionVisualSnapshot` returns a GPU-rendered image of any `Visual` (`external/Avalonia/tests/Avalonia.Headless.UnitTests/RenderingTests.cs:118`). Convert the snapshot to `WriteableBitmap` for comparisons if you want to isolate specific effects layers.

## 6. Troubleshooting

- **`GetLastRenderedFrame` throws** – ensure Skia is active; the helper checks for `HeadlessPlatformRenderInterface` and fails when only headless drawing is enabled.
- **Alpha mismatches** – multiply against a known background before diffing. Render your control inside a `Border` with a solid color or premultiply the buffer before comparison.
- **Different stride values** – always use `ILockedFramebuffer.RowBytes` instead of assuming width × 4 bytes.
- **Platform font differences** – embed test fonts or ship them with the test harness so text metrics remain identical across agents.
- **Large golden files** – compress PNGs with `optipng` or generate vector baselines by storing the render input (XAML/data) alongside the image for easier review.

## Practice lab

1. **Snapshot harness** – Build a `PixelAssert.Capture(window)` helper that returns baseline, actual, and diff images, then integrates them with your test framework’s logging.
2. **Tolerance sweeper** – Write a diagnostic that runs the same render with multiple tolerances, reporting how many pixels fail each threshold to help pick a sensible default.
3. **Golden management** – Implement a CLI command that regenerates baselines from the latest controls, writes them to disk, and updates a manifest listing checksum + control name.
4. **Alpha neutralization** – Add a utility that composites captured frames over a configurable background color before comparison, and verify it fixes regressions caused by transparent overlays.
5. **Snapshot localization** – Capture the same view under different resource cultures and ensure your comparison harness accepts localized text while still flagging layout drift.

What's next
- Next: [Chapter41](Chapter41.md)
