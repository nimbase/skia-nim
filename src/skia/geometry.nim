## Geometry, colour and metadata value types for the Skia binding.
##
## These are Nim-native mirrors of the `skc_*` value structs from
## `skia_raw`. They are trivially copyable and safe to keep on the stack;
## nothing here owns any Skia resource.

import std/math

import ../bindings/skia_raw

export ColorType, AlphaType, ColorSpace, BlendMode, PaintStyle, StrokeCap, StrokeJoin,
  FillType, TileMode, FilterMode, MipmapMode, PointMode, FontEdging, FontHinting,
  EncodedFormat, FontWeight, FontWidth, FontSlant

export ColorTypeUnknown, ColorTypeAlpha8, ColorTypeRGB565, ColorTypeARGB4444,
  ColorTypeRGBA8888, ColorTypeRGB888x, ColorTypeBGRA8888, ColorTypeRGBA1010102,
  ColorTypeBGRA1010102, ColorTypeRGB101010x, ColorTypeBGR101010x, ColorTypeBGR101010xXR,
  ColorTypeBGRA10101010XR, ColorTypeRGBA10x6, ColorTypeGray8, ColorTypeRGBAF16Norm,
  ColorTypeRGBAF16, ColorTypeRGBF16F16F16x, ColorTypeRGBAF32, ColorTypeR8G8Unorm,
  ColorTypeA16Float, ColorTypeR16Float, ColorTypeR16G16Float, ColorTypeA16Unorm,
  ColorTypeR16Unorm, ColorTypeR16G16Unorm, ColorTypeR16G16B16A16Unorm, ColorTypeSRGBA8888,
  ColorTypeR8Unorm

export AlphaTypeUnknown, AlphaTypeOpaque, AlphaTypePremul, AlphaTypeUnpremul
export ColorSpaceSrgb, ColorSpaceLinearSrgb

export BlendModeClear, BlendModeSrc, BlendModeDst, BlendModeSrcOver, BlendModeDstOver,
  BlendModeSrcIn, BlendModeDstIn, BlendModeSrcOut, BlendModeDstOut, BlendModeSrcATop,
  BlendModeDstATop, BlendModeXor, BlendModePlus, BlendModeModulate, BlendModeScreen,
  BlendModeOverlay, BlendModeDarken, BlendModeLighten, BlendModeColorDodge, BlendModeColorBurn,
  BlendModeHardLight, BlendModeSoftLight, BlendModeDifference, BlendModeExclusion,
  BlendModeMultiply, BlendModeHue, BlendModeSaturation, BlendModeColor, BlendModeLuminosity

export PaintStyleFill, PaintStyleStroke, PaintStyleStrokeAndFill
export StrokeCapButt, StrokeCapRound, StrokeCapSquare
export StrokeJoinMiter, StrokeJoinRound, StrokeJoinBevel
export FillTypeWinding, FillTypeEvenOdd, FillTypeInverseWinding, FillTypeInverseEvenOdd
export TileModeClamp, TileModeRepeat, TileModeMirror, TileModeDecal
export FilterModeNearest, FilterModeLinear
export MipmapModeNone, MipmapModeNearest, MipmapModeLinear
export PointModePoints, PointModeLines, PointModePolygon
export EncodedFormatBmp, EncodedFormatGif, EncodedFormatIco, EncodedFormatJpeg,
  EncodedFormatPng, EncodedFormatWbmp, EncodedFormatWebp
export FontWeightInvisible, FontWeightThin, FontWeightExtraLight, FontWeightLight,
  FontWeightNormal, FontWeightMedium, FontWeightSemiBold, FontWeightBold,
  FontWeightExtraBold, FontWeightBlack, FontWeightExtraBlack
export FontWidthUltraCondensed, FontWidthExtraCondensed, FontWidthCondensed,
  FontWidthSemiCondensed, FontWidthNormal, FontWidthSemiExpanded, FontWidthExpanded,
  FontWidthExtraExpanded, FontWidthUltraExpanded
export FontSlantUpright, FontSlantItalic, FontSlantOblique

