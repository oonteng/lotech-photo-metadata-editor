import Foundation

enum BatchMetadataField: String, CaseIterable, Identifiable, Sendable {
    case title
    case dateTaken
    case author
    case copyright
    case keywords
    case locationName

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .title: "Title"
        case .dateTaken: "Date"
        case .author: "Author"
        case .copyright: "Copyright"
        case .keywords: "Keywords"
        case .locationName: "Location"
        }
    }
}

struct BatchMetadataRow: Identifiable, Hashable, Sendable {
    enum Status: Hashable, Sendable {
        case pending
        case loading
        case loaded
        case readOnly
        case saving
        case saved
        case failed(String)

        var displayText: String {
            switch self {
            case .pending: "Pending"
            case .loading: "Loading"
            case .loaded: "Ready"
            case .readOnly: "Read-only"
            case .saving: "Saving"
            case .saved: "Saved"
            case let .failed(message): message
            }
        }
    }

    let id: URL
    let photoFile: PhotoFile
    var originalMetadata: PhotoMetadata
    var draftFileName: String
    var title: String
    var headline: String
    var dateTaken: String
    var dateCreated: String
    var dateModified: String
    var timezone: String
    var author: String
    var copyright: String
    var credit: String
    var license: String
    var website: String
    var email: String
    var keywords: String
    var locationName: String
    var latitude: String
    var longitude: String
    var altitude: String
    var city: String
    var province: String
    var country: String
    var status: Status

    init(photoFile: PhotoFile) {
        id = photoFile.url
        self.photoFile = photoFile
        originalMetadata = photoFile.metadata
        draftFileName = photoFile.fileName
        title = photoFile.metadata.title
        headline = photoFile.metadata.headline
        dateTaken = photoFile.metadata.dateTaken
        dateCreated = photoFile.metadata.dateCreated
        dateModified = photoFile.metadata.dateModified
        timezone = photoFile.metadata.timezone
        author = photoFile.metadata.author
        copyright = photoFile.metadata.copyright
        credit = photoFile.metadata.credit
        license = photoFile.metadata.license
        website = photoFile.metadata.website
        email = photoFile.metadata.email
        keywords = photoFile.metadata.keywords
        locationName = photoFile.metadata.locationName
        latitude = photoFile.metadata.latitude
        longitude = photoFile.metadata.longitude
        altitude = photoFile.metadata.altitude
        city = photoFile.metadata.city
        province = photoFile.metadata.province
        country = photoFile.metadata.country
        status = photoFile.supportsMetadataWriting ? .pending : .readOnly
    }

    var fileName: String {
        draftFileName
    }

    var fileExtension: String {
        photoFile.fileExtension.uppercased()
    }

    var isEditable: Bool {
        photoFile.supportsMetadataWriting
    }

    var hasDraftChanges: Bool {
        isEditable && (
            draftFileName != photoFile.fileName ||
            title != originalMetadata.title ||
            headline != originalMetadata.headline ||
            dateTaken != originalMetadata.dateTaken ||
            dateCreated != originalMetadata.dateCreated ||
            dateModified != originalMetadata.dateModified ||
            timezone != originalMetadata.timezone ||
            author != originalMetadata.author ||
            copyright != originalMetadata.copyright ||
            credit != originalMetadata.credit ||
            license != originalMetadata.license ||
            website != originalMetadata.website ||
            email != originalMetadata.email ||
            keywords != originalMetadata.keywords ||
            locationName != originalMetadata.locationName ||
            latitude != originalMetadata.latitude ||
            longitude != originalMetadata.longitude ||
            altitude != originalMetadata.altitude ||
            city != originalMetadata.city ||
            province != originalMetadata.province ||
            country != originalMetadata.country
        )
    }

    var hasGPS: Bool {
        !latitude.isEmpty && !longitude.isEmpty
    }

    var hasCopyright: Bool {
        !copyright.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasKeywords: Bool {
        !keywords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasDate: Bool {
        !dateTaken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var completenessPercent: Int {
        let checks = [
            !fileName.isEmpty,
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            hasDate,
            hasGPS,
            hasKeywords,
            hasCopyright
        ]
        let complete = checks.filter { $0 }.count
        return Int((Double(complete) / Double(checks.count) * 100).rounded())
    }

    var thumbnailData: Data? {
        originalMetadata.previewImageData
    }

    mutating func applyLoadedMetadata(_ metadata: PhotoMetadata) {
        originalMetadata = metadata
        draftFileName = metadata.fileName
        title = metadata.title
        headline = metadata.headline
        dateTaken = metadata.dateTaken
        dateCreated = metadata.dateCreated
        dateModified = metadata.dateModified
        timezone = metadata.timezone
        author = metadata.author
        copyright = metadata.copyright
        credit = metadata.credit
        license = metadata.license
        website = metadata.website
        email = metadata.email
        keywords = metadata.keywords
        locationName = metadata.locationName
        latitude = metadata.latitude
        longitude = metadata.longitude
        altitude = metadata.altitude
        city = metadata.city
        province = metadata.province
        country = metadata.country
        status = isEditable ? .loaded : .readOnly
    }

    mutating func discardDraftChanges() {
        draftFileName = photoFile.fileName
        title = originalMetadata.title
        headline = originalMetadata.headline
        dateTaken = originalMetadata.dateTaken
        dateCreated = originalMetadata.dateCreated
        dateModified = originalMetadata.dateModified
        timezone = originalMetadata.timezone
        author = originalMetadata.author
        copyright = originalMetadata.copyright
        credit = originalMetadata.credit
        license = originalMetadata.license
        website = originalMetadata.website
        email = originalMetadata.email
        keywords = originalMetadata.keywords
        locationName = originalMetadata.locationName
        latitude = originalMetadata.latitude
        longitude = originalMetadata.longitude
        altitude = originalMetadata.altitude
        city = originalMetadata.city
        province = originalMetadata.province
        country = originalMetadata.country
        status = isEditable ? .loaded : .readOnly
    }

    var metadataForSaving: PhotoMetadata {
        var metadata = originalMetadata
        metadata.fileName = draftFileName
        metadata.title = title
        metadata.headline = headline
        metadata.dateTaken = dateTaken
        metadata.dateCreated = dateCreated
        metadata.dateModified = dateModified
        metadata.timezone = timezone
        metadata.author = author
        metadata.copyright = copyright
        metadata.credit = credit
        metadata.license = license
        metadata.website = website
        metadata.email = email
        metadata.keywords = keywords
        metadata.locationName = locationName
        metadata.latitude = latitude
        metadata.longitude = longitude
        metadata.altitude = altitude
        metadata.city = city
        metadata.province = province
        metadata.country = country
        return metadata
    }

    func value(for field: BatchMetadataField) -> String {
        switch field {
        case .title: title
        case .dateTaken: dateTaken
        case .author: author
        case .copyright: copyright
        case .keywords: keywords
        case .locationName: locationName
        }
    }

    mutating func setValue(_ value: String, for field: BatchMetadataField) {
        switch field {
        case .title: title = value
        case .dateTaken: dateTaken = value
        case .author: author = value
        case .copyright: copyright = value
        case .keywords: keywords = value
        case .locationName: locationName = value
        }
    }
}
