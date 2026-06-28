import Foundation

nonisolated struct FolderBookmarkService: Sendable {
    private let bookmarkKey = "lastOpenedFolderBookmark"

    func saveFolder(_ folderURL: URL) throws {
        let bookmarkData = try folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }

    func restoredFolderURL() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        do {
            var isStale = false
            let folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try saveFolder(folderURL)
            }

            return folderURL
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return nil
        }
    }
}
