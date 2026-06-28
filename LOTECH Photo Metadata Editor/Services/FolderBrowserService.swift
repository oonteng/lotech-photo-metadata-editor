import Foundation

nonisolated struct FolderBrowserService: Sendable {
    enum FolderBrowserError: LocalizedError {
        case unreadableFolder

        var errorDescription: String? {
            switch self {
            case .unreadableFolder:
                "The selected folder could not be read."
            }
        }
    }

    private static let supportedPhotoExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "webp",
        "cr2", "cr3", "nef", "arw", "raf", "dng"
    ]

    nonisolated func libraryTree(for folderURL: URL) throws -> PhotoLibraryItem {
        try makeFolderItem(for: folderURL)
    }

    nonisolated func isSupportedPhotoFile(_ url: URL) -> Bool {
        Self.supportedPhotoExtensions.contains(url.pathExtension.lowercased())
    }

    private nonisolated func makeFolderItem(for folderURL: URL) throws -> PhotoLibraryItem {
        let contents: [URL]

        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .isRegularFileKey,
                    .isHiddenKey,
                    .fileSizeKey,
                    .creationDateKey,
                    .contentModificationDateKey
                ],
                options: [.skipsPackageDescendants]
            )
        } catch {
            throw FolderBrowserError.unreadableFolder
        }

        let childItems = try contents
            .filter { url in
                let values = try? url.resourceValues(forKeys: [.isHiddenKey])
                return values?.isHidden != true
            }
            .compactMap { url -> PhotoLibraryItem? in
                let resourceValues = try url.resourceValues(
                    forKeys: [
                        .isDirectoryKey,
                        .isRegularFileKey,
                        .fileSizeKey,
                        .creationDateKey,
                        .contentModificationDateKey
                    ]
                )

                if resourceValues.isDirectory == true {
                    return try makeFolderItem(for: url)
                }

                guard resourceValues.isRegularFile == true, isSupportedPhotoFile(url) else {
                    return nil
                }

                let photoFile = PhotoFile(url: url, resourceValues: resourceValues)

                return PhotoLibraryItem(
                    id: url,
                    name: url.lastPathComponent,
                    kind: .photoFile(photoFile)
                )
            }
            .sortedForDisplay()

        return PhotoLibraryItem(
            id: folderURL,
            name: folderURL.lastPathComponent,
            kind: .folder,
            children: childItems
        )
    }
}

private extension Array where Element == PhotoLibraryItem {
    nonisolated func sortedForDisplay() -> [PhotoLibraryItem] {
        sorted { lhs, rhs in
            switch (lhs.kind, rhs.kind) {
            case (.folder, .photoFile):
                true
            case (.photoFile, .folder):
                false
            default:
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }
}
