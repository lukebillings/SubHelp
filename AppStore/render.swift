import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

// App Store header (21:9) and search results (3:2) for SubHelp.
// Flat icon-gold, no prices, small shiba beside the line under the headline.

let iconPath = "/Users/lukebillings/code/lukebillings/SubHelp/SubHelp/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let outDir = "/Users/lukebillings/code/lukebillings/SubHelp/AppStore"

let iconGold = NSColor(srgbRed: 0.9823, green: 0.7709, blue: 0.0000, alpha: 1)
let ink = NSColor(srgbRed: 0.09, green: 0.07, blue: 0.04, alpha: 1)
let inkSoft = NSColor(srgbRed: 0.22, green: 0.15, blue: 0.04, alpha: 1)

struct Row {
    let title: String
    let detail: String
    let color: NSColor
}

let rows: [Row] = [
    Row(title: "Gym", detail: "Not opened in 5 months", color: NSColor(srgbRed: 0.96, green: 0.22, blue: 0.38, alpha: 1)),
    Row(title: "Music", detail: "Not opened in 4 months", color: NSColor(srgbRed: 0.12, green: 0.72, blue: 0.36, alpha: 1)),
    Row(title: "Streaming", detail: "Not opened in 6 months", color: NSColor(srgbRed: 0.00, green: 0.45, blue: 0.95, alpha: 1)),
]

let headlineLines = ["Still paying for", "subscriptions you", "don’t use?"]
let subline = "Find the ones you forgot."

let iconImage: NSImage = {
    guard let image = NSImage(contentsOfFile: iconPath) else {
        fatalError("Missing app icon")
    }
    return image
}()

/// Layout uses y = 0 at the top. The bitmap context uses y = 0 at the bottom.
var canvasH: CGFloat = 0

func box(_ topDown: NSRect) -> NSRect {
    NSRect(x: topDown.origin.x, y: canvasH - topDown.origin.y - topDown.height, width: topDown.width, height: topDown.height)
}

func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

func attrs(size: CGFloat, weight: NSFont.Weight, color: NSColor, kern: CGFloat) -> [NSAttributedString.Key: Any] {
    [.font: font(size, weight), .foregroundColor: color, .kern: kern]
}

func textWidth(_ text: String, size: CGFloat, weight: NSFont.Weight, kern: CGFloat) -> CGFloat {
    (text as NSString).size(withAttributes: attrs(size: size, weight: weight, color: ink, kern: kern)).width
}

func textHeight(_ text: String, size: CGFloat, weight: NSFont.Weight, kern: CGFloat) -> CGFloat {
    (text as NSString).size(withAttributes: attrs(size: size, weight: weight, color: ink, kern: kern)).height
}

func fitSize(text: String, maxWidth: CGFloat, weight: NSFont.Weight, maxSize: CGFloat, kernRatio: CGFloat) -> CGFloat {
    var size = maxSize
    while size > 28 {
        let kern = kernRatio * size
        if textWidth(text, size: size, weight: weight, kern: kern) <= maxWidth {
            return size
        }
        size -= 1
    }
    return 28
}

func fill(_ rect: NSRect, color: NSColor, radius: CGFloat) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func drawShiba(in topDown: NSRect) {
    let rect = box(topDown)
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: rect).addClip()
    iconImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func lineBox(_ size: CGFloat, _ weight: NSFont.Weight) -> (font: NSFont, height: CGFloat) {
    let f = font(size, weight)
    return (f, f.ascender - f.descender)
}

func drawLine(_ text: String, x: CGFloat, top: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor, kernRatio: CGFloat) -> CGFloat {
    let f = font(size, weight)
    let a = attrs(size: size, weight: weight, color: color, kern: kernRatio * size)
    let baseline = canvasH - top - f.ascender
    (text as NSString).draw(at: NSPoint(x: x, y: baseline), withAttributes: a)
    return f.ascender - f.descender
}

func pillSize(for fontSize: CGFloat) -> CGSize {
    let a = attrs(size: fontSize, weight: .bold, color: ink, kern: -0.02 * fontSize)
    let text = ("Unused" as NSString).size(withAttributes: a)
    let f = font(fontSize, .bold)
    let padX = fontSize * 0.62
    let padY = fontSize * 0.42
    return CGSize(width: text.width + padX * 2, height: (f.ascender - f.descender) + padY * 2)
}

func drawPill(_ label: String, fontSize: CGFloat, centerYFromTop: CGFloat, right: CGFloat) -> CGFloat {
    let kern = -0.02 * fontSize
    let a = attrs(size: fontSize, weight: .bold, color: ink, kern: kern)
    let text = label as NSString
    let measured = pillSize(for: fontSize)
    let padX = fontSize * 0.62
    let top = centerYFromTop - measured.height / 2
    let rect = box(NSRect(x: right - measured.width, y: top, width: measured.width, height: measured.height))
    fill(rect, color: .white, radius: measured.height / 2)
    let f = font(fontSize, .bold)
    let baseline = rect.midY - (f.ascender + f.descender) / 2
    text.draw(at: NSPoint(x: rect.minX + padX, y: baseline), withAttributes: a)
    return measured.width
}

