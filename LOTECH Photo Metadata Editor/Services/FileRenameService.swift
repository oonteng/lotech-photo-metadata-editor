import Foundation

nonisolated struct FileRenameService: Sendable {
    enum FileRenameError: LocalizedError {
        case emptyFileName
        case invalidFileName
        case duplicateFileName
        case renameFailed

        var errorDescription: String? {
            switch self {
            case .emptyFileName:
                "File name cannot be empty."
            case .invalidFileName:
                "File name contains invalid characters."
            case .duplicateFileName:
                "A file with that name already exists."
            case .renameFailed:
                "The file could not be renamed."
            }
        }
    }

    func rename(photoFile: PhotoFile, to requestedFileName: String) throws -> URL {
        let destinationURL = try destinationURL(for: photoFile, requestedFileName: requestedFileName)

        guard destinationURL != photoFile.url else {
            return photoFile.url
        }

        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw FileRenameError.duplicateFileName
        }

        do {
            try FileManager.default.moveItem(at: photoFile.url, to: destinationURL)
            return destinationURL
        } catch {
            throw FileRenameError.renameFailed
        }
    }

    private func destinationURL(for photoFile: PhotoFile, requestedFileName: String) throws -> URL {
        let trimmedName = requestedFileName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            throw FileRenameError.emptyFileName
        }

        guard
            !trimmedName.contains("/"),
            !trimmedName.contains(":"),
            trimmedName != ".",
            trimmedName != ".."
        else {
            throw FileRenameError.invalidFileName
        }

        let baseName = URL(fileURLWithPath: trimmedName).deletingPathExtension().lastPathComponent
        let fileName = "\(baseName).\(photoFile.fileExtension)"
        return photoFile.url.deletingLastPathComponent().appendingPathComponent(fileName)
    }
}
