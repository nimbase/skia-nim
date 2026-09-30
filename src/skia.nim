## Idiomatic Nim bindings for the Skia 2D graphics library.
##
## Skia is a C++ library with no C API of its own, so this package ships a
## hand-written C ABI (`src/bindings/capi/skia_capi.cpp`) which is compiled and linked
## automatically. Nothing needs to be installed or built separately: import
## this module and the shim and `libskia.a` are pulled into your binary.
##
## Two layers are available:
##
## * This module and `skia/resources` are the idiomatic layer. Handles own
##   their Skia resources, copy and destruction are automatic, and failures
##   raise `ValueError` or `IOError` rather than returning NULL.
## * `skia/bindings/skia_raw` is the raw FFI layer, re-exported below for
##   advanced use. It is an ABI-faithful transcription of the C header.
##
## Getting started::
##
##   import skia
##
##   let surface = newRgbaSurface(256, 256)
##   let canvas = surface.canvas
##
##   var paint = fillPaint(rgb(0.2, 0.4, 0.9))
##   paint.setAntiAlias(true)
##
##   var path = newPath()
##   path.addCircle(point(128, 128), 90)
##   canvas.drawPath(path, addr paint)
##
##   writeFile("out.png", surface.snapshot().encodePng().toString())

import bindings/skia_raw
import skia/geometry
import skia/resources

export geometry
export resources
export skia_raw

proc lastError*(): string =
  ## Description of the most recent Skia failure on this thread, or an
  ## empty string if there was none. Errors raised by this package already
  ## include this text.
  let s = skc_last_error()
  if s.isNil: "" else: $s

proc clearError*() =
  ## Discards the recorded error for this thread.
  skc_clear_error()

proc skiaVersion*(): string =
  ## The version of the Skia build this package is linked against.
  $skc_version()

export lastError, clearError, skiaVersion
