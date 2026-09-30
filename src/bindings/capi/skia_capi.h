/*
 * skia_capi.h - a stable C ABI over the Skia 2D graphics library.
 *
 * Skia itself is a C++ library with no C API of its own (the experimental
 * C API was removed upstream in 2023). This header is the C ABI that the
 * Nim binding in `src/bindings/skia_raw.nim` binds against; the C++
 * implementation lives in `skia_capi.cpp`.
 *
 * Conventions
 * -----------
 * Naming       all symbols are prefixed `skc_`.
 * Handles      objects with identity or reference counting are opaque
 *              pointers (`skc_surface_t`, `skc_paint_t`, ...).
 * Value types  small trivially-copyable geometry/colour structs are passed
 *              and returned by value.
 * Enums        plain C enums. Every value is `static_assert`ed against the
 *              corresponding Skia enum in skia_capi.cpp, so an upstream
 *              change breaks the build instead of corrupting memory.
 * Errors       creation functions return NULL on failure. A thread-local
 *              description of the most recent failure is available from
 *              `skc_last_error`.
 *
 * Ownership
 * ---------
 * A function whose name begins with `skc_<type>_new`, `_create`, `_decode`,
 * `_ref` or `_from` returns a handle that the caller owns and must release
 * with the matching `skc_<type>_free` / `skc_<type>_unref`.
 * A function named `skc_<type>_get_*` or `skc_<type>_peek_*` returns a
 * borrowed reference that stays valid only while the owning object is.
 * Handles for reference-counted Skia types (data, image, surface, shader,
 * image filter, path effect, colour filter, typeface, font manager) also
 * provide `_ref`; releasing is then simply balancing `_ref` with `_unref`.
 *
 * The single exception to "caller owns pixel memory" is documented on the
 * individual functions that borrow it.
 */

#ifndef SKIA_CAPI_H
#define SKIA_CAPI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/* Errors                                                              */
/* ------------------------------------------------------------------ */

/* Description of the most recent failure on the calling thread, or NULL if
   no failure has been recorded. The returned pointer is owned by the
   library and is valid until the next failing call on the same thread. */
const char *skc_last_error(void);

/* Discards the recorded error for the calling thread. */
void skc_clear_error(void);

/* Library version string, e.g. "0.153.3". Static storage. */
const char *skc_version(void);

/* ------------------------------------------------------------------ */
/* Enumerations                                                        */
/* ------------------------------------------------------------------ */

/* Pixel formats. Values mirror skia::SkColorType. */
typedef enum {
    SKC_COLOR_TYPE_UNKNOWN = 0,
    SKC_COLOR_TYPE_ALPHA_8 = 1,
    SKC_COLOR_TYPE_RGB_565 = 2,
    SKC_COLOR_TYPE_ARGB_4444 = 3,
    SKC_COLOR_TYPE_RGBA_8888 = 4,
    SKC_COLOR_TYPE_RGB_888X = 5,
    SKC_COLOR_TYPE_BGRA_8888 = 6,
    SKC_COLOR_TYPE_RGBA_1010102 = 7,
    SKC_COLOR_TYPE_BGRA_1010102 = 8,
    SKC_COLOR_TYPE_RGB_101010X = 9,
    SKC_COLOR_TYPE_BGR_101010X = 10,
    SKC_COLOR_TYPE_BGR_101010X_XR = 11,
    SKC_COLOR_TYPE_BGRA_10101010_XR = 12,
    SKC_COLOR_TYPE_RGBA_10X6 = 13,
    SKC_COLOR_TYPE_GRAY_8 = 14,
    SKC_COLOR_TYPE_RGBA_F16_NORM = 15,
    SKC_COLOR_TYPE_RGBA_F16 = 16,
    SKC_COLOR_TYPE_RGB_F16F16F16X = 17,
    SKC_COLOR_TYPE_RGBA_F32 = 18,
    SKC_COLOR_TYPE_R8G8_UNORM = 19,
    SKC_COLOR_TYPE_A16_FLOAT = 20,
    SKC_COLOR_TYPE_R16_FLOAT = 21,
    SKC_COLOR_TYPE_R16G16_FLOAT = 22,
    SKC_COLOR_TYPE_A16_UNORM = 23,
    SKC_COLOR_TYPE_R16_UNORM = 24,
    SKC_COLOR_TYPE_R16G16_UNORM = 25,
    SKC_COLOR_TYPE_R16G16B16A16_UNORM = 26,
    SKC_COLOR_TYPE_SRGBA_8888 = 27,
    SKC_COLOR_TYPE_R8_UNORM = 28
} skc_colortype_t;

