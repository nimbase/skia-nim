## Raw FFI layer for the Skia C ABI.
##
## This module is a faithful, ABI-level transcription of the C header
## `capi/skia_capi.h`. It contains no convenience, no ownership tracking and
## no error raising: a function here returns exactly what the C function
## returns, including NULL on failure. The idiomatic layer lives in `skia`
## and is what most users should import.
##
## Skia itself has no C API (the experimental one was removed upstream), so
## the C ABI is provided by the C++ shim in `capi/skia_capi.cpp`, which is
## compiled and linked into any program that imports this module.
##
## Skia is *not* vendored into this package. It is linked from a
## system-wide installation; see `skiaHome` below for the search order and
## for how to point at a non-standard location.

import std/os, std/strutils

const
  ## Where a system-wide Skia may live, in priority order:
  ##   1. `-d:skiaHome=/path/to/skia`
  ##   2. the `SKIA_DIR` environment variable
  ##   3. a user-global install, `$XDG_DATA_HOME/skia` or `~/.local/share/skia`
  ##   4. conventional prefixes: `/usr/local/skia`, `/opt/skia`,
  ##      `/usr/local`, `/usr`
  skiaCandidates =
    when defined(skiaHome):
      @[skiaHome.string]
    else:
      block:
        var found: seq[string] = @[]
        let env = getEnv("SKIA_DIR", "")
        if env.len > 0:
          found.add env
        let dataHome = getEnv("XDG_DATA_HOME", "")
        found.add(if dataHome.len > 0: dataHome / "skia"
                  else: getHomeDir() / ".local" / "share" / "skia")
        found.add @["/usr/local/skia", "/opt/skia", "/usr/local", "/usr"]
        found

const
  skiaRequiredFiles = "include/core/SkCanvas.h, modules/skcms/skcms.h, lib/libskia.a"

  skiaNotFoundMsg = """

Skia was not found.

This package compiles a C++ shim against the public headers of Skia and
links the Skia static library, both taken from a system-wide installation.
Skia itself is not bundled.

Point this package at an installation with either:
  * the SKIA_DIR environment variable:   SKIA_DIR=/opt/skia nim c ...
  * a compiler define:                   nim c -d:skiaHome=/opt/skia ...

An installation must contain: """ & skiaRequiredFiles & """

Searched, in order: """ & skiaCandidates.join(", ")

const
  bindingsDir = currentSourcePath.parentDir
    ## Directory holding this module and the C ABI it binds against.

  capiDir = bindingsDir / "capi"

  ## Root of the system-wide Skia installation being linked against.
  ##
  ## The first candidate that has both the public headers and a static
  ## `libskia.a` wins. Deliberately not guessed at when none does: a
  ## header/library mismatch links cleanly and then corrupts memory, so a
  ## wrong-but-plausible path is worse than a hard stop. An empty string
  ## means nothing was found; the `static` assertion below turns that into
  ## a compile error with instructions.
  skiaHome* =
    block:
      var found = ""
      for dir in skiaCandidates:
        if found.len == 0 and dir.len > 0 and
            fileExists(dir / "include" / "core" / "SkCanvas.h") and
            fileExists(dir / "modules" / "skcms" / "skcms.h") and
            fileExists(dir / "lib" / "libskia.a"):
          found = dir
      found

static:
  doAssert skiaHome.len > 0, skiaNotFoundMsg

const
  skiaIncludeDir = skiaHome / "include"
  skiaRootIncludeDir = skiaHome
  skiaModulesDir = skiaHome / "modules"
  skiaLibDir = skiaHome / "lib"

{.passC: "-I" & quoteShell(capiDir) & " -I" & quoteShell(skiaIncludeDir) &
    " -I" & quoteShell(skiaRootIncludeDir) & " -I" & quoteShell(skiaModulesDir) &
    " -DSK_GAMMA_EXPONENT=3".}

when defined(windows):
  {.passL: "-L" & quoteShell(skiaLibDir) & " -lskia -lfontconfig -lfreetype -luser32".}
  const cppFlags = "-std=c++17 /EHsc /w"
elif defined(macosx):
  {.passL: "-L" & quoteShell(skiaLibDir) & " -lskia -lc++ -framework CoreFoundation " &
           "-framework CoreText -framework CoreGraphics -framework ImageIO " &
           "-framework CoreServices".}
  const cppFlags = "-std=c++17 -stdlib=libc++ -w"
else:
  {.passL: "-L" & quoteShell(skiaLibDir) & " -lskia -lfontconfig -lfreetype -lpthread -ldl -lm".}
  const cppFlags = "-std=c++17 -w"

## NOTE: the call form `{.compile(...)}` is required here. The tuple form
## `{.compile: (src, dst)}` means "input, output object", not "input, flags".
{.compile(capiDir / "skia_capi.cpp",
    cppFlags & " -I" & quoteShell(capiDir) & " -I" & quoteShell(skiaIncludeDir) &
    " -I" & quoteShell(skiaRootIncludeDir) & " -I" & quoteShell(skiaModulesDir) &
    " -DSK_GAMMA_EXPONENT=3").}

