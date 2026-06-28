# LOTECH Metadata Standard

This document defines the logical metadata model used by LOTECH Photo Metadata Editor.

The UI must show stable user-facing fields such as Author, Title, Copyright, Keywords, GPS, Website, and Email. It must not expose EXIF, IPTC, TIFF, or XMP choices to the user.

## Design Rule

Read from every supported namespace and display the first meaningful value.

Write the logical field to every appropriate namespace supported by the current writer.

Do not hide fields because the current image does not already contain that metadata namespace.

## Current ImageIO Support

The current implementation writes through Apple's ImageIO APIs. ImageIO supports TIFF, EXIF, IPTC, and GPS dictionaries for the formats this app writes.

ImageIO does not expose a public `kCGImagePropertyXMPDictionary` in the current SDK, and testing showed that passing a raw `{XMP}` dictionary is dropped during write. Full XMP parity should therefore be implemented later with a dedicated XMP packet writer or a vetted metadata engine such as ExifTool, not by pretending ImageIO wrote XMP.

## Logical Field Mapping

| Logical Field | Read From | Write To | Status |
| --- | --- | --- | --- |
| Title | IPTC Object Name, TIFF Image Description, filename fallback | IPTC Object Name | Active |
| Headline | IPTC Headline, IPTC Extension Headline | IPTC Headline, IPTC Extension Headline | Active |
| Caption | IPTC Caption/Abstract, TIFF Image Description, EXIF User Comment | IPTC Caption/Abstract, TIFF Image Description, EXIF User Comment | Active |
| Keywords | IPTC Keywords | IPTC Keywords | Active |
| Author | TIFF Artist, IPTC Byline, IPTC Extension Creator Name | TIFF Artist, IPTC Byline, IPTC Extension Creator Name | Active |
| Copyright | TIFF Copyright, IPTC Copyright Notice | TIFF Copyright, IPTC Copyright Notice | Active |
| Credit | IPTC Credit | IPTC Credit | Active |
| License | IPTC Rights Usage Terms | IPTC Rights Usage Terms | Active |
| Website | IPTC Creator Contact Info `CiUrlWork` | IPTC Creator Contact Info `CiUrlWork` | Active |
| Email | IPTC Creator Contact Info `CiEmailWork` | IPTC Creator Contact Info `CiEmailWork` | Active |
| Date Taken | EXIF DateTimeOriginal, TIFF DateTime, IPTC Date Created/Time Created | EXIF DateTimeOriginal | Active |
| Date Created | IPTC Date Created/Time Created, EXIF DateTimeDigitized | EXIF DateTimeDigitized | Active |
| Date Modified | TIFF DateTime | TIFF DateTime | Active |
| GPS Latitude/Longitude | EXIF GPS Latitude/Longitude | EXIF GPS Latitude/Longitude, IPTC Extension Location GPS Latitude/Longitude | Active |
| GPS Altitude | EXIF GPS Altitude | EXIF GPS Altitude, IPTC Extension Location GPS Altitude | Active |
| Location | IPTC Content Location Name, IPTC Sublocation, IPTC Extension Location Name | IPTC Content Location Name, IPTC Sublocation, IPTC Extension Location Name | Active |
| City | IPTC City, IPTC Extension Location City | IPTC City, IPTC Extension Location City | Active |
| Province / State | IPTC Province/State, IPTC Extension Location Province/State | IPTC Province/State, IPTC Extension Location Province/State | Active |
| Country | IPTC Country Primary Location Name, IPTC Extension Location Country Name | IPTC Country Primary Location Name, IPTC Extension Location Country Name | Active |
| People | IPTC Extension Person In Image | IPTC Extension Person In Image | Active |
| Event | IPTC Extension Event | IPTC Extension Event | Active |

## Planned XMP Mapping

These mappings are not currently written by the ImageIO writer. They should be added when a dedicated XMP packet writer exists.

| Logical Field | Planned XMP Mapping |
| --- | --- |
| Title | `dc:title` |
| Headline | `photoshop:Headline` |
| Caption | `dc:description` |
| Keywords | `dc:subject`, `lr:hierarchicalSubject` when appropriate |
| Author | `dc:creator` |
| Copyright | `dc:rights`, `xmpRights:Marked`, `xmpRights:WebStatement` where appropriate |
| Credit | `photoshop:Credit` |
| License | `xmpRights:UsageTerms` |
| Website | `Iptc4xmpCore:CreatorContactInfo/Iptc4xmpCore:CiUrlWork` |
| Email | `Iptc4xmpCore:CreatorContactInfo/Iptc4xmpCore:CiEmailWork` |
| GPS | EXIF GPS namespace inside XMP |

## Implementation Files

- `LOTECH Photo Metadata Editor/Metadata/MetadataField.swift`
- `LOTECH Photo Metadata Editor/Metadata/MetadataMapper.swift`
- `LOTECH Photo Metadata Editor/Services/PhotoMetadataReaderService.swift`
- `LOTECH Photo Metadata Editor/Services/PhotoMetadataWriterService.swift`

All future metadata editors should follow this pattern: UI works with logical fields; format adapters handle standards-specific details.
