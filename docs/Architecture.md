# Architecture

LOTECH Photo Metadata Editor is organized around a simple rule: the UI works with logical photo metadata, while format-specific metadata standards are handled by services.

## Layers

- Views: SwiftUI screens for Single Edit, Batch Edit, GPS editing, and navigation.
- ViewModels: user workflow state, selections, save state, undo/redo state, and folder loading.
- Services: folder scanning, security-scoped access, metadata read/write, and file rename operations.
- Metadata: the LOTECH logical metadata mapper.
- Models: photo files, library rows, batch rows, and editable metadata fields.

## Metadata Flow

1. User selects a folder.
2. Folder scanner builds photo library items.
3. Reader extracts file metadata through ImageIO.
4. Metadata mapper translates standards-specific dictionaries into LOTECH logical fields.
5. UI edits logical fields.
6. Writer maps logical fields back into supported standards dictionaries.
7. Save pipeline writes a temporary image, finalizes metadata, replaces the original file, and rereads it.

## Save Philosophy

Edits should not overwrite files immediately. The app marks changed records as modified, enables Save, writes only after explicit user action, and refreshes metadata after saving.

## Release Policy

Version 1.0.0 is the first release candidate baseline. Future changes should preserve project structure, metadata mapping boundaries, and local-first behavior.
