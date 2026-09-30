# Installing Skia for this package

This package does **not** vendor Skia. It compiles a small C++ shim against
Skia's public headers and links Skia's static library, both of which come
from a system-wide installation.

## Layout

The binding looks for a directory containing:

```
<skia home>/
├── include/          Skia's public C++ headers
│   └── core/…        e.g. include/core/SkCanvas.h
├── modules/
│   └── skcms/…       needed by SkColorSpace.h
└── lib/
    └── libskia.a     static Skia
```

`include/` and `modules/` must sit side by side at the top level, because
Skia's own headers include each other root-relative
(`#include "include/core/SkTypes.h"`, `#include "modules/skcms/skcms.h"`).
A stock Skia checkout already has this shape; the `src/` and `.git/`
directories can be deleted to save space.

## Where the binding looks

In priority order, first match wins:

1. `-d:skiaHome=/path/to/skia` on the compiler command line
2. the `SKIA_DIR` environment variable
3. a user-global install: `$XDG_DATA_HOME/skia`, else `~/.local/share/skia`
4. `/usr/local/skia`, `/opt/skia`, `/usr/local`, `/usr`

If nothing matches, the build stops with a message listing every path it
tried and the files it was looking for. It does not fall back to a partial
or guessed location, because a header/library mismatch links cleanly and
then corrupts memory.

## A working setup

Prebuilt static libraries are published by
[rust-skia/skia-binaries](https://github.com/rust-skia/skia-binaries).
The exact artefact this package was developed against:

| | |
|---|---|
| Skia version | m153 (0.153.3) |
| Skia commit | `61e7ca4e99062cdd0ab69445d5963fb3365778f6` (rust-skia/skia fork) |
| Artefact | `skia-binaries-b7f043e0b1e2a850e702-x86_64-unknown-linux-gnu-jpegd-jpege-pdf.tar.gz` |
| Features | raster (CPU) only, libjpeg-turbo, PDF. No GPU backend, no WebP. |

To install it for the current user:

```sh
SKIA_TAG=0.153.3
SKIA_KEY=b7f043e0b1e2a850e702-x86_64-unknown-linux-gnu-jpegd-jpege-pdf
SKIA_COMMIT=61e7ca4e99062cdd0ab69445d5963fb3365778f6

# 1. static library
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/skia"
mkdir -p "$PREFIX/lib"
curl -L "https://github.com/rust-skia/skia-binaries/releases/download/$SKIA_TAG/skia-binaries-$SKIA_KEY.tar.gz" \
  | tar xzO skia-binaries/libskia.a > "$PREFIX/lib/libskia.a"
curl -L "https://github.com/rust-skia/skia-binaries/releases/download/$SKIA_TAG/skia-binaries-$SKIA_KEY.tar.gz" \
  | tar xzO skia-binaries/LICENSE_SKIA > "$PREFIX/LICENSE"

# 2. matching public headers, from the commit the library was built against
curl -L "https://codeload.github.com/rust-skia/skia/tar.gz/$SKIA_COMMIT" \
  | tar xz -C /tmp --wildcards "*/include/*" "*/modules/skcms/*"
cp -r "/tmp/skia-$SKIA_COMMIT/include" "$PREFIX/"
mkdir -p "$PREFIX/modules"
cp -r "/tmp/skia-$SKIA_COMMIT/modules/skcms" "$PREFIX/modules/"
```

For a system-wide install, use `PREFIX=/usr/local/skia` (needs write
access) and it will be found by the last rule in the search order.

## The headers and the library must match

Skia has no stable C++ ABI. Headers from one commit and `libskia.a` from
another will link without complaint and then read the wrong offsets at
runtime. `src/bindings/capi/skia_capi.cpp` guards against the *enumerated*
part of that with `static_assert`s on every `skc_*` value, so a renumbered
enum fails the build — but a struct layout change would not be caught.

To move to a newer Skia, pick a new tag and commit pair, redo the two steps
above, then update `skc_version()` in
`src/bindings/capi/skia_capi.cpp`.

## System libraries

Linked alongside Skia: `fontconfig` and `freetype` (for text), plus
`pthread`, `dl` and `m`. On Debian/Ubuntu:

```sh
sudo apt install libfontconfig1-dev libfreetype-dev
```

## Licence

Skia is BSD-3-Clause. Keep its `LICENSE` alongside the install.