/* Alpha handling. Values mirror skia::SkAlphaType. */
typedef enum {
    SKC_ALPHA_TYPE_UNKNOWN = 0,
    SKC_ALPHA_TYPE_OPAQUE = 1,
    SKC_ALPHA_TYPE_PREMUL = 2,
    SKC_ALPHA_TYPE_UNPREMUL = 3
} skc_alphatype_t;

/* Colour space. Values mirror skia::ColorSpace. */
typedef enum {
    SKC_COLOR_SPACE_SRGB = 0,
    SKC_COLOR_SPACE_DISPLAY_P3 = 1,
    SKC_COLOR_SPACE_LINEAR_SRGB = 2
} skc_colorspace_t;

/* Porter-Duff and advanced blend modes. Values mirror skia::SkBlendMode
   and are contiguous from 0 to 28. */
typedef enum {
    SKC_BLEND_MODE_CLEAR = 0,
    SKC_BLEND_MODE_SRC = 1,
    SKC_BLEND_MODE_DST = 2,
    SKC_BLEND_MODE_SRC_OVER = 3,
    SKC_BLEND_MODE_DST_OVER = 4,
    SKC_BLEND_MODE_SRC_IN = 5,
    SKC_BLEND_MODE_DST_IN = 6,
    SKC_BLEND_MODE_SRC_OUT = 7,
    SKC_BLEND_MODE_DST_OUT = 8,
    SKC_BLEND_MODE_SRC_ATOP = 9,
    SKC_BLEND_MODE_DST_ATOP = 10,
    SKC_BLEND_MODE_XOR = 11,
    SKC_BLEND_MODE_PLUS = 12,
    SKC_BLEND_MODE_MODULATE = 13,
    SKC_BLEND_MODE_SCREEN = 14,
    SKC_BLEND_MODE_OVERLAY = 15,
    SKC_BLEND_MODE_DARKEN = 16,
    SKC_BLEND_MODE_LIGHTEN = 17,
    SKC_BLEND_MODE_COLOR_DODGE = 18,
    SKC_BLEND_MODE_COLOR_BURN = 19,
    SKC_BLEND_MODE_HARD_LIGHT = 20,
    SKC_BLEND_MODE_SOFT_LIGHT = 21,
    SKC_BLEND_MODE_DIFFERENCE = 22,
    SKC_BLEND_MODE_EXCLUSION = 23,
    SKC_BLEND_MODE_MULTIPLY = 24,
    SKC_BLEND_MODE_HUE = 25,
    SKC_BLEND_MODE_SATURATION = 26,
    SKC_BLEND_MODE_COLOR = 27,
    SKC_BLEND_MODE_LUMINOSITY = 28
} skc_blendmode_t;

typedef enum {
    SKC_PAINT_STYLE_FILL = 0,
    SKC_PAINT_STYLE_STROKE = 1,
    SKC_PAINT_STYLE_STROKE_AND_FILL = 2
} skc_paintstyle_t;

typedef enum {
    SKC_STROKE_CAP_BUTT = 0,
    SKC_STROKE_CAP_ROUND = 1,
    SKC_STROKE_CAP_SQUARE = 2
} skc_strokecap_t;

typedef enum {
    SKC_STROKE_JOIN_MITER = 0,
    SKC_STROKE_JOIN_ROUND = 1,
    SKC_STROKE_JOIN_BEVEL = 2
} skc_strokejoin_t;

typedef enum {
    SKC_FILL_TYPE_WINDING = 0,
    SKC_FILL_TYPE_EVEN_ODD = 1,
    SKC_FILL_TYPE_INVERSE_WINDING = 2,
    SKC_FILL_TYPE_INVERSE_EVEN_ODD = 3
} skc_filltype_t;

typedef enum {
    SKC_TILE_MODE_CLAMP = 0,
    SKC_TILE_MODE_REPEAT = 1,
    SKC_TILE_MODE_MIRROR = 2,
    SKC_TILE_MODE_DECAL = 3
} skc_tilemode_t;

typedef enum {
    SKC_FILTER_MODE_NEAREST = 0,
    SKC_FILTER_MODE_LINEAR = 1
} skc_filtermode_t;

typedef enum {
    SKC_MIPMAP_MODE_NONE = 0,
    SKC_MIPMAP_MODE_NEAREST = 1,
    SKC_MIPMAP_MODE_LINEAR = 2
} skc_mipmapmode_t;

/* How a group of points is rasterised. Values mirror
   skia::SkCanvas::PointMode. */
