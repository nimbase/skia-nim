## Rendering, image codec, text and ownership tests.

import std/strutils
import unittest

import skia

proc pixelAt(px: openArray[byte]; w, h: int; x, y: int): uint32 =
  ## Reads one RGBA8888 pixel out of a premultiplied byte buffer.
  let i = (y * w + x) * 4
  result = (uint32(px[i + 3]).shl 24) or (uint32(px[i]).shl 16) or
    (uint32(px[i + 1]).shl 8) or uint32(px[i + 2])

suite "surface":
  test "creates with the requested size":
    let s = newRgbaSurface(64, 48)
    check s.width == 64
    check s.height == 48

  test "rejects zero-sized surfaces":
    expect IOError:
      discard newRgbaSurface(0, 10)

  test "starts fully transparent":
    let s = newRgbaSurface(4, 4)
    let px = s.readPixels()
    check px.len == 4 * 4 * 4
    check pixelAt(px, 4, 4, 0, 0) == 0

  test "surfaces are shared by copies and freed once":
    var a = newRgbaSurface(8, 8)
    let b = a
    a = newRgbaSurface(8, 8)
    check b.width == 8

  test "readPixels honours the surface pixel format":
    let s = newSurface(10, 10, ColorTypeGray8, AlphaTypeOpaque)
    check s.imageInfo.colorType == ColorTypeGray8
    check s.readPixels().len == 100
    let rgba = newRgbaSurface(10, 10)
    check rgba.readPixels().len == 400

suite "canvas":
  test "drawColor fills the surface":
    let s = newRgbaSurface(8, 8)
    s.canvas.drawColor(rgb(1, 0, 0))
    let px = s.readPixels()
    check pixelAt(px, 8, 8, 4, 4) == 0xFFFF0000'u32

  test "drawRect respects the rect":
    let s = newRgbaSurface(16, 16)
    s.canvas.drawColor(rgb(0, 0, 1))
    var white = fillPaint(ColorWhite)
    s.canvas.drawRect(rectXY(0, 0, 4, 4), white)
    let px = s.readPixels()
    check pixelAt(px, 16, 16, 1, 1) == 0xFFFFFFFF'u32
    check pixelAt(px, 16, 16, 10, 10) == 0xFF0000FF'u32

  test "scoped restores the save count":
    let s = newRgbaSurface(8, 8)
    let c = s.canvas
    let before = c.saveCount()
    c.scoped:
      c.translate(4, 4)
      check c.saveCount() == before + 1
    check c.saveCount() == before

  test "scoped restores state even when the body raises":
    let s = newRgbaSurface(8, 8)
    let c = s.canvas
    let before = c.saveCount()
    try:
      c.scoped:
        raise newException(ValueError, "boom")
    except ValueError:
      discard
    check c.saveCount() == before

  test "transformed offsets drawing and then restores":
    let s = newRgbaSurface(8, 8)
    let c = s.canvas
    var white = fillPaint(ColorWhite)
    c.transformed(translation(5, 5)):
      c.drawRect(rectLTRB(0, 0, 2, 2), white)
    let px = s.readPixels()
    # The square lands at (5,5)..(7,7), not at the origin.
    check pixelAt(px, 8, 8, 6, 6) == 0xFFFFFFFF'u32
    check pixelAt(px, 8, 8, 1, 1) == 0
    # Drawing again without the transform lands back at the origin.
    c.drawRect(rectLTRB(0, 0, 2, 2), white)
    let px2 = s.readPixels()
    check pixelAt(px2, 8, 8, 1, 1) == 0xFFFFFFFF'u32

  test "clipRect limits drawing":
    let s = newRgbaSurface(16, 16)
    let c = s.canvas
    c.scoped:
      c.clipRect(rectXY(0, 0, 8, 8))
      c.drawColor(rgb(1, 1, 1))
    let px = s.readPixels()
    check pixelAt(px, 16, 16, 1, 1) == 0xFFFFFFFF'u32
    check pixelAt(px, 16, 16, 12, 12) == 0

  test "clipBounds reports the surface size":
    check newRgbaSurface(20, 10).canvas.clipBounds() == irect(0, 0, 20, 10)