func drawRowCard(_ row: Row, in topDown: NSRect, titleSize: CGFloat, detailSize: CGFloat) {
    let rect = box(topDown)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 28
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    fill(rect, color: row.color, radius: topDown.height * 0.18)
    NSGraphicsContext.restoreGraphicsState()

    let pad = topDown.height * 0.16
    let pillFont = min(titleSize * 0.46, topDown.height * 0.15)
    let pill = pillSize(for: pillFont)
    let textX = topDown.minX + pad
    let titleMax = topDown.width - pad * 2 - pill.width - pad * 0.7
    let fittedTitle = fitSize(text: row.title, maxWidth: titleMax, weight: .black, maxSize: titleSize, kernRatio: -0.03)
    let fittedDetail = fitSize(text: row.detail, maxWidth: topDown.width - pad * 2, weight: .semibold, maxSize: detailSize, kernRatio: -0.015)

    let titleFont = font(fittedTitle, .black)
    let detailFont = font(fittedDetail, .semibold)
    let titleH = titleFont.ascender - titleFont.descender
    let detailH = detailFont.ascender - detailFont.descender
    let gap = max(fittedDetail * 0.38, (pill.height - titleH) / 2 + 14)
    let block = titleH + gap + detailH
    let blockTop = topDown.midY - block / 2
    _ = drawLine(row.title, x: textX, top: blockTop, size: fittedTitle, weight: .black, color: .white, kernRatio: -0.03)
    _ = drawPill("Unused", fontSize: pillFont, centerYFromTop: blockTop + titleH / 2, right: topDown.maxX - pad)
    _ = drawLine(row.detail, x: textX, top: blockTop + titleH + gap, size: fittedDetail, weight: .semibold, color: NSColor.white.withAlphaComponent(0.92), kernRatio: -0.015)
}

func headlineMetrics(width: CGFloat, maxSize: CGFloat) -> (size: CGFloat, step: CGFloat, lineBox: CGFloat, height: CGFloat) {
    let longest = headlineLines.max { textWidth($0, size: 200, weight: .black, kern: -9) < textWidth($1, size: 200, weight: .black, kern: -9) }!
    let size = fitSize(text: longest, maxWidth: width, weight: .black, maxSize: maxSize, kernRatio: -0.04)
    let box = lineBox(size, .black).height
    let step = box * 0.86
    let height = step * 2 + box
    return (size, step, box, height)
}

func drawCenteredHeadline(canvasWidth: CGFloat, top: CGFloat, maxWidth: CGFloat, maxSize: CGFloat) -> (bottom: CGFloat, size: CGFloat) {
    let metrics = headlineMetrics(width: maxWidth, maxSize: maxSize)
    let kern = -0.04 * metrics.size
    var cursor = top
    for line in headlineLines {
        let lineW = textWidth(line, size: metrics.size, weight: .black, kern: kern)
        _ = drawLine(line, x: (canvasWidth - lineW) / 2, top: cursor, size: metrics.size, weight: .black, color: ink, kernRatio: -0.04)
        cursor += metrics.step
    }
    return (top + metrics.height, metrics.size)
}

/// Big shiba with “SubHelp” vertically centered beside it. The row is centered on the canvas.
func drawBrandLockup(canvasWidth: CGFloat, top: CGFloat, shiba: CGFloat) -> CGFloat {
    let word = "SubHelp"
    let wordSize = shiba * 0.40
    let wordH = lineBox(wordSize, .black).height
    let rowH = max(shiba, wordH)
    let gap = shiba * 0.12
    let kern = -0.035 * wordSize
    let wordW = textWidth(word, size: wordSize, weight: .black, kern: kern)
    let rowW = shiba + gap + wordW
    let x = (canvasWidth - rowW) / 2
    drawShiba(in: NSRect(x: x, y: top + (rowH - shiba) / 2, width: shiba, height: shiba))
    let textTop = top + (rowH - wordH) / 2
    _ = drawLine(word, x: x + shiba + gap, top: textTop, size: wordSize, weight: .black, color: ink, kernRatio: -0.035)
    return top + rowH
}

func drawTextPoster(width: CGFloat, height: CGFloat, shiba: CGFloat, headlineMax: CGFloat, sideMargin: CGFloat) {
    paintBackground(NSSize(width: width, height: height))
    let textW = width - sideMargin * 2
    let metrics = headlineMetrics(width: textW, maxSize: headlineMax)
    let gap = shiba * 0.18
    let blockH = metrics.height + gap + shiba
    let top = (height - blockH) / 2
    let headline = drawCenteredHeadline(canvasWidth: width, top: top, maxWidth: textW, maxSize: headlineMax)
    _ = drawBrandLockup(canvasWidth: width, top: headline.bottom + gap, shiba: shiba)
    print("poster", width, "headline", headline.size, "shiba", shiba)
}

