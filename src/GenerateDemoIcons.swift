#!/usr/bin/env swift

import Foundation
import AppKit

/// Generates app icons with a "DEMO" watermark banner
/// Banner stays within icon bounds for macOS Tahoe compatibility
/// Usage: swift GenerateDemoIcons.swift

let fileManager = FileManager.default

// Determine paths relative to script location
let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let projectDir = scriptPath.deletingLastPathComponent()
let assetsDir = projectDir.appendingPathComponent("CrosswordStudio/Assets.xcassets")
let sourceIconDir = assetsDir.appendingPathComponent("AppIcon.appiconset")
let demoIconDir = assetsDir.appendingPathComponent("DemoAppIcon.appiconset")

print("Generating demo icons with DEMO watermark (Tahoe-compatible)...")
print("Source: \(sourceIconDir.path)")
print("Output: \(demoIconDir.path)")

// Create demo icon directory if needed
try? fileManager.createDirectory(at: demoIconDir, withIntermediateDirectories: true)

// Get all source icon files
let iconFiles = try! fileManager.contentsOfDirectory(at: sourceIconDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "png" && $0.lastPathComponent.contains("Default") }

for iconFile in iconFiles {
    let filename = iconFile.lastPathComponent
    let demoFilename = filename.replacingOccurrences(of: "Default", with: "Demo")
    let outputPath = demoIconDir.appendingPathComponent(demoFilename)

    guard let sourceImage = NSImage(contentsOf: iconFile) else {
        print("  Error: Could not load \(filename)")
        continue
    }

    let size = sourceImage.size

    // Banner dimensions - covers lower 30%, positioned slightly up from bottom
    let bannerHeight = size.height * 0.30
    let bannerY = size.height * 0.12  // Moved up from the very bottom

    let width = Int(size.width)
    let height = Int(size.height)

    // Create bitmap context
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
              data: nil,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: width * 4,
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        print("  Error: Could not create context for \(demoFilename)")
        continue
    }

    let rect = CGRect(origin: .zero, size: size)

    // Draw original icon
    guard let sourceCGImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("  Error: Could not get CGImage for \(filename)")
        continue
    }
    context.draw(sourceCGImage, in: rect)

    // Draw banner rectangle
    let bannerRect = CGRect(x: 0, y: 0, width: size.width, height: bannerY + bannerHeight)
    context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.92))
    context.fill(CGRect(x: 0, y: 0, width: size.width, height: bannerY + bannerHeight - bannerY))

    // Actually draw the banner in the correct position
    context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.92))
    context.fill(CGRect(x: 0, y: bannerY, width: size.width, height: bannerHeight))

    // Use destination-in to clip to original icon's alpha
    context.setBlendMode(.destinationIn)
    context.draw(sourceCGImage, in: rect)
    context.setBlendMode(.normal)

    // Create result image and draw text on top
    guard let resultCGImage = context.makeImage() else {
        print("  Error: Could not create result image for \(demoFilename)")
        continue
    }

    let newImage = NSImage(size: size)
    newImage.lockFocus()

    let nsContext = NSGraphicsContext.current!
    nsContext.cgContext.draw(resultCGImage, in: rect)

    // Draw "DEMO" text
    let fontSize = max(bannerHeight * 0.55, 5)
    let font = NSFont.boldSystemFont(ofSize: fontSize)
    let textAttributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let text = "DEMO"
    let textSize = text.size(withAttributes: textAttributes)
    let textX = (size.width - textSize.width) / 2
    let textY = bannerY + (bannerHeight - textSize.height) / 2
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)

    newImage.unlockFocus()

    // Save as PNG
    guard let tiffData = newImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("  Error: Could not create PNG for \(demoFilename)")
        continue
    }

    try! pngData.write(to: outputPath)
    print("  Created: \(demoFilename)")
}

print("")
print("Demo icons generated successfully!")