type
  Color* {.bycopy.} = object
    ## Unpremultiplied RGBA colour; components are normally in `[0, 1]`.
    r*, g*, b*, a*: float32

  Point* {.bycopy.} = object
    x*, y*: float32

  Rect* {.bycopy.} = object
    ## Half-open rectangle covering `[left, right)` by `[top, bottom)`.
    left*, top*, right*, bottom*: float32

  IRect* {.bycopy.} = object
    left*, top*, right*, bottom*: int32

  Matrix* {.bycopy.} = object
    ## Row-major 3x3 affine transform.
    m*: array[9, float32]

  ImageInfo* {.bycopy.} = object
    ## Pixel geometry and format of a bitmap-like surface.
    width*, height*: int32
    colorType*: ColorType
    alphaType*: AlphaType
    colorSpace*: ColorSpace

  FontStyle* {.bycopy.} = object
    weight*: FontWeight
    width*: FontWidth
    slant*: FontSlant

  FontMetrics* {.bycopy.} = object
    ascent*, descent*, leading*: float32
    top*, bottom*, xMin*, xMax*: float32

# ------------------------------------------------------------------
# Colour constructors
# ------------------------------------------------------------------

proc rgb*(r, g, b: float32): Color {.inline.} =
  ## Opaque colour from components in `[0, 1]`.
  Color(r: r, g: g, b: b, a: 1)

proc rgba*(r, g, b, a: float32): Color {.inline.} =
  Color(r: r, g: g, b: b, a: a)

proc colorArgb*(rgba: uint32): Color {.inline.} =
  ## Decodes a `0xAARRGGBB` value into unpremultiplied floats.
  Color(
    r: float32((rgba shr 16) and 0xFF) / 255.0,
    g: float32((rgba shr 8) and 0xFF) / 255.0,
    b: float32(rgba and 0xFF) / 255.0,
    a: float32((rgba shr 24) and 0xFF) / 255.0
  )

proc toUint32*(c: Color): uint32 {.inline.} =
  ## Rounds this colour back to `0xAARRGGBB`.
  proc q(x: float32): uint32 =
    uint32(int(clamp(round(x * 255.0), 0.0, 255.0)))
  (q(c.a) shl 24) or (q(c.r) shl 16) or (q(c.g) shl 8) or q(c.b)

const
  ColorTransparent* = Color(r: 0, g: 0, b: 0, a: 0)
  ColorBlack* = Color(r: 0, g: 0, b: 0, a: 1)
  ColorWhite* = Color(r: 1, g: 1, b: 1, a: 1)
  ColorRed* = Color(r: 1, g: 0, b: 0, a: 1)
  ColorGreen* = Color(r: 0, g: 1, b: 0, a: 1)
  ColorBlue* = Color(r: 0, g: 0, b: 1, a: 1)
  ColorYellow* = Color(r: 1, g: 1, b: 0, a: 1)
  ColorCyan* = Color(r: 0, g: 1, b: 1, a: 1)
  ColorMagenta* = Color(r: 1, g: 0, b: 1, a: 1)
  ColorGray* = Color(r: 0.5, g: 0.5, b: 0.5, a: 1)

# ------------------------------------------------------------------
# Point / Rect
# ------------------------------------------------------------------

proc point*(x, y: float32): Point {.inline.} = Point(x: x, y: y)

proc rectLTRB*(left, top, right, bottom: float32): Rect {.inline.} =
  Rect(left: left, top: top, right: right, bottom: bottom)

proc rect*(width, height: float32): Rect {.inline.} =
  ## Rectangle with its origin at `(0, 0)`.
  Rect(left: 0, top: 0, right: width, bottom: height)

proc rectXY*(x, y, width, height: float32): Rect {.inline.} =
  Rect(left: x, top: y, right: x + width, bottom: y + height)

proc width*(r: Rect): float32 {.inline.} = r.right - r.left
proc height*(r: Rect): float32 {.inline.} = r.bottom - r.top
proc isEmpty*(r: Rect): bool {.inline.} =
  r.right <= r.left or r.bottom <= r.top

proc center*(r: Rect): Point {.inline.} =
  Point(x: (r.left + r.right) / 2, y: (r.top + r.bottom) / 2)

proc width*(r: IRect): int32 {.inline.} = r.right - r.left
proc height*(r: IRect): int32 {.inline.} = r.bottom - r.top

proc irect*(left, top, right, bottom: int32): IRect {.inline.} =
  IRect(left: left, top: top, right: right, bottom: bottom)

# ------------------------------------------------------------------
# Matrix
# ------------------------------------------------------------------

