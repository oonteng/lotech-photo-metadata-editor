import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated struct PhotoMetadataWriterService: Sendable {
    enum PhotoMetadataWriterError: LocalizedError {
        case unsupportedFormat
        case unreadableImage
        case destinationCreationFailed(URL)
        case writeFailed(URL)
        case replaceFailed(String)
        case verificationFailed(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                "This file format is read-only in this version."
            case .unreadableImage:
                "The photo could not be opened for saving."
            case let .destinationCreationFailed(url):
                "CGImageDestinationCreateWithURL failed for temporary file: \(url.path)"
            case let .writeFailed(url):
                "CGImageDestinationFinalize failed for temporary file: \(url.path)"
            case let .replaceFailed(reason):
                "Temporary file replacement failed: \(reason)"
            case let .verificationFailed(reason):
                "Saved metadata verification failed: \(reason)"
            }
        }
    }

    func save(metadata: PhotoMetadata, to photoFile: PhotoFile) async throws {
        SavePipelineDiagnostic.log("Opening file: \(photoFile.url.path)")
        let didStartSecurityScope = photoFile.url.startAccessingSecurityScopedResource()
        SavePipelineDiagnostic.log("File security scope started: \(didStartSecurityScope)")

        defer {
            if didStartSecurityScope {
                photoFile.url.stopAccessingSecurityScopedResource()
            }
        }

        guard let typeIdentifier = typeIdentifier(for: photoFile) else {
            SavePipelineDiagnostic.log("Unsupported format: \(photoFile.fileExtension)")
            throw PhotoMetadataWriterError.unsupportedFormat
        }
        SavePipelineDiagnostic.log("Resolved type identifier: \(typeIdentifier)")
        SavePipelineDiagnostic.log("Original readable: \(FileManager.default.isReadableFile(atPath: photoFile.url.path))")
        SavePipelineDiagnostic.log("Original writable: \(FileManager.default.isWritableFile(atPath: photoFile.url.path))")

        guard let source = CGImageSourceCreateWithURL(photoFile.url as CFURL, nil) else {
            SavePipelineDiagnostic.log("CGImageSourceCreateWithURL failed")
            throw PhotoMetadataWriterError.unreadableImage
        }
        SavePipelineDiagnostic.log("CGImageSourceCreateWithURL succeeded")

        let imageCount = CGImageSourceGetCount(source)
        guard imageCount > 0 else {
            SavePipelineDiagnostic.log("Image source contains no images")
            throw PhotoMetadataWriterError.unreadableImage
        }
        SavePipelineDiagnostic.log("Image count: \(imageCount)")

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("lotech-\(UUID().uuidString)-\(photoFile.url.lastPathComponent)")
        SavePipelineDiagnostic.log("Temporary destination: \(temporaryURL.path)")
        SavePipelineDiagnostic.log("Temporary folder writable: \(FileManager.default.isWritableFile(atPath: temporaryURL.deletingLastPathComponent().path))")

        guard let destination = CGImageDestinationCreateWithURL(
            temporaryURL as CFURL,
            typeIdentifier as CFString,
            imageCount,
            nil
        ) else {
            SavePipelineDiagnostic.log("CGImageDestinationCreateWithURL failed")
            throw PhotoMetadataWriterError.destinationCreationFailed(temporaryURL)
        }
        SavePipelineDiagnostic.log("CGImageDestinationCreateWithURL succeeded")

        for index in 0..<imageCount {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                try? FileManager.default.removeItem(at: temporaryURL)
                SavePipelineDiagnostic.log("CGImageSourceCreateImageAtIndex failed at index \(index)")
                throw PhotoMetadataWriterError.unreadableImage
            }

            let existingProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
            let updatedProperties = mergedProperties(existingProperties, metadata: metadata)
            CGImageDestinationAddImage(destination, image, updatedProperties as CFDictionary)
            SavePipelineDiagnostic.log("Added image and metadata at index \(index)")
        }

        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: temporaryURL)
            SavePipelineDiagnostic.log("CGImageDestinationFinalize failed")
            throw PhotoMetadataWriterError.writeFailed(temporaryURL)
        }
        SavePipelineDiagnostic.log("CGImageDestinationFinalize succeeded")

        do {
            _ = try FileManager.default.replaceItemAt(
                photoFile.url,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: []
            )
            SavePipelineDiagnostic.log("File replacement succeeded")
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            let nsError = error as NSError
            let reason = "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription) userInfo=\(nsError.userInfo)"
            SavePipelineDiagnostic.log("File replacement failed: \(reason)")
            throw PhotoMetadataWriterError.replaceFailed(reason)
        }

        guard CGImageSourceCreateWithURL(photoFile.url as CFURL, nil) != nil else {
            SavePipelineDiagnostic.log("Verification reopen failed")
            throw PhotoMetadataWriterError.verificationFailed("The saved file could not be reopened.")
        }
        SavePipelineDiagnostic.log("Verification reopen succeeded")
    }

    private func typeIdentifier(for photoFile: PhotoFile) -> String? {
        switch photoFile.fileExtension.lowercased() {
        case "jpg", "jpeg":
            return UTType.jpeg.identifier
        case "png":
            return UTType.png.identifier
        case "tif", "tiff":
            return UTType.tiff.identifier
        case "heic", "heif":
            return UTType.heic.identifier
        case "webp":
            return UTType.webP.identifier
        default:
            return nil
        }
    }

    private func mergedProperties(
        _ properties: [CFString: Any],
        metadata: PhotoMetadata
    ) -> [CFString: Any] {
        MetadataMapper.write(metadata, into: properties)
    }
}