# ------------------------------------------------------------------
# Enumerations
#
# C enums are spelled as distinct 32-bit integers. The matching
# `static_assert`s in skia_capi.cpp keep these values honest.
# ------------------------------------------------------------------

type
  ColorType* = distinct cint
  AlphaType* = distinct cint
  ColorSpace* = distinct cint
  BlendMode* = distinct cint
  PaintStyle* = distinct cint
  StrokeCap* = distinct cint
  StrokeJoin* = distinct cint
  FillType* = distinct cint
  TileMode* = distinct cint
  FilterMode* = distinct cint
  MipmapMode* = distinct cint
  PointMode* = distinct cint
  FontEdging* = distinct cint
  FontHinting* = distinct cint
  EncodedFormat* = distinct cint
  FontWeight* = distinct cint
  FontWidth* = distinct cint
  FontSlant* = distinct cint

const
  ColorTypeUnknown* = ColorType(0)
  ColorTypeAlpha8* = ColorType(1)
  ColorTypeRGB565* = ColorType(2)
  ColorTypeARGB4444* = ColorType(3)
  ColorTypeRGBA8888* = ColorType(4)
  ColorTypeRGB888x* = ColorType(5)
  ColorTypeBGRA8888* = ColorType(6)
  ColorTypeRGBA1010102* = ColorType(7)
  ColorTypeBGRA1010102* = ColorType(8)
  ColorTypeRGB101010x* = ColorType(9)
  ColorTypeBGR101010x* = ColorType(10)
  ColorTypeBGR101010xXR* = ColorType(11)
  ColorTypeBGRA10101010XR* = ColorType(12)
  ColorTypeRGBA10x6* = ColorType(13)
  ColorTypeGray8* = ColorType(14)
  ColorTypeRGBAF16Norm* = ColorType(15)
  ColorTypeRGBAF16* = ColorType(16)
  ColorTypeRGBF16F16F16x* = ColorType(17)
  ColorTypeRGBAF32* = ColorType(18)
  ColorTypeR8G8Unorm* = ColorType(19)
  ColorTypeA16Float* = ColorType(20)
  ColorTypeR16Float* = ColorType(21)
  ColorTypeR16G16Float* = ColorType(22)
  ColorTypeA16Unorm* = ColorType(23)
  ColorTypeR16Unorm* = ColorType(24)
  ColorTypeR16G16Unorm* = ColorType(25)
  ColorTypeR16G16B16A16Unorm* = ColorType(26)
  ColorTypeSRGBA8888* = ColorType(27)
  ColorTypeR8Unorm* = ColorType(28)

  AlphaTypeUnknown* = AlphaType(0)
  AlphaTypeOpaque* = AlphaType(1)
  AlphaTypePremul* = AlphaType(2)
  AlphaTypeUnpremul* = AlphaType(3)

  ColorSpaceSrgb* = ColorSpace(0)
  ColorSpaceLinearSrgb* = ColorSpace(2)

  BlendModeClear* = BlendMode(0)
  BlendModeSrc* = BlendMode(1)
  BlendModeDst* = BlendMode(2)
  BlendModeSrcOver* = BlendMode(3)
  BlendModeDstOver* = BlendMode(4)
  BlendModeSrcIn* = BlendMode(5)
  BlendModeDstIn* = BlendMode(6)
  BlendModeSrcOut* = BlendMode(7)
  BlendModeDstOut* = BlendMode(8)
  BlendModeSrcATop* = BlendMode(9)
  BlendModeDstATop* = BlendMode(10)
  BlendModeXor* = BlendMode(11)
  BlendModePlus* = BlendMode(12)
  BlendModeModulate* = BlendMode(13)
  BlendModeScreen* = BlendMode(14)
  BlendModeOverlay* = BlendMode(15)
  BlendModeDarken* = BlendMode(16)
  BlendModeLighten* = BlendMode(17)
  BlendModeColorDodge* = BlendMode(18)
  BlendModeColorBurn* = BlendMode(19)
  BlendModeHardLight* = BlendMode(20)
  BlendModeSoftLight* = BlendMode(21)
  BlendModeDifference* = BlendMode(22)
  BlendModeExclusion* = BlendMode(23)
  BlendModeMultiply* = BlendMode(24)
  BlendModeHue* = BlendMode(25)
  BlendModeSaturation* = BlendMode(26)
  BlendModeColor* = BlendMode(27)
  BlendModeLuminosity* = BlendMode(28)

  PaintStyleFill* = PaintStyle(0)
  PaintStyleStroke* = PaintStyle(1)
  PaintStyleStrokeAndFill* = PaintStyle(2)

  StrokeCapButt* = StrokeCap(0)
  StrokeCapRound* = StrokeCap(1)
  StrokeCapSquare* = StrokeCap(2)

  StrokeJoinMiter* = StrokeJoin(0)
  StrokeJoinRound* = StrokeJoin(1)
  StrokeJoinBevel* = StrokeJoin(2)

  FillTypeWinding* = FillType(0)
  FillTypeEvenOdd* = FillType(1)
  FillTypeInverseWinding* = FillType(2)
  FillTypeInverseEvenOdd* = FillType(3)

  TileModeClamp* = TileMode(0)
  TileModeRepeat* = TileMode(1)
  TileModeMirror* = TileMode(2)
  TileModeDecal* = TileMode(3)

  FilterModeNearest* = FilterMode(0)
  FilterModeLinear* = FilterMode(1)

  MipmapModeNone* = MipmapMode(0)
  MipmapModeNearest* = MipmapMode(1)
  MipmapModeLinear* = MipmapMode(2)

  PointModePoints* = PointMode(0)
  PointModeLines* = PointMode(1)
  PointModePolygon* = PointMode(2)

  FontEdgingAlias* = FontEdging(0)
  FontEdgingAntiAlias* = FontEdging(1)
  FontEdgingSubpixelAntiAlias* = FontEdging(2)

  FontHintingNone* = FontHinting(0)
  FontHintingSlight* = FontHinting(1)
  FontHintingNormal* = FontHinting(2)
  FontHintingFull* = FontHinting(3)

  EncodedFormatBmp* = EncodedFormat(0)
  EncodedFormatGif* = EncodedFormat(1)
  EncodedFormatIco* = EncodedFormat(2)
  EncodedFormatJpeg* = EncodedFormat(3)
  EncodedFormatPng* = EncodedFormat(4)
  EncodedFormatWbmp* = EncodedFormat(5)
  EncodedFormatWebp* = EncodedFormat(6)

  FontWeightInvisible* = FontWeight(0)
  FontWeightThin* = FontWeight(100)
  FontWeightExtraLight* = FontWeight(200)
  FontWeightLight* = FontWeight(300)
  FontWeightNormal* = FontWeight(400)
  FontWeightMedium* = FontWeight(500)
  FontWeightSemiBold* = FontWeight(600)
  FontWeightBold* = FontWeight(700)
  FontWeightExtraBold* = FontWeight(800)
  FontWeightBlack* = FontWeight(900)
  FontWeightExtraBlack* = FontWeight(1000)

  FontWidthUltraCondensed* = FontWidth(1)
  FontWidthExtraCondensed* = FontWidth(2)
  FontWidthCondensed* = FontWidth(3)
  FontWidthSemiCondensed* = FontWidth(4)
  FontWidthNormal* = FontWidth(5)
  FontWidthSemiExpanded* = FontWidth(6)
  FontWidthExpanded* = FontWidth(7)
  FontWidthExtraExpanded* = FontWidth(8)
  FontWidthUltraExpanded* = FontWidth(9)

  FontSlantUpright* = FontSlant(0)
  FontSlantItalic* = FontSlant(1)
  FontSlantOblique* = FontSlant(2)