suite "paint":
  test "stores and returns its settings":
    var p = newPaint()
    p.setColor(rgb(0.1, 0.2, 0.3))
    check p.color() == rgb(0.1, 0.2, 0.3)
    p.setStyle(PaintStyleStroke)
    check p.style() == PaintStyleStroke
    p.setStrokeWidth(3)
    check p.strokeWidth() == 3
    p.setAntiAlias(true)
    check p.antiAlias()
    p.setBlendMode(BlendModeMultiply)
    check p.blendMode() == BlendModeMultiply

  test "presets are ready to use":
    let f = fillPaint(ColorRed)
    check f.style() == PaintStyleFill
    check f.color() == ColorRed
    let st = strokePaint(ColorBlue, 4)
    check st.style() == PaintStyleStroke
    check st.strokeWidth() == 4

  test "copies are independent, not shared":
    var a = fillPaint(ColorRed)
    let b = a
    a.setColor(ColorBlue)
    check a.color() == ColorBlue
    check b.color() == ColorRed

  test "a copy keeps the value it was copied from":
    var p = fillPaint(ColorRed)
    for i in 0 .. 100:
      let before = p.color()
      let q = p
      p.setColor(Color(r: float32(i) / 100, g: 0.5, b: 0.25, a: 1))
      # `q` is an independent deep copy, so it still holds the old colour.
      check q.color() == before
    check p.color() == Color(r: 1, g: 0.5, b: 0.25, a: 1)

suite "path":
  test "circle geometry has the expected bounds":
    var p = newPath()
    p.addCircle(point(50, 50), 10)
    let b = p.bounds
    check abs(b.left - 40) < 0.01
    check abs(b.right - 60) < 0.01
    check not p.isEmpty
    check p.countVerbs() > 0

  test "contains agrees with the circle":
    var p = newPath()
    p.addCircle(point(50, 50), 10)
    check p.contains(50, 50)
    check not p.contains(50, 80)

  test "lines and close build a triangle":
    var p = newPath()
    p.moveTo(0, 0)
    p.lineTo(10, 0)
    p.lineTo(0, 10)
    p.close()
    check p.bounds() == rectLTRB(0, 0, 10, 10)

  test "curves work":
    var p = newPath()
    p.moveTo(0, 0)
    p.quadTo(5, 10, 10, 0)
    p.cubicTo(12, 4, 14, 6, 16, 0)
    p.conicTo(18, 4, 20, 0, 0.5)
    check p.bounds().right >= 16
    check p.isFinite()

  test "addRect, addOval and addPolyline":
    var p = newPath()
    p.addRect(rectLTRB(0, 0, 4, 4))
    p.addOval(rectLTRB(10, 10, 20, 20))
    p.addPolyline([point(0, 0), point(5, 5), point(10, 0)])
    check p.bounds().right >= 20

  test "fill type is stored":
    var p = newPath()
    p.addRect(rectLTRB(0, 0, 4, 4))
    p.setFillType(FillTypeEvenOdd)
    check p.fillType() == FillTypeEvenOdd

  test "transform returns an independent copy":
    var p = newPath()
    p.addRect(rectLTRB(0, 0, 4, 4))
    let moved = p.transformed(translation(10, 0))
    check p.bounds() == rectLTRB(0, 0, 4, 4)
    check moved.bounds() == rectLTRB(10, 0, 14, 4)

  test "the builder form works":
    let p = newPath(proc(p: var Path) =
      p.moveTo(0, 0)
      p.lineTo(1, 1))
    check p.countVerbs() == 2

  test "fill type changes how a self-overlapping path is filled":
    # Two concentric squares wound the same way. Under the winding rule the
    # overlap is filled solid; under even-odd the centre becomes a hole.
    let overlap = newPath(proc(p: var Path) =
      p.addRect(rectLTRB(4, 4, 20, 20), true)
      p.addRect(rectLTRB(8, 8, 16, 16), true))

    var paint = fillPaint(ColorWhite)

    proc centreIs(setFill: FillType): bool =
      let s = newRgbaSurface(24, 24)
      var p = overlap
      p.setFillType(setFill)
      s.canvas.drawPath(p, paint)
      pixelAt(s.readPixels(), 24, 24, 12, 12) != 0

    check centreIs(FillTypeWinding)
    check not centreIs(FillTypeEvenOdd)

  test "reset empties the path":
    var p = newPath()
    p.addRect(rectLTRB(0, 0, 4, 4))
    p.reset()
    check p.isEmpty

