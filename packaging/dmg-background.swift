// Draws the disk image background with the OpenVault palette (assets/brand/BRAND.md).
//
// Light on purpose: the Finder paints icon labels dark once a background image
// is set and no .DS_Store key changes that, so a dark image hides the names.
// Paper (#F9FAFC) with a soft glow of the brand gradient behind the app icon,
// and a Graphite arrow pointing at Applications.
//
// Positions mirror icon_locations in dmg-settings.py (window 640x400, y from
// the top). The image is drawn past the window so it still covers a resize.
// A single 1x PNG: a @2x pair turns into an uncompressed TIFF, tens of MB.
//
// Regenerate packaging/dmg-background.png with:
//   swiftc -O packaging/dmg-background.swift -o /tmp/bggen && /tmp/bggen packaging

import AppKit

let width = 1280.0
let height = 800.0
let appCenter = CGPoint(x: 170, y: 190)
let applicationsCenter = CGPoint(x: 470, y: 190)

let outDir = CommandLine.arguments.dropFirst().first ?? "."

func hex(_ value: Int, alpha: Double = 1) -> CGColor {
    CGColor(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255, alpha: alpha)
}

/// CoreGraphics counts y from the bottom; the Finder window from the top.
func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: height - p.y) }

guard let ctx = CGContext(
    data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("no context") }

// Paper.
ctx.setFillColor(hex(0xF9FAFC))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// Brand glows: blue behind the app, purple fading toward Applications.
func glow(at center: CGPoint, radius: Double, color: Int, alpha: Double) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [hex(color, alpha: alpha), hex(color, alpha: 0)] as CFArray,
                              locations: [0, 1])!
    let c = flip(center)
    ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
}
glow(at: appCenter, radius: 260, color: 0x4490FE, alpha: 0.16)
glow(at: CGPoint(x: 360, y: 60), radius: 320, color: 0x8443D3, alpha: 0.08)

// Arrow from the app to Applications, clear of the 128px icons.
let start = flip(CGPoint(x: appCenter.x + 90, y: appCenter.y))
let end = flip(CGPoint(x: applicationsCenter.x - 90, y: applicationsCenter.y))
ctx.setStrokeColor(hex(0x52555C, alpha: 0.45))
ctx.setLineWidth(5)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: start)
ctx.addLine(to: end)
ctx.move(to: CGPoint(x: end.x - 16, y: end.y + 16))
ctx.addLine(to: end)
ctx.addLine(to: CGPoint(x: end.x - 16, y: end.y - 16))
ctx.strokePath()

guard let image = ctx.makeImage() else { fatalError("no image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
let path = "\(outDir)/dmg-background.png"
try! png.write(to: URL(fileURLWithPath: path))
print("wrote \(path) (\(Int(width))x\(Int(height)))")
