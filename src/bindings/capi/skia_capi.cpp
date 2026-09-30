/*
 * skia_capi.cpp - implements the C ABI declared in skia_capi.h on top of the
 * Skia C++ API.
 *
 * Every skc_* enum constant is checked against the Skia enum it mirrors with
 * a static_assert. If a future Skia renumbers an enum, this file fails to
 * compile instead of silently writing out-of-range values.
 */

#include "skia_capi.h"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <new>
#include <string>
#include <utility>
#include <vector>

#include "include/core/SkAlphaType.h"
#include "include/core/SkBlendMode.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkColor.h"
#include "include/core/SkColorSpace.h"
#include "include/core/SkColorType.h"
#include "include/core/SkData.h"
#include "include/core/SkFont.h"
#include "include/core/SkFontMetrics.h"
#include "include/core/SkFontMgr.h"
#include "include/core/SkFontStyle.h"
#include "include/core/SkFontTypes.h"
#include "include/core/SkImage.h"
#include "include/core/SkImageFilter.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkMatrix.h"
#include "include/core/SkPaint.h"
#include "include/core/SkPath.h"
#include "include/core/SkPathBuilder.h"
#include "include/core/SkPathEffect.h"
#include "include/core/SkPathTypes.h"
#include "include/core/SkPixmap.h"
#include "include/core/SkSamplingOptions.h"
#include "include/core/SkShader.h"
#include "include/core/SkString.h"
#include "include/core/SkSurface.h"
#include "include/core/SkTextBlob.h"
#include "include/core/SkTileMode.h"
#include "include/core/SkTypeface.h"
#include "include/codec/SkEncodedImageFormat.h"
#include "include/encode/SkJpegEncoder.h"
#include "include/encode/SkPngEncoder.h"
#include "include/effects/SkGradient.h"
#include "include/effects/SkImageFilters.h"
#include "include/effects/SkColorMatrixFilter.h"
#include "include/effects/SkCornerPathEffect.h"
#include "include/effects/SkDashPathEffect.h"
#include "include/effects/SkDiscretePathEffect.h"

#if defined(__linux__) || defined(__unix__) || defined(__APPLE__)
#    include "include/ports/SkFontMgr_fontconfig.h"
#    include "include/ports/SkFontScanner_FreeType.h"
#endif

/* ================================================================== */
/* Enum value verification                                             */
/* ================================================================== */

#define SKC_ASSERT_ENUM(CType, skType, CName, skName) \
    static_assert(static_cast<int>(CName) == static_cast<int>(skType::skName), \
                  #CName " must match " #skType "::" #skName)

SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_UNKNOWN, kUnknown_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_ALPHA_8, kAlpha_8_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGB_565, kRGB_565_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_ARGB_4444, kARGB_4444_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGBA_8888, kRGBA_8888_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGB_888X, kRGB_888x_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_BGRA_8888, kBGRA_8888_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGBA_1010102, kRGBA_1010102_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_BGRA_1010102, kBGRA_1010102_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGB_101010X, kRGB_101010x_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_BGR_101010X, kBGR_101010x_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_BGR_101010X_XR, kBGR_101010x_XR_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_BGRA_10101010_XR, kBGRA_10101010_XR_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGBA_10X6, kRGBA_10x6_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_GRAY_8, kGray_8_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGBA_F16_NORM, kRGBA_F16Norm_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGBA_F16, kRGBA_F16_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGB_F16F16F16X, kRGB_F16F16F16x_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_RGBA_F32, kRGBA_F32_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_R8G8_UNORM, kR8G8_unorm_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_A16_FLOAT, kA16_float_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_R16_FLOAT, kR16_float_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_R16G16_FLOAT, kR16G16_float_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_A16_UNORM, kA16_unorm_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_R16_UNORM, kR16_unorm_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_R16G16_UNORM, kR16G16_unorm_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_R16G16B16A16_UNORM, kR16G16B16A16_unorm_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_SRGBA_8888, kSRGBA_8888_SkColorType);
SKC_ASSERT_ENUM(skc_colortype_t, SkColorType, SKC_COLOR_TYPE_R8_UNORM, kR8_unorm_SkColorType);

SKC_ASSERT_ENUM(skc_alphatype_t, SkAlphaType, SKC_ALPHA_TYPE_UNKNOWN, kUnknown_SkAlphaType);
SKC_ASSERT_ENUM(skc_alphatype_t, SkAlphaType, SKC_ALPHA_TYPE_OPAQUE, kOpaque_SkAlphaType);
SKC_ASSERT_ENUM(skc_alphatype_t, SkAlphaType, SKC_ALPHA_TYPE_PREMUL, kPremul_SkAlphaType);
SKC_ASSERT_ENUM(skc_alphatype_t, SkAlphaType, SKC_ALPHA_TYPE_UNPREMUL, kUnpremul_SkAlphaType);

SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_CLEAR, kClear);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_SRC, kSrc);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_DST, kDst);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_SRC_OVER, kSrcOver);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_DST_OVER, kDstOver);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_SRC_IN, kSrcIn);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_DST_IN, kDstIn);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_SRC_OUT, kSrcOut);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_DST_OUT, kDstOut);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_SRC_ATOP, kSrcATop);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_DST_ATOP, kDstATop);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_XOR, kXor);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_PLUS, kPlus);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_MODULATE, kModulate);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_SCREEN, kScreen);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_OVERLAY, kOverlay);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_DARKEN, kDarken);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_LIGHTEN, kLighten);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_COLOR_DODGE, kColorDodge);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_COLOR_BURN, kColorBurn);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_HARD_LIGHT, kHardLight);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_SOFT_LIGHT, kSoftLight);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_DIFFERENCE, kDifference);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_EXCLUSION, kExclusion);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_MULTIPLY, kMultiply);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_HUE, kHue);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_SATURATION, kSaturation);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_COLOR, kColor);
SKC_ASSERT_ENUM(skc_blendmode_t, SkBlendMode, SKC_BLEND_MODE_LUMINOSITY, kLuminosity);
static_assert(static_cast<int>(SKC_BLEND_MODE_LUMINOSITY) ==
                  static_cast<int>(SkBlendMode::kLastMode),
              "blend modes must stay contiguous up to kLuminosity");

SKC_ASSERT_ENUM(skc_tilemode_t, SkTileMode, SKC_TILE_MODE_CLAMP, kClamp);
SKC_ASSERT_ENUM(skc_tilemode_t, SkTileMode, SKC_TILE_MODE_REPEAT, kRepeat);
SKC_ASSERT_ENUM(skc_tilemode_t, SkTileMode, SKC_TILE_MODE_MIRROR, kMirror);
SKC_ASSERT_ENUM(skc_tilemode_t, SkTileMode, SKC_TILE_MODE_DECAL, kDecal);

SKC_ASSERT_ENUM(skc_filtermode_t, SkFilterMode, SKC_FILTER_MODE_NEAREST, kNearest);
SKC_ASSERT_ENUM(skc_filtermode_t, SkFilterMode, SKC_FILTER_MODE_LINEAR, kLinear);
SKC_ASSERT_ENUM(skc_mipmapmode_t, SkMipmapMode, SKC_MIPMAP_MODE_NONE, kNone);
SKC_ASSERT_ENUM(skc_mipmapmode_t, SkMipmapMode, SKC_MIPMAP_MODE_NEAREST, kNearest);
SKC_ASSERT_ENUM(skc_mipmapmode_t, SkMipmapMode, SKC_MIPMAP_MODE_LINEAR, kLinear);

SKC_ASSERT_ENUM(skc_filltype_t, SkPathFillType, SKC_FILL_TYPE_WINDING, kWinding);
SKC_ASSERT_ENUM(skc_filltype_t, SkPathFillType, SKC_FILL_TYPE_EVEN_ODD, kEvenOdd);
SKC_ASSERT_ENUM(skc_filltype_t, SkPathFillType, SKC_FILL_TYPE_INVERSE_WINDING, kInverseWinding);
SKC_ASSERT_ENUM(skc_filltype_t, SkPathFillType, SKC_FILL_TYPE_INVERSE_EVEN_ODD, kInverseEvenOdd);

SKC_ASSERT_ENUM(skc_encodedformat_t, SkEncodedImageFormat, SKC_ENCODED_FORMAT_BMP, kBMP);
SKC_ASSERT_ENUM(skc_encodedformat_t, SkEncodedImageFormat, SKC_ENCODED_FORMAT_GIF, kGIF);
SKC_ASSERT_ENUM(skc_encodedformat_t, SkEncodedImageFormat, SKC_ENCODED_FORMAT_ICO, kICO);
SKC_ASSERT_ENUM(skc_encodedformat_t, SkEncodedImageFormat, SKC_ENCODED_FORMAT_JPEG, kJPEG);
SKC_ASSERT_ENUM(skc_encodedformat_t, SkEncodedImageFormat, SKC_ENCODED_FORMAT_PNG, kPNG);
SKC_ASSERT_ENUM(skc_encodedformat_t, SkEncodedImageFormat, SKC_ENCODED_FORMAT_WBMP, kWBMP);
SKC_ASSERT_ENUM(skc_encodedformat_t, SkEncodedImageFormat, SKC_ENCODED_FORMAT_WEBP, kWEBP);

SKC_ASSERT_ENUM(skc_fontslant_t, SkFontStyle, SKC_FONT_SLANT_UPRIGHT, kUpright_Slant);
SKC_ASSERT_ENUM(skc_fontslant_t, SkFontStyle, SKC_FONT_SLANT_ITALIC, kItalic_Slant);
SKC_ASSERT_ENUM(skc_fontslant_t, SkFontStyle, SKC_FONT_SLANT_OBLIQUE, kOblique_Slant);
static_assert(static_cast<int>(SKC_FONT_WEIGHT_NORMAL) ==
                  static_cast<int>(SkFontStyle::kNormal_Weight),
              "font weights are plain CSS numbers");
static_assert(static_cast<int>(SKC_FONT_WIDTH_NORMAL) ==
                  static_cast<int>(SkFontStyle::kNormal_Width),
              "font widths are plain CSS numbers");

