import AppKit
import Foundation

// Brew Manager 图标生成器:程序化绘制 1024 设计稿并导出全套 iconset 尺寸。
// 用法:swift tools/generate_icon.swift <输出iconset目录>

// MARK: - 设计稿(1024×1024 坐标系,y 轴向上)

/// 琥珀色渐变背景 + 白色啤酒杯剪影。
func drawIcon(in ctx: CGContext) {
    // 背景:macOS 风格圆角矩形(约 22.4% 圆角)
    let bgRect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 230, yRadius: 230)
    ctx.saveGState()
    bgPath.addClip()
    let topColor = NSColor(calibratedRed: 1.00, green: 0.77, blue: 0.24, alpha: 1) // 浅琥珀 #FFC53D
    let bottomColor = NSColor(calibratedRed: 0.88, green: 0.48, blue: 0.00, alpha: 1) // 深琥珀 #E07B00
    NSGradient(starting: topColor, ending: bottomColor)!.draw(in: bgPath, angle: -90)
    ctx.restoreGState()

    let white = NSColor(calibratedWhite: 1.0, alpha: 0.96)

    // 杯柄:描边圆角矩形(先画,让杯身盖住内侧接头)
    let handleRect = CGRect(x: 590, y: 370, width: 155, height: 215)
    let handle = NSBezierPath(roundedRect: handleRect, xRadius: 62, yRadius: 62)
    handle.lineWidth = 46
    white.setStroke()
    handle.stroke()

    // 杯身
    let bodyRect = CGRect(x: 280, y: 235, width: 340, height: 470)
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: 38, yRadius: 38)
    white.setFill()
    body.fill()

    // 泡沫:杯口上方三个交叠的圆
    for (cx, cy, r) in [(370.0, 697.0, 66.0), (472.0, 729.0, 78.0), (568.0, 691.0, 58.0)] {
        let foam = NSBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        foam.fill()
    }
    // 泡沫底部补齐,盖住杯身上沿与圆之间的缝隙
    let foamBase = NSBezierPath(roundedRect: CGRect(x: 290, y: 645, width: 320, height: 62), xRadius: 28, yRadius: 28)
    foamBase.fill()

    // 杯身两道竖向高光,暗示玻璃质感
    let highlight = NSColor(calibratedWhite: 1.0, alpha: 1.0)
    _ = highlight // 保持单色,不再叠加
}

// MARK: - 导出

func renderPNG(size: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw NSError(domain: "icon", code: 1) }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: ctx)
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon", code: 2)
    }
    try data.write(to: url)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("用法: swift tools/generate_icon.swift <输出iconset目录>")
    exit(1)
}
let iconsetDir = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// iconutil 要求的标准尺寸组合
let specs: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]
for spec in specs {
    let url = iconsetDir.appendingPathComponent("\(spec.name).png")
    try renderPNG(size: spec.pixels, to: url)
    print("已生成 \(spec.name).png (\(spec.pixels)px)")
}
print("iconset 输出完成: \(iconsetDir.path)")
