## Owning wrappers around the Skia objects exposed by `skia_raw`.
##
## Three ownership flavours are used, each matching how Skia itself treats the
## object:
##
## * **Shared** (`Data`, `Image`, `Shader`, `ImageFilter`, `PathEffect`,
##   `ColorFilter`, `Typeface`, `TextBlob`, `FontManager`, `Font`, `Surface`)
##   are backed by reference-counted Skia objects. Copying a handle is cheap
##   and every copy refers to the same underlying object, so mutating one
##   (for example `Font.setSize`) is visible through all of them.
##
## * **Value** (`Paint`, `Path`, `Pixmap`) mirror Skia value types. Copying
##   performs a real deep copy, so copies are fully independent.
##
## * **View** (`Canvas`) borrows from the `Surface` that produced it and holds
##   a reference to that surface, so it can never outlive it.
##
## Every function that can fail on the C side raises `ValueError` or
## `IOError` rather than returning a sentinel.

import ../bindings/skia_raw
import geometry

export geometry

# ------------------------------------------------------------------
# Error helpers
# ------------------------------------------------------------------

proc raiseSkia(context: string) {.noreturn.} =
  let detail = skc_last_error()
  var msg = context
  if not detail.isNil:
    msg.add ": "
    msg.add $detail
  raise newException(IOError, msg)

proc check(p: pointer; context: string) =
  ## Raises unless `p` is non-NULL, quoting the C-side error text.
  if p == nil:
    raiseSkia(context)

proc checkBool(ok: bool; context: string) =
  if not ok:
    raiseSkia(context)

# ------------------------------------------------------------------
# Shared (reference-counted) resources
# ------------------------------------------------------------------

template sharedResource(Name, handleType, unrefProc) =
  type
    Name* = object
      ## Reference-counted Skia object. Copies share the same underlying
      ## resource and are released together.
      raw: ptr handleType
      rc: ptr int

  proc `=destroy`*(x: var Name) =
    if x.raw != nil:
      if x.rc[] == 0:
        unrefProc(x.raw)
        dealloc(x.rc)
      else:
        dec x.rc[]

  proc `=wasMoved`*(x: var Name) =
    x.raw = nil
    x.rc = nil

  proc `=sink`*(dest: var Name; src: Name) =
    `=destroy`(dest)
    dest.raw = src.raw
    dest.rc = src.rc

  proc `=copy`*(dest: var Name; src: Name) =
    if src.raw != nil: inc src.rc[]
    `=destroy`(dest)
    dest.raw = src.raw
    dest.rc = src.rc

  proc `=dup`*(src: Name): Name =
    ## Field-by-field on purpose: `result = src` would recurse into `=copy`.
    result.raw = src.raw
    result.rc = src.rc
    if result.raw != nil: inc result.rc[]

  proc initShared*(d: var Name; raw: ptr handleType) {.raises: [].} =
    ## Takes ownership of one reference to `raw`.
    d.raw = raw
    d.rc = cast[ptr int](alloc0(sizeof(int)))

# ------------------------------------------------------------------
# Value resources (deep-copying)
# ------------------------------------------------------------------

template valueResource(Name, handleType, freeProc, copyProc, name) =
  type
    Name* = object
      ## Skia value type. Copying deep-copies, so copies are independent.
      raw: ptr handleType

  proc `=destroy`*(x: var Name) =
    if x.raw != nil: freeProc(x.raw)

  proc `=wasMoved`*(x: var Name) =
    x.raw = nil

  proc `=copy`*(dest: var Name; src: Name) =
    if src.raw == nil:
      dest.raw = nil
    else:
      dest.raw = copyProc(src.raw)
      if dest.raw == nil: raiseSkia("copying " & name & " failed")

  proc `=dup`*(src: Name): Name =
    result.raw = nil
    `=copy`(result, src)

# ------------------------------------------------------------------
# Data
# ------------------------------------------------------------------

sharedResource(Data, skc_data_t, skc_data_unref)

proc newData*(bytes: openArray[byte]): Data =
  ## Copies `bytes` into a new buffer.
  if bytes.len == 0:
    return Data(raw: skc_data_new_null())
  result.initShared(skc_data_new(unsafeAddr bytes[0], csize_t bytes.len))
  check(result.raw, "newData")

proc newData*(s: string): Data =
  ## Copies the bytes of `s` into a new buffer.
  if s.len == 0:
    return Data(raw: skc_data_new_null())
  result.initShared(skc_data_new(unsafeAddr s[0], csize_t s.len))
  check(result.raw, "newData")

proc size*(d: Data): int {.inline.} = int(skc_data_size(d.raw))
proc isEmpty*(d: Data): bool {.inline.} = d.size == 0

proc toSeq*(d: Data): seq[byte] =
  ## Copies the buffer contents into a new Nim sequence.
  result = newSeq[byte](d.size)
  if d.size > 0:
    copyMem(addr result[0], skc_data_data(d.raw), d.size)