static_assert(static_cast<int>(SKC_PAINT_STYLE_FILL) == static_cast<int>(SkPaint::kFill_Style),
              "paint styles must match");
static_assert(static_cast<int>(SKC_PAINT_STYLE_STROKE) ==
                  static_cast<int>(SkPaint::kStroke_Style),
              "paint styles must match");
static_assert(static_cast<int>(SKC_PAINT_STYLE_STROKE_AND_FILL) ==
                  static_cast<int>(SkPaint::kStrokeAndFill_Style),
              "paint styles must match");
static_assert(static_cast<int>(SKC_STROKE_CAP_BUTT) == static_cast<int>(SkPaint::kButt_Cap),
              "stroke caps must match");
static_assert(static_cast<int>(SKC_STROKE_CAP_ROUND) == static_cast<int>(SkPaint::kRound_Cap),
              "stroke caps must match");
static_assert(static_cast<int>(SKC_STROKE_CAP_SQUARE) == static_cast<int>(SkPaint::kSquare_Cap),
              "stroke caps must match");
static_assert(static_cast<int>(SKC_STROKE_JOIN_MITER) == static_cast<int>(SkPaint::kMiter_Join),
              "stroke joins must match");
static_assert(static_cast<int>(SKC_STROKE_JOIN_ROUND) == static_cast<int>(SkPaint::kRound_Join),
              "stroke joins must match");
static_assert(static_cast<int>(SKC_STROKE_JOIN_BEVEL) == static_cast<int>(SkPaint::kBevel_Join),
              "stroke joins must match");
static_assert(static_cast<int>(SKC_POINT_MODE_POINTS) ==
                  static_cast<int>(SkCanvas::kPoints_PointMode),
              "point modes must match");
static_assert(static_cast<int>(SKC_POINT_MODE_LINES) == static_cast<int>(SkCanvas::kLines_PointMode),
              "point modes must match");
static_assert(static_cast<int>(SKC_POINT_MODE_POLYGON) ==
                  static_cast<int>(SkCanvas::kPolygon_PointMode),
              "point modes must match");
static_assert(static_cast<int>(SKC_FONT_EDGING_ALIAS) == static_cast<int>(SkFont::Edging::kAlias),
              "font edging must match");
static_assert(static_cast<int>(SKC_FONT_EDGING_ANTIALIAS) ==
                  static_cast<int>(SkFont::Edging::kAntiAlias),
              "font edging must match");
static_assert(static_cast<int>(SKC_FONT_EDGING_SUBPIXEL_ANTIALIAS) ==
                  static_cast<int>(SkFont::Edging::kSubpixelAntiAlias),
              "font edging must match");
static_assert(static_cast<int>(SKC_HINTING_NONE) == static_cast<int>(SkFontHinting::kNone),
              "hinting must match");
static_assert(static_cast<int>(SKC_HINTING_SLIGHT) == static_cast<int>(SkFontHinting::kSlight),
              "hinting must match");
static_assert(static_cast<int>(SKC_HINTING_NORMAL) == static_cast<int>(SkFontHinting::kNormal),
              "hinting must match");
static_assert(static_cast<int>(SKC_HINTING_FULL) == static_cast<int>(SkFontHinting::kFull),
              "hinting must match");

/* The value structs are rebuilt field by field on the way in and out, but
   their sizes still have to match what the Nim side assumes. */
static_assert(sizeof(skc_color_t) == 16, "skc_color_t must be 4 floats");
static_assert(sizeof(skc_point_t) == 8, "skc_point_t must be 2 floats");
static_assert(sizeof(skc_rect_t) == 16, "skc_rect_t must be 4 floats");
static_assert(sizeof(skc_irect_t) == 16, "skc_irect_t must be 4 int32");
static_assert(sizeof(skc_matrix_t) == 36, "skc_matrix_t must be 9 floats");
static_assert(sizeof(skc_fontstyle_t) == 12, "skc_fontstyle_t must be 3 int32");
static_assert(sizeof(skc_fontmetrics_t) == 28, "skc_fontmetrics_t must be 7 floats");
static_assert(sizeof(skc_imageinfo_t) == 20, "skc_imageinfo_t must be 2 int32 + 3 enums");
static_assert(sizeof(bool) == 1, "the Nim side assumes a 1-byte bool");

/* ================================================================== */
/* Error reporting                                                     */
/* ================================================================== */

namespace {
thread_local std::string g_lastError;

void setError(const char *msg) { g_lastError = msg ? msg : "unknown error"; }
void clearError() { g_lastError.clear(); }
}  // namespace

extern "C" const char *skc_last_error(void) {
    return g_lastError.empty() ? nullptr : g_lastError.c_str();
}

extern "C" void skc_clear_error(void) { clearError(); }

extern "C" const char *skc_version(void) { return "0.153.3"; }

/* ================================================================== */
/* Conversions                                                         */
/* ================================================================== */

namespace {

SkColor4f toSkColor(skc_color_t c) { return SkColor4f{c.r, c.g, c.b, c.a}; }
skc_color_t fromSkColor(const SkColor4f &c) { return skc_color_t{c.fR, c.fG, c.fB, c.fA}; }

SkRect toSkRect(const skc_rect_t &r) {
    return SkRect::MakeXYWH(r.left, r.top, r.right - r.left, r.bottom - r.top);
}
skc_rect_t fromSkRect(const SkRect &r) {
    return skc_rect_t{r.left(), r.top(), r.right(), r.bottom()};
}

SkIRect toSkIRect(const skc_irect_t &r) {
    return SkIRect::MakeLTRB(r.left, r.top, r.right, r.bottom);
}
skc_irect_t fromSkIRect(const SkIRect &r) {
    return skc_irect_t{r.left(), r.top(), r.right(), r.bottom()};
}

SkMatrix toSkMatrix(const skc_matrix_t &m) {
    return SkMatrix::MakeAll(m.m[0], m.m[1], m.m[2], m.m[3], m.m[4], m.m[5], m.m[6], m.m[7],
                             m.m[8]);
}
skc_matrix_t fromSkMatrix(const SkMatrix &m) {
    return skc_matrix_t{m.getScaleX(),      m.getSkewX(), m.getTranslateX(),
                        m.getSkewY(),       m.getScaleY(), m.getTranslateY(),
                        m.getPerspX(),      m.getPerspY(), m.get(SkMatrix::kMPersp2)};
}

SkSamplingOptions toSampling(skc_filtermode_t f, skc_mipmapmode_t m) {
    return SkSamplingOptions(static_cast<SkFilterMode>(f), static_cast<SkMipmapMode>(m));
}

SkFontStyle toFontStyle(skc_fontstyle_t s) {
    return SkFontStyle(static_cast<int>(s.weight), static_cast<int>(s.width),
                       static_cast<SkFontStyle::Slant>(s.slant));
}
skc_fontstyle_t fromFontStyle(const SkFontStyle &s) {
    return skc_fontstyle_t{s.weight(), s.width(),
                           static_cast<skc_fontslant_t>(static_cast<int>(s.slant()))};
}

sk_sp<SkColorSpace> toColorSpace(skc_colorspace_t cs) {
    switch (cs) {
    case SKC_COLOR_SPACE_LINEAR_SRGB: return SkColorSpace::MakeSRGBLinear();
    case SKC_COLOR_SPACE_SRGB:
    default: return SkColorSpace::MakeSRGB();
    }
}

SkImageInfo toImageInfo(const skc_imageinfo_t &info) {
    return SkImageInfo::Make(info.width, info.height,
                             static_cast<SkColorType>(info.colorType),
                             static_cast<SkAlphaType>(info.alphaType),
                             toColorSpace(info.colorSpace));
}

skc_imageinfo_t fromImageInfo(const SkImageInfo &info) {
    const SkColorSpace *cs = info.colorSpace();
    skc_colorspace_t space = SKC_COLOR_SPACE_SRGB;
    if (cs && !cs->isSRGB()) space = SKC_COLOR_SPACE_LINEAR_SRGB;
    return skc_imageinfo_t{info.width(), info.height(),
                           static_cast<skc_colortype_t>(static_cast<int>(info.colorType())),
                           static_cast<skc_alphatype_t>(static_cast<int>(info.alphaType())),
                           space};
}

SkGradient toGradient(const skc_color_t *colors, const float *positions, size_t count,
                      skc_tilemode_t tileMode, std::vector<SkColor4f> &scratch) {
    scratch.clear();
    scratch.reserve(count);
    for (size_t i = 0; i < count; ++i) scratch.push_back(toSkColor(colors[i]));
    SkGradient::Colors c =
        positions == nullptr
            ? SkGradient::Colors(SkSpan(scratch), static_cast<SkTileMode>(tileMode))
            : SkGradient::Colors(SkSpan(scratch), SkSpan(positions, count),
                                 static_cast<SkTileMode>(tileMode));
    return SkGradient(c, SkGradient::Interpolation());
}

/* Holds an optional SkMatrix so that a NULL local-matrix argument can be
   turned into a pointer that is valid for the duration of one call. Skia
   copies the matrix, so a stack temporary is fine. */
class LocalMatrix {
public:
    explicit LocalMatrix(const skc_matrix_t *m) : ptr_(m ? &mx_ : nullptr) {
        if (ptr_) mx_ = toSkMatrix(*m);
    }
    const SkMatrix *get() const { return ptr_; }

private:
    SkMatrix mx_;
    const SkMatrix *ptr_;
};

/* Returns a raster-backed image with the same pixels. Images created by
   skc_image_new_from_encoded are decoded lazily, so peekPixels() fails on
   them until they have been drawn; this materialises one on demand. */
sk_sp<SkImage> ensureRaster(const sk_sp<SkImage> &src) {
    if (!src) return nullptr;
    SkPixmap pm;
    if (src->peekPixels(&pm)) return src;
    sk_sp<SkSurface> s = SkSurfaces::Raster(src->imageInfo());
    if (!s) return nullptr;
    s->getCanvas()->drawImage(src.get(), 0, 0);
    return s->makeImageSnapshot();
}

/* Copies at most bufSize-1 bytes plus a terminator; returns the length. */
size_t copyOut(const SkString &src, char *buf, size_t bufSize) {
    if (buf == nullptr || bufSize == 0) return 0;
    const size_t n = std::min(src.size(), bufSize - 1);
    std::memcpy(buf, src.c_str(), n);
    buf[n] = '\0';
    return n;
}

}  // namespace