suite "image codec":
  test "png round trip preserves dimensions":
    let s = newRgbaSurface(24, 16)
    s.canvas.drawColor(rgb(0, 1, 0))
    let png = s.snapshot().encodePng()
    check png.size > 0
    # PNG magic number.
    let bytes = png.toSeq()
    check bytes[0] == 0x89'u8
    check bytes[1] == uint8(ord('P'))
    let decoded = decodeImage(png)
    check decoded.width == 24
    check decoded.height == 16

  test "decoded pixels match what was drawn":
    let s = newRgbaSurface(4, 4)
    s.canvas.drawColor(rgb(1, 0, 0))
    let decoded = decodeImage(s.snapshot().encodePng())
    # PNG decodes to whatever Skia considers native, which is BGRA here, so
    # use toRgba to normalise before inspecting.
    check decoded.colorType() != ColorTypeRGBA8888
    let px = decoded.toRgba()
    check pixelAt(px, 4, 4, 2, 2) == 0xFFFF0000'u32

  test "toRgba always normalises to RGBA byte order":
    let s = newSurface(2, 2, ColorTypeGray8, AlphaTypeOpaque)
    s.canvas.drawColor(rgb(0.5, 0.5, 0.5))
    let px = decodeImage(s.snapshot().encodePng()).toRgba()
    check px.len == 2 * 2 * 4
    check px[0] == px[1] and px[1] == px[2] and px[3] == 0xFF'u8

  test "jpeg encodes":
    let s = newRgbaSurface(16, 16)
    s.canvas.drawColor(rgb(0.5, 0.5, 0.5))
    let jpg = s.snapshot().encodeJpeg(80)
    check jpg.size > 0
    check decodeImage(jpg).width == 16

  test "corrupt data raises rather than returning nil":
    expect IOError:
      discard decodeImage(newData("\x00\x01\x02\x03not an image"))

  test "images can be built from raw pixels":
    var px = newSeq[byte](4 * 4 * 4)
    for i in 0 ..< px.len: px[i] = 0xFF'u8
    let img = newImage(px, 4, 4, ColorTypeRGBA8888, AlphaTypeUnpremul)
    check img.width == 4
    check img.alphaType() == AlphaTypeUnpremul

  test "newImage validates its input":
    expect ValueError:
      discard newImage([1'u8, 2, 3], 4, 4, ColorTypeRGBA8888)

  test "encoded data can be fetched back":
    let s = newRgbaSurface(8, 8)
    let png = s.snapshot().encodePng()
    check decodeImage(png).encodedData().size == png.size

suite "shaders and filters":
  test "linear gradient":
    let sh = linearGradient(point(0, 0), point(10, 0), [ColorRed, ColorBlue])
    let s = newRgbaSurface(10, 10)
    var p = newPaint()
    p.setShader(sh)
    s.canvas.drawRect(rectLTRB(0, 0, 10, 10), p)
    let px = s.readPixels()
    proc red(i: int): int = int(px[i * 4])
    proc blue(i: int): int = int(px[i * 4 + 2])
    # A smooth red -> blue ramp across the row.
    check red(0) > 200 and blue(0) < 60
    check red(9) < 60 and blue(9) > 200
    for x in 0 ..< 9:
      check red(x + 1) < red(x)
      check blue(x + 1) > blue(x)

  test "radial gradient reaches the canvas":
    let sh = radialGradient(point(10, 10), 10, [ColorRed, ColorRed])
    let s = newRgbaSurface(20, 20)
    var p = newPaint()
    p.setShader(sh)
    s.canvas.drawRect(rectLTRB(0, 0, 20, 20), p)
    check pixelAt(s.readPixels(), 20, 20, 10, 10) == 0xFFFF0000'u32

  test "sweep gradient reaches the canvas":
    let sh = sweepGradient(point(10, 10), 0, 360, [ColorRed, ColorBlue])
    let s = newRgbaSurface(20, 20)
    var p = newPaint()
    p.setShader(sh)
    s.canvas.drawRect(rectLTRB(0, 0, 20, 20), p)
    let px = s.readPixels()
    # The first colour stop appears somewhere around the circle.
    var sawRed = false
    for i in countup(0, px.len - 4, 4):
      if px[i + 3] != 0'u8 and px[i] > 200'u8 and px[i + 2] < 60'u8:
        sawRed = true
        break
    check sawRed

  test "explicit positions must match the colour count":
    expect ValueError:
      discard linearGradient(point(0, 0), point(1, 0), [ColorRed, ColorBlue], [0.0'f32])

  test "a gradient needs at least one colour":
    expect ValueError:
      discard linearGradient(point(0, 0), point(1, 0), [])

  test "blur applied through a layer softens an edge":
    let s = newRgbaSurface(32, 32)
    s.canvas.drawColor(rgb(1, 1, 1))
    var black = fillPaint(ColorBlack, false)
    var p = newPaint()
    let f = blur(3, 3, TileModeClamp)
    p.setImageFilter(f)
    # Skia's raster pipeline applies image filters to layers, not to an
    # individual draw, so the drawing has to happen inside the layer.
    s.canvas.layer(p):
      s.canvas.drawRect(rectLTRB(8, 8, 24, 24), black)
    let px = s.readPixels()
    # White at the edges, black through the middle, and a smooth ramp between.
    check int(px[(16 * 32 + 0) * 4]) > 220
    check int(px[(16 * 32 + 16) * 4]) < 40
    var prev = int(px[(16 * 32 + 0) * 4])
    var monotone = true
    for x in 1 ..< 16:
      let v = int(px[(16 * 32 + x) * 4])
      if v > prev + 2: monotone = false
      prev = v
    check monotone
    # And the layer is popped, so the surrounding surface is intact.
    check int(px[(0 * 32 + 0) * 4]) == 255

  test "dash effect":
    let e = dashEffect([4.0'f32, 2.0'f32], 0)
    discard e

  test "dash effect needs intervals":
    expect ValueError:
      discard dashEffect([])

suite "text":
  test "the default font manager can enumerate families":
    let mgr = defaultFontManager()
    check mgr.familyCount() > 0
    check mgr.familyName(0).len > 0

  test "measuring a string gives a positive advance":
    let mgr = defaultFontManager()
    let tf = mgr.defaultTypeface()
    let font = newFont(tf, 24)
    let m = font.measureText("Hello")
    check m.advance > 0
    check m.bounds.width > 0

  test "font metrics are plausible":
    let mgr = defaultFontManager()
    let tf = mgr.defaultTypeface()
    let font = newFont(tf, 20)
    let fm = font.metrics
    check fm.ascent < 0
    check fm.descent > 0
    check font.spacing > 0

  test "drawing text marks the surface":
    let s = newRgbaSurface(120, 40)
    let mgr = defaultFontManager()
    let tf = mgr.defaultTypeface()
    let font = newFont(tf, 24)
    var white = fillPaint(ColorWhite)
    s.canvas.drawText("Hi", point(4, 28), font, white)
    let px = s.readPixels()
    var painted = false
    for i in countup(0, px.len - 4, 4):
      if px[i + 3] != 0'u8:
        painted = true
        break
    check painted

  test "typeface exposes its family and style":
    let mgr = defaultFontManager()
    let tf = mgr.defaultTypeface()
    check tf.familyName().len > 0
    check tf.style() == fontStyle()

  test "an unmatchable family is reported, not guessed at":
    let mgr = defaultFontManager()
    expect IOError:
      discard mgr.matchFamilyStyle("definitely-not-a-real-font-xyz", fontStyle())

  test "text blobs can be built and drawn":
    let mgr = defaultFontManager()
    let tf = mgr.defaultTypeface()
    let font = newFont(tf, 16)
    let blob = newTextBlob("Skia", font)
    # A blob is built at the origin, so its bounds start at x = 0.
    check blob.bounds().width > 0
    check blob.bounds().left < 1
    let s = newRgbaSurface(64, 24)
    var white = fillPaint(ColorWhite)
    s.canvas.drawTextBlob(blob, point(2, 16), white)
    let px = s.readPixels()
    var painted = false
    for i in countup(0, px.len - 4, 4):
      if px[i + 3] != 0'u8:
        painted = true
        break
    check painted

suite "error reporting":
  test "errors carry the C-side explanation":
    var message = ""
    try:
      discard newRgbaSurface(0, 0)
    except IOError as e:
      message = e.msg
    check "invalid dimensions" in message

  test "lastError is readable and clearable":
    expect IOError:
      discard newRgbaSurface(0, 0)
    check lastError().len > 0
    clearError()
    check lastError().len == 0

  test "the version string is reported":
    check skiaVersion().len > 0
