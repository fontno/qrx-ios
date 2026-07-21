// gen_icons.swift — renders three QRX icon concepts as 1024x1024 PNGs plus a
// preview contact sheet at home-screen sizes, using only CoreGraphics/ImageIO.
// Run: swift gen_icons.swift
import CoreGraphics
import Foundation
import ImageIO

let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}
func hex(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    rgba(CGFloat((v >> 16) & 0xFF) / 255, CGFloat((v >> 8) & 0xFF) / 255, CGFloat(v & 0xFF) / 255, a)
}

// Brand palette
let deepIndigo = hex(0x241680)
let violet = hex(0x7C4DFF)
let inkViolet = hex(0x6C3CE9)
let inkBlue = hex(0x2979FF)
let lavender = hex(0xF3F0FF)
let white = hex(0xFFFFFF)

/// Bitmap context flipped to top-down coordinates (like SVG) so y grows downward.
func makeCanvas(_ w: Int = size, _ h: Int = size) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func savePNG(_ ctx: CGContext, _ name: String) {
    let img = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: name) as CFURL,
                                               "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("write failed \(name)") }
    print("wrote \(name)")
}

/// Rounded rect with independent corner radii (for leaf shapes).
func roundedRect(_ rect: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
    if tr > 0 { p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr) }
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
    if br > 0 { p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br) }
    p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
    if bl > 0 { p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl) }
    p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
    if tl > 0 { p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl) }
    p.closeSubpath()
    return p
}

func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

/// Fills a path with a diagonal (top-left → bottom-right) two-stop gradient
/// spanning the path's own bounding box — same as SVG objectBoundingBox.
func fillGrad(_ ctx: CGContext, _ path: CGPath, _ c1: CGColor, _ c2: CGColor,
              evenOdd: Bool = false, alpha: CGFloat = 1) {
    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.addPath(path)
    ctx.clip(using: evenOdd ? .evenOdd : .winding)
    let box = path.boundingBox
    let grad = CGGradient(colorsSpace: cs, colors: [c1, c2] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: box.minX, y: box.minY),
                           end: CGPoint(x: box.maxX, y: box.maxY),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

func fill(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, evenOdd: Bool = false) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath(using: evenOdd ? .evenOdd : .winding)
    ctx.restoreGState()
}

/// QR finder-pattern eye: outer ring (even-odd) + pupil, uniform radii.
func drawEye(_ ctx: CGContext, x: CGFloat, y: CGFloat, outer: CGFloat, outerR: CGFloat,
             holeInset: CGFloat, holeR: CGFloat, pupil: CGFloat, pupilR: CGFloat,
             _ c1: CGColor, _ c2: CGColor) {
    let ring = CGMutablePath()
    ring.addPath(rrect(x, y, outer, outer, outerR))
    ring.addPath(rrect(x + holeInset, y + holeInset, outer - 2 * holeInset, outer - 2 * holeInset, holeR))
    fillGrad(ctx, ring, c1, c2, evenOdd: true)
    let pupilInset = (outer - pupil) / 2
    fillGrad(ctx, rrect(x + pupilInset, y + pupilInset, pupil, pupil, pupilR), c1, c2)
}

// MARK: - Concept A: "Styled code" — white modules + leaf eye on indigo→violet

func iconA() -> CGContext {
    let ctx = makeCanvas()
    let grad = CGGradient(colorsSpace: cs, colors: [deepIndigo, violet] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 1024, y: 1024), options: [])

    // Leaf eye: sharp TL/BR, rounded TR/BL — matches the app's leaf eye shape
    let ring = CGMutablePath()
    ring.addPath(roundedRect(CGRect(x: 170, y: 170, width: 284, height: 284), tl: 0, tr: 84, br: 0, bl: 84))
    ring.addPath(roundedRect(CGRect(x: 226, y: 226, width: 172, height: 172), tl: 0, tr: 44, br: 0, bl: 44))
    fill(ctx, ring, white, evenOdd: true)
    fill(ctx, rrect(266, 266, 92, 92, 30), white)

    // Modules: 84px rounded squares on a 100px grid
    let cells: [(CGFloat, CGFloat)] = [
        (570, 170), (770, 170), (670, 270), (570, 370), (770, 370),
        (170, 570), (370, 570), (270, 670), (470, 670), (170, 770), (370, 770),
        (470, 470), (670, 470), (570, 570), (770, 570), (670, 670), (570, 770), (770, 770),
    ]
    for (x, y) in cells {
        fill(ctx, rrect(x, y, 84, 84, 26), white)
    }
    return ctx
}

// MARK: - Concept B: "The eye" — one giant gradient finder pattern on lavender