proc `==`*(a, b: ColorType): bool {.borrow.}
proc `==`*(a, b: AlphaType): bool {.borrow.}
proc `==`*(a, b: ColorSpace): bool {.borrow.}
proc `==`*(a, b: BlendMode): bool {.borrow.}
proc `==`*(a, b: PaintStyle): bool {.borrow.}
proc `==`*(a, b: StrokeCap): bool {.borrow.}
proc `==`*(a, b: StrokeJoin): bool {.borrow.}
proc `==`*(a, b: FillType): bool {.borrow.}
proc `==`*(a, b: TileMode): bool {.borrow.}
proc `==`*(a, b: FilterMode): bool {.borrow.}
proc `==`*(a, b: MipmapMode): bool {.borrow.}
proc `==`*(a, b: PointMode): bool {.borrow.}
proc `==`*(a, b: FontEdging): bool {.borrow.}
proc `==`*(a, b: FontHinting): bool {.borrow.}
proc `==`*(a, b: EncodedFormat): bool {.borrow.}
proc `==`*(a, b: FontWeight): bool {.borrow.}
proc `==`*(a, b: FontWidth): bool {.borrow.}
proc `==`*(a, b: FontSlant): bool {.borrow.}

# ------------------------------------------------------------------
# Value types
#
# Field order matches the C struct exactly; never reorder these.
# ------------------------------------------------------------------

const
  skiaCapiHeader* = "skia_capi.h"
    ## The C header this module binds against. Nim emits an `#include` for
    ## it instead of writing its own declarations, so the C compiler checks
    ## every signature and struct field below against the real thing.