typedef enum {
    SKC_POINT_MODE_POINTS = 0,
    SKC_POINT_MODE_LINES = 1,
    SKC_POINT_MODE_POLYGON = 2
} skc_pointmode_t;

/* Glyph edge rasterisation. Values mirror skia::SkFont::Edging. */
typedef enum {
    SKC_FONT_EDGING_ALIAS = 0,
    SKC_FONT_EDGING_ANTIALIAS = 1,
    SKC_FONT_EDGING_SUBPIXEL_ANTIALIAS = 2
} skc_fongedging_t;

typedef enum {
    SKC_HINTING_NONE = 0,
    SKC_HINTING_SLIGHT = 1,
    SKC_HINTING_NORMAL = 2,
    SKC_HINTING_FULL = 3
} skc_hinting_t;

typedef enum {
    SKC_ENCODED_FORMAT_BMP = 0,
    SKC_ENCODED_FORMAT_GIF = 1,
    SKC_ENCODED_FORMAT_ICO = 2,
    SKC_ENCODED_FORMAT_JPEG = 3,
    SKC_ENCODED_FORMAT_PNG = 4,
    SKC_ENCODED_FORMAT_WBMP = 5,
    SKC_ENCODED_FORMAT_WEBP = 6
} skc_encodedformat_t;

typedef enum {
    SKC_FONT_WEIGHT_INVISIBLE = 0,
    SKC_FONT_WEIGHT_THIN = 100,
    SKC_FONT_WEIGHT_EXTRA_LIGHT = 200,
    SKC_FONT_WEIGHT_LIGHT = 300,
    SKC_FONT_WEIGHT_NORMAL = 400,
    SKC_FONT_WEIGHT_MEDIUM = 500,
    SKC_FONT_WEIGHT_SEMI_BOLD = 600,
    SKC_FONT_WEIGHT_BOLD = 700,
    SKC_FONT_WEIGHT_EXTRA_BOLD = 800,
    SKC_FONT_WEIGHT_BLACK = 900,
    SKC_FONT_WEIGHT_EXTRA_BLACK = 1000
} skc_fontweight_t;

typedef enum {
    SKC_FONT_WIDTH_ULTRA_CONDENSED = 1,
    SKC_FONT_WIDTH_EXTRA_CONDENSED = 2,
    SKC_FONT_WIDTH_CONDENSED = 3,
    SKC_FONT_WIDTH_SEMI_CONDENSED = 4,
    SKC_FONT_WIDTH_NORMAL = 5,
    SKC_FONT_WIDTH_SEMI_EXPANDED = 6,
    SKC_FONT_WIDTH_EXPANDED = 7,
    SKC_FONT_WIDTH_EXTRA_EXPANDED = 8,
    SKC_FONT_WIDTH_ULTRA_EXPANDED = 9
} skc_fontwidth_t;

typedef enum {
    SKC_FONT_SLANT_UPRIGHT = 0,
    SKC_FONT_SLANT_ITALIC = 1,
    SKC_FONT_SLANT_OBLIQUE = 2
} skc_fontslant_t;

/* ------------------------------------------------------------------ */
/* Value types                                                         */
/* ------------------------------------------------------------------ */

/* Unpremultiplied RGBA colour with components in [0, 1]. */
typedef struct skc_color {
    float r;
    float g;
    float b;
    float a;
} skc_color_t;

typedef struct skc_point {
    float x;
    float y;
} skc_point_t;

/* Half-open rectangle: [left, right) x [top, bottom). */
typedef struct skc_rect {
    float left;
    float top;
    float right;
    float bottom;
} skc_rect_t;

typedef struct skc_irect {
    int32_t left;
    int32_t top;
    int32_t right;
    int32_t bottom;
} skc_irect_t;

/* 3x3 transformation in row-major order, laid out exactly like the nine
   floats of skia::SkMatrix. Stored by value; never memcpy'd against
   SkMatrix by the implementation. */
typedef struct skc_matrix {
    float m[9];
} skc_matrix_t;

typedef struct skc_imageinfo {
    int32_t width;
    int32_t height;
    skc_colortype_t colorType;
    skc_alphatype_t alphaType;
    skc_colorspace_t colorSpace;
} skc_imageinfo_t;

typedef struct skc_fontstyle {
    int32_t weight;
    int32_t width;
    skc_fontslant_t slant;
} skc_fontstyle_t;

/* Text metrics, mirroring the fields of skia::SkFontMetrics that are
   meaningful for horizontal text. All distances are in the same units as
   the size the font was created with. */
typedef struct skc_fontmetrics {
    float ascent;
    float descent;
    float leading;
    float top;
    float bottom;
    float xMin;
    float xMax;
} skc_fontmetrics_t;