/* ================================================================== */
/* Value type helpers                                                  */
/* ================================================================== */

extern "C" {

skc_rect_t skc_rect_make(float left, float top, float right, float bottom) {
    return skc_rect_t{left, top, right, bottom};
}
skc_rect_t skc_rect_make_wh(float width, float height) {
    return skc_rect_t{0, 0, width, height};
}
bool skc_rect_is_empty(const skc_rect_t *r) { return r == nullptr || toSkRect(*r).isEmpty(); }
skc_irect_t skc_irect_make(int32_t left, int32_t top, int32_t right, int32_t bottom) {
    return skc_irect_t{left, top, right, bottom};
}

skc_matrix_t skc_matrix_identity(void) { return fromSkMatrix(SkMatrix::I()); }
skc_matrix_t skc_matrix_make_translate(float dx, float dy) {
    return fromSkMatrix(SkMatrix::Translate(dx, dy));
}
skc_matrix_t skc_matrix_make_scale(float sx, float sy) {
    return fromSkMatrix(SkMatrix::Scale(sx, sy));
}
skc_matrix_t skc_matrix_make_rotate(float degrees) {
    return fromSkMatrix(SkMatrix::RotateDeg(degrees));
}
skc_matrix_t skc_matrix_make_all(float scaleX, float skewX, float transX, float skewY,
                                 float scaleY, float transY, float perspX, float perspY,
                                 float perspZ) {
    return fromSkMatrix(SkMatrix::MakeAll(scaleX, skewX, transX, skewY, scaleY, transY, perspX,
                                          perspY, perspZ));
}
void skc_matrix_set_identity(skc_matrix_t *m) { *m = skc_matrix_identity(); }
void skc_matrix_pre_translate(skc_matrix_t *m, float dx, float dy) {
    SkMatrix t = toSkMatrix(*m);
    t.preTranslate(dx, dy);
    *m = fromSkMatrix(t);
}
void skc_matrix_pre_scale(skc_matrix_t *m, float sx, float sy) {
    SkMatrix t = toSkMatrix(*m);
    t.preScale(sx, sy);
    *m = fromSkMatrix(t);
}
void skc_matrix_pre_rotate(skc_matrix_t *m, float degrees) {
    SkMatrix t = toSkMatrix(*m);
    t.preRotate(degrees);
    *m = fromSkMatrix(t);
}
void skc_matrix_post_translate(skc_matrix_t *m, float dx, float dy) {
    SkMatrix t = toSkMatrix(*m);
    t.postTranslate(dx, dy);
    *m = fromSkMatrix(t);
}
void skc_matrix_post_scale(skc_matrix_t *m, float sx, float sy) {
    SkMatrix t = toSkMatrix(*m);
    t.postScale(sx, sy);
    *m = fromSkMatrix(t);
}
void skc_matrix_post_rotate(skc_matrix_t *m, float degrees) {
    SkMatrix t = toSkMatrix(*m);
    t.postRotate(degrees);
    *m = fromSkMatrix(t);
}
void skc_matrix_concat(skc_matrix_t *target, const skc_matrix_t *a, const skc_matrix_t *b) {
    SkMatrix r = toSkMatrix(*a);
    r.preConcat(toSkMatrix(*b));
    *target = fromSkMatrix(r);
}
bool skc_matrix_invert(const skc_matrix_t *src, skc_matrix_t *dst) {
    SkMatrix m = toSkMatrix(*src);
    if (!m.invert(&m)) return false;
    *dst = fromSkMatrix(m);
    return true;
}
void skc_matrix_map_rect(const skc_matrix_t *m, skc_rect_t *rect) {
    if (rect == nullptr) return;
    SkRect r = toSkRect(*rect);
    toSkMatrix(*m).mapRect(&r);
    *rect = fromSkRect(r);
}

skc_fontstyle_t skc_fontstyle_normal(void) {
    return skc_fontstyle_t{SKC_FONT_WEIGHT_NORMAL, SKC_FONT_WIDTH_NORMAL, SKC_FONT_SLANT_UPRIGHT};
}
skc_fontstyle_t skc_fontstyle_make(skc_fontweight_t weight, skc_fontwidth_t width,
                                   skc_fontslant_t slant) {
    return skc_fontstyle_t{static_cast<int32_t>(weight), static_cast<int32_t>(width), slant};
}

}  // extern "C"

/* ================================================================== */
/* Handle definitions                                                  */
/* ================================================================== */

struct skc_data {
    sk_sp<const SkData> sp;
};

struct skc_pixmap {
    SkPixmap pixmap;
    skc_imageinfo_t info{};
};

struct skc_canvas {
    SkCanvas *canvas = nullptr;  // borrowed from the owning surface
};

struct skc_surface {
    sk_sp<SkSurface> sp;
    // Set when the surface wraps caller pixels we own; keeps them alive.
    sk_sp<SkData> pixelData;
    skc_canvas canvas;  // stable address for skc_surface_get_canvas
};

struct skc_paint {
    SkPaint paint;
};

struct skc_path {
    SkPathBuilder builder;
    /* The fill type is tracked here rather than left to SkPathBuilder,
       because SkPathBuilder::setFillType does not survive a snapshot()
       reliably in every build (it reads back as kWinding under some
       toolchain configurations). SkPath::setFillType is dependable, so the
       authoritative value is stamped onto each snapshot. */
    SkPathFillType fillType = SkPathFillType::kWinding;
    mutable SkPath cached;
    mutable bool dirty = true;

    const SkPath &path() const {
        if (dirty) {
            cached = builder.snapshot();
            cached.setFillType(fillType);
            dirty = false;
        }
        return cached;
    }
    void touch() { dirty = true; }
};

struct skc_image {
    sk_sp<SkImage> sp;
};

struct skc_shader {
    sk_sp<SkShader> sp;
};

struct skc_image_filter {
    sk_sp<SkImageFilter> sp;
};

struct skc_path_effect {
    sk_sp<SkPathEffect> sp;
};

struct skc_color_filter {
    sk_sp<SkColorFilter> sp;
};

struct skc_typeface {
    sk_sp<SkTypeface> sp;
};

struct skc_font_manager {
    sk_sp<SkFontMgr> sp;
};

struct skc_font {
    SkFont font;
};

struct skc_text_blob {
    sk_sp<SkTextBlob> sp;
};

/* ================================================================== */
/* Data                                                                */
/* ================================================================== */

