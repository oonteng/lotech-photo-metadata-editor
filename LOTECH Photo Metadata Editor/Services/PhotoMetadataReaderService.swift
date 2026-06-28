import AppKit
import CoreGraphics
import Foundation
import ImageIO

nonisolated struct PhotoMetadataReaderService: Sendable {
    enum PhotoMetadataReaderError: LocalizedError {
        case unreadableMetadata

        var errorDescription: String? {
            switch self {
            case .unreadableMetadata:
                "The selected photo's metadata could not be read."
            }
        }
    }

    func metadata(for photoFile: PhotoFile) async throws -> PhotoMetadata {
        let didStartSecurityScope = photoFile.url.startAccessingSecurityScopedResource()

        defer {
            if didStartSecurityScope {
                photoFile.url.stopAccessingSecurityScopedResource()
            }
        }

        guard
            let source = CGImageSourceCreateWithURL(photoFile.url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            throw PhotoMetadataReaderError.unreadableMetadata
        }

        var metadata = MetadataMapper.read(from: properties, base: photoFile.metadata)
        metadata.orientation = displayOrientationString(properties)
        metadata.dimensions = dimensionsString(properties)
        metadata.megapixels = megapixelsString(properties)
        metadata.colorProfile = string(properties[kCGImagePropertyProfileName]) ?? ""
        metadata.previewImageData = previewImageData(for: source)

        return metadata
    }

    private func string(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private func dimensionsString(_ properties: [CFString: Any]) -> String {
        guard
            let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
            let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else {
            return ""
        }

        return "\(width.intValue) x \(height.intValue)"
    }

    private func displayOrientationString(_ properties: [CFString: Any]) -> String {
        let rawOrientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue
        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue

        let displayWidth: Int?
        let displayHeight: Int?
        if rawOrientation == 6 || rawOrientation == 8 {
            displayWidth = height
            displayHeight = width
        } else {
            displayWidth = width
            displayHeight = height
        }

        guard let displayWidth, let displayHeight else {
            return rawOrientation.map { "Orientation \($0)" } ?? ""
        }

        if displayHeight > displayWidth {
            return "Portrait"
        }

        if displayWidth > displayHeight {
            return "Landscape"
        }

        return "Square"
    }

    private func megapixelsString(_ properties: [CFString: Any]) -> String {
        guard
            let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
            let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
        else {
            return ""
        }

        let megapixels = Double(width.intValue * height.intValue) / 1_000_000
        return String(format: "%.1f MP", megapixels)
    }

    private func previewImageData(for source: CGImageSource) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 900,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let nsImage = NSImage(cgImage: image, size: .zero)
        guard let tiffData = nsImage.tiffRepresentation else {
            return nil
        }

        return tiffData
    }
}
