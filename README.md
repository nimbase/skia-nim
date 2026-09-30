<p align="center">
  Nim bindings for <a href="https://skia.org">Skia</a><br>
  low-level C-style wrapper & high-level API
</p>

<p align="center">
  <code>nimble install skia</code>
</p>

<p align="center">
  <a href="https://nimbase.github.io/skia-nim/">API reference</a><br>
  <img src="https://github.com/nimbase/skia-nim/workflows/test/badge.svg" alt="Github Actions">  <img src="https://github.com/nimbase/skia-nim/workflows/docs/badge.svg" alt="Github Actions">
</p>

Curated bindings for the Skia 2D graphics library. The package is split into
a thin, 1:1 core layer over a C ABI and an idiomatic Nim wrapper layer that
manages resources for you.

Skia is a C++ library and its experimental C API was removed upstream in
2023, so there is no C header to bind against. This package therefore ships
its own C ABI (`src/bindings/capi/skia_capi.cpp`), which is compiled and
linked automatically into any program that imports it.

Skia itself is not vendored here: it links against a system-wide
installation, found via `SKIA_DIR` or `-d:skiaHome=...`. See
[SKIA-INSTALL.md](SKIA-INSTALL.md).

> [!NOTE]
> This library is a work in progress. Coverage currently focuses on the CPU
> raster backend: surfaces, canvases, paints, paths, images, PNG/JPEG
> codecs, gradients, image and path effects, and simple text. Not bound
> yet: the GPU backends (`GrDirectContext` / Graphite), `SkPicture`
> recording, `skparagraph` shaping, and the SVG and PDF backends. The
> vendored prebuilt library covers Linux x86-64 only. Contributions
> welcome.

## Features

- Two layers in one package: a thin C-style mapping of the C header
  `src/bindings/capi/skia_capi.h` (as `skia/bindings/skia_raw`), plus a safe
  high-level API on top
- No build step for the consumer — the C++ shim is small enough to compile
  in a second and links straight into your binary; you only need Skia
  already installed, which you probably have via Chrome or Android tooling
- Enum values that cannot silently drift: every `skc_*` constant is
  `static_assert`ed against the Skia enum it mirrors, so an upstream
  renumber breaks the build instead of writing an out-of-range value
- Bindings the C compiler checks — Nim emits no declarations of its own and
  `#include`s the real header, so a signature or field mismatch is a compile
  error
- RAII-style resource management in three flavours, each matching how Skia
  itself treats the object. `Surface`, `Image`, `Shader`, `Typeface`,
  `Font` and friends share one reference-counted handle; `Paint`, `Path` and
  `Pixmap` deep-copy so copies are independent; `Canvas` holds a reference
  to its `Surface` and so cannot outlive it
- `ValueError` and `IOError` on failure, with Skia's own explanation
  attached, rather than NULL sentinels
- Idiomatic helpers on top of the C surface: `fillPaint` / `strokePaint`
  presets, `newPath(proc (p: var Path) ...)` builders, `canvas.scoped` and
  `canvas.transformed` for balanced save/restore, and `$` on every enum
  for readable error messages
- Graphics: shapes, paths with all curve types, fill rules, blend modes,
  clipping, transforms, linear / radial / sweep / conical gradients, blur
  filters, dash and corner path effects, and colour matrix filters
- Images: PNG and JPEG encoding, lazy decode, pixel read-back normalised to
  RGBA, and `snapshot` from any surface
- Text through the platform font manager, with measurement, metrics, and
  reusable text blobs
- Tested for memory safety under AddressSanitizer: no leaks and no invalid
  accesses attributable to the binding

## Requirements

- Nim >= 2.2.10
- A C++17 compiler. The shim is built with whatever `nim c` uses, via
  `{.compile(...)}` in `src/bindings/skia_raw.nim`.
- A system-wide Skia installation, with matching public headers and a static
  `libskia.a`. This is the one real prerequisite — see
  [SKIA-INSTALL.md](SKIA-INSTALL.md) for how to get one. The binding
  searches, in order: `-d:skiaHome=…`, `$SKIA_DIR`,
  `$XDG_DATA_HOME/skia` (or `~/.local/share/skia`), then `/usr/local/skia`,
  `/opt/skia`, `/usr/local` and `/usr`. If it finds none it stops with the
  list of paths it tried rather than guessing.
