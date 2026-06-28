import AppKit
import SwiftUI

struct MetadataEditorView: View {
    let item: PhotoLibraryItem?
    @Binding var metadata: PhotoMetadata
    let failedField: EditableMetadataField?
    let saveErrorMessage: String
    let isEditingEnabled: Bool
    let hasUnsavedChanges: Bool
    let isSaving: Bool
    let onCommitField: (EditableMetadataField) -> Void
    let onSaveChanges: () -> Void
    @FocusState private var focusedField: EditableMetadataField?

    var body: some View {
        Group {
            if let item, item.isPhotoFile {
                editor
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: focusedField) { oldField, newField in
            guard let oldField, oldField != newField else {
                return
            }

            onCommitField(oldField)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 24)

            GeometryReader { proxy in
                let availableWidth = proxy.size.width
                let isWide = availableWidth > 980
                let editorWidth = isWide ? availableWidth * 0.48 : availableWidth

                Group {
                    if isWide {
                        HStack(alignment: .top, spacing: 28) {
                            ScrollView {
                                metadataFields
                                    .frame(width: editorWidth, alignment: .topLeading)
                                    .padding(.bottom, 24)
                            }
                            .frame(width: editorWidth)

                            ScrollView {
                                inspector
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(.bottom, 24)
                            }
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                metadataFields
                                inspector
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
                .frame(width: availableWidth, alignment: .topLeading)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(metadata.fileName)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(action: onSaveChanges) {
                Label("Save Changes", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasUnsavedChanges || isSaving || !isEditingEnabled)
        }
    }

    private var metadataFields: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 14) {
            sectionLabel("File")
            metadataRow(.fileName, text: $metadata.fileName)
            readOnlyRow("Dimensions", metadata.dimensions)
            readOnlyRow("Megapixels", metadata.megapixels)
            readOnlyRow("File Size", metadata.fileSize)
            readOnlyRow("Color Profile", metadata.colorProfile)

            sectionLabel("IPTC")
            metadataRow(.title, text: $metadata.title)
            metadataRow(.headline, text: $metadata.headline)
            metadataEditorRow(.caption, text: $metadata.caption, minHeight: 94)
            metadataRow(.keywords, text: $metadata.keywords)
            metadataRow(.city, text: $metadata.city)
            metadataRow(.province, text: $metadata.province)
            metadataRow(.country, text: $metadata.country)
            metadataRow(.people, text: $metadata.people)
            metadataRow(.event, text: $metadata.event)

            sectionLabel("Copyright")
            metadataRow(.author, text: $metadata.author)
            metadataRow(.copyright, text: $metadata.copyright)
            metadataRow(.credit, text: $metadata.credit)
            metadataRow(.license, text: $metadata.license)
            metadataRow(.website, text: $metadata.website)
            metadataRow(.email, text: $metadata.email)

            sectionLabel("Date / Time")
            dateWarningRow()
            metadataRow(.dateTaken, text: $metadata.dateTaken)
            metadataRow(.dateCreated, text: $metadata.dateCreated)
            metadataRow(.dateModified, text: $metadata.dateModified)
            metadataRow(.timezone, text: $metadata.timezone)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 22) {
            photoPreview

            HStack(alignment: .top, spacing: 16) {
                inspectorCard("Camera") {
                    inspectorLine("Make", metadata.cameraMake)
                    inspectorLine("Model", metadata.cameraModel)
                    inspectorLine("Lens", metadata.lens)
                    inspectorLine("ISO", metadata.iso)
                    inspectorLine("Aperture", metadata.aperture)
                    inspectorLine("Shutter", metadata.shutterSpeed)
                    inspectorLine("Focal", metadata.focalLength)
                    inspectorLine("Orientation", metadata.orientation)
                }

                inspectorCard("GPS") {
                    inspectorLocationLine(metadata.locationDisplay)
                    inspectorLine("Latitude", metadata.latitude)
                    inspectorLine("Longitude", metadata.longitude)
                    inspectorLine("Altitude", metadata.altitude)
                    inspectorLine("Direction", metadata.cameraDirection)
                }
            }

            GPSInspectorView(metadata: $metadata)
        }
    }

    private var photoPreview: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor)

            Group {
                if let previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("No Preview")
                            .font(.headline)
                        Text("Select a supported photo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(0)
        }
        .frame(maxWidth: .infinity, minHeight: 500, maxHeight: 640)
    }

    private var previewImage: NSImage? {
        guard let data = metadata.previewImageData else {
            return nil
        }

        return NSImage(data: data)
    }

    private func sectionLabel(_ title: String) -> some View {
        GridRow {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Divider()
        }
    }

    private func metadataRow(_ field: EditableMetadataField, text: Binding<String>, compact: Bool = false) -> some View {
        GridRow {
            fieldLabel(field.displayName, compact: compact)

            ZStack(alignment: .trailing) {
                TextField(field.displayName, text: text)
                    .textFieldStyle(.roundedBorder)
                    .padding(.trailing, failedField == field ? 124 : 0)
                    .focused($focusedField, equals: field)
                    .disabled(!isEditingEnabled)
                    .onSubmit {
                        focusedField = nil
                    }

                if failedField == field {
                    failurePill(for: field)
                        .padding(.trailing, 7)
                }
            }
            .frame(minWidth: compact ? 210 : 280, idealWidth: compact ? 260 : 440, maxWidth: .infinity)
            .overlay {
                if failedField == field {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.red, lineWidth: 1)
                }
            }
        }
    }

    private func dateWarningRow() -> some View {
        GridRow {
            Color.clear
                .frame(width: 140)

            Text("Normally leave unchanged. Edit only when repairing metadata.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.10), in: Capsule())
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metadataEditorRow(_ field: EditableMetadataField, text: Binding<String>, minHeight: CGFloat) -> some View {
        GridRow(alignment: .top) {
            fieldLabel(field.displayName)
                .padding(.top, 6)

            PaddedTextEditor(text: text) {
                onCommitField(field)
            }
            .frame(minWidth: 280, idealWidth: 440, maxWidth: .infinity, minHeight: minHeight)
            .disabled(!isEditingEnabled)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(failedField == field ? Color.red : Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if failedField == field {
                    failurePill(for: field)
                        .padding(8)
                }
            }
        }
    }

    private func readOnlyRow(_ label: String, _ value: String) -> some View {
        GridRow {
            fieldLabel(label)
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(value.isEmpty ? .secondary : .primary)
                .frame(minWidth: 280, idealWidth: 440, maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inspectorCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 8) {
                content()
            }
        }
        .font(.caption)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func inspectorLine(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value.isEmpty ? "—" : value)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inspectorLocationLine(_ value: String) -> some View {
        GridRow {
            Text(value.isEmpty ? "—" : value)
                .font(.caption.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridCellColumns(2)
        }
    }

    private func fieldLabel(_ title: String, compact: Bool = false) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(width: compact ? 82 : 140, alignment: .trailing)
    }

    private func failurePill(for field: EditableMetadataField) -> some View {
        let message = saveErrorMessage.isEmpty ? field.failureMessage : saveErrorMessage

        return Text(message)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.red.opacity(0.12), in: Capsule())
            .accessibilityLabel(message)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Open a folder and select a photo")
                .font(.title3.weight(.semibold))
            Text("JPEG, HEIC, PNG, TIFF, WebP, DNG, and common camera RAW files are supported for browsing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