skc_rect_t skc_rect_make(float left, float top, float right, float bottom);
skc_rect_t skc_rect_make_wh(float width, float height);
bool skc_rect_is_empty(const skc_rect_t *r);
skc_irect_t skc_irect_make(int32_t left, int32_t top, int32_t right, int32_t bottom);

skc_matrix_t skc_matrix_identity(void);
skc_matrix_t skc_matrix_make_translate(float dx, float dy);
skc_matrix_t skc_matrix_make_scale(float sx, float sy);
skc_matrix_t skc_matrix_make_rotate(float degrees);
skc_matrix_t skc_matrix_make_all(float scaleX, float skewX, float transX,
                                 float skewY, float scaleY, float transY,
                                 float perspX, float perspY, float perspZ);
void skc_matrix_set_identity(skc_matrix_t *m);
void skc_matrix_pre_translate(skc_matrix_t *m, float dx, float dy);
void skc_matrix_pre_scale(skc_matrix_t *m, float sx, float sy);
void skc_matrix_pre_rotate(skc_matrix_t *m, float degrees);
void skc_matrix_post_translate(skc_matrix_t *m, float dx, float dy);
void skc_matrix_post_scale(skc_matrix_t *m, float sx, float sy);
void skc_matrix_post_rotate(skc_matrix_t *m, float degrees);
void skc_matrix_concat(skc_matrix_t *target, const skc_matrix_t *a, const skc_matrix_t *b);
bool skc_matrix_invert(const skc_matrix_t *src, skc_matrix_t *dst);
void skc_matrix_map_rect(const skc_matrix_t *m, skc_rect_t *rect);

skc_fontstyle_t skc_fontstyle_normal(void);
skc_fontstyle_t skc_fontstyle_make(skc_fontweight_t weight, skc_fontwidth_t width,
                                   skc_fontslant_t slant);

/* ------------------------------------------------------------------ */
/* Opaque handles                                                      */
/* ------------------------------------------------------------------ */

typedef struct skc_data skc_data_t;
typedef struct skc_pixmap skc_pixmap_t;
typedef struct skc_surface skc_surface_t;
typedef struct skc_canvas skc_canvas_t;
typedef struct skc_paint skc_paint_t;
typedef struct skc_path skc_path_t;
typedef struct skc_image skc_image_t;
typedef struct skc_shader skc_shader_t;
typedef struct skc_image_filter skc_image_filter_t;
typedef struct skc_path_effect skc_path_effect_t;
typedef struct skc_color_filter skc_color_filter_t;
typedef struct skc_typeface skc_typeface_t;
typedef struct skc_font_manager skc_font_manager_t;
typedef struct skc_font skc_font_t;
typedef struct skc_text_blob skc_text_blob_t;

/* Called when Skia is finished with a buffer it was given ownership of.
   `ctx` is the pointer supplied alongside `pixels`. Never called with
   NULL pixels. May run on any thread. */
typedef void (*skc_release_proc)(void *ctx);

/* ------------------------------------------------------------------ */
/* Data - a reference-counted immutable byte buffer                     */
/* ------------------------------------------------------------------ */

/* Copies `size` bytes. Returns NULL if `size` is non-zero and `data` is
   NULL, or on allocation failure. */
skc_data_t *skc_data_new(const void *data, size_t size);
skc_data_t *skc_data_new_null(void); /* zero-length buffer */
skc_data_t *skc_data_ref(skc_data_t *data);   /* owned */
void skc_data_unref(skc_data_t *data);
size_t skc_data_size(const skc_data_t *data);
const void *skc_data_data(const skc_data_t *data); /* borrowed */

/* ------------------------------------------------------------------ */
/* Pixmap - a non-owning view over caller-owned pixels                  */
/* ------------------------------------------------------------------ */

/* Does not take ownership of `pixels`; they must outlive the pixmap. */
skc_pixmap_t *skc_pixmap_new(const skc_imageinfo_t *info, void *pixels, size_t rowBytes);
void skc_pixmap_free(skc_pixmap_t *pixmap);
bool skc_pixmap_reset(skc_pixmap_t *pixmap, const skc_imageinfo_t *info, void *pixels,
                      size_t rowBytes);
int32_t skc_pixmap_width(const skc_pixmap_t *pixmap);
int32_t skc_pixmap_height(const skc_pixmap_t *pixmap);
size_t skc_pixmap_row_bytes(const skc_pixmap_t *pixmap);
const skc_imageinfo_t *skc_pixmap_image_info(const skc_pixmap_t *pixmap);
void *skc_pixmap_pixels(const skc_pixmap_t *pixmap); /* borrowed */
bool skc_pixmap_read_pixels(const skc_pixmap_t *src, const skc_imageinfo_t *dstInfo,
                            void *dstPixels, size_t dstRowBytes);