extern "C" {

skc_data_t *skc_data_new(const void *data, size_t size) {
    clearError();
    if (size > 0 && data == nullptr) {
        setError("skc_data_new: data is NULL but size is non-zero");
        return nullptr;
    }
    skc_data_t *h = new (std::nothrow) skc_data;
    if (h == nullptr) {
        setError("skc_data_new: out of memory");
        return nullptr;
    }
    h->sp = SkData::MakeWithCopy(data, size);
    if (!h->sp) {
        setError("skc_data_new: allocation failed");
        delete h;
        return nullptr;
    }
    return h;
}

skc_data_t *skc_data_new_null(void) {
    clearError();
    skc_data_t *h = new (std::nothrow) skc_data;
    if (h == nullptr) {
        setError("skc_data_new_null: out of memory");
        return nullptr;
    }
    h->sp = SkData::MakeWithoutCopy(nullptr, 0);
    return h;
}

skc_data_t *skc_data_ref(skc_data_t *data) {
    if (data == nullptr) return nullptr;
    skc_data_t *h = new (std::nothrow) skc_data;
    if (h == nullptr) {
        setError("skc_data_ref: out of memory");
        return nullptr;
    }
    h->sp = data->sp;
    return h;
}

void skc_data_unref(skc_data_t *data) { delete data; }

size_t skc_data_size(const skc_data_t *data) { return data == nullptr ? 0 : data->sp->size(); }

const void *skc_data_data(const skc_data_t *data) {
    return data == nullptr ? nullptr : data->sp->data();
}

/* ================================================================== */
/* Pixmap                                                              */
/* ================================================================== */

skc_pixmap_t *skc_pixmap_new(const skc_imageinfo_t *info, void *pixels, size_t rowBytes) {
    clearError();
    if (info == nullptr || pixels == nullptr) {
        setError("skc_pixmap_new: info and pixels are required");
        return nullptr;
    }
    skc_pixmap_t *h = new (std::nothrow) skc_pixmap;
    if (h == nullptr) {
        setError("skc_pixmap_new: out of memory");
        return nullptr;
    }
    h->info = *info;
    h->pixmap.reset(toImageInfo(*info), pixels, rowBytes);
    if (h->pixmap.isEmpty()) {
        setError("skc_pixmap_new: invalid info or rowBytes");
        delete h;
        return nullptr;
    }
    return h;
}

void skc_pixmap_free(skc_pixmap_t *pixmap) { delete pixmap; }

bool skc_pixmap_reset(skc_pixmap_t *pixmap, const skc_imageinfo_t *info, void *pixels,
                      size_t rowBytes) {
    if (pixmap == nullptr || info == nullptr || pixels == nullptr) return false;
    pixmap->info = *info;
    pixmap->pixmap.reset(toImageInfo(*info), pixels, rowBytes);
    return !pixmap->pixmap.isEmpty();
}

int32_t skc_pixmap_width(const skc_pixmap_t *p) { return p == nullptr ? 0 : p->pixmap.width(); }
int32_t skc_pixmap_height(const skc_pixmap_t *p) { return p == nullptr ? 0 : p->pixmap.height(); }
size_t skc_pixmap_row_bytes(const skc_pixmap_t *p) {
    return p == nullptr ? 0 : p->pixmap.rowBytes();
}
const skc_imageinfo_t *skc_pixmap_image_info(const skc_pixmap_t *p) {
    return p == nullptr ? nullptr : &p->info;
}
void *skc_pixmap_pixels(const skc_pixmap_t *p) {
    return p == nullptr ? nullptr : const_cast<void *>(p->pixmap.addr());
}
bool skc_pixmap_read_pixels(const skc_pixmap_t *src, const skc_imageinfo_t *dstInfo,
                            void *dstPixels, size_t dstRowBytes) {
    if (src == nullptr || dstInfo == nullptr || dstPixels == nullptr) return false;
    return src->pixmap.readPixels(toImageInfo(*dstInfo), dstPixels, dstRowBytes);
}

/* ================================================================== */
/* Surface                                                             */
/* ================================================================== */

skc_surface_t *skc_surface_new_raster(const skc_imageinfo_t *info) {
    clearError();
    if (info == nullptr) {
        setError("skc_surface_new_raster: info is required");
        return nullptr;
    }
    sk_sp<SkSurface> s = SkSurfaces::Raster(toImageInfo(*info));
    if (!s) {
        setError("skc_surface_new_raster: invalid dimensions or colour type");
        return nullptr;
    }
    skc_surface_t *h = new (std::nothrow) skc_surface;
    if (h == nullptr) {
        setError("skc_surface_new_raster: out of memory");
        return nullptr;
    }
    h->sp = std::move(s);
    h->canvas.canvas = h->sp->getCanvas();
    return h;
}

skc_surface_t *skc_surface_new_raster_with_row_bytes(const skc_imageinfo_t *info,
                                                     size_t rowBytes) {
    clearError();
    if (info == nullptr) {
        setError("skc_surface_new_raster_with_row_bytes: info is required");
        return nullptr;
    }
    sk_sp<SkSurface> s = SkSurfaces::Raster(toImageInfo(*info), rowBytes, nullptr);
    if (!s) {
        setError("skc_surface_new_raster_with_row_bytes: invalid info or rowBytes");
        return nullptr;
    }
    skc_surface_t *h = new (std::nothrow) skc_surface;
    if (h == nullptr) {
        setError("skc_surface_new_raster_with_row_bytes: out of memory");
        return nullptr;
    }
    h->sp = std::move(s);
    h->canvas.canvas = h->sp->getCanvas();
    return h;
}

skc_surface_t *skc_surface_new_raster_direct(const skc_imageinfo_t *info, void *pixels,
                                             size_t rowBytes) {
    clearError();
    if (info == nullptr || pixels == nullptr) {
        setError("skc_surface_new_raster_direct: info and pixels are required");
        return nullptr;
    }
    sk_sp<SkSurface> s = SkSurfaces::WrapPixels(toImageInfo(*info), pixels, rowBytes);
    if (!s) {
        setError("skc_surface_new_raster_direct: invalid info or rowBytes");
        return nullptr;
    }
    skc_surface_t *h = new (std::nothrow) skc_surface;
    if (h == nullptr) {
        setError("skc_surface_new_raster_direct: out of memory");
        return nullptr;
    }
    h->sp = std::move(s);
    h->canvas.canvas = h->sp->getCanvas();
    return h;
}

skc_surface_t *skc_surface_new_raster_owned(const skc_imageinfo_t *info, void *pixels,
                                            size_t rowBytes, skc_release_proc release,
                                            void *releaseCtx) {
    clearError();
    if (info == nullptr || pixels == nullptr) {
        setError("skc_surface_new_raster_owned: info and pixels are required");
        return nullptr;
    }
    if (release == nullptr) {
        setError("skc_surface_new_raster_owned: a release proc is required, because the "
                 "surface keeps these pixels alive; use skc_surface_new_raster_direct to "
                 "borrow memory you manage yourself");
        return nullptr;
    }
    struct ReleaseCtx {
        skc_release_proc proc;
        void *ctx;
        static void Run(const void *, void *p) {
            ReleaseCtx *self = static_cast<ReleaseCtx *>(p);
            self->proc(self->ctx);
            delete self;
        }
    };
    ReleaseCtx *rc = new (std::nothrow) ReleaseCtx;
    if (rc == nullptr) {
        setError("skc_surface_new_raster_owned: out of memory");
        return nullptr;
    }
    rc->proc = release;
    rc->ctx = releaseCtx ? releaseCtx : pixels;
    sk_sp<SkData> data =
        SkData::MakeWithProc(pixels, rowBytes * static_cast<size_t>(info->height),
                            &ReleaseCtx::Run, rc);
    if (!data) {
        setError("skc_surface_new_raster_owned: could not take ownership of the pixels");
        ReleaseCtx::Run(pixels, rc);
        return nullptr;
    }
    sk_sp<SkSurface> s = SkSurfaces::WrapPixels(toImageInfo(*info), pixels, rowBytes);
    if (!s) {
        setError("skc_surface_new_raster_owned: invalid info or rowBytes");
        return nullptr;
    }
    skc_surface_t *h = new (std::nothrow) skc_surface;
    if (h == nullptr) {
        setError("skc_surface_new_raster_owned: out of memory");
        return nullptr;
    }
    h->sp = std::move(s);
    h->pixelData = std::move(data);  // keeps `pixels` alive for the surface's lifetime
    h->canvas.canvas = h->sp->getCanvas();
    return h;
}

skc_surface_t *skc_surface_ref(skc_surface_t *surface) {
    if (surface == nullptr) return nullptr;
    skc_surface_t *h = new (std::nothrow) skc_surface;
    if (h == nullptr) {
        setError("skc_surface_ref: out of memory");
        return nullptr;
    }
    h->sp = surface->sp;
    h->canvas.canvas = h->sp->getCanvas();
    return h;
}

void skc_surface_unref(skc_surface_t *surface) { delete surface; }

int32_t skc_surface_width(const skc_surface_t *s) { return s == nullptr ? 0 : s->sp->width(); }
int32_t skc_surface_height(const skc_surface_t *s) { return s == nullptr ? 0 : s->sp->height(); }

skc_canvas_t *skc_surface_get_canvas(skc_surface_t *surface) {
    return surface == nullptr ? nullptr : &surface->canvas;
}

void skc_surface_flush(skc_surface_t *surface) {
    (void)surface;  // raster surfaces draw synchronously; nothing to flush
}
void skc_surface_flush_and_submit(skc_surface_t *surface) {
    (void)surface;  // no GPU backend yet; kept for API symmetry
}

skc_image_t *skc_surface_make_image_snapshot(skc_surface_t *surface) {
    clearError();
    if (surface == nullptr) {
        setError("skc_surface_make_image_snapshot: surface is NULL");
        return nullptr;
    }
    sk_sp<SkImage> img = surface->sp->makeImageSnapshot();
    if (!img) {
        setError("skc_surface_make_image_snapshot: failed");
        return nullptr;
    }
    skc_image_t *h = new (std::nothrow) skc_image;
    if (h == nullptr) {
        setError("skc_surface_make_image_snapshot: out of memory");
        return nullptr;
    }
    h->sp = std::move(img);
    return h;
}

bool skc_surface_read_pixels(skc_surface_t *surface, const skc_imageinfo_t *dstInfo,
                             void *dstPixels, size_t dstRowBytes) {
    if (surface == nullptr || dstInfo == nullptr || dstPixels == nullptr) return false;
    return surface->sp->readPixels(toImageInfo(*dstInfo), dstPixels, dstRowBytes, 0, 0);
}

skc_pixmap_t *skc_surface_peek_pixels(skc_surface_t *surface) {
    clearError();
    if (surface == nullptr) return nullptr;
    SkPixmap pm;
    if (!surface->sp->peekPixels(&pm)) {
        setError("skc_surface_peek_pixels: not a raster surface");
        return nullptr;
    }
    skc_pixmap_t *h = new (std::nothrow) skc_pixmap;
    if (h == nullptr) {
        setError("skc_surface_peek_pixels: out of memory");
        return nullptr;
    }
    h->info = fromImageInfo(pm.info());
    h->pixmap.reset(pm.info(), pm.addr(), pm.rowBytes());
    return h;
}

}  // extern "C"

/* ================================================================== */
/* Canvas                                                              */
/* ================================================================== */

namespace {
const SkPaint kDefaultPaint;
const SkPaint &paintOr(const skc_paint_t *p) { return p == nullptr ? kDefaultPaint : p->paint; }
SkCanvas *c(skc_canvas_t *c) { return c == nullptr ? nullptr : c->canvas; }
}  // namespace