proc toString*(d: Data): string =
  result = newString(d.size)
  if d.size > 0:
    copyMem(addr result[0], skc_data_data(d.raw), d.size)

# ------------------------------------------------------------------
# Pixmap
# ------------------------------------------------------------------

proc pixmapCopy(src: ptr skc_pixmap_t): ptr skc_pixmap_t =
  let info = skc_pixmap_image_info(src)
  if info == nil: return nil
  var dup = info[]
  skc_pixmap_new(addr dup, skc_pixmap_pixels(src), skc_pixmap_row_bytes(src))

proc pixmapFree(p: ptr skc_pixmap_t) = skc_pixmap_free(p)

valueResource(Pixmap, skc_pixmap_t, pixmapFree, pixmapCopy, "Pixmap")

proc newPixmap*(info: ImageInfo; pixels: pointer; rowBytes: int): Pixmap =
  var raw = toRaw(info)
  result.raw = skc_pixmap_new(addr raw, pixels, csize_t rowBytes)
  check(result.raw, "newPixmap")

proc width*(p: Pixmap): int32 {.inline.} = skc_pixmap_width(p.raw)
proc height*(p: Pixmap): int32 {.inline.} = skc_pixmap_height(p.raw)
proc rowBytes*(p: Pixmap): int {.inline.} = int(skc_pixmap_row_bytes(p.raw))
proc imageInfo*(p: Pixmap): ImageInfo {.inline.} = fromRaw(skc_pixmap_image_info(p.raw)[])
proc pixels*(p: Pixmap): pointer {.inline.} = skc_pixmap_pixels(p.raw)

proc toSeq*(p: Pixmap): seq[byte] =
  ## Copies the referenced pixels into a new Nim sequence.
  let n = int(p.width) * int(p.height) * int(p.imageInfo.bytesPerPixel)
  result = newSeq[byte](n)
  if n > 0:
    copyMem(addr result[0], p.pixels, n)

# ------------------------------------------------------------------
# Surface
# ------------------------------------------------------------------

sharedResource(Surface, skc_surface_t, skc_surface_unref)

proc newSurface*(info: ImageInfo): Surface =
  ## Allocates a CPU raster surface.
  var raw = toRaw(info)
  result.initShared(skc_surface_new_raster(addr raw))
  check(result.raw, "newSurface(" & $info.width & "x" & $info.height & ")")

proc newSurface*(width, height: int32; colorType = ColorTypeRGBA8888;
    alphaType = AlphaTypePremul; colorSpace = ColorSpaceSrgb): Surface =
  newSurface(imageInfo(width, height, colorType, alphaType, colorSpace))

proc newRgbaSurface*(width, height: int32): Surface =
  ## An sRGB surface with premultiplied 8-bit alpha.
  newSurface(width, height, ColorTypeRGBA8888, AlphaTypePremul)

proc newOpaqueSurface*(width, height: int32): Surface =
  ## An sRGB surface with no alpha channel; slightly faster to draw into.
  newSurface(width, height, ColorTypeRGBA8888, AlphaTypeOpaque)

proc width*(s: Surface): int32 {.inline.} = skc_surface_width(s.raw)
proc height*(s: Surface): int32 {.inline.} = skc_surface_height(s.raw)
proc size*(s: Surface): (int32, int32) {.inline.} = (s.width, s.height)

proc flush*(s: Surface) {.inline.} = skc_surface_flush(s.raw)

proc rasterPixels*(s: Surface): Pixmap =
  ## A non-owning view of the surface's pixels. Valid while the surface is.
  result.raw = skc_surface_peek_pixels(s.raw)
  check(result.raw, "rasterPixels")
proc imageInfo*(s: Surface): ImageInfo =
  ## The surface's actual pixel format.
  let pm = s.rasterPixels()
  pm.imageInfo()

proc readPixels*(s: Surface): seq[byte] =
  ## Copies the surface contents into a new Nim sequence, in the surface's
  ## own pixel format.
  let info = s.imageInfo()
  let bpp = info.bytesPerPixel
  if bpp == 0:
    raise newException(ValueError, "unsupported colour type for readPixels")
  result = newSeq[byte](int(s.width) * int(s.height) * bpp)
  var raw = toRaw(info)
  checkBool(skc_surface_read_pixels(s.raw, addr raw, addr result[0],
    csize_t(int(s.width) * bpp)), "readPixels")

# ------------------------------------------------------------------
# Image
# ------------------------------------------------------------------

sharedResource(Image, skc_image_t, skc_image_unref)

proc decodeImage*(data: Data): Image =
  ## Decodes PNG, JPEG or WebP data, depending on what Skia was built with.
  result.initShared(skc_image_new_from_encoded(data.raw))
  check(result.raw, "decodeImage")

