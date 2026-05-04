#!/usr/bin/env swift
import AppKit
import CoreGraphics

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func drawIcon(size: Int) -> NSImage {
    let s   = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); return img }

    // 背景圓角矩形（深藍漸層）
    let radius = s * 0.22
    let path   = CGPath(roundedRect: CGRect(x: 0, y: 0, width: s, height: s),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let bgColors  = [CGColor(red: 0.08, green: 0.10, blue: 0.20, alpha: 1),
                     CGColor(red: 0.06, green: 0.08, blue: 0.16, alpha: 1)]
    let bgGrad    = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: bgColors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bgGrad,
                           start: CGPoint(x: 0, y: s),
                           end:   CGPoint(x: s, y: 0),
                           options: [])

    let cx = s / 2, cy = s / 2
    let ro = s * 0.40   // 弧半徑
    let strokeW = max(1.5, s * 0.055)

    // 弧從 225° 到 315°（下方缺口）——以 macOS 座標（Y 朝上）換算
    // 225° → 左下, 315° → 右下（缺口朝下）
    func arcPoint(_ deg: CGFloat, r: CGFloat) -> CGPoint {
        let rad = deg * .pi / 180
        return CGPoint(x: cx + r * cos(rad), y: cy + r * sin(rad))
    }

    // 背景弧（全圓弧 225°..315° 順時針，缺口 90°）
    ctx.setLineWidth(strokeW)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: ro,
               startAngle: 225 * .pi / 180, endAngle: 315 * .pi / 180,
               clockwise: false)
    ctx.strokePath()

    // 前景弧（漸層，約 75% 填滿）
    // 使用 clip + 漸層 填充弧
    ctx.saveGState()
    ctx.setLineWidth(strokeW)
    ctx.setLineCap(.round)
    let arcEnd = 225 + 270 * 0.72  // 72% 的弧長
    let arcPath = CGMutablePath()
    arcPath.addArc(center: CGPoint(x: cx, y: cy), radius: ro,
                   startAngle: 225 * .pi / 180, endAngle: CGFloat(arcEnd) * .pi / 180,
                   clockwise: false)
    ctx.addPath(arcPath)
    // 用粗路徑的 stroke color 漸層：先描邊再蓋漸層
    ctx.setStrokeColor(CGColor(red: 0.40, green: 0.85, blue: 1.0, alpha: 1))
    ctx.strokePath()
    ctx.restoreGState()

    // 三根柱狀 bar（由下往上）
    let barW   = s * 0.10
    let barGap = s * 0.055
    let barBottom = cy + s * 0.20
    let barMaxH   = s * 0.38
    let barHeights: [CGFloat] = [0.55, 0.90, 0.40]
    let barXs: [CGFloat]      = [cx - barW - barGap, cx, cx + barW + barGap]
    let barColors: [CGFloat]  = [0.70, 1.0, 0.45]   // 亮度

    for (i, bx) in barXs.enumerated() {
        let bh   = barMaxH * barHeights[i]
        let by   = barBottom - bh
        let br   = barW / 2
        let barRect = CGRect(x: bx - barW / 2, y: by, width: barW, height: bh)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: br, cornerHeight: br, transform: nil)
        let bright  = barColors[i]
        ctx.setFillColor(CGColor(red: bright * 0.7 + 0.3,
                                 green: bright,
                                 blue: 1.0,
                                 alpha: 0.90))
        ctx.addPath(barPath)
        ctx.fillPath()
    }

    img.unlockFocus()
    return img
}

func savePNG(_ image: NSImage, to url: URL) {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: url)
}

// 產生 iconset 所需的各尺寸
let iconsetSizes: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in iconsetSizes {
    let img = drawIcon(size: size)
    savePNG(img, to: outDir.appendingPathComponent(name))
    print("✓ \(name)")
}
print("Done — run: iconutil -c icns \(outDir.path)")
