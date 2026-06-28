import Foundation

nonisolated enum MetadataField: String, CaseIterable, Identifiable, Sendable {
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
    case gps
    case locationName
    case city
    case province
    case country
    case people
    case event

    var id: String {
        rawValue
    }
}