proc newImage*(pixels: openArray[byte]; width, height: int32;
    colorType = ColorTypeRGBA8888; alphaType = AlphaTypePremul;
    colorSpace = ColorSpaceSrgb): Image =
  ## Wraps a copy of `pixels` as an image.
  let info = imageInfo(width, height, colorType, alphaType, colorSpace)
  let bpp = info.bytesPerPixel
  if bpp == 0:
    raise newException(ValueError, "unsupported colour type")
  let expected = int(width) * int(height) * bpp
  if pixels.len != expected:
    raise newException(ValueError,
      "expected " & $expected & " bytes for " & $width & "x" & $height &
      " but got " & $pixels.len)
  var raw = toRaw(info)
  result.initShared(skc_image_new_from_pixels_copy(
    addr raw, cast[pointer](unsafeAddr pixels[0]), csize_t(int(width) * bpp), nil, nil))
  check(result.raw, "newImage")

proc decodeImage*(bytes: openArray[byte]): Image =
  decodeImage(newData(bytes))

proc snapshot*(s: Surface): Image =
  ## An immutable copy of the current contents.
  result.initShared(skc_surface_make_image_snapshot(s.raw))
  check(result.raw, "snapshot")

proc width*(i: Image): int32 {.inline.} = skc_image_width(i.raw)
proc height*(i: Image): int32 {.inline.} = skc_image_height(i.raw)
proc colorType*(i: Image): ColorType {.inline.} = skc_image_get_color_type(i.raw)
proc alphaType*(i: Image): AlphaType {.inline.} = skc_image_get_alpha_type(i.raw)

proc encodeImage*(i: Image; format: EncodedFormat; quality = 100): Data =
  ## Encodes the image. `quality` applies to JPEG only and is ignored for PNG.
  case format
  of EncodedFormatPng, EncodedFormatJpeg: discard
  else:
    raise newException(ValueError,
      "only PNG and JPEG encoding is supported by this build, got " & $format)
  result.initShared(skc_image_encode(i.raw, format, quality.cint))
  check(result.raw, "encodeImage")

proc encodePng*(i: Image): Data {.inline.} =
  encodeImage(i, EncodedFormatPng)

proc encodeJpeg*(i: Image; quality = 90): Data {.inline.} =
  encodeImage(i, EncodedFormatJpeg, quality)

proc encodedData*(i: Image): Data =
  ## The original encoded bytes, if the image came from an encoded stream.
  result.initShared(skc_image_get_encoded_data(i.raw))
  if result.raw == nil:
    raise newException(IOError, "this image was not decoded from encoded data")

proc toPixmap*(i: Image): Pixmap =
  ## A non-owning view of the image's pixels, in the image's own format.
  result.raw = skc_image_new_pixmap_from_image(i.raw)
  check(result.raw, "toPixmap")

proc imageInfo*(i: Image): ImageInfo =
  ## The image's pixel format.
  toPixmap(i).imageInfo()

proc toSeq*(i: Image): seq[byte] =
  ## Copies the pixels out in the image's own format, which is not always
  ## RGBA. Prefer ``toRgba`` unless you specifically need the native layout.
  toPixmap(i).toSeq()

proc toRgba*(i: Image): seq[byte] =
  ## Copies the pixels out as tightly packed `0xAARRGGBB`-order RGBA8888,
  ## converting colour type and alpha type as needed. Four bytes per pixel,
  ## regardless of how the image is stored.
  let w = int(i.width)
  let h = int(i.height)
  result = newSeq[byte](w * h * 4)
  var raw = toRaw(imageInfo(i.width, i.height))
  checkBool(skc_image_read_pixels(i.raw, addr raw, addr result[0], csize_t(w * 4)),
    "toRgba")

proc savePng*(i: Image; path: string) =
  ## Writes a PNG file. Raises `IOError` if the write fails.
  let data = i.encodePng()
  try:
    writeFile(path, data.toString())
  except IOError as e:
    raise newException(IOError, "savePng(" & path & "): " & e.msg)

# ------------------------------------------------------------------
# Shader
# ------------------------------------------------------------------

sharedResource(Shader, skc_shader_t, skc_shader_unref)

proc rawColors(colors: openArray[Color]): seq[skc_color_t] =
  if colors.len == 0:
    raise newException(ValueError, "a gradient needs at least one colour")
  result = newSeq[skc_color_t](colors.len)
  for i, c in colors: result[i] = toRaw(c)

proc rawPositions(positions: openArray[float32]; colorCount: int): seq[cfloat] =
  ## Empty when there are no explicit stops, which means "spread evenly".
  if positions.len == 0: return @[]
  if positions.len != colorCount:
    raise newException(ValueError,
      "expected " & $colorCount & " positions to match the colours, got " &
      $positions.len)
  result = newSeq[cfloat](positions.len)
  for i, p in positions: result[i] = p.cfloat

proc linearGradient*(start, finish: Point; colors: openArray[Color];
    positions: openArray[float32] = []; tileMode = TileModeClamp;
    localMatrix: ptr Matrix = nil): Shader =
  ## A two-point linear gradient.
  let cs = rawColors(colors)
  let ps = rawPositions(positions, colors.len)
  var lm: skc_matrix_t
  let lmPtr = if localMatrix.isNil: nil else: (lm = toRaw(localMatrix[]); addr lm)
  result.initShared(skc_shader_new_linear(toRaw(start), toRaw(finish), addr cs[0],
    if ps.len > 0: addr ps[0] else: nil, csize_t cs.len, tileMode, lmPtr))
  check(result.raw, "linearGradient")