proc identityMatrix*(): Matrix {.inline.} =
  Matrix(m: [1, 0, 0, 0, 1, 0, 0, 0, 1])

proc translation*(dx, dy: float32): Matrix {.inline.} =
  Matrix(m: [1, 0, dx, 0, 1, dy, 0, 0, 1])

proc scaling*(sx, sy: float32): Matrix {.inline.} =
  Matrix(m: [sx, 0, 0, 0, sy, 0, 0, 0, 1])

proc rotation*(degrees: float32): Matrix {.inline.} =
  let r = degrees * PI / 180.0
  let c = cos(r).float32
  let s = sin(r).float32
  Matrix(m: [c, -s, 0, s, c, 0, 0, 0, 1])

proc concat*(a, b: Matrix): Matrix {.inline.} =
  ## Returns `a * b`, i.e. apply ``b`` first and then ``a``.
  result.m = [
    a.m[0] * b.m[0] + a.m[1] * b.m[3], a.m[0] * b.m[1] + a.m[1] * b.m[4],
    a.m[0] * b.m[2] + a.m[1] * b.m[5] + a.m[2],
    a.m[3] * b.m[0] + a.m[4] * b.m[3], a.m[3] * b.m[1] + a.m[4] * b.m[4],
    a.m[3] * b.m[2] + a.m[4] * b.m[5] + a.m[5],
    a.m[6] * b.m[0] + a.m[7] * b.m[3] + a.m[8] * b.m[2],
    a.m[6] * b.m[1] + a.m[7] * b.m[4] + a.m[8] * b.m[5],
    a.m[6] * b.m[2] + a.m[7] * b.m[5] + a.m[8]
  ]

proc `*`*(a, b: Matrix): Matrix {.inline.} = concat(a, b)

proc translate*(m: Matrix; dx, dy: float32): Matrix {.inline.} =
  concat(translation(dx, dy), m)

proc scale*(m: Matrix; sx, sy: float32): Matrix {.inline.} =
  concat(scaling(sx, sy), m)

proc rotate*(m: Matrix; degrees: float32): Matrix {.inline.} =
  concat(rotation(degrees), m)

proc mapRect*(m: Matrix; r: Rect): Rect {.inline.} =
  ## Transforms the four corners and returns their bounding box.
  let corners = [
    Point(x: r.left, y: r.top), Point(x: r.right, y: r.top),
    Point(x: r.left, y: r.bottom), Point(x: r.right, y: r.bottom)
  ]
  var lo = Inf.float32
  var hi = -Inf.float32
  var lo2 = Inf.float32
  var hi2 = -Inf.float32
  for c in corners:
    let x = m.m[0] * c.x + m.m[1] * c.y + m.m[2]
    let y = m.m[3] * c.x + m.m[4] * c.y + m.m[5]
    if x < lo: lo = x
    if x > hi: hi = x
    if y < lo2: lo2 = y
    if y > hi2: hi2 = y
  Rect(left: lo, top: lo2, right: hi, bottom: hi2)

# ------------------------------------------------------------------
# ImageInfo
# ------------------------------------------------------------------

proc imageInfo*(width, height: int32; colorType = ColorTypeRGBA8888;
    alphaType = AlphaTypePremul; colorSpace = ColorSpaceSrgb): ImageInfo {.inline.} =
  ImageInfo(
    width: width, height: height, colorType: colorType,
    alphaType: alphaType, colorSpace: colorSpace
  )

proc bytesPerPixel*(i: ImageInfo): int {.inline.} =
  ## Bytes per pixel for the common 8-bit-per-channel formats; 0 otherwise.
  case i.colorType
  of ColorTypeAlpha8, ColorTypeGray8, ColorTypeR8Unorm: 1
  of ColorTypeRGB565, ColorTypeARGB4444, ColorTypeRGBA10x6: 2
  of ColorTypeRGBA8888, ColorTypeBGRA8888, ColorTypeRGB888x, ColorTypeSRGBA8888: 4
  else: 0

# ------------------------------------------------------------------
# FontStyle / FontMetrics
# ------------------------------------------------------------------

proc fontStyle*(weight = FontWeightNormal; width = FontWidthNormal;
    slant = FontSlantUpright): FontStyle {.inline.} =
  FontStyle(weight: weight, width: width, slant: slant)

proc `==`*(a, b: FontStyle): bool =
  a.weight == b.weight and a.width == b.width and a.slant == b.slant