func iconB() -> CGContext {
    let ctx = makeCanvas()
    ctx.setFillColor(lavender)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    drawEye(ctx, x: 232, y: 232, outer: 560, outerR: 150,
            holeInset: 92, holeR: 96, pupil: 232, pupilR: 72, inkViolet, inkBlue)

    // Trailing module hints toward the corner
    fillGrad(ctx, rrect(836, 836, 72, 72, 24), inkViolet, inkBlue)
    fillGrad(ctx, rrect(732, 884, 48, 48, 16), inkViolet, inkBlue, alpha: 0.55)
    fillGrad(ctx, rrect(884, 732, 48, 48, 16), inkViolet, inkBlue, alpha: 0.55)
    return ctx
}

// MARK: - Concept C: "Logo in the middle" — QR skeleton + center sparkle badge

func iconC() -> CGContext {
    let ctx = makeCanvas()
    ctx.setFillColor(lavender)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    for (x, y): (CGFloat, CGFloat) in [(108, 108), (636, 108), (108, 636)] {
        drawEye(ctx, x: x, y: y, outer: 280, outerR: 88,
                holeInset: 68, holeR: 28, pupil: 76, pupilR: 24, inkViolet, inkBlue)
    }

    // Sparse modules around the center
    let cells: [(CGFloat, CGFloat)] = [
        (472, 132), (472, 260), (132, 472), (260, 472), (812, 472), (684, 540),
        (472, 812), (540, 684), (812, 684), (684, 812), (812, 812),
    ]
    for (x, y) in cells {
        fillGrad(ctx, rrect(x, y, 80, 80, 26), inkViolet, inkBlue, alpha: 0.85)
    }

    // Center brand badge with sparkle
    fillGrad(ctx, rrect(362, 362, 300, 300, 86), inkViolet, inkBlue)
    let sparkle = CGMutablePath()
    sparkle.move(to: CGPoint(x: 512, y: 418))
    sparkle.addCurve(to: CGPoint(x: 606, y: 512), control1: CGPoint(x: 524, y: 476), control2: CGPoint(x: 548, y: 500))
    sparkle.addCurve(to: CGPoint(x: 512, y: 606), control1: CGPoint(x: 548, y: 524), control2: CGPoint(x: 524, y: 548))
    sparkle.addCurve(to: CGPoint(x: 418, y: 512), control1: CGPoint(x: 500, y: 548), control2: CGPoint(x: 476, y: 524))
    sparkle.addCurve(to: CGPoint(x: 512, y: 418), control1: CGPoint(x: 476, y: 500), control2: CGPoint(x: 500, y: 476))
    sparkle.closeSubpath()
    fill(ctx, sparkle, white)
    return ctx
}

// MARK: - Round 2 variants

/// A2: modules forming an "X" (the suite letter) + leaf eye, on the gradient.
func iconA2() -> CGContext {
    let ctx = makeCanvas()
    let grad = CGGradient(colorsSpace: cs, colors: [deepIndigo, violet] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 1024, y: 1024), options: [])

    let ring = CGMutablePath()
    ring.addPath(roundedRect(CGRect(x: 170, y: 170, width: 284, height: 284), tl: 0, tr: 84, br: 0, bl: 84))
    ring.addPath(roundedRect(CGRect(x: 226, y: 226, width: 172, height: 172), tl: 0, tr: 44, br: 0, bl: 44))
    fill(ctx, ring, white, evenOdd: true)
    fill(ctx, rrect(266, 266, 92, 92, 30), white)

    // X: main diagonal continues out of the eye; anti-diagonal crosses it
    let cells: [(Int, Int)] = [(3, 3), (4, 4), (5, 5), (6, 6),
                               (6, 0), (5, 1), (4, 2), (2, 4), (1, 5), (0, 6)]
    for (r, c) in cells {
        fill(ctx, rrect(170 + CGFloat(c) * 100, 170 + CGFloat(r) * 100, 84, 84, 26), white)
    }
    return ctx
}

/// B2: inverted — giant white eye on the brand gradient.
func iconB2() -> CGContext {
    let ctx = makeCanvas()
    let grad = CGGradient(colorsSpace: cs, colors: [deepIndigo, violet] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 1024, y: 1024), options: [])

    let ring = CGMutablePath()
    ring.addPath(rrect(232, 232, 560, 560, 150))
    ring.addPath(rrect(324, 324, 376, 376, 96))
    fill(ctx, ring, white, evenOdd: true)
    fill(ctx, rrect(396, 396, 232, 232, 72), white)

    fill(ctx, rrect(836, 836, 72, 72, 24), white)
    fill(ctx, rrect(732, 884, 48, 48, 16), hex(0xFFFFFF, 0.55))
    fill(ctx, rrect(884, 732, 48, 48, 16), hex(0xFFFFFF, 0.55))
    return ctx
}

