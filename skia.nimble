# Package

version       = "0.1.0"
author        = "George Lemon"
description   = "Idiomatic Nim bindings for the Skia 2D graphics library"
license       = "MIT"
srcDir        = "src"

# Skia itself is NOT vendored or shipped. The package links against a
# system-wide Skia installation; see SKIA-INSTALL.md for how to obtain one
# and how to point this package at it.
requires "nim >= 2.2.10"