/* ------------------------------------------------------------------ */
/* Surface - a drawing destination                                     */
/* ------------------------------------------------------------------ */

skc_surface_t *skc_surface_new_raster(const skc_imageinfo_t *info);
skc_surface_t *skc_surface_new_raster_with_row_bytes(const skc_imageinfo_t *info,
                                                     size_t rowBytes);
/* `pixels` is *borrowed*: it must stay valid until the surface is freed. */
skc_surface_t *skc_surface_new_raster_direct(const skc_imageinfo_t *info, void *pixels,
                                             size_t rowBytes);
/* Wraps `pixels` without copying and keeps them alive for the life of the
   surface, calling `release(releaseCtx)` once Skia is done. `release` is
   required. Use `skc_surface_new_raster_direct` instead when you would rather
   manage the buffer's lifetime yourself. */
skc_surface_t *skc_surface_new_raster_owned(const skc_imageinfo_t *info, void *pixels,
                                            size_t rowBytes, skc_release_proc release,
                                            void *releaseCtx);
skc_surface_t *skc_surface_ref(skc_surface_t *surface);   /* owned */
void skc_surface_unref(skc_surface_t *surface);
int32_t skc_surface_width(const skc_surface_t *surface);
int32_t skc_surface_height(const skc_surface_t *surface);
skc_canvas_t *skc_surface_get_canvas(skc_surface_t *surface); /* borrowed */
void skc_surface_flush(skc_surface_t *surface);
void skc_surface_flush_and_submit(skc_surface_t *surface);
skc_image_t *skc_surface_make_image_snapshot(skc_surface_t *surface); /* owned */
bool skc_surface_read_pixels(skc_surface_t *surface, const skc_imageinfo_t *dstInfo,
                             void *dstPixels, size_t dstRowBytes);
skc_pixmap_t *skc_surface_peek_pixels(skc_surface_t *surface); /* borrowed */

/* ------------------------------------------------------------------ */
/* Canvas - the drawing API                                            */
/* ------------------------------------------------------------------ */

int skc_canvas_save(skc_canvas_t *canvas);
int skc_canvas_save_layer(skc_canvas_t *canvas, const skc_paint_t *paint); /* paint may be NULL */
void skc_canvas_restore(skc_canvas_t *canvas, int saveCount);
int skc_canvas_get_save_count(const skc_canvas_t *canvas);
void skc_canvas_clip_rect(skc_canvas_t *canvas, const skc_rect_t *rect, bool antiAlias);
/* For an inverted clip, set the path's fill type to one of the inverse
   fill types before calling. */
void skc_canvas_clip_path(skc_canvas_t *canvas, const skc_path_t *path, bool antiAlias);
void skc_canvas_draw_color(skc_canvas_t *canvas, skc_color_t color, skc_blendmode_t mode);
void skc_canvas_draw_rect(skc_canvas_t *canvas, const skc_rect_t *rect, const skc_paint_t *paint);
void skc_canvas_draw_oval(skc_canvas_t *canvas, const skc_rect_t *oval, const skc_paint_t *paint);
void skc_canvas_draw_circle(skc_canvas_t *canvas, float cx, float cy, float radius,
                            const skc_paint_t *paint);
void skc_canvas_draw_line(skc_canvas_t *canvas, float x0, float y0, float x1, float y1,
                          const skc_paint_t *paint);
void skc_canvas_draw_points(skc_canvas_t *canvas, skc_point_t *points, size_t count,
                            skc_pointmode_t mode, const skc_paint_t *paint);
void skc_canvas_draw_path(skc_canvas_t *canvas, const skc_path_t *path, const skc_paint_t *paint);
void skc_canvas_draw_image(skc_canvas_t *canvas, const skc_image_t *image, float x, float y,
                           const skc_paint_t *paint);
void skc_canvas_draw_image_rect(skc_canvas_t *canvas, const skc_image_t *image,
                                const skc_rect_t *src, const skc_rect_t *dst,
                                skc_filtermode_t filter, skc_mipmapmode_t mipmap,
                                const skc_paint_t *paint);
void skc_canvas_draw_text(skc_canvas_t *canvas, const char *text, size_t length, float x,
                          float y, const skc_font_t *font, const skc_paint_t *paint);
void skc_canvas_draw_text_blob(skc_canvas_t *canvas, const skc_text_blob_t *blob,
                               float x, float y, const skc_paint_t *paint);
