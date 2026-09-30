## Layout and ABI tests.
##
## The value structs in `skia_raw` are mirrored by Nim-native types in
## `skia/geometry`. Both are checked here against the C ABI, because a
## silent mismatch in either would corrupt memory rather than fail to
## compile.

import unittest

import skia

suite "ABI layout":
  test "raw value structs have the size the C header declares":
    static:
      doAssert sizeof(skc_color_t) == 16
      doAssert sizeof(skc_point_t) == 8
      doAssert sizeof(skc_rect_t) == 16
      doAssert sizeof(skc_irect_t) == 16
      doAssert sizeof(skc_matrix_t) == 36
      doAssert sizeof(skc_imageinfo_t) == 20
      doAssert sizeof(skc_fontstyle_t) == 12
      doAssert sizeof(skc_fontmetrics_t) == 28
      doAssert sizeof(bool) == 1

  test "Nim value types match the raw ones exactly":
    static:
      doAssert sizeof(Color) == sizeof(skc_color_t)
      doAssert sizeof(Point) == sizeof(skc_point_t)
      doAssert sizeof(Rect) == sizeof(skc_rect_t)
      doAssert sizeof(IRect) == sizeof(skc_irect_t)
      doAssert sizeof(Matrix) == sizeof(skc_matrix_t)
      doAssert sizeof(ImageInfo) == sizeof(skc_imageinfo_t)
      doAssert sizeof(FontStyle) == sizeof(skc_fontstyle_t)
      doAssert sizeof(FontMetrics) == sizeof(skc_fontmetrics_t)

  test "struct field offsets are in C declaration order":
    static:
      doAssert offsetOf(skc_rect_t, left) == 0
      doAssert offsetOf(skc_rect_t, top) == 4
      doAssert offsetOf(skc_rect_t, right) == 8
      doAssert offsetOf(skc_rect_t, bottom) == 12
      doAssert offsetOf(skc_color_t, r) == 0
      doAssert offsetOf(skc_color_t, g) == 4
      doAssert offsetOf(skc_color_t, b) == 8
      doAssert offsetOf(skc_color_t, a) == 12
      doAssert offsetOf(skc_imageinfo_t, width) == 0
      doAssert offsetOf(skc_imageinfo_t, height) == 4
      doAssert offsetOf(skc_imageinfo_t, colorType) == 8
      doAssert offsetOf(skc_imageinfo_t, alphaType) == 12
      doAssert offsetOf(skc_imageinfo_t, colorSpace) == 16

  test "value types survive a round trip through the raw layer":
    let c = rgba(0.25, 0.5, 0.75, 1)
    check fromRaw(toRaw(c)) == c
    let r = rectXY(1, 2, 3, 4)
    check fromRaw(toRaw(r)) == r
    let i = imageInfo(7, 9, ColorTypeBGRA8888, AlphaTypeOpaque, ColorSpaceLinearSrgb)
    check fromRaw(toRaw(i)) == i
    let m = translation(3, 4) * scaling(2, 2)
    check fromRaw(toRaw(m)) == m
    let fs = fontStyle(FontWeightBold, FontWidthCondensed, FontSlantOblique)
    check fromRaw(toRaw(fs)) == fs

suite "geometry":
  test "rect helpers":
    let r = rectXY(10, 20, 30, 40)
    check r.width == 30
    check r.height == 40
    check not r.isEmpty
    check rect(0, 0).isEmpty
    check r.center == point(25, 40)

  test "colour conversion to 0xAARRGGBB":
    check ColorRed.toUint32() == 0xFFFF0000'u32
    check ColorBlue.toUint32() == 0xFF0000FF'u32
    check ColorTransparent.toUint32() == 0x00000000'u32
    check colorArgb(0xFF0000FF'u32) == ColorBlue

  test "matrix composition and mapping":
    let m = translation(10, 0) * scaling(2, 2)
    let mapped = m.mapRect(rectLTRB(0, 0, 1, 1))
    check mapped == rectXY(10, 0, 2, 2)
    check identityMatrix() * identityMatrix() == identityMatrix()

  test "rotation maps a square to a diamond":
    let m = rotation(45)
    let r = m.mapRect(rectLTRB(-1, -1, 1, 1))
    check abs(r.width - r.height) < 0.001
    check r.width > 2.7 and r.width < 2.9

  test "byte sizes of common colour types":
    check imageInfo(1, 1, ColorTypeRGBA8888).bytesPerPixel == 4
    check imageInfo(1, 1, ColorTypeGray8).bytesPerPixel == 1
    check imageInfo(1, 1, ColorTypeRGBAF16).bytesPerPixel == 0

  test "enum values stringify readably":
    check $BlendModeSrcOver == "srcOver"
    check $ColorTypeRGBA8888 == "rgba8888"
    check $EncodedFormatPng == "png"