# ------------------------------------------------------------------
# Conversions to and from the raw C structs
# ------------------------------------------------------------------

proc toRaw*(c: Color): skc_color_t {.inline.} =
  skc_color_t(r: c.r.cfloat, g: c.g.cfloat, b: c.b.cfloat, a: c.a.cfloat)

proc fromRaw*(c: skc_color_t): Color {.inline.} =
  Color(r: c.r.float32, g: c.g.float32, b: c.b.float32, a: c.a.float32)

proc toRaw*(p: Point): skc_point_t {.inline.} =
  skc_point_t(x: p.x.cfloat, y: p.y.cfloat)

proc fromRaw*(p: skc_point_t): Point {.inline.} =
  Point(x: p.x.float32, y: p.y.float32)

proc toRaw*(r: Rect): skc_rect_t {.inline.} =
  skc_rect_t(
    left: r.left.cfloat, top: r.top.cfloat,
    right: r.right.cfloat, bottom: r.bottom.cfloat
  )

proc fromRaw*(r: skc_rect_t): Rect {.inline.} =
  Rect(
    left: r.left.float32, top: r.top.float32,
    right: r.right.float32, bottom: r.bottom.float32
  )

proc toRaw*(r: IRect): skc_irect_t {.inline.} =
  skc_irect_t(
    left: r.left.int32, top: r.top.int32,
    right: r.right.int32, bottom: r.bottom.int32
  )

proc fromRaw*(r: skc_irect_t): IRect {.inline.} =
  IRect(
    left: r.left.int32, top: r.top.int32,
    right: r.right.int32, bottom: r.bottom.int32
  )

proc toRaw*(m: Matrix): skc_matrix_t {.inline.} =
  result.m = [m.m[0].cfloat, m.m[1].cfloat, m.m[2].cfloat, m.m[3].cfloat, m.m[4].cfloat,
    m.m[5].cfloat, m.m[6].cfloat, m.m[7].cfloat, m.m[8].cfloat]

proc fromRaw*(m: skc_matrix_t): Matrix {.inline.} =
  result.m = [m.m[0].float32, m.m[1].float32, m.m[2].float32, m.m[3].float32, m.m[4].float32,
    m.m[5].float32, m.m[6].float32, m.m[7].float32, m.m[8].float32]

proc toRaw*(i: ImageInfo): skc_imageinfo_t {.inline.} =
  skc_imageinfo_t(
    width: i.width.int32, height: i.height.int32,
    colorType: i.colorType, alphaType: i.alphaType, colorSpace: i.colorSpace
  )

proc fromRaw*(i: skc_imageinfo_t): ImageInfo {.inline.} =
  ImageInfo(
    width: i.width.int32, height: i.height.int32,
    colorType: i.colorType, alphaType: i.alphaType, colorSpace: i.colorSpace
  )

proc toRaw*(s: FontStyle): skc_fontstyle_t {.inline.} =
  skc_fontstyle_t(weight: s.weight.int32, width: s.width.int32, slant: s.slant)

proc fromRaw*(s: skc_fontstyle_t): FontStyle {.inline.} =
  FontStyle(weight: FontWeight(s.weight), width: FontWidth(s.width), slant: s.slant)

proc fromRaw*(m: skc_fontmetrics_t): FontMetrics {.inline.} =
  FontMetrics(
    ascent: m.ascent.float32, descent: m.descent.float32, leading: m.leading.float32,
    top: m.top.float32, bottom: m.bottom.float32,
    xMin: m.xMin.float32, xMax: m.xMax.float32
  )

# ------------------------------------------------------------------
# Readable names for the enum-like values
#
# Error messages and `echo` output are far more useful with a symbolic
# name than a bare integer, and these also make the values easy to inspect
# in a debugger.
# ------------------------------------------------------------------

proc nameTable*[T](names: auto): proc(v: T): string =
  ## Builds a lookup from value to symbolic name. A fixed-size array is
  ## required so the closure captures only a constant.
  const n = names.len
  proc lookup(v: T): string =
    let i = int(cint(v))
    if i >= 0 and i < n and names[i].len > 0: names[i] else: $i
  lookup

