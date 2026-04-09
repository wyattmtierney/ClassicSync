import AppKit

enum ArtworkResizer {
    static let maxDimension: CGFloat = 500

    /// Returns JPEG data, resized to max 500×500 if needed.
    static func jpegData(from image: NSImage) -> Data? {
        let size = image.size
        let needsResize = size.width > maxDimension || size.height > maxDimension

        let target: NSImage
        if needsResize {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = NSSize(width: size.width * scale, height: size.height * scale)
            target = NSImage(size: newSize)
            target.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize),
                       from: NSRect(origin: .zero, size: size),
                       operation: .copy,
                       fraction: 1.0)
            target.unlockFocus()
        } else {
            target = image
        }

        guard let tiff = target.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