/// B3: like B2 but the eye is the app's leaf shape (one sharp corner).
func iconB3() -> CGContext {
    let ctx = makeCanvas()
    let grad = CGGradient(colorsSpace: cs, colors: [deepIndigo, violet] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 1024, y: 1024), options: [])

    let ring = CGMutablePath()
    ring.addPath(roundedRect(CGRect(x: 232, y: 232, width: 560, height: 560), tl: 0, tr: 170, br: 170, bl: 170))
    ring.addPath(roundedRect(CGRect(x: 324, y: 324, width: 376, height: 376), tl: 0, tr: 110, br: 110, bl: 110))
    fill(ctx, ring, white, evenOdd: true)
    fill(ctx, roundedRect(CGRect(x: 396, y: 396, width: 232, height: 232), tl: 0, tr: 72, br: 72, bl: 72), white)

    fill(ctx, rrect(836, 836, 72, 72, 24), white)
    fill(ctx, rrect(732, 884, 48, 48, 16), hex(0xFFFFFF, 0.55))
    fill(ctx, rrect(884, 732, 48, 48, 16), hex(0xFFFFFF, 0.55))
    return ctx
}

/// C2: decluttered "logo in the middle" — three eyes + center badge only.
func iconC2() -> CGContext {
    let ctx = makeCanvas()
    ctx.setFillColor(lavender)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    for (x, y): (CGFloat, CGFloat) in [(96, 96), (624, 96), (96, 624)] {
        drawEye(ctx, x: x, y: y, outer: 304, outerR: 96,
                holeInset: 72, holeR: 32, pupil: 88, pupilR: 28, inkViolet, inkBlue)
    }
    fillGrad(ctx, rrect(624, 624, 304, 304, 96), inkViolet, inkBlue)
    let s: CGFloat = 776, r: CGFloat = 100
    let sparkle = CGMutablePath()
    sparkle.move(to: CGPoint(x: s, y: s - r))
    sparkle.addCurve(to: CGPoint(x: s + r, y: s), control1: CGPoint(x: s + 13, y: s - 38), control2: CGPoint(x: s + 38, y: s - 13))
    sparkle.addCurve(to: CGPoint(x: s, y: s + r), control1: CGPoint(x: s + 38, y: s + 13), control2: CGPoint(x: s + 13, y: s + 38))
    sparkle.addCurve(to: CGPoint(x: s - r, y: s), control1: CGPoint(x: s - 13, y: s + 38), control2: CGPoint(x: s - 38, y: s + 13))
    sparkle.addCurve(to: CGPoint(x: s, y: s - r), control1: CGPoint(x: s - 38, y: s - 13), control2: CGPoint(x: s - 13, y: s - 38))
    sparkle.closeSubpath()
    fill(ctx, sparkle, white)
    return ctx
}

// MARK: - Preview contact sheet at home-screen sizes (180pt + 60pt rows)

func preview(_ icons: [CGImage]) -> CGContext {
    let big: CGFloat = 180, small: CGFloat = 60, gap: CGFloat = 44
    let w = Int(gap + (big + gap) * CGFloat(icons.count))
    let h = Int(gap + big + 36 + small + gap)
    let ctx = makeCanvas(w, h)
    ctx.setFillColor(hex(0xE7E7EE))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    func draw(_ img: CGImage, _ rect: CGRect) {
        ctx.saveGState()
        // iOS home-screen corner radius ≈ 22.4% of icon size
        ctx.addPath(rrect(rect.minX, rect.minY, rect.width, rect.height, rect.width * 0.224))
        ctx.clip()
        // Un-flip for CGImage drawing
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        ctx.restoreGState()
    }

    for (i, img) in icons.enumerated() {
        let x = gap + (big + gap) * CGFloat(i)
        draw(img, CGRect(x: x, y: gap, width: big, height: big))
        draw(img, CGRect(x: x + (big - small) / 2, y: gap + big + 36, width: small, height: small))
    }
    return ctx
}

let a = iconA(), b = iconB(), c = iconC()
savePNG(a, "iconA_dots.png")
savePNG(b, "iconB_eye.png")
savePNG(c, "iconC_badge.png")
savePNG(preview([a.makeImage()!, b.makeImage()!, c.makeImage()!]), "preview.png")

let a2 = iconA2(), b2 = iconB2(), b3 = iconB3(), c2 = iconC2()
savePNG(a2, "iconA2_x.png")
savePNG(b2, "iconB2_whiteeye.png")
savePNG(b3, "iconB3_leaf.png")
savePNG(c2, "iconC2_corner.png")
savePNG(preview([a.makeImage()!, a2.makeImage()!, b2.makeImage()!,
                 b3.makeImage()!, c2.makeImage()!, b.makeImage()!]), "preview2.png")
