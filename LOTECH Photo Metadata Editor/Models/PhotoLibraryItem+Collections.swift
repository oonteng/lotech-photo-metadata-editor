import Foundation

extension Array where Element == PhotoLibraryItem {
    func firstItem(withID id: PhotoLibraryItem.ID) -> PhotoLibraryItem? {
        for item in self {
            if item.id == id {
                return item
            }

            if let child = item.children?.firstItem(withID: id) {
                return child
            }
        }

        return nil
    }

    func foldersOnly() -> [PhotoLibraryItem] {
        compactMap { item in
            guard case .folder = item.kind else {
                return nil
            }

            return PhotoLibraryItem(
                id: item.id,
                name: item.name,
                kind: item.kind,
                children: item.children?.foldersOnly()
            )
        }
    }

    func replacingPhotoFile(oldURL: URL, with photoFile: PhotoFile) -> [PhotoLibraryItem] {
        map { item in
            if item.id == oldURL {
                return PhotoLibraryItem(id: photoFile.url, name: photoFile.fileName, kind: .photoFile(photoFile))
            }

            guard let children = item.children else {
                return item
            }

            return PhotoLibraryItem(
                id: item.id,
                name: item.name,
                kind: item.kind,
                children: children.replacingPhotoFile(oldURL: oldURL, with: photoFile)
            )
        }
    }
}

extension PhotoLibraryItem {
    func directPhotoFilesForBatchEditing() -> [PhotoFile] {
        children?.compactMap(\.photoFile) ?? []
    }
}