func drawSubline(x: CGFloat, top: CGFloat, maxWidth: CGFloat, shiba: CGFloat, maxSize: CGFloat) -> CGFloat {
    let gap: CGFloat = shiba * 0.18
    let textMax = maxWidth - shiba - gap
    let size = min(maxSize, fitSize(text: subline, maxWidth: textMax, weight: .semibold, maxSize: maxSize, kernRatio: -0.02))
    let textH = lineBox(size, .semibold).height
    let rowH = max(shiba, textH)
    let shibaRect = NSRect(x: x, y: top + (rowH - shiba) / 2, width: shiba, height: shiba)
    drawShiba(in: shibaRect)
    let textTop = top + (rowH - textH) / 2
    _ = drawLine(subline, x: x + shiba + gap, top: textTop, size: size, weight: .semibold, color: inkSoft, kernRatio: -0.02)
    return top + rowH
}

func drawPhone(in topDown: NSRect) {
    let radius = topDown.width * 0.145
    let bezelRect = box(topDown)
    NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1).setFill()
    NSBezierPath(roundedRect: bezelRect, xRadius: radius, yRadius: radius).fill()

    let bezel = topDown.width * 0.034
    let screen = topDown.insetBy(dx: bezel, dy: bezel)
    let screenRadius = topDown.width * 0.112
    NSColor(srgbRed: 0.97, green: 0.97, blue: 0.96, alpha: 1).setFill()
    NSBezierPath(roundedRect: box(screen), xRadius: screenRadius, yRadius: screenRadius).fill()

    let islandW = screen.width * 0.32
    let islandH = topDown.width * 0.068
    let island = NSRect(x: screen.midX - islandW / 2, y: screen.minY + topDown.width * 0.032, width: islandW, height: islandH)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: box(island), xRadius: islandH / 2, yRadius: islandH / 2).fill()

    let side = screen.width * 0.05
    let cardsTop = island.maxY + screen.height * 0.04
    let bottomPad = screen.height * 0.07
    let gap = screen.height * 0.02
    let cardsHeight = screen.maxY - bottomPad - cardsTop
    let cardH = (cardsHeight - gap * 2) / 3
    let titleSize = cardH * 0.20
    let detailSize = cardH * 0.105

    for (index, row) in rows.enumerated() {
        let card = NSRect(
            x: screen.minX + side,
            y: cardsTop + CGFloat(index) * (cardH + gap),
            width: screen.width - side * 2,
            height: cardH
        )
        drawRowCard(row, in: card, titleSize: titleSize, detailSize: detailSize)
    }

    let barW = screen.width * 0.34
    let barH = max(10, topDown.width * 0.014)
    let bar = NSRect(x: screen.midX - barW / 2, y: screen.maxY - screen.height * 0.028 - barH, width: barW, height: barH)
    NSColor.black.withAlphaComponent(0.82).setFill()
    NSBezierPath(roundedRect: box(bar), xRadius: barH / 2, yRadius: barH / 2).fill()
}

func render(width: Int, height: Int, draw: () -> Void) -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create context")
    }
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldSmoothFonts(false)
    ctx.setAllowsFontSmoothing(false)

    let graphics = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    draw()
    NSGraphicsContext.restoreGraphicsState()

    guard let image = ctx.makeImage() else { fatalError("Could not make image") }
    return image
}

func writePNG(_ image: CGImage, name: String) {
    let width = image.width
    let height = image.height
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        fatalError("Could not flatten")
    }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let flat = ctx.makeImage() else { fatalError("flatten") }

    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("destination")
    }
    CGImageDestinationAddImage(dest, flat, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("finalize") }
    print("wrote", url.path)
}

func paintBackground(_ size: NSSize) {
    iconGold.setFill()
    NSRect(origin: .zero, size: size).fill()
}

func drawHeader() {
    // Wide and short, so the shiba is large but the headline still fits in one glance.
    drawTextPoster(width: 3840, height: 1646, shiba: 360, headlineMax: 270, sideMargin: 200)
}

func drawSearch() {
    drawTextPoster(width: 3840, height: 2560, shiba: 560, headlineMax: 340, sideMargin: 200)
}

let header = render(width: 3840, height: 1646) {
    canvasH = 1646
    drawHeader()
}
writePNG(header, name: "SubHelp-Header-3840x1646.png")

let search = render(width: 3840, height: 2560) {
    canvasH = 2560
    drawSearch()
}
writePNG(search, name: "SubHelp-Search-3840x2560.png")
