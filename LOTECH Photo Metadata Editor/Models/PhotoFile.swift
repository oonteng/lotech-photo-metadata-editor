import Foundation

nonisolated struct PhotoFile: Hashable, Sendable {
    let url: URL
    let path: String
    let fileName: String
    let fileExtension: String
    let fileSize: Int64?
    let createdDate: Date?
    let modifiedDate: Date?
    var metadata: PhotoMetadata
    var isDirty: Bool

    var supportsMetadataWriting: Bool {
        ["jpg", "jpeg", "png", "tif", "tiff", "heic", "heif", "webp"].contains(fileExtension.lowercased())
    }

    init(url: URL, resourceValues: URLResourceValues = URLResourceValues()) {
        self.url = url
        path = url.path
        fileName = url.lastPathComponent
        fileExtension = url.pathExtension
        fileSize = resourceValues.fileSize.map(Int64.init)
        createdDate = resourceValues.creationDate
        modifiedDate = resourceValues.contentModificationDate
        metadata = PhotoMetadata.placeholder(for: url, fileSize: fileSize, createdDate: createdDate, modifiedDate: modifiedDate)
        isDirty = false
    }
}