proc radialGradient*(center: Point; radius: float32; colors: openArray[Color];
    positions: openArray[float32] = []; tileMode = TileModeClamp;
    localMatrix: ptr Matrix = nil): Shader =
  ## A radial gradient fading out at `radius`.
  let cs = rawColors(colors)
  let ps = rawPositions(positions, colors.len)
  var lm: skc_matrix_t
  let lmPtr = if localMatrix.isNil: nil else: (lm = toRaw(localMatrix[]); addr lm)
  result.initShared(skc_shader_new_radial(center.x.cfloat, center.y.cfloat,
    radius.cfloat, addr cs[0], if ps.len > 0: addr ps[0] else: nil,
    csize_t cs.len, tileMode, lmPtr))
  check(result.raw, "radialGradient")

proc sweepGradient*(center: Point; startAngle, endAngle: float32;
    colors: openArray[Color]; positions: openArray[float32] = [];
    tileMode = TileModeClamp; localMatrix: ptr Matrix = nil): Shader =
  ## A conic gradient sweeping from `startAngle` to `endAngle` degrees.
  let cs = rawColors(colors)
  let ps = rawPositions(positions, colors.len)
  var lm: skc_matrix_t
  let lmPtr = if localMatrix.isNil: nil else: (lm = toRaw(localMatrix[]); addr lm)
  result.initShared(skc_shader_new_sweep(center.x.cfloat, center.y.cfloat,
    startAngle.cfloat, endAngle.cfloat, addr cs[0], if ps.len > 0: addr ps[0] else: nil,
    csize_t cs.len, tileMode, lmPtr))
  check(result.raw, "sweepGradient")

# ------------------------------------------------------------------
# Image filter
# ------------------------------------------------------------------

sharedResource(ImageFilter, skc_image_filter_t, skc_image_filter_unref)

proc blur*(sigmaX, sigmaY: float32; tileMode = TileModeDecal): ImageFilter =
  ## A Gaussian blur. A `sigma` of 0 disables blurring on that axis.
  result.initShared(skc_image_filter_new_blur(sigmaX.cfloat, sigmaY.cfloat, tileMode))
  check(result.raw, "blur")

# ------------------------------------------------------------------
# Path effect
# ------------------------------------------------------------------

sharedResource(PathEffect, skc_path_effect_t, skc_path_effect_unref)

