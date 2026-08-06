#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <AppIcon.iconset>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    let size = CGFloat(variant.pixels)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let backgroundRect = NSRect(x: 0, y: 0, width: size, height: size)
    let background = NSBezierPath(
        roundedRect: backgroundRect.insetBy(dx: size * 0.04, dy: size * 0.04),
        xRadius: size * 0.22,
        yRadius: size * 0.22
    )
    NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
    background.fill()

    let circleRect = backgroundRect.insetBy(dx: size * 0.14, dy: size * 0.14)
    NSColor(calibratedRed: 0.114, green: 0.725, blue: 0.329, alpha: 1).setFill()
    NSBezierPath(ovalIn: circleRect).fill()

    NSColor(calibratedWhite: 0.04, alpha: 1).setStroke()
    for index in 0..<3 {
        let offset = CGFloat(index) * size * 0.105
        let path = NSBezierPath()
        path.move(to: NSPoint(x: size * 0.29, y: size * 0.62 - offset))
        path.curve(
            to: NSPoint(x: size * 0.72, y: size * 0.58 - offset),
            controlPoint1: NSPoint(x: size * 0.43, y: size * 0.69 - offset),
            controlPoint2: NSPoint(x: size * 0.62, y: size * 0.68 - offset)
        )
        path.lineWidth = max(1, size * (index == 0 ? 0.045 : 0.038))
        path.lineCapStyle = .round
        path.stroke()
    }

    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Could not render \(variant.name)\n", stderr)
        exit(1)
    }

    try pngData.write(to: outputDirectory.appendingPathComponent(variant.name))
}