const
  blendModeNames = [
    "clear", "src", "dst", "srcOver", "dstOver", "srcIn", "dstIn", "srcOut", "dstOut",
    "srcATop", "dstATop", "xor", "plus", "modulate", "screen", "overlay", "darken",
    "lighten", "colorDodge", "colorBurn", "hardLight", "softLight", "difference",
    "exclusion", "multiply", "hue", "saturation", "color", "luminosity"
  ]
  colorTypeNames = [
    "unknown", "alpha8", "rgb565", "argb4444", "rgba8888", "rgb888x", "bgra8888",
    "rgba1010102", "bgra1010102", "rgb101010x", "bgr101010x", "bgr101010xXR",
    "bgra10101010XR", "rgba10x6", "gray8", "rgbaF16Norm", "rgbaF16", "rgbF16F16F16x",
    "rgbaF32", "r8G8Unorm", "a16Float", "r16Float", "r16G16Float", "a16Unorm", "r16Unorm",
    "r16G16Unorm", "r16G16B16A16Unorm", "srgba8888", "r8Unorm"
  ]
  alphaTypeNames = ["unknown", "opaque", "premul", "unpremul"]
  colorSpaceNames = ["srgb", "displayP3", "linearSrgb"]
  paintStyleNames = ["fill", "stroke", "strokeAndFill"]
  strokeCapNames = ["butt", "round", "square"]
  strokeJoinNames = ["miter", "round", "bevel"]
  fillTypeNames = ["winding", "evenOdd", "inverseWinding", "inverseEvenOdd"]
  tileModeNames = ["clamp", "repeat", "mirror", "decal"]
  filterModeNames = ["nearest", "linear"]
  mipmapModeNames = ["none", "nearest", "linear"]
  pointModeNames = ["points", "lines", "polygon"]
  fontEdgingNames = ["alias", "antiAlias", "subpixelAntiAlias"]
  fontHintingNames = ["none", "slight", "normal", "full"]
  encodedFormatNames = ["bmp", "gif", "ico", "jpeg", "png", "wbmp", "webp"]

let
  blendModeName = nameTable[BlendMode](blendModeNames)
  colorTypeName = nameTable[ColorType](colorTypeNames)
  alphaTypeName = nameTable[AlphaType](alphaTypeNames)
  colorSpaceName = nameTable[ColorSpace](colorSpaceNames)
  paintStyleName = nameTable[PaintStyle](paintStyleNames)
  strokeCapName = nameTable[StrokeCap](strokeCapNames)
  strokeJoinName = nameTable[StrokeJoin](strokeJoinNames)
  fillTypeName = nameTable[FillType](fillTypeNames)
  tileModeName = nameTable[TileMode](tileModeNames)
  filterModeName = nameTable[FilterMode](filterModeNames)
  mipmapModeName = nameTable[MipmapMode](mipmapModeNames)
  pointModeName = nameTable[PointMode](pointModeNames)
  fontEdgingName = nameTable[FontEdging](fontEdgingNames)
  fontHintingName = nameTable[FontHinting](fontHintingNames)
  encodedFormatName = nameTable[EncodedFormat](encodedFormatNames)

proc `$`*(x: BlendMode): string = blendModeName(x)
proc `$`*(x: ColorType): string = colorTypeName(x)
proc `$`*(x: AlphaType): string = alphaTypeName(x)
proc `$`*(x: ColorSpace): string = colorSpaceName(x)
proc `$`*(x: PaintStyle): string = paintStyleName(x)
proc `$`*(x: StrokeCap): string = strokeCapName(x)
proc `$`*(x: StrokeJoin): string = strokeJoinName(x)
proc `$`*(x: FillType): string = fillTypeName(x)
proc `$`*(x: TileMode): string = tileModeName(x)
proc `$`*(x: FilterMode): string = filterModeName(x)
proc `$`*(x: MipmapMode): string = mipmapModeName(x)
proc `$`*(x: PointMode): string = pointModeName(x)
proc `$`*(x: FontEdging): string = fontEdgingName(x)
proc `$`*(x: FontHinting): string = fontHintingName(x)
proc `$`*(x: EncodedFormat): string = encodedFormatName(x)
proc `$`*(x: FontWeight): string = $int(x)
proc `$`*(x: FontWidth): string = $int(x)
proc `$`*(x: FontSlant): string =
  case x
  of FontSlantUpright: "upright"
  of FontSlantItalic: "italic"
  of FontSlantOblique: "oblique"
  else: $int(x)
