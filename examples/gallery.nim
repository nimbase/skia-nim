## A small gallery showing the main drawing primitives.
##
## Run with:  nim c -r --path:src examples/gallery.nim

import std/os
import skia

const
  W = 480
  H = 360

proc drawGallery(): Surface =
  let surface = newRgbaSurface(W, H)
  let canvas = surface.canvas
  canvas.drawColor(rgb(0.10, 0.11, 0.13))

  # --- a linear gradient background band ------------------------------
  let sky = linearGradient(point(0, 0), point(0, 120),
    [rgb(0.15, 0.20, 0.35), rgb(0.45, 0.25, 0.40)])
  var band = newPaint()
  band.setShader(sky)
  canvas.drawRect(rectLTRB(0, 0, float32(W), 120), band)

  # --- shapes ---------------------------------------------------------
  var fill = fillPaint(rgb(0.95, 0.35, 0.30))
  var outline = strokePaint(rgb(0.85, 0.88, 0.95), 3)
  outline.setAntiAlias(true)

  canvas.drawCircle(point(70, 200), 36, fill)
  canvas.drawOval(rectLTRB(130, 164, 220, 236), outline)

  var rounded = newPath()
  rounded.addRect(rectLTRB(250, 164, 340, 236))
  canvas.drawPath(rounded, outline)

  # --- a stroked path with rounded corners and dashes ------------------
  let corner = cornerEffect(8)
  var soft = strokePaint(rgb(0.30, 0.80, 0.65), 8)
  soft.setPathEffect(corner)

  var squiggle = newPath()
  squiggle.moveTo(20.0'f32, 300.0'f32)
  for i in 0 .. 6:
    let dy = (if i mod 2 == 0: -14.0'f32 else: 14.0'f32)
    squiggle.lineTo(20.0'f32 + float32(i) * 22.0'f32, 300.0'f32 + dy)
  canvas.drawPath(squiggle, soft)

  let dash = dashEffect([10.0'f32, 6.0'f32])
  var dashed = strokePaint(rgb(0.98, 0.80, 0.35), 3)
  dashed.setPathEffect(dash)
  canvas.drawLine(point(360, 200), point(450, 280), dashed)

  # --- text -----------------------------------------------------------
  let mgr = defaultFontManager()
  let typeface = mgr.defaultTypeface()
  let heading = newFont(typeface, 22)
  let body = newFont(typeface, 14)

  var title = fillPaint(ColorWhite)
  var subtitle = fillPaint(rgb(0.85, 0.87, 0.92))
  canvas.drawText("Skia from Nim", point(20, 40), heading, title)
  canvas.drawText("raster backend, C ABI shim", point(20, 64), body, subtitle)

  # --- a blur, which Skia applies to a layer ---------------------------
  var blurPaint = newPaint()
  let blurFilter = blur(6, 6, TileModeClamp)
  blurPaint.setImageFilter(blurFilter)
  var glow = fillPaint(rgb(1, 0.75, 0.2), true)
  canvas.layer(blurPaint):
    canvas.drawCircle(point(400, 200), 30, glow)

  result = surface

proc main() =
  let surface = drawGallery()
  let png = surface.snapshot().encodePng()
  let dest = paramStr(1)
  if dest.len > 0:
    writeFile(dest, png.toString())
    echo "wrote ", dest, " (", png.size, " bytes)"
  else:
    stdout.write(png.toString())

when isMainModule:
  main()