- Linux x86-64 is the configuration this package is developed and tested
  against. The `passC` / `passL` blocks carry macOS and Windows variants,
  but you will need to supply your own `libskia` and headers for those.

System libraries linked alongside Skia: `fontconfig` and `freetype` (for
text), plus the usual `pthread` / `dl` / `m`.

## Examples

### Shapes, gradients and encoding

```nim
import skia

let surface = newRgbaSurface(480, 360)
let canvas = surface.canvas
canvas.drawColor(rgb(0.10, 0.11, 0.13))

# a gradient band across the top
var band = newPaint()
band.setShader(linearGradient(point(0, 0), point(0, 120),
  [rgb(0.15, 0.20, 0.35), rgb(0.45, 0.25, 0.40)]))
canvas.drawRect(rectLTRB(0, 0, 480, 120), band)

# a shape
var path = newPath()
path.addCircle(point(240, 240), 90)
canvas.drawPath(path, fillPaint(rgb(0.95, 0.35, 0.30)))

surface.snapshot().savePng("out.png")
```

`newPath` also takes a builder, so a shape can be written in one expression:

```nim
var rounded = newPath(proc (p: var Path) =
  p.moveTo(0, 0)
  p.lineTo(90, 0)
  p.cubicTo(120, 0, 120, 60, 90, 60)
  p.lineTo(0, 60)
  p.close())
canvas.drawPath(rounded, strokePaint(rgb(0.30, 0.80, 0.65), 3))
```

### Balanced state

`scoped` and `transformed` restore the canvas even if the body raises, so
there is no bookkeeping to get wrong:

```nim
canvas.scoped:
  canvas.clipRect(rectXY(0, 0, 100, 100))
  canvas.drawColor(rgb(0.2, 0.4, 0.9))

canvas.transformed(translation(40, 40)):
  canvas.drawRect(rectLTRB(0, 0, 60, 60), fillPaint(ColorWhite))
```

### Image filters

Skia's raster pipeline applies a paint's image filter to a *layer*, not to
an individual draw, so the drawing goes inside `layer`:

```nim
var filterPaint = newPaint()
filterPaint.setImageFilter(blur(6, 6, TileModeClamp))

canvas.layer(filterPaint):
  canvas.drawCircle(point(400, 200), 30, fillPaint(rgb(1, 0.75, 0.2)))
```

### Text

```nim
let mgr = defaultFontManager()
let typeface = mgr.defaultTypeface()
let heading = newFont(typeface, 22)

let measured = heading.measureText("Skia from Nim")
echo measured.advance, " px wide, top at ", measured.bounds.top

canvas.drawText("Skia from Nim", point(20, 40), heading,
  fillPaint(ColorWhite))
```

### Decoding and reading pixels

```nim
let decoded = decodeImage(newData(readFile("input.png")))
canvas.drawImage(decoded, point(20, 20))

# native layout is whatever Skia chose; toRgba always normalises it
let rgba = decoded.toRgba()
echo decoded.colorType, " -> ", rgba.len, " bytes of RGBA"
```

### Errors

Failures raise with Skia's own explanation attached:

```nim
try:
  discard newRgbaSurface(0, 0)
except IOError as e:
  echo e.msg
  # => newSurface(0x0): skc_surface_new_raster: invalid dimensions or colour type
```

## Tests

```sh
nimble test                                         # 62 tests
nim c -r --path:src examples/gallery.nim out.png    # renders a gallery
```

The suite covers ABI layout (`sizeof` and `offsetOf` checks pinning both the
C header and the Nim mirrors of every value struct), ownership and copy
semantics, error paths, PNG/JPEG round trips, gradients, blur, fill rules
and text metrics.

## Building against a different Skia

See [SKIA-INSTALL.md](SKIA-INSTALL.md) for the exact Skia commit this was
developed against and the steps to move to a newer one. Skia has no stable
C++ ABI, so headers and library must come from the same commit — mixing
them links fine and then corrupts memory.

The vendored copy of Skia that earlier versions of this package carried in
`third_party/` has been removed: it was 38 MB of build inputs that had no
business inside a library, and it is now a system dependency instead.

### ❤ Contributions & Support
- 🐛 Found a bug? [Create a new Issue](https://github.com/nimbase/skia-nim/issues)
- 👋 Wanna help? [Fork it!](https://github.com/nimbase/skia-nim/fork)

### 🎩 License
MIT license | Nim Community.

Skia itself is BSD-3-Clause; keep its `LICENSE` alongside your Skia
installation.
