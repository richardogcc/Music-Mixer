#!/usr/bin/env swift
// Generates the app icon for Music Mixer: renders the iconset PNGs into
// build/AppIcon.iconset and converts them to Resources/AppIcon.icns.
// Run from the repo root: swift scripts/make_icon.swift
import Foundation
import CoreGraphics
import AppKit

// size → filename suffix
let iconset: [(Int, String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let outDir = root.appendingPathComponent("build/AppIcon.iconset", isDirectory: true)
try? fm.removeItem(at: outDir)
try! fm.createDirectory(at: outDir, withIntermediateDirectories: true)

func makeIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Flip to top-left origin (easier maths)
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    let pad = s * 0.09
    let r   = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let cr  = s * 0.22

    // ── Background: dark radial gradient ──────────────────────────────
    ctx.saveGState()
    let bgPath = CGPath(roundedRect: r, cornerWidth: cr, cornerHeight: cr, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    let bgColors = [
        CGColor(red: 0.13, green: 0.13, blue: 0.20, alpha: 1),
        CGColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1),
    ] as CFArray
    let locs: [CGFloat] = [0, 1]
    let gradient = CGGradient(colorsSpace: cs, colors: bgColors, locations: locs)!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: r.midX, y: r.minY),
        end:   CGPoint(x: r.midX, y: r.maxY),
        options: []
    )
    ctx.restoreGState()

    // ── Three equaliser bars (vertical) ───────────────────────────────
    // Heights as fractions of the inner area
    let barHeights: [CGFloat] = [0.52, 0.78, 0.40]
    let barCount  = CGFloat(barHeights.count)
    let innerW    = r.width  * 0.62
    let innerH    = r.height * 0.56
    let barW      = innerW / (barCount + (barCount - 1) * 0.55)
    let gapW      = barW * 0.55
    let totalW    = barW * barCount + gapW * (barCount - 1)
    let startX    = r.midX - totalW / 2
    let baseY     = r.midY + innerH * 0.22

    // Bar gradient: blue → purple
    let barColors = [
        CGColor(red: 0.04, green: 0.52, blue: 1.00, alpha: 1), // #0A84FF
        CGColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 1), // #BF5AF2
    ] as CFArray
    let barGradient = CGGradient(colorsSpace: cs, colors: barColors, locations: locs)!

    for (i, heightFrac) in barHeights.enumerated() {
        let x    = startX + CGFloat(i) * (barW + gapW)
        let barH = innerH * heightFrac
        let y    = baseY - barH
        let bCR  = barW * 0.38
        let bar  = CGRect(x: x, y: y, width: barW, height: barH)
        let barPath = CGPath(roundedRect: bar, cornerWidth: bCR, cornerHeight: bCR, transform: nil)

        ctx.saveGState()
        ctx.addPath(barPath)
        ctx.clip()
        ctx.drawLinearGradient(
            barGradient,
            start: CGPoint(x: bar.midX, y: bar.maxY),
            end:   CGPoint(x: bar.midX, y: bar.minY),
            options: []
        )
        ctx.restoreGState()

        // Gloss cap on top of each bar
        let capH  = barH * 0.18
        let capR  = CGRect(x: x, y: y, width: barW, height: capH)
        let capPath = CGPath(roundedRect: capR, cornerWidth: bCR, cornerHeight: bCR, transform: nil)
        ctx.saveGState()
        ctx.addPath(capPath)
        ctx.clip()
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
        ctx.fill(capR)
        ctx.restoreGState()
    }

    // ── Subtle horizontal tick marks (like a mixer grid) ───────────────
    let tickAlpha: CGFloat = 0.12
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: tickAlpha))
    ctx.setLineWidth(max(1, s * 0.009))
    for frac: CGFloat in [0.25, 0.5, 0.75] {
        let ty = (r.maxY - r.minY) * (1 - frac) + r.minY - (r.height - innerH) * 0.1
        let lx = r.midX - totalW / 2 - barW * 0.3
        let rx = r.midX + totalW / 2 + barW * 0.3
        ctx.move(to: CGPoint(x: lx, y: ty))
        ctx.addLine(to: CGPoint(x: rx, y: ty))
        ctx.strokePath()
    }

    // ── Rounded rect border glow ───────────────────────────────────────
    ctx.saveGState()
    let borderPath = CGPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5),
                             cornerWidth: cr, cornerHeight: cr, transform: nil)
    ctx.addPath(borderPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
    ctx.setLineWidth(max(1, s * 0.012))
    ctx.strokePath()
    ctx.restoreGState()

    return ctx.makeImage()
}

for (size, name) in iconset {
    guard let img = makeIcon(size: size) else {
        print("⚠️  Could not generate \(name).png")
        continue
    }
    let rep = NSBitmapImageRep(cgImage: img)
    if let data = rep.representation(using: .png, properties: [:]) {
        let dest = outDir.appendingPathComponent("\(name).png")
        try! data.write(to: dest)
        print("✅  \(dest.lastPathComponent)  (\(size)px)")
    }
}

let icnsPath = root.appendingPathComponent("Resources/AppIcon.icns").path
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", outDir.path, "-o", icnsPath]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "\nDone: Resources/AppIcon.icns" : "\niconutil failed")