void skc_canvas_translate(skc_canvas_t *canvas, float dx, float dy);
void skc_canvas_scale(skc_canvas_t *canvas, float sx, float sy);
void skc_canvas_rotate(skc_canvas_t *canvas, float degrees);
void skc_canvas_concat(skc_canvas_t *canvas, const skc_matrix_t *matrix);
void skc_canvas_set_matrix(skc_canvas_t *canvas, const skc_matrix_t *matrix);
void skc_canvas_reset_matrix(skc_canvas_t *canvas);
skc_irect_t skc_canvas_get_device_clip_bounds(const skc_canvas_t *canvas);

/* ------------------------------------------------------------------ */
/* Paint                                                               */
/* ------------------------------------------------------------------ */

skc_paint_t *skc_paint_new(void);                     /* owned */
skc_paint_t *skc_paint_new_copy(const skc_paint_t *src); /* owned */
void skc_paint_free(skc_paint_t *paint);
void skc_paint_set_style(skc_paint_t *paint, skc_paintstyle_t style);
skc_paintstyle_t skc_paint_get_style(const skc_paint_t *paint);
void skc_paint_set_color(skc_paint_t *paint, skc_color_t color);
skc_color_t skc_paint_get_color(const skc_paint_t *paint);
void skc_paint_set_stroke_width(skc_paint_t *paint, float width);
float skc_paint_get_stroke_width(const skc_paint_t *paint);
void skc_paint_set_stroke_miter(skc_paint_t *paint, float miter);
float skc_paint_get_stroke_miter(const skc_paint_t *paint);
void skc_paint_set_stroke_cap(skc_paint_t *paint, skc_strokecap_t cap);
skc_strokecap_t skc_paint_get_stroke_cap(const skc_paint_t *paint);
void skc_paint_set_stroke_join(skc_paint_t *paint, skc_strokejoin_t join);
skc_strokejoin_t skc_paint_get_stroke_join(const skc_paint_t *paint);
void skc_paint_set_anti_alias(skc_paint_t *paint, bool antiAlias);
bool skc_paint_get_anti_alias(const skc_paint_t *paint);
void skc_paint_set_blend_mode(skc_paint_t *paint, skc_blendmode_t mode);
skc_blendmode_t skc_paint_get_blend_mode(const skc_paint_t *paint);
void skc_paint_set_dither(skc_paint_t *paint, bool dither);
bool skc_paint_get_dither(const skc_paint_t *paint);
void skc_paint_set_shader(skc_paint_t *paint, skc_shader_t *shader); /* borrows a ref */
void skc_paint_set_image_filter(skc_paint_t *paint, skc_image_filter_t *filter);
void skc_paint_set_path_effect(skc_paint_t *paint, skc_path_effect_t *effect);
void skc_paint_set_color_filter(skc_paint_t *paint, skc_color_filter_t *filter);
void skc_paint_reset(skc_paint_t *paint);

/* ------------------------------------------------------------------ */
/* Path                                                                */
/* ------------------------------------------------------------------ */

skc_path_t *skc_path_new(void);                        /* owned */
skc_path_t *skc_path_new_copy(const skc_path_t *src);  /* owned */
void skc_path_free(skc_path_t *path);
void skc_path_reset(skc_path_t *path);
void skc_path_set_fill_type(skc_path_t *path, skc_filltype_t fillType);
skc_filltype_t skc_path_get_fill_type(const skc_path_t *path);
void skc_path_move_to(skc_path_t *path, float x, float y);
void skc_path_line_to(skc_path_t *path, float x, float y);
void skc_path_quad_to(skc_path_t *path, float x1, float y1, float x2, float y2);
void skc_path_cubic_to(skc_path_t *path, float x1, float y1, float x2, float y2, float x3,
                       float y3);
void skc_path_conic_to(skc_path_t *path, float x1, float y1, float x2, float y2, float w);
void skc_path_close(skc_path_t *path);
void skc_path_add_rect(skc_path_t *path, const skc_rect_t *rect, bool clockwise);
void skc_path_add_oval(skc_path_t *path, const skc_rect_t *oval, bool clockwise);
void skc_path_add_circle(skc_path_t *path, float cx, float cy, float radius, bool clockwise);
void skc_path_add_arc(skc_path_t *path, const skc_rect_t *oval, float startAngleDeg,
                      float sweepAngleDeg, bool forceMoveTo);
void skc_path_add_poly(skc_path_t *path, const skc_point_t *points, size_t count,
                       bool isClosed);
