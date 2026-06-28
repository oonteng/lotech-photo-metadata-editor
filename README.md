# LOTECH Photo Metadata Editor

A modern macOS photo metadata editor with spreadsheet-style batch editing and Apple Maps GPS correction.

LOTECH Photo Metadata Editor is built for cleaning and repairing large photo libraries while keeping the workflow local-first. It presents a simple logical metadata model to the user while internally mapping fields across the image metadata standards supported by Apple ImageIO.

## Features

- Single Edit view for focused metadata correction.
- Batch Edit spreadsheet for editing many photos at once.
- Apple Maps GPS search, map pin editing, reverse geocoding, and coordinate repair.
- Copyright, credit, license, website, email, keywords, date/time, title, caption, location, and GPS editing.
- Metadata completeness indicators for archive cleanup.
- Undo, redo, reload, and explicit save workflow.
- Local-first design. Photos stay on the Mac unless the user chooses otherwise.

## Metadata Philosophy

The app uses a LOTECH logical metadata model. Users edit fields such as Author, Copyright, Keywords, GPS, Website, and Email without needing to know whether the file stores those values in TIFF, EXIF, IPTC, GPS, or a future XMP engine.

Current standards coverage is documented in [docs/Metadata_Standard.md](docs/Metadata_Standard.md).

## Requirements

- macOS 26.5 or later.
- Xcode 26.6 or later to build from source.

## Building

Open `LOTECH Photo Metadata Editor.xcodeproj` in Xcode and build the `LOTECH Photo Metadata Editor` scheme.

For release packaging, use the Release configuration and verify both Apple Silicon and Universal builds before distribution.

## Project Structure

- `LOTECH Photo Metadata Editor/Models` - app data models.
- `LOTECH Photo Metadata Editor/Views` - SwiftUI interface.
- `LOTECH Photo Metadata Editor/ViewModels` - app workflow state.
- `LOTECH Photo Metadata Editor/Services` - folder scanning, metadata IO, and rename services.
- `LOTECH Photo Metadata Editor/Metadata` - logical metadata mapping layer.
- `LOTECH Photo Metadata Editor/Utilities` - diagnostics and supporting utilities.
- `docs` - architecture and metadata documentation.

## Privacy

LOTECH Photo Metadata Editor is local-first. It reads and writes files selected by the user and does not upload photo libraries to a server.

## License

MIT License. Copyright (c) 2026 Lee Oon Teng.