type
  skc_color_t* {.importc: "skc_color_t", header: skiaCapiHeader, bycopy, completeStruct.} = object
    r*, g*, b*, a*: cfloat

  skc_point_t* {.importc: "skc_point_t", header: skiaCapiHeader, bycopy, completeStruct.} = object
    x*, y*: cfloat

  skc_rect_t* {.importc: "skc_rect_t", header: skiaCapiHeader, bycopy, completeStruct.} = object
    left*, top*, right*, bottom*: cfloat

  skc_irect_t* {.importc: "skc_irect_t", header: skiaCapiHeader, bycopy, completeStruct.} = object
    left*, top*, right*, bottom*: int32

  skc_matrix_t* {.importc: "skc_matrix_t", header: skiaCapiHeader, bycopy, completeStruct.} = object
    ## Row-major 3x3 transform, matching the storage of `skia::SkMatrix`.
    m*: array[9, cfloat]

  skc_imageinfo_t* {.importc: "skc_imageinfo_t", header: skiaCapiHeader, bycopy, completeStruct.} = object
    width*, height*: int32
    colorType*: ColorType
    alphaType*: AlphaType
    colorSpace*: ColorSpace

  skc_fontstyle_t* {.importc: "skc_fontstyle_t", header: skiaCapiHeader, bycopy, completeStruct.} = object
    weight*, width*: int32
    slant*: FontSlant

  skc_fontmetrics_t* {.importc: "skc_fontmetrics_t", header: skiaCapiHeader, bycopy, completeStruct.} = object
    ascent*, descent*, leading*, top*, bottom*, xMin*, xMax*: cfloat

# ------------------------------------------------------------------
# Opaque handles
# ------------------------------------------------------------------

{.push callconv: cdecl, importc, header: skiaCapiHeader.}