void skc_path_transform(skc_path_t *path, const skc_matrix_t *matrix);
bool skc_path_is_empty(const skc_path_t *path);
bool skc_path_is_finite(const skc_path_t *path);
size_t skc_path_count_verbs(const skc_path_t *path);
skc_rect_t skc_path_get_bounds(const skc_path_t *path);
skc_rect_t skc_path_compute_tight_bounds(const skc_path_t *path);
bool skc_path_contains_point(const skc_path_t *path, float x, float y);

/* ------------------------------------------------------------------ */
/* Image                                                               */
/* ------------------------------------------------------------------ */

/* Decodes PNG/JPEG/WebP when Skia was built with support for them. */
skc_image_t *skc_image_new_from_encoded(const skc_data_t *encoded); /* owned */
/* Copies `pixmap`'s pixels. */
skc_image_t *skc_image_new_from_pixmap_copy(const skc_pixmap_t *pixmap);         /* owned */
/* Copies `pixels` (height * rowBytes bytes) into a new image. The caller's
   buffer is not retained; if `release` is non-NULL it is called with
   `releaseCtx` (or `pixels` when that is NULL) before returning. The buffer
   is never freed implicitly. */
skc_image_t *skc_image_new_from_pixels_copy(const skc_imageinfo_t *info, void *pixels,
                                            size_t rowBytes, skc_release_proc release,
                                            void *releaseCtx);
skc_image_t *skc_image_ref(skc_image_t *image);   /* owned */
void skc_image_unref(skc_image_t *image);
int32_t skc_image_width(const skc_image_t *image);
int32_t skc_image_height(const skc_image_t *image);
skc_colortype_t skc_image_get_color_type(const skc_image_t *image);
skc_alphatype_t skc_image_get_alpha_type(const skc_image_t *image);
/* Returns the original encoded bytes, or NULL if the image was not decoded
   from an encoded stream. */
skc_data_t *skc_image_get_encoded_data(const skc_image_t *image); /* owned */
/* PNG, JPEG and WebP are supported. `quality` is 0..100 for lossy
   formats and ignored for PNG. Returns NULL on failure. */
skc_data_t *skc_image_encode(const skc_image_t *image, skc_encodedformat_t format,
                             int quality); /* owned */
bool skc_image_read_pixels(const skc_image_t *image, const skc_imageinfo_t *dstInfo,
                           void *dstPixels, size_t dstRowBytes);
skc_pixmap_t *skc_image_new_pixmap_from_image(const skc_image_t *image); /* owned */

/* ------------------------------------------------------------------ */
/* Shaders                                                             */
/* ------------------------------------------------------------------ */

skc_shader_t *skc_shader_ref(skc_shader_t *shader);   /* owned */
void skc_shader_unref(skc_shader_t *shader);

/* `positions` may be NULL, in which case colours are spread evenly.
   `localMatrix` may be NULL. Returns NULL if `colorCount` is zero. */
skc_shader_t *skc_shader_new_linear(skc_point_t start, skc_point_t end,
                                    const skc_color_t *colors, const float *positions,
                                    size_t colorCount, skc_tilemode_t tileMode,
                                    const skc_matrix_t *localMatrix); /* owned */
skc_shader_t *skc_shader_new_radial(float cx, float cy, float radius, const skc_color_t *colors,
                                    const float *positions, size_t colorCount,
                                    skc_tilemode_t tileMode,
                                    const skc_matrix_t *localMatrix);  /* owned */
skc_shader_t *skc_shader_new_sweep(float cx, float cy, float startAngle, float endAngle,
                                   const skc_color_t *colors, const float *positions,
                                   size_t colorCount, skc_tilemode_t tileMode,
                                   const skc_matrix_t *localMatrix);   /* owned */
skc_shader_t *skc_shader_new_two_point_conical(float startX, float startY, float startRadius,
                                               float endX, float endY, float endRadius,
                                               const skc_color_t *colors,
                                               const float *positions, size_t colorCount,
                                               skc_tilemode_t tileMode,
                                               const skc_matrix_t *localMatrix); /* owned */

/* ------------------------------------------------------------------ */
/* Image filters, path effects, colour filters                         */
/* ------------------------------------------------------------------ */

skc_image_filter_t *skc_image_filter_ref(skc_image_filter_t *filter); /* owned */
void skc_image_filter_unref(skc_image_filter_t *filter);
skc_image_filter_t *skc_image_filter_new_blur(float sigmaX, float sigmaY,
                                              skc_tilemode_t tileMode); /* owned */
skc_image_filter_t *skc_image_filter_new_color_filter(skc_color_filter_t *input); /* owned */