extern "C" {

int skc_canvas_save(skc_canvas_t *canvas) { return c(canvas) ? c(canvas)->save() : -1; }

int skc_canvas_save_layer(skc_canvas_t *canvas, const skc_paint_t *paint) {
    if (!c(canvas)) return -1;
    return c(canvas)->saveLayer(nullptr, paint == nullptr ? nullptr : &paint->paint);
}

void skc_canvas_restore(skc_canvas_t *canvas, int saveCount) {
    if (c(canvas)) c(canvas)->restoreToCount(saveCount);
}

int skc_canvas_get_save_count(const skc_canvas_t *canvas) {
    return c(const_cast<skc_canvas_t *>(canvas)) ? c(const_cast<skc_canvas_t *>(canvas))->getSaveCount()
                                                  : -1;
}

void skc_canvas_clip_rect(skc_canvas_t *canvas, const skc_rect_t *rect, bool antiAlias) {
    if (c(canvas) && rect) c(canvas)->clipRect(toSkRect(*rect), antiAlias);
}

void skc_canvas_clip_path(skc_canvas_t *canvas, const skc_path_t *path, bool antiAlias) {
    /* For an inverted clip, give the path an inverse fill type before calling. */
    if (c(canvas) && path) c(canvas)->clipPath(path->path(), antiAlias);
}

void skc_canvas_draw_color(skc_canvas_t *canvas, skc_color_t color, skc_blendmode_t mode) {
    if (c(canvas)) c(canvas)->drawColor(toSkColor(color), static_cast<SkBlendMode>(mode));
}

void skc_canvas_draw_rect(skc_canvas_t *canvas, const skc_rect_t *rect,
                          const skc_paint_t *paint) {
    if (c(canvas) && rect) c(canvas)->drawRect(toSkRect(*rect), paintOr(paint));
}

void skc_canvas_draw_oval(skc_canvas_t *canvas, const skc_rect_t *oval,
                          const skc_paint_t *paint) {
    if (c(canvas) && oval) c(canvas)->drawOval(toSkRect(*oval), paintOr(paint));
}

void skc_canvas_draw_circle(skc_canvas_t *canvas, float cx, float cy, float radius,
                            const skc_paint_t *paint) {
    if (c(canvas)) c(canvas)->drawCircle(cx, cy, radius, paintOr(paint));
}

void skc_canvas_draw_line(skc_canvas_t *canvas, float x0, float y0, float x1, float y1,
                          const skc_paint_t *paint) {
    if (c(canvas)) c(canvas)->drawLine(x0, y0, x1, y1, paintOr(paint));
}

void skc_canvas_draw_points(skc_canvas_t *canvas, skc_point_t *points, size_t count,
                            skc_pointmode_t mode, const skc_paint_t *paint) {
    if (c(canvas) && points && count > 0) {
        c(canvas)->drawPoints(static_cast<SkCanvas::PointMode>(mode),
                              SkSpan(reinterpret_cast<const SkPoint *>(points), count),
                              paintOr(paint));
    }
}

void skc_canvas_draw_path(skc_canvas_t *canvas, const skc_path_t *path,
                          const skc_paint_t *paint) {
    if (c(canvas) && path) c(canvas)->drawPath(path->path(), paintOr(paint));
}

void skc_canvas_draw_image(skc_canvas_t *canvas, const skc_image_t *image, float x, float y,
                           const skc_paint_t *paint) {
    if (c(canvas) && image) {
        c(canvas)->drawImage(image->sp.get(), x, y, SkSamplingOptions(),
                             paint == nullptr ? nullptr : &paint->paint);
    }
}

void skc_canvas_draw_image_rect(skc_canvas_t *canvas, const skc_image_t *image,
                                const skc_rect_t *src, const skc_rect_t *dst,
                                skc_filtermode_t filter, skc_mipmapmode_t mipmap,
                                const skc_paint_t *paint) {
    if (!c(canvas) || !image || !src || !dst) return;
    c(canvas)->drawImageRect(image->sp.get(), toSkRect(*src), toSkRect(*dst),
                             toSampling(filter, mipmap), paint == nullptr ? nullptr : &paint->paint,
                             SkCanvas::kFast_SrcRectConstraint);
}

void skc_canvas_draw_text(skc_canvas_t *canvas, const char *text, size_t length, float x,
                          float y, const skc_font_t *font, const skc_paint_t *paint) {
    if (!c(canvas) || !text || !font || length == 0) return;
    sk_sp<SkTextBlob> blob =
        SkTextBlob::MakeFromText(text, length, font->font, SkTextEncoding::kUTF8);
    if (blob) c(canvas)->drawTextBlob(blob.get(), x, y, paintOr(paint));
}

void skc_canvas_draw_text_blob(skc_canvas_t *canvas, const skc_text_blob_t *blob, float x,
                               float y, const skc_paint_t *paint) {
    if (c(canvas) && blob) c(canvas)->drawTextBlob(blob->sp.get(), x, y, paintOr(paint));
}

void skc_canvas_translate(skc_canvas_t *canvas, float dx, float dy) {
    if (c(canvas)) c(canvas)->translate(dx, dy);
}
void skc_canvas_scale(skc_canvas_t *canvas, float sx, float sy) {
    if (c(canvas)) c(canvas)->scale(sx, sy);
}
void skc_canvas_rotate(skc_canvas_t *canvas, float degrees) {
    if (c(canvas)) c(canvas)->rotate(degrees);
}
void skc_canvas_concat(skc_canvas_t *canvas, const skc_matrix_t *matrix) {
    if (c(canvas) && matrix) c(canvas)->concat(toSkMatrix(*matrix));
}
void skc_canvas_set_matrix(skc_canvas_t *canvas, const skc_matrix_t *matrix) {
    if (c(canvas) && matrix) c(canvas)->setMatrix(toSkMatrix(*matrix));
}
void skc_canvas_reset_matrix(skc_canvas_t *canvas) {
    if (c(canvas)) c(canvas)->resetMatrix();
}
skc_irect_t skc_canvas_get_device_clip_bounds(const skc_canvas_t *canvas) {
    if (!canvas || !canvas->canvas) return skc_irect_t{0, 0, 0, 0};
    return fromSkIRect(canvas->canvas->getDeviceClipBounds());
}

/* ================================================================== */
/* Paint                                                               */
/* ================================================================== */

skc_paint_t *skc_paint_new(void) {
    clearError();
    skc_paint_t *h = new (std::nothrow) skc_paint;
    if (h == nullptr) setError("skc_paint_new: out of memory");
    return h;
}

skc_paint_t *skc_paint_new_copy(const skc_paint_t *src) {
    clearError();
    skc_paint_t *h = new (std::nothrow) skc_paint;
    if (h == nullptr) {
        setError("skc_paint_new_copy: out of memory");
        return nullptr;
    }
    if (src) h->paint = src->paint;
    return h;
}

void skc_paint_free(skc_paint_t *paint) { delete paint; }
void skc_paint_reset(skc_paint_t *paint) {
    if (paint) paint->paint = SkPaint();
}

void skc_paint_set_style(skc_paint_t *p, skc_paintstyle_t s) {
    if (p) p->paint.setStyle(static_cast<SkPaint::Style>(s));
}
skc_paintstyle_t skc_paint_get_style(const skc_paint_t *p) {
    return p ? static_cast<skc_paintstyle_t>(p->paint.getStyle()) : SKC_PAINT_STYLE_FILL;
}
void skc_paint_set_color(skc_paint_t *p, skc_color_t color) {
    if (p) p->paint.setColor4f(toSkColor(color));
}
skc_color_t skc_paint_get_color(const skc_paint_t *p) {
    return p ? fromSkColor(p->paint.getColor4f()) : skc_color_t{0, 0, 0, 0};
}
void skc_paint_set_stroke_width(skc_paint_t *p, float w) {
    if (p) p->paint.setStrokeWidth(w);
}
float skc_paint_get_stroke_width(const skc_paint_t *p) { return p ? p->paint.getStrokeWidth() : 0; }
void skc_paint_set_stroke_miter(skc_paint_t *p, float m) {
    if (p) p->paint.setStrokeMiter(m);
}
float skc_paint_get_stroke_miter(const skc_paint_t *p) { return p ? p->paint.getStrokeMiter() : 0; }
void skc_paint_set_stroke_cap(skc_paint_t *p, skc_strokecap_t c) {
    if (p) p->paint.setStrokeCap(static_cast<SkPaint::Cap>(c));
}
skc_strokecap_t skc_paint_get_stroke_cap(const skc_paint_t *p) {
    return p ? static_cast<skc_strokecap_t>(p->paint.getStrokeCap()) : SKC_STROKE_CAP_BUTT;
}
void skc_paint_set_stroke_join(skc_paint_t *p, skc_strokejoin_t j) {
    if (p) p->paint.setStrokeJoin(static_cast<SkPaint::Join>(j));
}
skc_strokejoin_t skc_paint_get_stroke_join(const skc_paint_t *p) {
    return p ? static_cast<skc_strokejoin_t>(p->paint.getStrokeJoin()) : SKC_STROKE_JOIN_MITER;
}
void skc_paint_set_anti_alias(skc_paint_t *p, bool aa) {
    if (p) p->paint.setAntiAlias(aa);
}
bool skc_paint_get_anti_alias(const skc_paint_t *p) { return p && p->paint.isAntiAlias(); }
void skc_paint_set_blend_mode(skc_paint_t *p, skc_blendmode_t m) {
    if (p) p->paint.setBlendMode(static_cast<SkBlendMode>(m));
}
skc_blendmode_t skc_paint_get_blend_mode(const skc_paint_t *p) {
    return p ? static_cast<skc_blendmode_t>(p->paint.getBlendMode_or(SkBlendMode::kSrcOver))
             : SKC_BLEND_MODE_SRC_OVER;
}
void skc_paint_set_dither(skc_paint_t *p, bool dither) {
    if (p) p->paint.setDither(dither);
}
bool skc_paint_get_dither(const skc_paint_t *p) { return p && p->paint.isDither(); }
void skc_paint_set_shader(skc_paint_t *p, skc_shader_t *shader) {
    if (p) p->paint.setShader(shader ? shader->sp : nullptr);
}
void skc_paint_set_image_filter(skc_paint_t *p, skc_image_filter_t *f) {
    if (p) p->paint.setImageFilter(f ? f->sp : nullptr);
}
void skc_paint_set_path_effect(skc_paint_t *p, skc_path_effect_t *e) {
    if (p) p->paint.setPathEffect(e ? e->sp : nullptr);
}
void skc_paint_set_color_filter(skc_paint_t *p, skc_color_filter_t *f) {
    if (p) p->paint.setColorFilter(f ? f->sp : nullptr);
}

/* ================================================================== */
/* Path                                                                */
/* ================================================================== */

skc_path_t *skc_path_new(void) {
    clearError();
    skc_path_t *h = new (std::nothrow) skc_path;
    if (h == nullptr) setError("skc_path_new: out of memory");
    return h;
}

skc_path_t *skc_path_new_copy(const skc_path_t *src) {
    clearError();
    skc_path_t *h = new (std::nothrow) skc_path;
    if (h == nullptr) {
        setError("skc_path_new_copy: out of memory");
        return nullptr;
    }
    if (src) h->builder.addPath(src->path());
    return h;
}

void skc_path_free(skc_path_t *path) { delete path; }
void skc_path_reset(skc_path_t *p) {
    if (p) {
        p->builder.reset();
        p->touch();
    }
}
void skc_path_set_fill_type(skc_path_t *p, skc_filltype_t ft) {
    if (p) {
        p->fillType = static_cast<SkPathFillType>(ft);
        p->builder.setFillType(p->fillType);
        p->touch();
    }
}
skc_filltype_t skc_path_get_fill_type(const skc_path_t *p) {
    return p ? static_cast<skc_filltype_t>(static_cast<int>(p->path().getFillType()))
             : SKC_FILL_TYPE_WINDING;
}
void skc_path_move_to(skc_path_t *p, float x, float y) {
    if (p) {
        p->builder.moveTo(x, y);
        p->touch();
    }
}
void skc_path_line_to(skc_path_t *p, float x, float y) {
    if (p) {
        p->builder.lineTo(x, y);
        p->touch();
    }
}
void skc_path_quad_to(skc_path_t *p, float x1, float y1, float x2, float y2) {
    if (p) {
        p->builder.quadTo(x1, y1, x2, y2);
        p->touch();
    }
}
void skc_path_cubic_to(skc_path_t *p, float x1, float y1, float x2, float y2, float x3,
                       float y3) {
    if (p) {
        p->builder.cubicTo(x1, y1, x2, y2, x3, y3);
        p->touch();
    }
}
void skc_path_conic_to(skc_path_t *p, float x1, float y1, float x2, float y2, float w) {
    if (p) {
        p->builder.conicTo(x1, y1, x2, y2, w);
        p->touch();
    }
}
void skc_path_close(skc_path_t *p) {
    if (p) {
        p->builder.close();
        p->touch();
    }
}
void skc_path_add_rect(skc_path_t *p, const skc_rect_t *rect, bool clockwise) {
    if (p && rect) {
        p->builder.addRect(toSkRect(*rect),
                           clockwise ? SkPathDirection::kCW : SkPathDirection::kCCW);
        p->touch();
    }
}
void skc_path_add_oval(skc_path_t *p, const skc_rect_t *oval, bool clockwise) {
    if (p && oval) {
        p->builder.addOval(toSkRect(*oval),
                           clockwise ? SkPathDirection::kCW : SkPathDirection::kCCW);
        p->touch();
    }
}
void skc_path_add_circle(skc_path_t *p, float cx, float cy, float radius, bool clockwise) {
    if (p) {
        p->builder.addCircle(cx, cy, radius,
                             clockwise ? SkPathDirection::kCW : SkPathDirection::kCCW);
        p->touch();
    }
}
void skc_path_add_arc(skc_path_t *p, const skc_rect_t *oval, float startAngleDeg,
                      float sweepAngleDeg, bool forceMoveTo) {
    if (p && oval) {
        if (forceMoveTo) p->builder.moveTo(oval->left, oval->top);
        p->builder.addArc(toSkRect(*oval), startAngleDeg, sweepAngleDeg);
        p->touch();
    }
}
void skc_path_add_poly(skc_path_t *p, const skc_point_t *points, size_t count, bool isClosed) {
    if (p && points && count > 0) {
        p->builder.addPolygon(
            SkSpan(reinterpret_cast<const SkPoint *>(points), count), isClosed);
        p->touch();
    }
}
void skc_path_transform(skc_path_t *p, const skc_matrix_t *matrix) {
    if (p && matrix) {
        p->builder.transform(toSkMatrix(*matrix));
        p->touch();
    }
}
bool skc_path_is_empty(const skc_path_t *p) { return p == nullptr || p->path().isEmpty(); }
bool skc_path_is_finite(const skc_path_t *p) { return p && p->path().isFinite(); }
size_t skc_path_count_verbs(const skc_path_t *p) {
    return p ? static_cast<size_t>(p->path().countVerbs()) : 0;
}
skc_rect_t skc_path_get_bounds(const skc_path_t *p) {
    return p ? fromSkRect(p->path().getBounds()) : skc_rect_t{0, 0, 0, 0};
}
skc_rect_t skc_path_compute_tight_bounds(const skc_path_t *p) {
    return p ? fromSkRect(p->path().computeTightBounds()) : skc_rect_t{0, 0, 0, 0};
}
bool skc_path_contains_point(const skc_path_t *p, float x, float y) {
    return p && p->path().contains(x, y);
}

/* ================================================================== */
/* Image                                                               */
/* ================================================================== */

skc_image_t *skc_image_new_from_encoded(const skc_data_t *encoded) {
    clearError();
    if (encoded == nullptr) {
        setError("skc_image_new_from_encoded: encoded is NULL");
        return nullptr;
    }
    sk_sp<SkImage> img = SkImages::DeferredFromEncodedData(encoded->sp);
    if (!img) {
        setError("skc_image_new_from_encoded: unsupported or corrupt image data");
        return nullptr;
    }
    skc_image_t *h = new (std::nothrow) skc_image;
    if (h == nullptr) {
        setError("skc_image_new_from_encoded: out of memory");
        return nullptr;
    }
    h->sp = std::move(img);
    return h;
}

skc_image_t *skc_image_new_from_pixmap_copy(const skc_pixmap_t *pixmap) {
    clearError();
    if (pixmap == nullptr) {
        setError("skc_image_new_from_pixmap_copy: pixmap is NULL");
        return nullptr;
    }
    sk_sp<SkImage> img = SkImages::RasterFromPixmapCopy(pixmap->pixmap);
    if (!img) {
        setError("skc_image_new_from_pixmap_copy: failed");
        return nullptr;
    }
    skc_image_t *h = new (std::nothrow) skc_image;
    if (h == nullptr) {
        setError("skc_image_new_from_pixmap_copy: out of memory");
        return nullptr;
    }
    h->sp = std::move(img);
    return h;
}

skc_image_t *skc_image_new_from_pixels_copy(const skc_imageinfo_t *info, void *pixels,
                                            size_t rowBytes, skc_release_proc release,
                                            void *releaseCtx) {
    clearError();
    if (info == nullptr || pixels == nullptr) {
        setError("skc_image_new_from_pixels_copy: info and pixels are required");
        return nullptr;
    }
    /* The copy means the caller's buffer is free the moment this returns. The
       buffer is never freed here: it may be GC-managed or stack memory. */
    sk_sp<SkData> data =
        SkData::MakeWithCopy(pixels, rowBytes * static_cast<size_t>(info->height));
    if (release != nullptr) release(releaseCtx != nullptr ? releaseCtx : pixels);
    if (!data) {
        setError("skc_image_new_from_pixels_copy: allocation failed");
        return nullptr;
    }
    sk_sp<SkImage> img = SkImages::RasterFromData(toImageInfo(*info), data, rowBytes);
    if (!img) {
        setError("skc_image_new_from_pixels_copy: invalid info or rowBytes");
        return nullptr;
    }
    skc_image_t *h = new (std::nothrow) skc_image;
    if (h == nullptr) {
        setError("skc_image_new_from_pixels_copy: out of memory");
        return nullptr;
    }
    h->sp = std::move(img);
    return h;
}

skc_image_t *skc_image_ref(skc_image_t *image) {
    if (image == nullptr) return nullptr;
    skc_image_t *h = new (std::nothrow) skc_image;
    if (h == nullptr) {
        setError("skc_image_ref: out of memory");
        return nullptr;
    }
    h->sp = image->sp;
    return h;
}

void skc_image_unref(skc_image_t *image) { delete image; }

int32_t skc_image_width(const skc_image_t *i) { return i == nullptr ? 0 : i->sp->width(); }
int32_t skc_image_height(const skc_image_t *i) { return i == nullptr ? 0 : i->sp->height(); }
skc_colortype_t skc_image_get_color_type(const skc_image_t *i) {
    return i ? static_cast<skc_colortype_t>(static_cast<int>(i->sp->colorType()))
             : SKC_COLOR_TYPE_UNKNOWN;
}
skc_alphatype_t skc_image_get_alpha_type(const skc_image_t *i) {
    return i ? static_cast<skc_alphatype_t>(static_cast<int>(i->sp->alphaType()))
             : SKC_ALPHA_TYPE_UNKNOWN;
}

skc_data_t *skc_image_get_encoded_data(const skc_image_t *image) {
    clearError();
    if (image == nullptr) return nullptr;
    sk_sp<const SkData> data = image->sp->refEncodedData();
    if (!data) return nullptr;
    skc_data_t *h = new (std::nothrow) skc_data;
    if (h == nullptr) {
        setError("skc_image_get_encoded_data: out of memory");
        return nullptr;
    }
    h->sp = data;
    return h;
}

skc_data_t *skc_image_encode(const skc_image_t *image, skc_encodedformat_t format, int quality) {
    clearError();
    if (image == nullptr) {
        setError("skc_image_encode: image is NULL");
        return nullptr;
    }
    sk_sp<SkImage> raster = ensureRaster(image->sp);
    SkPixmap pm;
    if (!raster || !raster->peekPixels(&pm)) {
        setError("skc_image_encode: image could not be rasterized");
        return nullptr;
    }
    const int q = SkTo<int>(SkTPin(quality, 0, 100));
    sk_sp<SkData> out;
    switch (static_cast<SkEncodedImageFormat>(format)) {
    case SkEncodedImageFormat::kPNG: {
        SkPngEncoder::Options options;
        out = SkPngEncoder::Encode(pm, options);
        break;
    }
    case SkEncodedImageFormat::kJPEG: {
        SkJpegEncoder::Options options;
        options.fQuality = q;
        out = SkJpegEncoder::Encode(pm, options);
        break;
    }
    default:
        setError("skc_image_encode: only PNG and JPEG are supported by this build");
        return nullptr;
    }
    if (!out) {
        setError("skc_image_encode: encoding failed");
        return nullptr;
    }
    skc_data_t *h = new (std::nothrow) skc_data;
    if (h == nullptr) {
        setError("skc_image_encode: out of memory");
        return nullptr;
    }
    h->sp = std::move(out);
    return h;
}

bool skc_image_read_pixels(const skc_image_t *image, const skc_imageinfo_t *dstInfo,
                           void *dstPixels, size_t dstRowBytes) {
    if (image == nullptr || dstInfo == nullptr || dstPixels == nullptr) return false;
    return image->sp->readPixels(toImageInfo(*dstInfo), dstPixels, dstRowBytes, 0, 0);
}

skc_pixmap_t *skc_image_new_pixmap_from_image(const skc_image_t *image) {
    clearError();
    if (image == nullptr) return nullptr;
    sk_sp<SkImage> raster = ensureRaster(image->sp);
    SkPixmap pm;
    if (!raster || !raster->peekPixels(&pm)) {
        setError("skc_image_new_pixmap_from_image: image could not be rasterized");
        return nullptr;
    }
    skc_pixmap_t *h = new (std::nothrow) skc_pixmap;
    if (h == nullptr) {
        setError("skc_image_new_pixmap_from_image: out of memory");
        return nullptr;
    }
    h->info = fromImageInfo(pm.info());
    h->pixmap.reset(pm.info(), pm.addr(), pm.rowBytes());
    return h;
}

/* ================================================================== */
/* Shaders, filters, effects                                           */
/* ================================================================== */

skc_shader_t *skc_shader_ref(skc_shader_t *s) {
    if (s == nullptr) return nullptr;
    skc_shader_t *h = new (std::nothrow) skc_shader;
    if (h == nullptr) {
        setError("skc_shader_ref: out of memory");
        return nullptr;
    }
    h->sp = s->sp;
    return h;
}
void skc_shader_unref(skc_shader_t *s) { delete s; }

skc_shader_t *skc_shader_new_linear(skc_point_t start, skc_point_t end,
                                    const skc_color_t *colors, const float *positions,
                                    size_t colorCount, skc_tilemode_t tileMode,
                                    const skc_matrix_t *localMatrix) {
    clearError();
    if (colors == nullptr || colorCount == 0) {
        setError("skc_shader_new_linear: at least one colour is required");
        return nullptr;
    }
    SkPoint pts[2] = {SkPoint::Make(start.x, start.y), SkPoint::Make(end.x, end.y)};
    const LocalMatrix lm(localMatrix);
    std::vector<SkColor4f> scratch;
    sk_sp<SkShader> sh = SkShaders::LinearGradient(
        pts, toGradient(colors, positions, colorCount, tileMode, scratch), lm.get());
    if (!sh) {
        setError("skc_shader_new_linear: invalid parameters");
        return nullptr;
    }
    skc_shader_t *h = new (std::nothrow) skc_shader;
    if (h == nullptr) {
        setError("skc_shader_new_linear: out of memory");
        return nullptr;
    }
    h->sp = std::move(sh);
    return h;
}

skc_shader_t *skc_shader_new_radial(float cx, float cy, float radius, const skc_color_t *colors,
                                    const float *positions, size_t colorCount,
                                    skc_tilemode_t tileMode,
                                    const skc_matrix_t *localMatrix) {
    clearError();
    if (colors == nullptr || colorCount == 0) {
        setError("skc_shader_new_radial: at least one colour is required");
        return nullptr;
    }
    const LocalMatrix lm(localMatrix);
    std::vector<SkColor4f> scratch;
    sk_sp<SkShader> sh =
        SkShaders::RadialGradient(SkPoint::Make(cx, cy), radius,
                                  toGradient(colors, positions, colorCount, tileMode, scratch),
                                  lm.get());
    if (!sh) {
        setError("skc_shader_new_radial: invalid parameters");
        return nullptr;
    }
    skc_shader_t *h = new (std::nothrow) skc_shader;
    if (h == nullptr) {
        setError("skc_shader_new_radial: out of memory");
        return nullptr;
    }
    h->sp = std::move(sh);
    return h;
}

skc_shader_t *skc_shader_new_sweep(float cx, float cy, float startAngle, float endAngle,
                                   const skc_color_t *colors, const float *positions,
                                   size_t colorCount, skc_tilemode_t tileMode,
                                   const skc_matrix_t *localMatrix) {
    clearError();
    if (colors == nullptr || colorCount == 0) {
        setError("skc_shader_new_sweep: at least one colour is required");
        return nullptr;
    }
    const LocalMatrix lm(localMatrix);
    std::vector<SkColor4f> scratch;
    sk_sp<SkShader> sh =
        SkShaders::SweepGradient(SkPoint::Make(cx, cy), startAngle, endAngle,
                                 toGradient(colors, positions, colorCount, tileMode, scratch),
                                 lm.get());
    if (!sh) {
        setError("skc_shader_new_sweep: startAngle must be less than endAngle");
        return nullptr;
    }
    skc_shader_t *h = new (std::nothrow) skc_shader;
    if (h == nullptr) {
        setError("skc_shader_new_sweep: out of memory");
        return nullptr;
    }
    h->sp = std::move(sh);
    return h;
}

skc_shader_t *skc_shader_new_two_point_conical(float startX, float startY, float startRadius,
                                               float endX, float endY, float endRadius,
                                               const skc_color_t *colors, const float *positions,
                                               size_t colorCount, skc_tilemode_t tileMode,
                                               const skc_matrix_t *localMatrix) {
    clearError();
    if (colors == nullptr || colorCount == 0) {
        setError("skc_shader_new_two_point_conical: at least one colour is required");
        return nullptr;
    }
    const LocalMatrix lm(localMatrix);
    std::vector<SkColor4f> scratch;
    sk_sp<SkShader> sh = SkShaders::TwoPointConicalGradient(
        SkPoint::Make(startX, startY), startRadius, SkPoint::Make(endX, endY), endRadius,
        toGradient(colors, positions, colorCount, tileMode, scratch), lm.get());
    if (!sh) {
        setError("skc_shader_new_two_point_conical: invalid parameters");
        return nullptr;
    }
    skc_shader_t *h = new (std::nothrow) skc_shader;
    if (h == nullptr) {
        setError("skc_shader_new_two_point_conical: out of memory");
        return nullptr;
    }
    h->sp = std::move(sh);
    return h;
}

skc_image_filter_t *skc_image_filter_ref(skc_image_filter_t *f) {
    if (f == nullptr) return nullptr;
    skc_image_filter_t *h = new (std::nothrow) skc_image_filter;
    if (h == nullptr) {
        setError("skc_image_filter_ref: out of memory");
        return nullptr;
    }
    h->sp = f->sp;
    return h;
}
void skc_image_filter_unref(skc_image_filter_t *f) { delete f; }

skc_image_filter_t *skc_image_filter_new_blur(float sigmaX, float sigmaY,
                                              skc_tilemode_t tileMode) {
    clearError();
    sk_sp<SkImageFilter> f =
        SkImageFilters::Blur(sigmaX, sigmaY, static_cast<SkTileMode>(tileMode), nullptr);
    if (!f) {
        setError("skc_image_filter_new_blur: invalid sigma");
        return nullptr;
    }
    skc_image_filter_t *h = new (std::nothrow) skc_image_filter;
    if (h == nullptr) {
        setError("skc_image_filter_new_blur: out of memory");
        return nullptr;
    }
    h->sp = std::move(f);
    return h;
}

skc_image_filter_t *skc_image_filter_new_color_filter(skc_color_filter_t *input) {
    clearError();
    if (input == nullptr) {
        setError("skc_image_filter_new_color_filter: input is NULL");
        return nullptr;
    }
    sk_sp<SkImageFilter> f = SkImageFilters::ColorFilter(input->sp, nullptr);
    if (!f) {
        setError("skc_image_filter_new_color_filter: failed");
        return nullptr;
    }
    skc_image_filter_t *h = new (std::nothrow) skc_image_filter;
    if (h == nullptr) {
        setError("skc_image_filter_new_color_filter: out of memory");
        return nullptr;
    }
    h->sp = std::move(f);
    return h;
}

skc_path_effect_t *skc_path_effect_ref(skc_path_effect_t *e) {
    if (e == nullptr) return nullptr;
    skc_path_effect_t *h = new (std::nothrow) skc_path_effect;
    if (h == nullptr) {
        setError("skc_path_effect_ref: out of memory");
        return nullptr;
    }
    h->sp = e->sp;
    return h;
}
void skc_path_effect_unref(skc_path_effect_t *e) { delete e; }

skc_path_effect_t *skc_path_effect_new_dash(const float *intervals, size_t count, float phase) {
    clearError();
    if (intervals == nullptr || count == 0) {
        setError("skc_path_effect_new_dash: at least one interval is required");
        return nullptr;
    }
    sk_sp<SkPathEffect> e = SkDashPathEffect::Make(SkSpan(intervals, count), phase);
    if (!e) {
        setError("skc_path_effect_new_dash: invalid intervals");
        return nullptr;
    }
    skc_path_effect_t *h = new (std::nothrow) skc_path_effect;
    if (h == nullptr) {
        setError("skc_path_effect_new_dash: out of memory");
        return nullptr;
    }
    h->sp = std::move(e);
    return h;
}

skc_path_effect_t *skc_path_effect_new_corner(float radius) {
    clearError();
    sk_sp<SkPathEffect> e = SkCornerPathEffect::Make(radius);
    if (!e) {
        setError("skc_path_effect_new_corner: invalid radius");
        return nullptr;
    }
    skc_path_effect_t *h = new (std::nothrow) skc_path_effect;
    if (h == nullptr) {
        setError("skc_path_effect_new_corner: out of memory");
        return nullptr;
    }
    h->sp = std::move(e);
    return h;
}

skc_path_effect_t *skc_path_effect_new_discrete(float segLength, float dev, uint32_t seed) {
    clearError();
    sk_sp<SkPathEffect> e = SkDiscretePathEffect::Make(segLength, dev, seed);
    if (!e) {
        setError("skc_path_effect_new_discrete: invalid parameters");
        return nullptr;
    }
    skc_path_effect_t *h = new (std::nothrow) skc_path_effect;
    if (h == nullptr) {
        setError("skc_path_effect_new_discrete: out of memory");
        return nullptr;
    }
    h->sp = std::move(e);
    return h;
}

skc_color_filter_t *skc_color_filter_ref(skc_color_filter_t *f) {
    if (f == nullptr) return nullptr;
    skc_color_filter_t *h = new (std::nothrow) skc_color_filter;
    if (h == nullptr) {
        setError("skc_color_filter_ref: out of memory");
        return nullptr;
    }
    h->sp = f->sp;
    return h;
}
void skc_color_filter_unref(skc_color_filter_t *f) { delete f; }

skc_color_filter_t *skc_color_filter_new_matrix(const float rowMajor[20]) {
    clearError();
    if (rowMajor == nullptr) {
        setError("skc_color_filter_new_matrix: rowMajor is required");
        return nullptr;
    }
    sk_sp<SkColorFilter> f = SkColorFilters::Matrix(rowMajor, SkColorFilters::Clamp::kYes);
    if (!f) {
        setError("skc_color_filter_new_matrix: failed");
        return nullptr;
    }
    skc_color_filter_t *h = new (std::nothrow) skc_color_filter;
    if (h == nullptr) {
        setError("skc_color_filter_new_matrix: out of memory");
        return nullptr;
    }
    h->sp = std::move(f);
    return h;
}

skc_color_filter_t *skc_color_filter_new_table(const uint8_t tableA[256]) {
    clearError();
    if (tableA == nullptr) {
        setError("skc_color_filter_new_table: table is required");
        return nullptr;
    }
    sk_sp<SkColorFilter> f = SkColorFilters::TableARGB(tableA, nullptr, nullptr, nullptr);
    if (!f) {
        setError("skc_color_filter_new_table: failed");
        return nullptr;
    }
    skc_color_filter_t *h = new (std::nothrow) skc_color_filter;
    if (h == nullptr) {
        setError("skc_color_filter_new_table: out of memory");
        return nullptr;
    }
    h->sp = std::move(f);
    return h;
}

/* ================================================================== */
/* Fonts                                                               */
/* ================================================================== */

skc_font_manager_t *skc_font_manager_new(void) {
    clearError();
#if defined(__linux__) || defined(__unix__) || defined(__APPLE__)
    sk_sp<SkFontMgr> mgr = SkFontMgr_New_FontConfig(nullptr, SkFontScanner_Make_FreeType());
#elif defined(_WIN32)
    sk_sp<SkFontMgr> mgr = SkFontMgr_New_DirectWrite();
#else
    sk_sp<SkFontMgr> mgr = SkFontMgr::RefEmpty();
#endif
    if (!mgr) {
        setError("skc_font_manager_new: no font manager available");
        return nullptr;
    }
    skc_font_manager_t *h = new (std::nothrow) skc_font_manager;
    if (h == nullptr) {
        setError("skc_font_manager_new: out of memory");
        return nullptr;
    }
    h->sp = std::move(mgr);
    return h;
}

void skc_font_manager_unref(skc_font_manager_t *m) { delete m; }

int skc_font_manager_get_family_count(const skc_font_manager_t *m) {
    return m == nullptr ? 0 : m->sp->countFamilies();
}

size_t skc_font_manager_get_family_name(const skc_font_manager_t *m, int index, char *buf,
                                        size_t bufSize) {
    if (m == nullptr || index < 0 || index >= m->sp->countFamilies()) return 0;
    SkString name;
    m->sp->getFamilyName(index, &name);
    return copyOut(name, buf, bufSize);
}

skc_typeface_t *skc_font_manager_default_typeface(const skc_font_manager_t *m) {
    clearError();
    if (m == nullptr) {
        setError("skc_font_manager_default_typeface: manager is NULL");
        return nullptr;
    }
    sk_sp<SkTypeface> tf = m->sp->matchFamilyStyle(nullptr, SkFontStyle());
    if (!tf) {
        setError("skc_font_manager_default_typeface: no default font found");
        return nullptr;
    }
    skc_typeface_t *h = new (std::nothrow) skc_typeface;
    if (h == nullptr) {
        setError("skc_font_manager_default_typeface: out of memory");
        return nullptr;
    }
    h->sp = std::move(tf);
    return h;
}

skc_typeface_t *skc_font_manager_match_family_style(const skc_font_manager_t *m,
                                                    const char *family, skc_fontstyle_t style) {
    clearError();
    if (m == nullptr) {
        setError("skc_font_manager_match_family_style: manager is NULL");
        return nullptr;
    }
    sk_sp<SkTypeface> tf = m->sp->matchFamilyStyle(family, toFontStyle(style));
    if (!tf) {
        setError("skc_font_manager_match_family_style: no matching font");
        return nullptr;
    }
    skc_typeface_t *h = new (std::nothrow) skc_typeface;
    if (h == nullptr) {
        setError("skc_font_manager_match_family_style: out of memory");
        return nullptr;
    }
    h->sp = std::move(tf);
    return h;
}

skc_typeface_t *skc_font_manager_typeface_from_file(const skc_font_manager_t *m,
                                                    const char *path, int ttcIndex) {
    clearError();
    if (m == nullptr || path == nullptr) {
        setError("skc_font_manager_typeface_from_file: manager and path are required");
        return nullptr;
    }
    sk_sp<SkTypeface> tf = m->sp->makeFromFile(path, ttcIndex);
    if (!tf) {
        setError("skc_font_manager_typeface_from_file: could not load the font file");
        return nullptr;
    }
    skc_typeface_t *h = new (std::nothrow) skc_typeface;
    if (h == nullptr) {
        setError("skc_font_manager_typeface_from_file: out of memory");
        return nullptr;
    }
    h->sp = std::move(tf);
    return h;
}

skc_typeface_t *skc_typeface_ref(skc_typeface_t *t) {
    if (t == nullptr) return nullptr;
    skc_typeface_t *h = new (std::nothrow) skc_typeface;
    if (h == nullptr) {
        setError("skc_typeface_ref: out of memory");
        return nullptr;
    }
    h->sp = t->sp;
    return h;
}
void skc_typeface_unref(skc_typeface_t *t) { delete t; }

size_t skc_typeface_get_family_name(const skc_typeface_t *t, char *buf, size_t bufSize) {
    if (t == nullptr) return 0;
    SkString name;
    t->sp->getFamilyName(&name);
    return copyOut(name, buf, bufSize);
}

skc_fontstyle_t skc_typeface_get_style(const skc_typeface_t *t) {
    return t ? fromFontStyle(t->sp->fontStyle()) : skc_fontstyle_normal();
}
bool skc_typeface_is_bold(const skc_typeface_t *t) {
    return t && t->sp->fontStyle().weight() >= SkFontStyle::kSemiBold_Weight;
}
bool skc_typeface_is_italic(const skc_typeface_t *t) {
    return t && t->sp->fontStyle().slant() != SkFontStyle::kUpright_Slant;
}

skc_font_t *skc_font_new(skc_typeface_t *typeface, float size) {
    clearError();
    skc_font_t *h = new (std::nothrow) skc_font;
    if (h == nullptr) {
        setError("skc_font_new: out of memory");
        return nullptr;
    }
    if (typeface) {
        h->font.setTypeface(typeface->sp);
    } else if (skc_font_manager_t *mgr = skc_font_manager_new()) {
        if (sk_sp<SkTypeface> tf = mgr->sp->matchFamilyStyle(nullptr, SkFontStyle())) {
            h->font.setTypeface(std::move(tf));
        }
        skc_font_manager_unref(mgr);
    }
    h->font.setSize(size);
    return h;
}

void skc_font_free(skc_font_t *f) { delete f; }
float skc_font_get_size(const skc_font_t *f) { return f ? f->font.getSize() : 0; }
void skc_font_set_size(skc_font_t *f, float s) {
    if (f) f->font.setSize(s);
}
void skc_font_set_edging(skc_font_t *f, skc_fongedging_t e) {
    if (f) f->font.setEdging(static_cast<SkFont::Edging>(e));
}
void skc_font_set_hinting(skc_font_t *f, skc_hinting_t h) {
    if (f) f->font.setHinting(static_cast<SkFontHinting>(h));
}
void skc_font_set_subpixel(skc_font_t *f, bool s) {
    if (f) f->font.setSubpixel(s);
}
void skc_font_set_embolden(skc_font_t *f, bool e) {
    if (f) f->font.setEmbolden(e);
}
void skc_font_set_scale_x(skc_font_t *f, float sx) {
    if (f) f->font.setScaleX(sx);
}

float skc_font_get_spacing(const skc_font_t *f) { return f ? f->font.getSpacing() : 0; }

bool skc_font_get_metrics(const skc_font_t *f, skc_fontmetrics_t *out) {
    if (f == nullptr || out == nullptr) return false;
    SkFontMetrics m;
    f->font.getMetrics(&m);
    out->ascent = m.fAscent;
    out->descent = m.fDescent;
    out->leading = m.fLeading;
    out->top = m.fTop;
    out->bottom = m.fBottom;
    out->xMin = m.fXMin;
    out->xMax = m.fXMax;
    return true;
}

float skc_font_measure_text(const skc_font_t *f, const char *text, size_t length,
                            skc_rect_t *bounds) {
    if (f == nullptr || text == nullptr) return 0;
    SkRect b;
    const float adv = f->font.measureText(text, length, SkTextEncoding::kUTF8, &b);
    if (bounds != nullptr) *bounds = fromSkRect(b);
    return adv;
}

float skc_font_get_ascent(const skc_font_t *f) {
    if (f == nullptr) return 0;
    SkFontMetrics m;
    f->font.getMetrics(&m);
    return m.fAscent;
}

float skc_font_get_descent(const skc_font_t *f) {
    if (f == nullptr) return 0;
    SkFontMetrics m;
    f->font.getMetrics(&m);
    return m.fDescent;
}

/* ================================================================== */
/* Text blobs                                                          */
/* ================================================================== */

skc_text_blob_t *skc_text_blob_new(const char *text, size_t length,
                                   const skc_font_t *font) {
    clearError();
    if (text == nullptr || font == nullptr || length == 0) {
        setError("skc_text_blob_new: text, font and a non-zero length are required");
        return nullptr;
    }
    sk_sp<SkTextBlob> b =
        SkTextBlob::MakeFromText(text, length, font->font, SkTextEncoding::kUTF8);
    if (!b) {
        setError("skc_text_blob_new: failed");
        return nullptr;
    }
    skc_text_blob_t *h = new (std::nothrow) skc_text_blob;
    if (h == nullptr) {
        setError("skc_text_blob_new: out of memory");
        return nullptr;
    }
    h->sp = std::move(b);
    return h;
}

void skc_text_blob_unref(skc_text_blob_t *b) { delete b; }

void skc_text_blob_get_bounds(const skc_text_blob_t *b, skc_rect_t *bounds) {
    if (b == nullptr || bounds == nullptr) return;
    *bounds = fromSkRect(b->sp->bounds());
}

}  // extern "C"
