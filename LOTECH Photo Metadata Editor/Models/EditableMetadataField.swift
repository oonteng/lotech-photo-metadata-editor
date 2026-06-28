import Foundation

nonisolated enum EditableMetadataField: Hashable, Sendable {
    case fileName
    case title
    case headline
    case caption
    case keywords
    case author
    case copyright
    case credit
    case license
    case website
    case email
    case dateTaken
    case dateCreated
    case dateModified
    case timezone
    case cameraMake
    case cameraModel
    case lens
    case iso
    case aperture
    case shutterSpeed
    case focalLength
    case orientation
    case latitude
    case longitude
    case altitude
    case cameraDirection
    case locationName
    case city
    case province
    case country
    case people
    case event

    var displayName: String {
        switch self {
        case .fileName: "File Name"
        case .title: "Title"
        case .headline: "Headline"
        case .caption: "Caption"
        case .keywords: "Keywords"
        case .author: "Author"
        case .copyright: "Copyright"
        case .credit: "Credit"
        case .license: "License"
        case .website: "Website"
        case .email: "Email"
        case .dateTaken: "Date Taken"
        case .dateCreated: "Date Created"
        case .dateModified: "Date Modified"
        case .timezone: "Timezone"
        case .cameraMake: "Camera Make"
        case .cameraModel: "Camera Model"
        case .lens: "Lens"
        case .iso: "ISO"
        case .aperture: "Aperture"
        case .shutterSpeed: "Shutter"
        case .focalLength: "Focal Length"
        case .orientation: "Orientation"
        case .latitude: "Latitude"
        case .longitude: "Longitude"
        case .altitude: "Altitude"
        case .cameraDirection: "Direction"
        case .locationName: "Location"
        case .city: "City"
        case .province: "Province"
        case .country: "Country"
        case .people: "People"
        case .event: "Event"
        }
    }

    var failureMessage: String {
        "Cannot write to file"
    }
}