skc_path_effect_t *skc_path_effect_ref(skc_path_effect_t *effect);  /* owned */
void skc_path_effect_unref(skc_path_effect_t *effect);
skc_path_effect_t *skc_path_effect_new_dash(const float *intervals, size_t count,
                                            float phase);            /* owned */
skc_path_effect_t *skc_path_effect_new_corner(float radius);          /* owned */
skc_path_effect_t *skc_path_effect_new_discrete(float segLength, float dev,
                                                uint32_t seed);     /* owned */

skc_color_filter_t *skc_color_filter_ref(skc_color_filter_t *filter); /* owned */
void skc_color_filter_unref(skc_color_filter_t *filter);
/* `rowMajor` is a 4x5 colour matrix in row-major order. */
skc_color_filter_t *skc_color_filter_new_matrix(const float rowMajor[20]); /* owned */
/* `table` is 256 entries; each entry is an ARGB value. */
skc_color_filter_t *skc_color_filter_new_table(const uint8_t tableA[256]); /* owned */

/* ------------------------------------------------------------------ */
/* Typefaces and fonts                                                 */
/* ------------------------------------------------------------------ */

/* The platform font manager (fontconfig on Linux, CoreText on macOS,
   DirectWrite on Windows). Never NULL. */
skc_font_manager_t *skc_font_manager_new(void);   /* owned */
void skc_font_manager_unref(skc_font_manager_t *mgr);
int skc_font_manager_get_family_count(const skc_font_manager_t *mgr);
/* Copies at most `bufSize - 1` bytes plus a NUL terminator. Returns the
   number of bytes written, excluding the terminator. */
size_t skc_font_manager_get_family_name(const skc_font_manager_t *mgr, int index, char *buf,
                                        size_t bufSize);
skc_typeface_t *skc_font_manager_default_typeface(const skc_font_manager_t *mgr); /* owned */
skc_typeface_t *skc_font_manager_match_family_style(const skc_font_manager_t *mgr,
                                                    const char *family,
                                                    skc_fontstyle_t style); /* owned */
skc_typeface_t *skc_font_manager_typeface_from_file(const skc_font_manager_t *mgr,
                                                    const char *path, int ttcIndex); /* owned */

skc_typeface_t *skc_typeface_ref(skc_typeface_t *typeface);  /* owned */
void skc_typeface_unref(skc_typeface_t *typeface);
size_t skc_typeface_get_family_name(const skc_typeface_t *typeface, char *buf, size_t bufSize);
skc_fontstyle_t skc_typeface_get_style(const skc_typeface_t *typeface);
bool skc_typeface_is_bold(const skc_typeface_t *typeface);
bool skc_typeface_is_italic(const skc_typeface_t *typeface);

/* `typeface` may be NULL, selecting a default. The font borrows a
   reference to the typeface, so it must outlive the font. */
skc_font_t *skc_font_new(skc_typeface_t *typeface, float size);  /* owned */
void skc_font_free(skc_font_t *font);
float skc_font_get_size(const skc_font_t *font);
void skc_font_set_size(skc_font_t *font, float size);
void skc_font_set_edging(skc_font_t *font, skc_fongedging_t edging);
void skc_font_set_hinting(skc_font_t *font, skc_hinting_t hinting);
void skc_font_set_subpixel(skc_font_t *font, bool subpixel);
void skc_font_set_embolden(skc_font_t *font, bool embolden);
void skc_font_set_scale_x(skc_font_t *font, float scaleX);
float skc_font_get_spacing(const skc_font_t *font);
bool skc_font_get_metrics(const skc_font_t *font, skc_fontmetrics_t *metrics);
/* Measures `length` bytes of `text` (pass length 0 for NUL-terminated).
   `advance` receives the total advance; `bounds` is filled when non-NULL. */
float skc_font_measure_text(const skc_font_t *font, const char *text, size_t length,
                            skc_rect_t *bounds);
float skc_font_get_ascent(const skc_font_t *font);
float skc_font_get_descent(const skc_font_t *font);

/* ------------------------------------------------------------------ */
/* Text blobs                                                          */
/* ------------------------------------------------------------------ */

/* Builds a single run of text positioned at the origin. `length` is in
   bytes, not characters; pass 0 for a NUL-terminated string. The run has no
   kerning or shaping: glyphs are placed at their default advances. Position
   it with skc_canvas_draw_text_blob. */
skc_text_blob_t *skc_text_blob_new(const char *text, size_t length,
                                   const skc_font_t *font);  /* owned */
void skc_text_blob_unref(skc_text_blob_t *blob);
void skc_text_blob_get_bounds(const skc_text_blob_t *blob, skc_rect_t *bounds);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* SKIA_CAPI_H */
