import Foundation
import ImageIO

nonisolated enum MetadataMapper {
    private static let contactEmailKey = "CiEmailWork"
    private static let contactURLKey = "CiUrlWork"

    static func read(from properties: [CFString: Any], base metadata: PhotoMetadata) -> PhotoMetadata {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
        let contact = iptc[kCGImagePropertyIPTCCreatorContactInfo] as? [String: Any] ?? [:]

        var mapped = metadata
        mapped.title = firstString(
            iptc[kCGImagePropertyIPTCObjectName],
            tiff[kCGImagePropertyTIFFImageDescription],
            fallback: mapped.title
        )
        mapped.headline = firstString(
            iptc[kCGImagePropertyIPTCHeadline],
            iptc[kCGImagePropertyIPTCExtHeadline]
        )
        mapped.caption = firstString(
            iptc[kCGImagePropertyIPTCCaptionAbstract],
            tiff[kCGImagePropertyTIFFImageDescription],
            exif[kCGImagePropertyExifUserComment]
        )
        mapped.keywords = firstStringList(iptc[kCGImagePropertyIPTCKeywords])
        mapped.author = firstString(
            tiff[kCGImagePropertyTIFFArtist],
            iptc[kCGImagePropertyIPTCByline],
            iptc[kCGImagePropertyIPTCExtCreatorName]
        )
        mapped.copyright = firstString(
            tiff[kCGImagePropertyTIFFCopyright],
            iptc[kCGImagePropertyIPTCCopyrightNotice]
        )
        mapped.credit = firstString(iptc[kCGImagePropertyIPTCCredit])
        mapped.license = firstString(iptc[kCGImagePropertyIPTCRightsUsageTerms])
        mapped.website = firstString(contact[contactURLKey])
        mapped.email = firstString(contact[contactEmailKey])
        mapped.dateTaken = firstString(
            exif[kCGImagePropertyExifDateTimeOriginal],
            tiff[kCGImagePropertyTIFFDateTime],
            joinedDateTime(date: iptc[kCGImagePropertyIPTCDateCreated], time: iptc[kCGImagePropertyIPTCTimeCreated]),
            fallback: mapped.dateTaken
        )
        mapped.dateCreated = firstString(
            joinedDateTime(date: iptc[kCGImagePropertyIPTCDateCreated], time: iptc[kCGImagePropertyIPTCTimeCreated]),
            exif[kCGImagePropertyExifDateTimeDigitized],
            fallback: mapped.dateCreated.isEmpty ? mapped.dateTaken : mapped.dateCreated
        )
        mapped.dateModified = firstString(tiff[kCGImagePropertyTIFFDateTime], fallback: mapped.dateModified)
        mapped.cameraMake = firstString(tiff[kCGImagePropertyTIFFMake])
        mapped.cameraModel = firstString(tiff[kCGImagePropertyTIFFModel])
        mapped.lens = firstString(exif[kCGImagePropertyExifLensModel])
        mapped.iso = numberList(exif[kCGImagePropertyExifISOSpeedRatings])
        mapped.aperture = apertureString(exif[kCGImagePropertyExifFNumber])
        mapped.shutterSpeed = exposureString(exif[kCGImagePropertyExifExposureTime])
        mapped.focalLength = focalLengthString(exif[kCGImagePropertyExifFocalLength])
        mapped.latitude = coordinateString(value: gps[kCGImagePropertyGPSLatitude], reference: gps[kCGImagePropertyGPSLatitudeRef])
        mapped.longitude = coordinateString(value: gps[kCGImagePropertyGPSLongitude], reference: gps[kCGImagePropertyGPSLongitudeRef])
        mapped.altitude = firstString(gps[kCGImagePropertyGPSAltitude])
        mapped.cameraDirection = firstString(gps[kCGImagePropertyGPSImgDirection])
        mapped.city = firstString(iptc[kCGImagePropertyIPTCCity], iptc[kCGImagePropertyIPTCExtLocationCity])
        mapped.province = firstString(iptc[kCGImagePropertyIPTCProvinceState], iptc[kCGImagePropertyIPTCExtLocationProvinceState])
        mapped.country = firstString(iptc[kCGImagePropertyIPTCCountryPrimaryLocationName], iptc[kCGImagePropertyIPTCExtLocationCountryName])
        mapped.locationName = firstString(
            iptc[kCGImagePropertyIPTCContentLocationName],
            iptc[kCGImagePropertyIPTCSubLocation],
            iptc[kCGImagePropertyIPTCExtLocationLocationName],
            fallback: [mapped.city, mapped.country].filter { !$0.isEmpty }.joined(separator: ", ")
        )
        mapped.people = firstStringList(iptc[kCGImagePropertyIPTCExtPersonInImage])
        mapped.event = firstString(iptc[kCGImagePropertyIPTCExtEvent])

        return mapped
    }

    static func write(_ metadata: PhotoMetadata, into properties: [CFString: Any]) -> [CFString: Any] {
        var merged = properties
        var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        var exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        var iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any] ?? [:]
        var gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
        var contact = iptc[kCGImagePropertyIPTCCreatorContactInfo] as? [String: Any] ?? [:]

        set(metadata.title, for: kCGImagePropertyIPTCObjectName, in: &iptc)
        set(metadata.headline, for: kCGImagePropertyIPTCHeadline, in: &iptc)
        set(metadata.headline, for: kCGImagePropertyIPTCExtHeadline, in: &iptc)
        set(metadata.caption, for: kCGImagePropertyIPTCCaptionAbstract, in: &iptc)
        set(metadata.caption, for: kCGImagePropertyTIFFImageDescription, in: &tiff)
        set(metadata.caption, for: kCGImagePropertyExifUserComment, in: &exif)
        set(metadata.author, for: kCGImagePropertyTIFFArtist, in: &tiff)
        set(metadata.author, for: kCGImagePropertyIPTCByline, in: &iptc)
        set(metadata.author, for: kCGImagePropertyIPTCExtCreatorName, in: &iptc)
        set(metadata.copyright, for: kCGImagePropertyTIFFCopyright, in: &tiff)
        set(metadata.copyright, for: kCGImagePropertyIPTCCopyrightNotice, in: &iptc)
        set(metadata.credit, for: kCGImagePropertyIPTCCredit, in: &iptc)
        set(metadata.license, for: kCGImagePropertyIPTCRightsUsageTerms, in: &iptc)
        set(metadata.dateModified, for: kCGImagePropertyTIFFDateTime, in: &tiff)
        set(metadata.dateTaken, for: kCGImagePropertyExifDateTimeOriginal, in: &exif)
        set(metadata.dateCreated, for: kCGImagePropertyExifDateTimeDigitized, in: &exif)
        set(metadata.city, for: kCGImagePropertyIPTCCity, in: &iptc)
        set(metadata.city, for: kCGImagePropertyIPTCExtLocationCity, in: &iptc)
        set(metadata.province, for: kCGImagePropertyIPTCProvinceState, in: &iptc)
        set(metadata.province, for: kCGImagePropertyIPTCExtLocationProvinceState, in: &iptc)
        set(metadata.country, for: kCGImagePropertyIPTCCountryPrimaryLocationName, in: &iptc)
        set(metadata.country, for: kCGImagePropertyIPTCExtLocationCountryName, in: &iptc)
        set(metadata.locationName, for: kCGImagePropertyIPTCContentLocationName, in: &iptc)
        set(metadata.locationName, for: kCGImagePropertyIPTCSubLocation, in: &iptc)
        set(metadata.locationName, for: kCGImagePropertyIPTCExtLocationLocationName, in: &iptc)
        set(metadata.event, for: kCGImagePropertyIPTCExtEvent, in: &iptc)

        let keywords = list(from: metadata.keywords)
        setList(keywords, for: kCGImagePropertyIPTCKeywords, in: &iptc)
        setList(list(from: metadata.people), for: kCGImagePropertyIPTCExtPersonInImage, in: &iptc)
        setContact(metadata.email, for: contactEmailKey, in: &contact)
        setContact(metadata.website, for: contactURLKey, in: &contact)
        if contact.isEmpty {
            iptc.removeValue(forKey: kCGImagePropertyIPTCCreatorContactInfo)
        } else {
            iptc[kCGImagePropertyIPTCCreatorContactInfo] = contact
        }

        writeGPS(metadata, into: &gps, iptc: &iptc)

        merged[kCGImagePropertyTIFFDictionary] = tiff
        merged[kCGImagePropertyExifDictionary] = exif
        merged[kCGImagePropertyIPTCDictionary] = iptc
        merged[kCGImagePropertyGPSDictionary] = gps
        return merged
    }

    private static func writeGPS(
        _ metadata: PhotoMetadata,
        into gps: inout [CFString: Any],
        iptc: inout [CFString: Any]
    ) {
        if let latitude = Double(metadata.latitude), let longitude = Double(metadata.longitude) {
            gps[kCGImagePropertyGPSLatitude] = abs(latitude)
            gps[kCGImagePropertyGPSLatitudeRef] = latitude < 0 ? "S" : "N"
            gps[kCGImagePropertyGPSLongitude] = abs(longitude)
            gps[kCGImagePropertyGPSLongitudeRef] = longitude < 0 ? "W" : "E"
            iptc[kCGImagePropertyIPTCExtLocationGPSLatitude] = latitude
            iptc[kCGImagePropertyIPTCExtLocationGPSLongitude] = longitude
        } else {
            gps.removeValue(forKey: kCGImagePropertyGPSLatitude)
            gps.removeValue(forKey: kCGImagePropertyGPSLatitudeRef)
            gps.removeValue(forKey: kCGImagePropertyGPSLongitude)
            gps.removeValue(forKey: kCGImagePropertyGPSLongitudeRef)
            iptc.removeValue(forKey: kCGImagePropertyIPTCExtLocationGPSLatitude)
            iptc.removeValue(forKey: kCGImagePropertyIPTCExtLocationGPSLongitude)
        }

        if let altitude = Double(metadata.altitude) {
            gps[kCGImagePropertyGPSAltitude] = abs(altitude)
            gps[kCGImagePropertyGPSAltitudeRef] = altitude < 0 ? 1 : 0
            iptc[kCGImagePropertyIPTCExtLocationGPSAltitude] = altitude
        } else {
            gps.removeValue(forKey: kCGImagePropertyGPSAltitude)
            gps.removeValue(forKey: kCGImagePropertyGPSAltitudeRef)
            iptc.removeValue(forKey: kCGImagePropertyIPTCExtLocationGPSAltitude)
        }
    }

    private static func firstString(_ values: Any?..., fallback: String = "") -> String {
        for value in values {
            if let string = string(value), !string.isEmpty {
                return string
            }
        }

        return fallback
    }

    private static func firstStringList(_ value: Any?) -> String {
        if let values = value as? [String] {
            return values.joined(separator: ", ")
        }
        if let values = value as? [Any] {
            return values.compactMap(string).joined(separator: ", ")
        }

        return string(value) ?? ""
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let value as NSNumber:
            return value.stringValue
        default:
            return nil
        }
    }

    private static func list(from value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func set(_ value: String, for key: CFString, in dictionary: inout [CFString: Any]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            dictionary.removeValue(forKey: key)
        } else {
            dictionary[key] = trimmed
        }
    }

    private static func setContact(_ value: String, for key: String, in dictionary: inout [String: Any]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            dictionary.removeValue(forKey: key)
        } else {
            dictionary[key] = trimmed
        }
    }

    private static func setList(_ values: [String], for key: CFString, in dictionary: inout [CFString: Any]) {
        if values.isEmpty {
            dictionary.removeValue(forKey: key)
        } else {
            dictionary[key] = values
        }
    }

    private static func joinedDateTime(date: Any?, time: Any?) -> String? {
        guard let dateString = string(date) else {
            return nil
        }

        guard let timeString = string(time) else {
            return dateString
        }

        return "\(dateString) \(timeString)"
    }

    private static func numberList(_ value: Any?) -> String {
        if let values = value as? [NSNumber] {
            return values.map(\.stringValue).joined(separator: ", ")
        }

        return string(value) ?? ""
    }

    private static func apertureString(_ value: Any?) -> String {
        guard let value = value as? NSNumber else {
            return string(value) ?? ""
        }

        return String(format: "f/%.1f", value.doubleValue)
    }

    private static func exposureString(_ value: Any?) -> String {
        guard let value = value as? NSNumber else {
            return string(value) ?? ""
        }

        let seconds = value.doubleValue
        if seconds > 0, seconds < 1 {
            return "1/\(Int(round(1 / seconds)))"
        }

        return String(format: "%.2fs", seconds)
    }

    private static func focalLengthString(_ value: Any?) -> String {
        guard let value = value as? NSNumber else {
            return string(value) ?? ""
        }

        return String(format: "%.0fmm", value.doubleValue)
    }

    private static func coordinateString(value: Any?, reference: Any?) -> String {
        guard let number = value as? NSNumber else {
            return string(value) ?? ""
        }

        var coordinate = number.doubleValue
        let ref = string(reference)?.uppercased()
        if ref == "S" || ref == "W" {
            coordinate *= -1
        }

        return String(format: "%.6f", coordinate)
    }
}