type
  skc_data_t* {.importc: "skc_data_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_pixmap_t* {.importc: "skc_pixmap_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_surface_t* {.importc: "skc_surface_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_canvas_t* {.importc: "skc_canvas_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_paint_t* {.importc: "skc_paint_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_path_t* {.importc: "skc_path_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_image_t* {.importc: "skc_image_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_shader_t* {.importc: "skc_shader_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_image_filter_t* {.importc: "skc_image_filter_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_path_effect_t* {.importc: "skc_path_effect_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_color_filter_t* {.importc: "skc_color_filter_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_typeface_t* {.importc: "skc_typeface_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_font_manager_t* {.importc: "skc_font_manager_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_font_t* {.importc: "skc_font_t", header: skiaCapiHeader, incompleteStruct.} = object
  skc_text_blob_t* {.importc: "skc_text_blob_t", header: skiaCapiHeader, incompleteStruct.} = object

  CReleaseProc* = proc(ctx: pointer) {.cdecl.}

{.pop.}

{.push callconv: cdecl, importc, header: skiaCapiHeader.}

# ------------------------------------------------------------------
# Errors and version
# ------------------------------------------------------------------

proc skc_last_error*(): cstring
proc skc_clear_error*()
proc skc_version*(): cstring

# ------------------------------------------------------------------
# Value helpers
# ------------------------------------------------------------------

proc skc_rect_make*(left, top, right, bottom: cfloat): skc_rect_t
proc skc_rect_make_wh*(width, height: cfloat): skc_rect_t
proc skc_rect_is_empty*(r: ptr skc_rect_t): bool
proc skc_irect_make*(left, top, right, bottom: int32): skc_irect_t

proc skc_matrix_identity*(): skc_matrix_t
proc skc_matrix_make_translate*(dx, dy: cfloat): skc_matrix_t
proc skc_matrix_make_scale*(sx, sy: cfloat): skc_matrix_t
proc skc_matrix_make_rotate*(degrees: cfloat): skc_matrix_t
proc skc_matrix_make_all*(scaleX, skewX, transX, skewY, scaleY, transY, perspX, perspY,
    perspZ: cfloat): skc_matrix_t
proc skc_matrix_set_identity*(m: ptr skc_matrix_t)
proc skc_matrix_pre_translate*(m: ptr skc_matrix_t; dx, dy: cfloat)
proc skc_matrix_pre_scale*(m: ptr skc_matrix_t; sx, sy: cfloat)
proc skc_matrix_pre_rotate*(m: ptr skc_matrix_t; degrees: cfloat)
proc skc_matrix_post_translate*(m: ptr skc_matrix_t; dx, dy: cfloat)
proc skc_matrix_post_scale*(m: ptr skc_matrix_t; sx, sy: cfloat)
proc skc_matrix_post_rotate*(m: ptr skc_matrix_t; degrees: cfloat)
proc skc_matrix_concat*(target: ptr skc_matrix_t; a, b: ptr skc_matrix_t)
proc skc_matrix_invert*(src: ptr skc_matrix_t; dst: ptr skc_matrix_t): bool
proc skc_matrix_map_rect*(m: ptr skc_matrix_t; rect: ptr skc_rect_t)

proc skc_fontstyle_normal*(): skc_fontstyle_t
proc skc_fontstyle_make*(weight: FontWeight; width: FontWidth; slant: FontSlant): skc_fontstyle_t

# ------------------------------------------------------------------
# Data
# ------------------------------------------------------------------

proc skc_data_new*(data: pointer; size: csize_t): ptr skc_data_t
proc skc_data_new_null*(): ptr skc_data_t
proc skc_data_ref*(data: ptr skc_data_t): ptr skc_data_t
proc skc_data_unref*(data: ptr skc_data_t)
proc skc_data_size*(data: ptr skc_data_t): csize_t
proc skc_data_data*(data: ptr skc_data_t): pointer

# ------------------------------------------------------------------
# Pixmap
# ------------------------------------------------------------------

proc skc_pixmap_new*(info: ptr skc_imageinfo_t; pixels: pointer; rowBytes: csize_t): ptr skc_pixmap_t
proc skc_pixmap_free*(pixmap: ptr skc_pixmap_t)
proc skc_pixmap_reset*(pixmap: ptr skc_pixmap_t; info: ptr skc_imageinfo_t; pixels: pointer;
    rowBytes: csize_t): bool
proc skc_pixmap_width*(pixmap: ptr skc_pixmap_t): int32
proc skc_pixmap_height*(pixmap: ptr skc_pixmap_t): int32
proc skc_pixmap_row_bytes*(pixmap: ptr skc_pixmap_t): csize_t
proc skc_pixmap_image_info*(pixmap: ptr skc_pixmap_t): ptr skc_imageinfo_t
proc skc_pixmap_pixels*(pixmap: ptr skc_pixmap_t): pointer
proc skc_pixmap_read_pixels*(src: ptr skc_pixmap_t; dstInfo: ptr skc_imageinfo_t; dstPixels: pointer;
    dstRowBytes: csize_t): bool

# ------------------------------------------------------------------
# Surface
# ------------------------------------------------------------------

proc skc_surface_new_raster*(info: ptr skc_imageinfo_t): ptr skc_surface_t
proc skc_surface_new_raster_with_row_bytes*(info: ptr skc_imageinfo_t;
    rowBytes: csize_t): ptr skc_surface_t
proc skc_surface_new_raster_direct*(info: ptr skc_imageinfo_t; pixels: pointer;
    rowBytes: csize_t): ptr skc_surface_t
proc skc_surface_new_raster_owned*(info: ptr skc_imageinfo_t; pixels: pointer;
    rowBytes: csize_t; release: CReleaseProc; releaseCtx: pointer): ptr skc_surface_t
proc skc_surface_ref*(surface: ptr skc_surface_t): ptr skc_surface_t
proc skc_surface_unref*(surface: ptr skc_surface_t)
proc skc_surface_width*(surface: ptr skc_surface_t): int32
proc skc_surface_height*(surface: ptr skc_surface_t): int32
proc skc_surface_get_canvas*(surface: ptr skc_surface_t): ptr skc_canvas_t
proc skc_surface_flush*(surface: ptr skc_surface_t)
proc skc_surface_flush_and_submit*(surface: ptr skc_surface_t)
proc skc_surface_make_image_snapshot*(surface: ptr skc_surface_t): ptr skc_image_t
proc skc_surface_read_pixels*(surface: ptr skc_surface_t; dstInfo: ptr skc_imageinfo_t;
    dstPixels: pointer; dstRowBytes: csize_t): bool
proc skc_surface_peek_pixels*(surface: ptr skc_surface_t): ptr skc_pixmap_t

# ------------------------------------------------------------------
# Canvas
# ------------------------------------------------------------------

proc skc_canvas_save*(canvas: ptr skc_canvas_t): cint
proc skc_canvas_save_layer*(canvas: ptr skc_canvas_t; paint: ptr skc_paint_t): cint
proc skc_canvas_restore*(canvas: ptr skc_canvas_t; saveCount: cint)
proc skc_canvas_get_save_count*(canvas: ptr skc_canvas_t): cint
proc skc_canvas_clip_rect*(canvas: ptr skc_canvas_t; rect: ptr skc_rect_t; antiAlias: bool)
proc skc_canvas_clip_path*(canvas: ptr skc_canvas_t; path: ptr skc_path_t; antiAlias: bool)
proc skc_canvas_draw_color*(canvas: ptr skc_canvas_t; color: skc_color_t; mode: BlendMode)
proc skc_canvas_draw_rect*(canvas: ptr skc_canvas_t; rect: ptr skc_rect_t; paint: ptr skc_paint_t)
proc skc_canvas_draw_oval*(canvas: ptr skc_canvas_t; oval: ptr skc_rect_t; paint: ptr skc_paint_t)
proc skc_canvas_draw_circle*(canvas: ptr skc_canvas_t; cx, cy, radius: cfloat; paint: ptr skc_paint_t)
proc skc_canvas_draw_line*(canvas: ptr skc_canvas_t; x0, y0, x1, y1: cfloat; paint: ptr skc_paint_t)
proc skc_canvas_draw_points*(canvas: ptr skc_canvas_t; points: ptr skc_point_t; count: csize_t;
    mode: PointMode; paint: ptr skc_paint_t)
proc skc_canvas_draw_path*(canvas: ptr skc_canvas_t; path: ptr skc_path_t; paint: ptr skc_paint_t)
proc skc_canvas_draw_image*(canvas: ptr skc_canvas_t; image: ptr skc_image_t; x, y: cfloat;
    paint: ptr skc_paint_t)
proc skc_canvas_draw_image_rect*(canvas: ptr skc_canvas_t; image: ptr skc_image_t; src, dst: ptr skc_rect_t;
    filter: FilterMode; mipmap: MipmapMode; paint: ptr skc_paint_t)
proc skc_canvas_draw_text*(canvas: ptr skc_canvas_t; text: cstring; length: csize_t;
    x, y: cfloat; font: ptr skc_font_t; paint: ptr skc_paint_t)
proc skc_canvas_draw_text_blob*(canvas: ptr skc_canvas_t; blob: ptr skc_text_blob_t; x, y: cfloat;
    paint: ptr skc_paint_t)
proc skc_canvas_translate*(canvas: ptr skc_canvas_t; dx, dy: cfloat)
proc skc_canvas_scale*(canvas: ptr skc_canvas_t; sx, sy: cfloat)
proc skc_canvas_rotate*(canvas: ptr skc_canvas_t; degrees: cfloat)
proc skc_canvas_concat*(canvas: ptr skc_canvas_t; matrix: ptr skc_matrix_t)
proc skc_canvas_set_matrix*(canvas: ptr skc_canvas_t; matrix: ptr skc_matrix_t)
proc skc_canvas_reset_matrix*(canvas: ptr skc_canvas_t)
proc skc_canvas_get_device_clip_bounds*(canvas: ptr skc_canvas_t): skc_irect_t

# ------------------------------------------------------------------
# Paint
# ------------------------------------------------------------------

proc skc_paint_new*(): ptr skc_paint_t
proc skc_paint_new_copy*(src: ptr skc_paint_t): ptr skc_paint_t
proc skc_paint_free*(paint: ptr skc_paint_t)
proc skc_paint_set_style*(paint: ptr skc_paint_t; style: PaintStyle)
proc skc_paint_get_style*(paint: ptr skc_paint_t): PaintStyle
proc skc_paint_set_color*(paint: ptr skc_paint_t; color: skc_color_t)
proc skc_paint_get_color*(paint: ptr skc_paint_t): skc_color_t
proc skc_paint_set_stroke_width*(paint: ptr skc_paint_t; width: cfloat)
proc skc_paint_get_stroke_width*(paint: ptr skc_paint_t): cfloat
proc skc_paint_set_stroke_miter*(paint: ptr skc_paint_t; miter: cfloat)
proc skc_paint_get_stroke_miter*(paint: ptr skc_paint_t): cfloat
proc skc_paint_set_stroke_cap*(paint: ptr skc_paint_t; cap: StrokeCap)
proc skc_paint_get_stroke_cap*(paint: ptr skc_paint_t): StrokeCap
proc skc_paint_set_stroke_join*(paint: ptr skc_paint_t; join: StrokeJoin)
proc skc_paint_get_stroke_join*(paint: ptr skc_paint_t): StrokeJoin
proc skc_paint_set_anti_alias*(paint: ptr skc_paint_t; antiAlias: bool)
proc skc_paint_get_anti_alias*(paint: ptr skc_paint_t): bool
proc skc_paint_set_blend_mode*(paint: ptr skc_paint_t; mode: BlendMode)
proc skc_paint_get_blend_mode*(paint: ptr skc_paint_t): BlendMode
proc skc_paint_set_dither*(paint: ptr skc_paint_t; dither: bool)
proc skc_paint_get_dither*(paint: ptr skc_paint_t): bool
proc skc_paint_set_shader*(paint: ptr skc_paint_t; shader: ptr skc_shader_t)
proc skc_paint_set_image_filter*(paint: ptr skc_paint_t; filter: ptr skc_image_filter_t)
proc skc_paint_set_path_effect*(paint: ptr skc_paint_t; effect: ptr skc_path_effect_t)
proc skc_paint_set_color_filter*(paint: ptr skc_paint_t; filter: ptr skc_color_filter_t)
proc skc_paint_reset*(paint: ptr skc_paint_t)

# ------------------------------------------------------------------
# Path
# ------------------------------------------------------------------

proc skc_path_new*(): ptr skc_path_t
proc skc_path_new_copy*(src: ptr skc_path_t): ptr skc_path_t
proc skc_path_free*(path: ptr skc_path_t)
proc skc_path_reset*(path: ptr skc_path_t)
proc skc_path_set_fill_type*(path: ptr skc_path_t; fillType: FillType)
proc skc_path_get_fill_type*(path: ptr skc_path_t): FillType
proc skc_path_move_to*(path: ptr skc_path_t; x, y: cfloat)
proc skc_path_line_to*(path: ptr skc_path_t; x, y: cfloat)
proc skc_path_quad_to*(path: ptr skc_path_t; x1, y1, x2, y2: cfloat)
proc skc_path_cubic_to*(path: ptr skc_path_t; x1, y1, x2, y2, x3, y3: cfloat)
proc skc_path_conic_to*(path: ptr skc_path_t; x1, y1, x2, y2, w: cfloat)
proc skc_path_close*(path: ptr skc_path_t)
proc skc_path_add_rect*(path: ptr skc_path_t; rect: ptr skc_rect_t; clockwise: bool)
proc skc_path_add_oval*(path: ptr skc_path_t; oval: ptr skc_rect_t; clockwise: bool)
proc skc_path_add_circle*(path: ptr skc_path_t; cx, cy, radius: cfloat; clockwise: bool)
proc skc_path_add_arc*(path: ptr skc_path_t; oval: ptr skc_rect_t; startAngleDeg, sweepAngleDeg: cfloat;
    forceMoveTo: bool)
proc skc_path_add_poly*(path: ptr skc_path_t; points: ptr skc_point_t; count: csize_t; isClosed: bool)
proc skc_path_transform*(path: ptr skc_path_t; matrix: ptr skc_matrix_t)
proc skc_path_is_empty*(path: ptr skc_path_t): bool
proc skc_path_is_finite*(path: ptr skc_path_t): bool
proc skc_path_count_verbs*(path: ptr skc_path_t): csize_t
proc skc_path_get_bounds*(path: ptr skc_path_t): skc_rect_t
proc skc_path_compute_tight_bounds*(path: ptr skc_path_t): skc_rect_t
proc skc_path_contains_point*(path: ptr skc_path_t; x, y: cfloat): bool

# ------------------------------------------------------------------
# Image
# ------------------------------------------------------------------

proc skc_image_new_from_encoded*(encoded: ptr skc_data_t): ptr skc_image_t
proc skc_image_new_from_pixmap_copy*(pixmap: ptr skc_pixmap_t): ptr skc_image_t
proc skc_image_new_from_pixels_copy*(info: ptr skc_imageinfo_t; pixels: pointer;
    rowBytes: csize_t; release: CReleaseProc; releaseCtx: pointer): ptr skc_image_t
proc skc_image_ref*(image: ptr skc_image_t): ptr skc_image_t
proc skc_image_unref*(image: ptr skc_image_t)
proc skc_image_width*(image: ptr skc_image_t): int32
proc skc_image_height*(image: ptr skc_image_t): int32
proc skc_image_get_color_type*(image: ptr skc_image_t): ColorType
proc skc_image_get_alpha_type*(image: ptr skc_image_t): AlphaType
proc skc_image_get_encoded_data*(image: ptr skc_image_t): ptr skc_data_t
proc skc_image_encode*(image: ptr skc_image_t; format: EncodedFormat; quality: cint): ptr skc_data_t
proc skc_image_read_pixels*(image: ptr skc_image_t; dstInfo: ptr skc_imageinfo_t; dstPixels: pointer;
    dstRowBytes: csize_t): bool
proc skc_image_new_pixmap_from_image*(image: ptr skc_image_t): ptr skc_pixmap_t

# ------------------------------------------------------------------
# Shaders
# ------------------------------------------------------------------

proc skc_shader_ref*(shader: ptr skc_shader_t): ptr skc_shader_t
proc skc_shader_unref*(shader: ptr skc_shader_t)
proc skc_shader_new_linear*(start, endPoint: skc_point_t; colors: ptr skc_color_t;
    positions: ptr cfloat; colorCount: csize_t; tileMode: TileMode;
    localMatrix: ptr skc_matrix_t): ptr skc_shader_t
proc skc_shader_new_radial*(cx, cy, radius: cfloat; colors: ptr skc_color_t;
    positions: ptr cfloat; colorCount: csize_t; tileMode: TileMode;
    localMatrix: ptr skc_matrix_t): ptr skc_shader_t
proc skc_shader_new_sweep*(cx, cy, startAngle, endAngle: cfloat; colors: ptr skc_color_t;
    positions: ptr cfloat; colorCount: csize_t; tileMode: TileMode;
    localMatrix: ptr skc_matrix_t): ptr skc_shader_t
proc skc_shader_new_two_point_conical*(startX, startY, startRadius, endX, endY, endRadius: cfloat;
    colors: ptr skc_color_t; positions: ptr cfloat; colorCount: csize_t; tileMode: TileMode;
    localMatrix: ptr skc_matrix_t): ptr skc_shader_t

# ------------------------------------------------------------------
# Filters and effects
# ------------------------------------------------------------------

proc skc_image_filter_ref*(filter: ptr skc_image_filter_t): ptr skc_image_filter_t
proc skc_image_filter_unref*(filter: ptr skc_image_filter_t)
proc skc_image_filter_new_blur*(sigmaX, sigmaY: cfloat; tileMode: TileMode): ptr skc_image_filter_t
proc skc_image_filter_new_color_filter*(input: ptr skc_color_filter_t): ptr skc_image_filter_t

proc skc_path_effect_ref*(effect: ptr skc_path_effect_t): ptr skc_path_effect_t
proc skc_path_effect_unref*(effect: ptr skc_path_effect_t)
proc skc_path_effect_new_dash*(intervals: ptr cfloat; count: csize_t; phase: cfloat): ptr skc_path_effect_t
proc skc_path_effect_new_corner*(radius: cfloat): ptr skc_path_effect_t
proc skc_path_effect_new_discrete*(segLength, dev: cfloat; seed: uint32): ptr skc_path_effect_t

proc skc_color_filter_ref*(filter: ptr skc_color_filter_t): ptr skc_color_filter_t
proc skc_color_filter_unref*(filter: ptr skc_color_filter_t)
proc skc_color_filter_new_matrix*(rowMajor: ptr cfloat): ptr skc_color_filter_t
proc skc_color_filter_new_table*(tableA: ptr uint8): ptr skc_color_filter_t

# ------------------------------------------------------------------
# Fonts
# ------------------------------------------------------------------

proc skc_font_manager_new*(): ptr skc_font_manager_t
proc skc_font_manager_unref*(mgr: ptr skc_font_manager_t)
proc skc_font_manager_get_family_count*(mgr: ptr skc_font_manager_t): cint
proc skc_font_manager_get_family_name*(mgr: ptr skc_font_manager_t; index: cint; buf: cstring;
    bufSize: csize_t): csize_t
proc skc_font_manager_default_typeface*(mgr: ptr skc_font_manager_t): ptr skc_typeface_t
proc skc_font_manager_match_family_style*(mgr: ptr skc_font_manager_t; family: cstring;
    style: skc_fontstyle_t): ptr skc_typeface_t
proc skc_font_manager_typeface_from_file*(mgr: ptr skc_font_manager_t; path: cstring;
    ttcIndex: cint): ptr skc_typeface_t

proc skc_typeface_ref*(typeface: ptr skc_typeface_t): ptr skc_typeface_t
proc skc_typeface_unref*(typeface: ptr skc_typeface_t)
proc skc_typeface_get_family_name*(typeface: ptr skc_typeface_t; buf: cstring;
    bufSize: csize_t): csize_t
proc skc_typeface_get_style*(typeface: ptr skc_typeface_t): skc_fontstyle_t
proc skc_typeface_is_bold*(typeface: ptr skc_typeface_t): bool
proc skc_typeface_is_italic*(typeface: ptr skc_typeface_t): bool

proc skc_font_new*(typeface: ptr skc_typeface_t; size: cfloat): ptr skc_font_t
proc skc_font_free*(font: ptr skc_font_t)
proc skc_font_get_size*(font: ptr skc_font_t): cfloat
proc skc_font_set_size*(font: ptr skc_font_t; size: cfloat)
proc skc_font_set_edging*(font: ptr skc_font_t; edging: FontEdging)
proc skc_font_set_hinting*(font: ptr skc_font_t; hinting: FontHinting)
proc skc_font_set_subpixel*(font: ptr skc_font_t; subpixel: bool)
proc skc_font_set_embolden*(font: ptr skc_font_t; embolden: bool)
proc skc_font_set_scale_x*(font: ptr skc_font_t; scaleX: cfloat)
proc skc_font_get_spacing*(font: ptr skc_font_t): cfloat
proc skc_font_get_metrics*(font: ptr skc_font_t; metrics: ptr skc_fontmetrics_t): bool
proc skc_font_measure_text*(font: ptr skc_font_t; text: cstring; length: csize_t;
    bounds: ptr skc_rect_t): cfloat
proc skc_font_get_ascent*(font: ptr skc_font_t): cfloat
proc skc_font_get_descent*(font: ptr skc_font_t): cfloat

# ------------------------------------------------------------------
# Text blobs
# ------------------------------------------------------------------

proc skc_text_blob_new*(text: cstring; length: csize_t;
    font: ptr skc_font_t): ptr skc_text_blob_t
proc skc_text_blob_unref*(blob: ptr skc_text_blob_t)
proc skc_text_blob_get_bounds*(blob: ptr skc_text_blob_t; bounds: ptr skc_rect_t)

{.pop.}
