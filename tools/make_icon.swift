// 앱 아이콘 원본(1024px PNG)을 그린다. 35mm 필름 통과 빠져나온 필름.
// 사용: swift tools/make_icon.swift <출력.png>
import AppKit

let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// 가로 방향 그라데이션으로 원통처럼 보이게 칠한다.
func fillCylinder(_ path: CGPath, _ colors: [CGColor], _ locations: [CGFloat]) {
    let box = path.boundingBox
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: box.minX, y: 0), end: CGPoint(x: box.maxX, y: 0), options: [])
    ctx.restoreGState()
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// 배경: macOS 아이콘 격자에 맞춘 둥근 사각형
let tile = roundedRect(CGRect(x: 100, y: 100, width: 824, height: 824), 185)
ctx.saveGState()
ctx.addPath(tile)
ctx.clip()
let background = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(0xF8F2E7), rgb(0xE9DDC8)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
ctx.restoreGState()

// 배치 기준
let dy: CGFloat = -10
let body = CGRect(x: 262, y: 280 + dy, width: 250, height: 460)
let film = CGRect(x: 470, y: body.midY - 165, width: 0, height: 330)
let filmEnd: CGFloat = 800

// 필름: 통 안에서 나와 끝이 반쯤 잘린 모양
let filmPath = CGMutablePath()
let cutX: CGFloat = 650
let tongueBottom = film.midY + 10
filmPath.move(to: CGPoint(x: film.minX, y: film.minY))
filmPath.addLine(to: CGPoint(x: cutX, y: film.minY))
filmPath.addCurve(
    to: CGPoint(x: cutX + 70, y: tongueBottom),
    control1: CGPoint(x: cutX + 45, y: film.minY),
    control2: CGPoint(x: cutX + 30, y: tongueBottom)
)
filmPath.addLine(to: CGPoint(x: filmEnd - 24, y: tongueBottom))
filmPath.addQuadCurve(to: CGPoint(x: filmEnd, y: tongueBottom + 24), control: CGPoint(x: filmEnd, y: tongueBottom))
filmPath.addLine(to: CGPoint(x: filmEnd, y: film.maxY - 24))
filmPath.addQuadCurve(to: CGPoint(x: filmEnd - 24, y: film.maxY), control: CGPoint(x: filmEnd, y: film.maxY))
filmPath.addLine(to: CGPoint(x: film.minX, y: film.maxY))
filmPath.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.18))
ctx.addPath(filmPath)
ctx.setFillColor(rgb(0xC9772C))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(filmPath)
ctx.clip()
let filmShade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [rgb(0xD98A3D), rgb(0xA95E1F)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(filmShade, start: CGPoint(x: 0, y: film.maxY), end: CGPoint(x: 0, y: film.minY), options: [])
ctx.restoreGState()

// 필름 구멍(퍼포레이션): 위아래 가장자리
ctx.saveGState()
ctx.addPath(filmPath)
ctx.clip()
ctx.setFillColor(rgb(0xF1E8D9))
let holeW: CGFloat = 22, holeH: CGFloat = 30, pitch: CGFloat = 42, inset: CGFloat = 18
var x = body.maxX + 14
while x + holeW < filmEnd - 18 {
    ctx.addPath(roundedRect(CGRect(x: x, y: film.maxY - inset - holeH, width: holeW, height: holeH), 6))
    if x + holeW < cutX - 4 {
        ctx.addPath(roundedRect(CGRect(x: x, y: film.minY + inset, width: holeW, height: holeH), 6))
    }
    x += pitch
}
ctx.fillPath()
ctx.restoreGState()

// 필름 통: 위아래 뚜껑, 몸통, 심
let metal = [rgb(0x26262B), rgb(0x76767F), rgb(0x45454C), rgb(0x1E1E22)]
let metalStops: [CGFloat] = [0, 0.32, 0.7, 1]
let capInset: CGFloat = -14
let topCap = roundedRect(CGRect(x: body.minX + capInset, y: body.maxY - 6, width: body.width - capInset * 2, height: 50), 14)
let bottomCap = roundedRect(CGRect(x: body.minX + capInset, y: body.minY - 44, width: body.width - capInset * 2, height: 50), 14)
let spindle = roundedRect(CGRect(x: body.midX - 48, y: body.maxY + 40, width: 96, height: 52), 10)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.25))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
fillCylinder(spindle, metal, metalStops)
fillCylinder(roundedRect(body, 4), [rgb(0x0F434A), rgb(0x2E97A1), rgb(0x1E737C), rgb(0x0E3A40)], metalStops)
fillCylinder(topCap, metal, metalStops)
fillCylinder(bottomCap, metal, metalStops)
ctx.endTransparencyLayer()
ctx.restoreGState()

// 심 윗면의 홈
ctx.setFillColor(rgb(0x18181B))
ctx.fill(CGRect(x: body.midX - 8, y: body.maxY + 62, width: 16, height: 30))

// 몸통 띠와 숫자
let band = CGRect(x: body.minX, y: body.midY - 78, width: body.width, height: 156)
fillCylinder(CGPath(rect: band, transform: nil), [rgb(0xD8CDB8), rgb(0xFFFBF2), rgb(0xF1E8D8), rgb(0xCFC3AD)], metalStops)

let font = NSFont.systemFont(ofSize: 132, weight: .heavy)
let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 132) } ?? font
let label = NSAttributedString(string: "35", attributes: [
    .font: rounded,
    .foregroundColor: NSColor(srgbRed: 0.08, green: 0.30, blue: 0.34, alpha: 1),
    .kern: -4,
])
let labelSize = label.size()
label.draw(at: CGPoint(x: band.midX - labelSize.width / 2 - 4, y: band.midY - labelSize.height / 2 + 4))

// 필름이 나오는 입구(빛 막는 천)
ctx.addPath(roundedRect(CGRect(x: body.maxX - 10, y: film.minY - 14, width: 18, height: film.height + 28), 8))
ctx.setFillColor(rgb(0x141416))
ctx.fillPath()

NSGraphicsContext.restoreGraphicsState()

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try! rep.representation(using: .png, properties: [:])!.write(to: output)
