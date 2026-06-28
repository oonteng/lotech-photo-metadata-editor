import Foundation

nonisolated struct PhotoLibraryItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case folder
        case photoFile(PhotoFile)

        var systemImageName: String {
            switch self {
            case .folder:
                "folder"
            case .photoFile:
                "photo"
            }
        }
    }

    let id: URL
    let name: String
    let kind: Kind
    let children: [PhotoLibraryItem]?

    init(id: URL, name: String, kind: Kind, children: [PhotoLibraryItem]? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.children = children
    }

    var isPhotoFile: Bool {
        photoFile != nil
    }

    var photoFile: PhotoFile? {
        guard case let .photoFile(photoFile) = kind else {
            return nil
        }

        return photoFile
    }
}