proc dashEffect*(intervals: openArray[float32]; phase = 0.0'f32): PathEffect =
  ## Alternating on/off dash lengths.
  if intervals.len == 0:
    raise newException(ValueError, "dashEffect needs at least one interval")
  var storage = newSeq[cfloat](intervals.len)
  for i, v in intervals: storage[i] = v.cfloat
  result.initShared(skc_path_effect_new_dash(addr storage[0], csize_t storage.len,
    phase.cfloat))
  check(result.raw, "dashEffect")

proc cornerEffect*(radius: float32): PathEffect =
  ## Rounds off sharp corners.
  result.initShared(skc_path_effect_new_corner(radius.cfloat))
  check(result.raw, "cornerEffect")

# ------------------------------------------------------------------
# Colour filter
# ------------------------------------------------------------------

sharedResource(ColorFilter, skc_color_filter_t, skc_color_filter_unref)

proc colorMatrix*(rowMajor: array[20, float32]): ColorFilter =
  ## A 4x5 colour transform in row-major order.
  var storage: array[20, cfloat]
  for i in 0 ..< 20: storage[i] = rowMajor[i].cfloat
  result.initShared(skc_color_filter_new_matrix(addr storage[0]))
  check(result.raw, "colorMatrix")

# ------------------------------------------------------------------
# Paint
# ------------------------------------------------------------------

proc paintCopy(src: ptr skc_paint_t): ptr skc_paint_t = skc_paint_new_copy(src)
proc paintFree(p: ptr skc_paint_t) = skc_paint_free(p)

valueResource(Paint, skc_paint_t, paintFree, paintCopy, "Paint")

proc newPaint*(): Paint =
  result.raw = skc_paint_new()
  check(result.raw, "newPaint")

proc setColor*(p: var Paint; c: Color) {.inline.} =
  skc_paint_set_color(p.raw, toRaw(c))
proc color*(p: Paint): Color {.inline.} = fromRaw(skc_paint_get_color(p.raw))

proc setStyle*(p: var Paint; s: PaintStyle) {.inline.} =
  skc_paint_set_style(p.raw, s)
proc style*(p: Paint): PaintStyle {.inline.} = skc_paint_get_style(p.raw)

proc setStrokeWidth*(p: var Paint; w: float32) {.inline.} =
  skc_paint_set_stroke_width(p.raw, w.cfloat)
proc strokeWidth*(p: Paint): float32 {.inline.} = skc_paint_get_stroke_width(p.raw).float32

proc setStrokeMiter*(p: var Paint; m: float32) {.inline.} =
  skc_paint_set_stroke_miter(p.raw, m.cfloat)
proc strokeMiter*(p: Paint): float32 {.inline.} = skc_paint_get_stroke_miter(p.raw).float32

proc setStrokeCap*(p: var Paint; c: StrokeCap) {.inline.} =
  skc_paint_set_stroke_cap(p.raw, c)
proc strokeCap*(p: Paint): StrokeCap {.inline.} = skc_paint_get_stroke_cap(p.raw)

proc setStrokeJoin*(p: var Paint; j: StrokeJoin) {.inline.} =
  skc_paint_set_stroke_join(p.raw, j)
proc strokeJoin*(p: Paint): StrokeJoin {.inline.} = skc_paint_get_stroke_join(p.raw)

proc setAntiAlias*(p: var Paint; on: bool) {.inline.} =
  skc_paint_set_anti_alias(p.raw, on)
proc antiAlias*(p: Paint): bool {.inline.} = skc_paint_get_anti_alias(p.raw)

proc setDither*(p: var Paint; on: bool) {.inline.} =
  skc_paint_set_dither(p.raw, on)
proc dither*(p: Paint): bool {.inline.} = skc_paint_get_dither(p.raw)

proc setBlendMode*(p: var Paint; m: BlendMode) {.inline.} =
  skc_paint_set_blend_mode(p.raw, m)
proc blendMode*(p: Paint): BlendMode {.inline.} = skc_paint_get_blend_mode(p.raw)

proc setShader*(p: var Paint; s: Shader) {.inline.} =
  ## Sets the shader that supplies this paint's colour. The paint borrows the
  ## shader, so the shader must outlive the paint.
  skc_paint_set_shader(p.raw, s.raw)

proc clearShader*(p: var Paint) {.inline.} = skc_paint_set_shader(p.raw, nil)

proc setImageFilter*(p: var Paint; f: ImageFilter) {.inline.} =
  ## Note: Skia's raster pipeline only applies an image filter when the paint
  ## is used for a layer, not for an individual draw. To blur a drawing, put
  ## the filter on the layer's paint::
  ##
  ##   var p = newPaint()
  ##   p.setImageFilter(blur(6, 6))
  ##   canvas.layer(p):
  ##     canvas.drawRect(r, fillPaint(ColorWhite))
  skc_paint_set_image_filter(p.raw, f.raw)

proc clearImageFilter*(p: var Paint) {.inline.} =
  skc_paint_set_image_filter(p.raw, nil)

proc setPathEffect*(p: var Paint; e: PathEffect) {.inline.} =
  skc_paint_set_path_effect(p.raw, e.raw)

proc clearPathEffect*(p: var Paint) {.inline.} =
  skc_paint_set_path_effect(p.raw, nil)

proc setColorFilter*(p: var Paint; f: ColorFilter) {.inline.} =
  skc_paint_set_color_filter(p.raw, f.raw)

proc clearColorFilter*(p: var Paint) {.inline.} =
  skc_paint_set_color_filter(p.raw, nil)

proc reset*(p: var Paint) {.inline.} = skc_paint_reset(p.raw)

proc fillPaint*(color: Color; antiAlias = true): Paint =
  ## A ready-made fill paint.
  result = newPaint()
  result.setColor(color)
  result.setAntiAlias(antiAlias)
  result.setStyle(PaintStyleFill)

proc strokePaint*(color: Color; width: float32; antiAlias = true): Paint =
  ## A ready-made stroke paint.
  result = newPaint()
  result.setColor(color)
  result.setAntiAlias(antiAlias)
  result.setStyle(PaintStyleStroke)
  result.setStrokeWidth(width)


# ------------------------------------------------------------------
# Path
# ------------------------------------------------------------------

proc pathCopy(src: ptr skc_path_t): ptr skc_path_t = skc_path_new_copy(src)
proc pathFree(p: ptr skc_path_t) = skc_path_free(p)

valueResource(Path, skc_path_t, pathFree, pathCopy, "Path")

proc newPath*(): Path =
  result.raw = skc_path_new()
  check(result.raw, "newPath")


proc newPath*(build: proc(p: var Path) {.closure.}): Path =
  ## Builds a path in one expression.
  result = newPath()
  build(result)

proc reset*(p: var Path) {.inline.} = skc_path_reset(p.raw)

proc setFillType*(p: var Path; f: FillType) {.inline.} =
  skc_path_set_fill_type(p.raw, f)
proc fillType*(p: Path): FillType {.inline.} = skc_path_get_fill_type(p.raw)

proc moveTo*(p: var Path; x, y: float32) {.inline.} =
  skc_path_move_to(p.raw, x.cfloat, y.cfloat)
proc moveTo*(p: var Path; pt: Point) {.inline.} = p.moveTo(pt.x, pt.y)
proc lineTo*(p: var Path; x, y: float32) {.inline.} =
  skc_path_line_to(p.raw, x.cfloat, y.cfloat)
proc lineTo*(p: var Path; pt: Point) {.inline.} = p.lineTo(pt.x, pt.y)
proc quadTo*(p: var Path; x1, y1, x2, y2: float32) {.inline.} =
  skc_path_quad_to(p.raw, x1.cfloat, y1.cfloat, x2.cfloat, y2.cfloat)
proc cubicTo*(p: var Path; x1, y1, x2, y2, x3, y3: float32) {.inline.} =
  skc_path_cubic_to(p.raw, x1.cfloat, y1.cfloat, x2.cfloat, y2.cfloat, x3.cfloat, y3.cfloat)
proc conicTo*(p: var Path; x1, y1, x2, y2, w: float32) {.inline.} =
  skc_path_conic_to(p.raw, x1.cfloat, y1.cfloat, x2.cfloat, y2.cfloat, w.cfloat)
proc close*(p: var Path) {.inline.} = skc_path_close(p.raw)

proc addRect*(p: var Path; r: Rect; clockwise = true) {.inline.} =
  var cr = toRaw(r)
  skc_path_add_rect(p.raw, addr cr, clockwise)

proc addOval*(p: var Path; r: Rect; clockwise = true) {.inline.} =
  var cr = toRaw(r)
  skc_path_add_oval(p.raw, addr cr, clockwise)

proc addCircle*(p: var Path; center: Point; radius: float32; clockwise = true) {.inline.} =
  skc_path_add_circle(p.raw, center.x.cfloat, center.y.cfloat, radius.cfloat, clockwise)

proc addArc*(p: var Path; oval: Rect; startAngleDeg, sweepAngleDeg: float32;
    forceMoveTo = false) {.inline.} =
  var cr = toRaw(oval)
  skc_path_add_arc(p.raw, addr cr, startAngleDeg.cfloat, sweepAngleDeg.cfloat, forceMoveTo)

proc addPolyline*(p: var Path; points: openArray[Point]; isClosed = false) =
  if points.len == 0:
    raise newException(ValueError, "addPolyline needs at least one point")
  var storage = newSeq[skc_point_t](points.len)
  for i, pt in points: storage[i] = toRaw(pt)
  skc_path_add_poly(p.raw, addr storage[0], csize_t storage.len, isClosed)

proc transform*(p: var Path; m: Matrix) =
  var cm = toRaw(m)
  skc_path_transform(p.raw, addr cm)

proc isEmpty*(p: Path): bool {.inline.} = skc_path_is_empty(p.raw)
proc isFinite*(p: Path): bool {.inline.} = skc_path_is_finite(p.raw)
proc countVerbs*(p: Path): int {.inline.} = int(skc_path_count_verbs(p.raw))
proc bounds*(p: Path): Rect {.inline.} = fromRaw(skc_path_get_bounds(p.raw))
proc tightBounds*(p: Path): Rect {.inline.} = fromRaw(skc_path_compute_tight_bounds(p.raw))
proc contains*(p: Path; x, y: float32): bool {.inline.} =
  skc_path_contains_point(p.raw, x.cfloat, y.cfloat)

proc transformed*(p: Path; m: Matrix): Path =
  ## An independent copy of `p` with `m` applied.
  result = p
  result.transform(m)

# ------------------------------------------------------------------
# Typeface
# ------------------------------------------------------------------

sharedResource(Typeface, skc_typeface_t, skc_typeface_unref)

proc familyName*(t: Typeface): string =
  var buf = newString(512)
  let n = int(skc_typeface_get_family_name(t.raw, buf.cstring, csize_t buf.len))
  buf.setLen(min(n, buf.len - 1))
  buf

proc style*(t: Typeface): FontStyle {.inline.} = fromRaw(skc_typeface_get_style(t.raw))
proc isBold*(t: Typeface): bool {.inline.} = skc_typeface_is_bold(t.raw)
proc isItalic*(t: Typeface): bool {.inline.} = skc_typeface_is_italic(t.raw)

# ------------------------------------------------------------------
# Font manager
# ------------------------------------------------------------------

sharedResource(FontManager, skc_font_manager_t, skc_font_manager_unref)

proc defaultFontManager*(): FontManager =
  ## The platform font manager.
  result.initShared(skc_font_manager_new())
  check(result.raw, "defaultFontManager")

proc familyCount*(m: FontManager): int {.inline.} =
  int(skc_font_manager_get_family_count(m.raw))

proc familyName*(m: FontManager; index: int): string =
  var buf = newString(512)
  let n = int(skc_font_manager_get_family_name(m.raw, index.cint, buf.cstring,
    csize_t buf.len))
  if n == 0:
    raise newException(ValueError, "no font family at index " & $index)
  buf.setLen(min(n, buf.len - 1))
  buf

proc defaultTypeface*(m: FontManager): Typeface =
  result.initShared(skc_font_manager_default_typeface(m.raw))
  check(result.raw, "defaultTypeface")

proc matchFamilyStyle*(m: FontManager; family: string; style: FontStyle): Typeface =
  ## The closest match for `family` at `style`.
  var raw = toRaw(style)
  result.initShared(skc_font_manager_match_family_style(m.raw, family.cstring, raw))
  check(result.raw, "matchFamilyStyle(" & family & ")")

proc typefaceFromFile*(m: FontManager; path: string; ttcIndex = 0): Typeface =
  result.initShared(skc_font_manager_typeface_from_file(m.raw, path.cstring,
    ttcIndex.cint))
  check(result.raw, "typefaceFromFile(" & path & ")")

# ------------------------------------------------------------------
# Font
# ------------------------------------------------------------------

sharedResource(Font, skc_font_t, skc_font_free)

proc newFont*(typeface: Typeface; size: float32): Font =
  ## A font at `size` pixels. Copies of a `Font` share the same underlying
  ## Skia font, so mutating one is visible through the others.
  result.initShared(skc_font_new(typeface.raw, size.cfloat))
  check(result.raw, "newFont")

proc newFont*(size: float32): Font =
  ## A font using the platform's default typeface.
  newFont(Typeface(), size)

proc size*(f: Font): float32 {.inline.} = skc_font_get_size(f.raw).float32
proc setSize*(f: var Font; s: float32) {.inline.} = skc_font_set_size(f.raw, s.cfloat)
proc spacing*(f: Font): float32 {.inline.} = skc_font_get_spacing(f.raw).float32
proc ascent*(f: Font): float32 {.inline.} = skc_font_get_ascent(f.raw).float32
proc descent*(f: Font): float32 {.inline.} = skc_font_get_descent(f.raw).float32

proc setEdging*(f: var Font; e: FontEdging) {.inline.} = skc_font_set_edging(f.raw, e)
proc setHinting*(f: var Font; h: FontHinting) {.inline.} = skc_font_set_hinting(f.raw, h)
proc setSubpixel*(f: var Font; on: bool) {.inline.} = skc_font_set_subpixel(f.raw, on)
proc setEmbolden*(f: var Font; on: bool) {.inline.} = skc_font_set_embolden(f.raw, on)
proc setScaleX*(f: var Font; s: float32) {.inline.} = skc_font_set_scale_x(f.raw, s.cfloat)

proc metrics*(f: Font): FontMetrics =
  var raw: skc_fontmetrics_t
  checkBool(skc_font_get_metrics(f.raw, addr raw), "metrics")
  fromRaw(raw)

proc measureText*(f: Font; text: string): tuple[advance: float32, bounds: Rect] =
  ## Total advance and tight bounds of `text` at the baseline origin.
  var b: skc_rect_t
  let adv = skc_font_measure_text(f.raw, text.cstring, csize_t text.len, addr b)
  (adv.float32, fromRaw(b))

proc measureText*(f: Font; text: string; bounds: var Rect): float32 =
  let m = f.measureText(text)
  bounds = m.bounds
  m.advance

# ------------------------------------------------------------------
# Text blob
# ------------------------------------------------------------------

sharedResource(TextBlob, skc_text_blob_t, skc_text_blob_unref)

proc newTextBlob*(text: string; font: Font): TextBlob =
  ## A run of text positioned at the origin, which can be drawn repeatedly at
  ## different offsets. Glyphs use their default advances; there is no
  ## kerning, shaping or fallback for missing glyphs.
  if font.raw == nil:
    raise newException(ValueError, "newTextBlob needs a font; build one with newFont")
  result.initShared(skc_text_blob_new(text.cstring, csize_t text.len, font.raw))
  check(result.raw, "newTextBlob")



proc bounds*(b: TextBlob): Rect =
  var r: skc_rect_t
  skc_text_blob_get_bounds(b.raw, addr r)
  fromRaw(r)

# ------------------------------------------------------------------
# Canvas
# ------------------------------------------------------------------

type
  Canvas* = object
    ## A drawing surface view. Holds a reference to the `Surface` it came
    ## from, so it can never outlive its backing pixels.
    raw: ptr skc_canvas_t
    owner: Surface

proc canvas*(s: Surface): Canvas =
  ## The drawing context of this surface.
  Canvas(raw: skc_surface_get_canvas(s.raw), owner: s)

proc surface*(c: Canvas): Surface {.inline.} = c.owner

proc save*(c: Canvas): int =
  ## Saves the current state and returns the save count to pass to
  ## `restore`. Always pair with `restore`, ideally via `defer`.
  int(skc_canvas_save(c.raw))

proc restore*(c: Canvas; saveCount: int) {.inline.} =
  skc_canvas_restore(c.raw, saveCount.cint)

proc saveLayer*(c: Canvas; paint: Paint = Paint()): int =
  ## Like `save`, but draws into a transparent layer first. A NULL paint uses
  ## the default paint. This is also how image filters are applied: put one on
  ## `paint` and draw inside the layer.
  int(skc_canvas_save_layer(c.raw, paint.raw))

proc saveCount*(c: Canvas): int {.inline.} = int(skc_canvas_get_save_count(c.raw))

template scoped*(c: Canvas; body: untyped) =
  ## Runs `body` with the canvas state saved, restoring it afterwards even
  ## if `body` raises.
  block:
    let top = c.save()
    try:
      body
    finally:
      c.restore(top)

template layer*(c: Canvas; paint: Paint; body: untyped) =
  ## Runs `body` inside a transparent layer painted with `paint`. This is
  ## also how image filters are applied: set one on `paint` and draw inside.
  block:
    let top = c.saveLayer(paint)
    try:
      body
    finally:
      c.restore(top)

proc clipRect*(c: Canvas; r: Rect; antiAlias = false) =
  var cr = toRaw(r)
  skc_canvas_clip_rect(c.raw, addr cr, antiAlias)

proc clipPath*(c: Canvas; p: Path; antiAlias = false) =
  ## For an inverted clip, set an inverse fill type on the path first.
  skc_canvas_clip_path(c.raw, p.raw, antiAlias)

proc drawColor*(c: Canvas; color: Color; mode = BlendModeSrcOver) {.inline.} =
  skc_canvas_draw_color(c.raw, toRaw(color), mode)

proc drawRect*(c: Canvas; r: Rect; paint: Paint = Paint()) =
  var cr = toRaw(r)
  skc_canvas_draw_rect(c.raw, addr cr, paint.raw)

proc drawOval*(c: Canvas; r: Rect; paint: Paint = Paint()) =
  var cr = toRaw(r)
  skc_canvas_draw_oval(c.raw, addr cr, paint.raw)

proc drawCircle*(c: Canvas; center: Point; radius: float32; paint: Paint = Paint()) =
  skc_canvas_draw_circle(c.raw, center.x.cfloat, center.y.cfloat, radius.cfloat,
    paint.raw)

proc drawLine*(c: Canvas; start, finish: Point; paint: Paint = Paint()) =
  skc_canvas_draw_line(c.raw, start.x.cfloat, start.y.cfloat, finish.x.cfloat,
    finish.y.cfloat, paint.raw)

proc drawPoints*(c: Canvas; points: openArray[Point]; mode = PointModePoints;
    paint: Paint = Paint()) =
  if points.len == 0: return
  var storage = newSeq[skc_point_t](points.len)
  for i, p in points: storage[i] = toRaw(p)
  skc_canvas_draw_points(c.raw, addr storage[0], csize_t storage.len, mode,
    paint.raw)

proc drawPath*(c: Canvas; p: Path; paint: Paint = Paint()) =
  skc_canvas_draw_path(c.raw, p.raw, paint.raw)

proc drawImage*(c: Canvas; i: Image; at: Point; paint: Paint = Paint()) =
  skc_canvas_draw_image(c.raw, i.raw, at.x.cfloat, at.y.cfloat,
    paint.raw)

proc drawImage*(c: Canvas; i: Image; src, dst: Rect;
    filter = FilterModeLinear; mipmap = MipmapModeNone; paint: Paint = Paint()) =
  var cs = toRaw(src)
  var cd = toRaw(dst)
  skc_canvas_draw_image_rect(c.raw, i.raw, addr cs, addr cd, filter, mipmap,
    paint.raw)

proc drawText*(c: Canvas; text: string; origin: Point; font: Font;
    paint: Paint = Paint()) =
  if font.raw == nil:
    raise newException(ValueError, "drawText needs a font; build one with newFont")
  skc_canvas_draw_text(c.raw, text.cstring, csize_t text.len,
    origin.x.cfloat, origin.y.cfloat, font.raw, paint.raw)

proc drawTextBlob*(c: Canvas; b: TextBlob; at: Point; paint: Paint = Paint()) =
  skc_canvas_draw_text_blob(c.raw, b.raw, at.x.cfloat, at.y.cfloat,
    paint.raw)

proc translate*(c: Canvas; dx, dy: float32) {.inline.} =
  skc_canvas_translate(c.raw, dx.cfloat, dy.cfloat)
proc scale*(c: Canvas; sx, sy: float32) {.inline.} =
  skc_canvas_scale(c.raw, sx.cfloat, sy.cfloat)
proc rotate*(c: Canvas; degrees: float32) {.inline.} =
  skc_canvas_rotate(c.raw, degrees.cfloat)
proc concat*(c: Canvas; m: Matrix) =
  var cm = toRaw(m)
  skc_canvas_concat(c.raw, addr cm)
proc setMatrix*(c: Canvas; m: Matrix) =
  var cm = toRaw(m)
  skc_canvas_set_matrix(c.raw, addr cm)
proc resetMatrix*(c: Canvas) {.inline.} = skc_canvas_reset_matrix(c.raw)

proc clipBounds*(c: Canvas): IRect {.inline.} =
  fromRaw(skc_canvas_get_device_clip_bounds(c.raw))

template transformed*(c: Canvas; m: Matrix; body: untyped) =
  ## Runs `body` with `m` concatenated onto the canvas transform, restoring
  ## the previous transform afterwards.
  block:
    let top = c.save()
    try:
      c.concat(m)
      body
    finally:
      c.restore(top)
