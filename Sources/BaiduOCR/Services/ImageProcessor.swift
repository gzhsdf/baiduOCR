import AppKit
import CoreGraphics
import ImageIO

enum ImageProcessor {
    static func toBase64(_ image: NSImage, maxSizeMB: Int = 4) -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = image.size
        let maxBytes = maxSizeMB * 1024 * 1024

        // Try compression levels from 0.7 down to 0.2
        for quality in stride(from: 0.7, through: 0.2, by: -0.1) {
            let options: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: quality
            ]
            if let jpeg = rep.representation(using: .jpeg, properties: options),
               jpeg.count <= maxBytes {
                return jpeg.base64EncodedString()
            }
        }

        // If still too large, resize to half and try again
        let scaledRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(image.size.width * 0.5),
            pixelsHigh: Int(image.size.height * 0.5),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaledRep)
        image.draw(in: NSRect(x: 0, y: 0, width: scaledRep.size.width, height: scaledRep.size.height),
                   from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let jpeg = scaledRep.representation(using: .jpeg, properties: [.compressionFactor: 0.5]) else {
            return ""
        }
        return jpeg.base64EncodedString()
    }

    static func crop(_ image: NSImage, to rect: NSRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let scale = image.size.width / CGFloat(cgImage.width)
        let pixelRect = NSRect(
            x: rect.origin.x / scale,
            y: (image.size.height - rect.origin.y - rect.size.height) / scale,
            width: rect.size.width / scale,
            height: rect.size.height / scale
        )
        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }
}
