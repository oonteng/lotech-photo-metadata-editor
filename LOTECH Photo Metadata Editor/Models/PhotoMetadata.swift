import Foundation

nonisolated struct PhotoMetadata: Hashable, Sendable {
    var fileName: String
    var title: String
    var headline: String
    var caption: String
    var keywords: String
    var author: String
    var copyright: String
    var credit: String
    var license: String
    var website: String
    var email: String
    var dateTaken: String
    var dateCreated: String
    var dateModified: String
    var timezone: String
    var cameraMake: String
    var cameraModel: String
    var lens: String
    var iso: String
    var aperture: String
    var shutterSpeed: String
    var focalLength: String
    var orientation: String
    var latitude: String
    var longitude: String
    var altitude: String
    var cameraDirection: String
    var locationName: String
    var city: String
    var province: String
    var country: String
    var people: String
    var event: String
    var dimensions: String
    var megapixels: String
    var fileSize: String
    var colorProfile: String
    var previewImageData: Data?

    static let sample = PhotoMetadata(
        fileName: "IMG_0001.jpg",
        title: "Marina Bay Evening",
        headline: "Singapore waterfront",
        caption: "Sample photo metadata will appear here when a photo is selected.",
        keywords: "travel, singapore, evening",
        author: "LOTECH",
        copyright: "Copyright 2026 LOTECH",
        credit: "",
        license: "",
        website: "",
        email: "",
        dateTaken: "2026",
        dateCreated: "",
        dateModified: "",
        timezone: "",
        cameraMake: "Canon",
        cameraModel: "EOS R6",
        lens: "RF 24-105mm",
        iso: "200",
        aperture: "f/4",
        shutterSpeed: "1/250",
        focalLength: "70mm",
        orientation: "Landscape",
        latitude: "1.352083",
        longitude: "103.819839",
        altitude: "",
        cameraDirection: "",
        locationName: "Singapore",
        city: "Singapore",
        province: "",
        country: "Singapore",
        people: "",
        event: "",
        dimensions: "6000 x 4000",
        megapixels: "24.0 MP",
        fileSize: "",
        colorProfile: "",
        previewImageData: nil
    )

    static func placeholder(for url: URL, fileSize: Int64? = nil, createdDate: Date? = nil, modifiedDate: Date? = nil) -> PhotoMetadata {
        PhotoMetadata(
            fileName: url.lastPathComponent,
            title: url.deletingPathExtension().lastPathComponent,
            headline: "",
            caption: "",
            keywords: "",
            author: "",
            copyright: "",
            credit: "",
            license: "",
            website: "",
            email: "",
            dateTaken: "",
            dateCreated: createdDate.map(Self.dateFormatter.string(from:)) ?? "",
            dateModified: modifiedDate.map(Self.dateFormatter.string(from:)) ?? "",
            timezone: "",
            cameraMake: "",
            cameraModel: "",
            lens: "",
            iso: "",
            aperture: "",
            shutterSpeed: "",
            focalLength: "",
            orientation: "",
            latitude: "",
            longitude: "",
            altitude: "",
            cameraDirection: "",
            locationName: "",
            city: "",
            province: "",
            country: "",
            people: "",
            event: "",
            dimensions: "",
            megapixels: "",
            fileSize: fileSize.map(Self.byteFormatter.string(fromByteCount:)) ?? "",
            colorProfile: "",
            previewImageData: nil
        )
    }

    func value(for field: EditableMetadataField) -> String {
        switch field {
        case .fileName: fileName
        case .title: title
        case .headline: headline
        case .caption: caption
        case .keywords: keywords
        case .author: author
        case .copyright: copyright
        case .credit: credit
        case .license: license
        case .website: website
        case .email: email
        case .dateTaken: dateTaken
        case .dateCreated: dateCreated
        case .dateModified: dateModified
        case .timezone: timezone
        case .cameraMake: cameraMake
        case .cameraModel: cameraModel
        case .lens: lens
        case .iso: iso
        case .aperture: aperture
        case .shutterSpeed: shutterSpeed
        case .focalLength: focalLength
        case .orientation: orientation
        case .latitude: latitude
        case .longitude: longitude
        case .altitude: altitude
        case .cameraDirection: cameraDirection
        case .locationName: locationName
        case .city: city
        case .province: province
        case .country: country
        case .people: people
        case .event: event
        }
    }

    func renamedFileMetadata(for photoFile: PhotoFile) -> PhotoMetadata {
        var metadata = self
        metadata.fileName = photoFile.fileName
        return metadata
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let byteFormatter = ByteCountFormatter()
}
