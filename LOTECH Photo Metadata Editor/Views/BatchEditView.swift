import AppKit
import SwiftUI

struct BatchEditView: View {
    private enum SortColumn: String, CaseIterable {
        case selected
        case thumbnail
        case fileName
        case title
        case dateTime
        case gps
        case keywords
        case copyright
        case metadata
        case status

        var title: String {
            switch self {
            case .selected: ""
            case .thumbnail: ""
            case .fileName: "File Name"
            case .title: "Title"
            case .dateTime: "Date / Time"
            case .gps: "GPS"
            case .keywords: "Keywords"
            case .copyright: "Copyright"
            case .metadata: "Metadata"
            case .status: "Status"
            }
        }
    }

    private enum FilterKind: String, CaseIterable, Identifiable {
        case missingGPS
        case missingCopyright
        case missingKeywords
        case modified
        case selected
        case heic
        case jpeg

        var id: String { rawValue }

        var title: String {
            switch self {
            case .missingGPS: "Missing GPS"
            case .missingCopyright: "Missing Copyright"
            case .missingKeywords: "Missing Keywords"
            case .modified: "Modified"
            case .selected: "Selected"
            case .heic: "HEIC"
            case .jpeg: "JPEG"
            }
        }
    }

    private enum EditorKind: String {
        case rename
        case title
        case dateTime
        case gps
        case keywords
        case copyright
    }

    private struct ActiveEditor: Identifiable {
        let kind: EditorKind
        let rowIDs: [BatchMetadataRow.ID]

        var id: String {
            "\(kind.rawValue)-\(rowIDs.map(\.path).joined(separator: "|"))"
        }
    }

    @Binding var rows: [BatchMetadataRow]
    @Binding var selection: Set<BatchMetadataRow.ID>
    let isLoading: Bool
    let isSaving: Bool
    let hasDraftChanges: Bool
    let onSave: () -> Void
    let onDiscard: () -> Void
    let onReload: () -> Void
    let onOpenSingleEdit: (BatchMetadataRow.ID) -> Void

    @AppStorage("batch.thumbnailSize") private var thumbnailSize = 42.0
    @AppStorage("batch.sortColumn") private var storedSortColumn = SortColumn.fileName.rawValue
    @AppStorage("batch.sortAscending") private var isSortAscending = true
    @State private var searchText = ""
    @State private var activeFilters: Set<FilterKind> = []
    @State private var editorSheet: ActiveEditor?
    @State private var undoStack: [[BatchMetadataRow]] = []
    @State private var redoStack: [[BatchMetadataRow]] = []

    var body: some View {
        VStack(spacing: 12) {
            header
            filterBar
            table
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(item: $editorSheet) { sheet in
            editor(for: sheet)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Batch Edit")
                    .font(.title2.weight(.semibold))
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search filename, title, keywords, location...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 12)

                Text("Small")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $thumbnailSize, in: 28...76)
                    .frame(width: 150)
                Text("Large")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 22)

                Button(action: undo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(undoStack.isEmpty || isLoading || isSaving)

                Button(action: redo) {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                }
                .disabled(redoStack.isEmpty || isLoading || isSaving)

                Button(action: onReload) {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading || isSaving || hasDraftChanges)

                Button(role: .destructive, action: onDiscard) {
                    Label("Discard", systemImage: "trash")
                }
                .disabled(!hasDraftChanges || isLoading || isSaving)

                Button(action: onSave) {
                    Label("Save Changes", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasDraftChanges || isLoading || isSaving)
            }

            HStack(spacing: 8) {
                ForEach(FilterKind.allCases) { filter in
                    Toggle(filter.title, isOn: Binding(
                        get: { activeFilters.contains(filter) },
                        set: { isOn in
                            if isOn {
                                activeFilters.insert(filter)
                            } else {
                                activeFilters.remove(filter)
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                }
            }
        }
    }

    private var table: some View {
        Group {
            if rows.isEmpty {
                emptyState
            } else if filteredRows.isEmpty {
                emptyFilteredState
            } else {
                ScrollView(.vertical) {
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 0) {
                            headerRow
                                .background(Color(nsColor: .controlBackgroundColor))
                            Divider()

                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredRows.map(\.id), id: \.self) { rowID in
                                    if let row = binding(for: rowID) {
                                        dataRow(row)
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(width: tableWidth, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(SortColumn.allCases, id: \.self) { column in
                if column == .selected {
                    Button(action: toggleVisibleSelection) {
                        Image(systemName: selectAllSystemImage)
                            .foregroundStyle(selectAllForegroundStyle)
                            .frame(width: width(for: column), height: 34)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        sortRows(by: column)
                    } label: {
                        HStack(spacing: 4) {
                            Text(column.title)
                                .font(.caption.weight(.semibold))
                            if currentSortColumn == column {
                                Image(systemName: isSortAscending ? "chevron.up" : "chevron.down")
                                    .font(.caption2.weight(.semibold))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(width: width(for: column), height: 34, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(column == .thumbnail)
                }
            }
        }
    }

    private func dataRow(_ row: Binding<BatchMetadataRow>) -> some View {
        let rowValue = row.wrappedValue

        return HStack(spacing: 0) {
            tableCell(.selected) {
                Button {
                    selectRow(rowValue)
                } label: {
                    Image(systemName: selection.contains(rowValue.id) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(selection.contains(rowValue.id) ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }

            tableCell(.thumbnail) {
                thumbnail(for: rowValue)
            }

            tableCell(.fileName) {
                HStack(spacing: 7) {
                    if rowValue.hasDraftChanges {
                        Circle()
                            .fill(.orange)
                            .frame(width: 7, height: 7)
                    }
                    Text(rowValue.fileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            tableCell(.title) {
                groupButton(primary: rowValue.title, fallback: "Title") {
                    openEditor(.title, from: rowValue.id)
                }
            }

            tableCell(.dateTime) {
                groupButton(primary: rowValue.dateTaken, fallback: "Date / Time") {
                    openEditor(.dateTime, from: rowValue.id)
                }
            }

            tableCell(.gps) {
                groupButton(primary: rowValue.locationName, fallback: rowValue.hasGPS ? "Coordinates" : "Missing GPS") {
                    openEditor(.gps, from: rowValue.id)
                }
            }

            tableCell(.keywords) {
                groupButton(primary: rowValue.keywords, fallback: "Keywords") {
                    openEditor(.keywords, from: rowValue.id)
                }
            }

            tableCell(.copyright) {
                groupButton(primary: rowValue.copyright, fallback: "Copyright") {
                    openEditor(.copyright, from: rowValue.id)
                }
            }

            tableCell(.metadata) {
                completenessView(rowValue.completenessPercent)
            }

            tableCell(.status) {
                statusView(for: rowValue)
            }
        }
        .frame(height: rowHeight)
        .background(rowBackground(for: rowValue))
        .contentShape(Rectangle())
        .onTapGesture {
            selectRow(rowValue)
        }
        .onTapGesture(count: 2) {
            onOpenSingleEdit(rowValue.id)
        }
        .contextMenu {
            Button("Undo", action: undo)
                .disabled(undoStack.isEmpty || isLoading || isSaving)
            Button("Redo", action: redo)
                .disabled(redoStack.isEmpty || isLoading || isSaving)
            Divider()
            Button("Edit GPS") {
                openEditor(.gps, from: rowValue.id)
            }
            Button("Edit Copyright") {
                openEditor(.copyright, from: rowValue.id)
            }
            Button("Edit Date / Time") {
                openEditor(.dateTime, from: rowValue.id)
            }
            Button("Edit Keywords") {
                openEditor(.keywords, from: rowValue.id)
            }
            Button("Rename") {
                openEditor(.rename, from: rowValue.id)
            }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([rowValue.photoFile.url])
            }
            Button("Copy File Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(rowValue.fileName, forType: .string)
            }
            Button("Open Containing Folder") {
                NSWorkspace.shared.open(rowValue.photoFile.url.deletingLastPathComponent())
            }
            Divider()
            Button("Save Changes") {
                onSave()
            }
            .disabled(!hasDraftChanges || isLoading || isSaving)
        }
    }

    private func tableCell<Content: View>(_ column: SortColumn, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 8)
            .frame(width: width(for: column), height: rowHeight, alignment: .leading)
            .clipped()
    }

    private func groupButton(primary: String, fallback: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : primary)
                .foregroundStyle(primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading || isSaving)
    }

    private func thumbnail(for row: BatchMetadataRow) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
            if let data = row.thumbnailData {
                Image(nsImage: BatchThumbnailCache.image(for: row.id, data: data))
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: max(12, thumbnailSize * 0.38)))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .help(row.fileName)
    }

    private func completenessView(_ percent: Int) -> some View {
        HStack(spacing: 6) {
            ProgressView(value: Double(percent), total: 100)
                .progressViewStyle(.linear)
                .frame(width: 70)
            Text("\(percent)%")
                .font(.caption.monospacedDigit())
        }
    }

    private func statusView(for row: BatchMetadataRow) -> some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon(for: row))
                .foregroundStyle(statusColor(for: row))
            Text(statusText(for: row))
                .font(.caption)
                .foregroundStyle(statusColor(for: row))
                .lineLimit(1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.stack")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("No editable photos in this folder")
                .font(.headline)
            Text("Choose a folder with JPEG, HEIC, PNG, TIFF, or WebP files.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyFilteredState: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No photos match these filters")
                .font(.headline)
            Text("Adjust search or quick filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func editor(for editor: ActiveEditor) -> some View {
        let selectedRows = rowsForEditing(editor.rowIDs)

        switch editor.kind {
        case .rename:
            BatchRenameEditor(rows: selectedRows) { draft in
                applyBatchEdit(to: editor.rowIDs) { row, offset in
                    row.draftFileName = draft.fileName(for: offset, originalExtension: row.photoFile.fileExtension)
                }
            }
        case .title:
            TitleEditor(rows: selectedRows) { draft in
                applyBatchEdit(to: editor.rowIDs) { row, offset in
                    row.title = draft.title(for: offset)
                    row.headline = draft.headline
                }
            }
        case .dateTime:
            DateTimeEditor(rows: selectedRows) { draft in
                applyBatchEdit(to: editor.rowIDs) { row, _ in
                    row.dateTaken = draft.dateTaken
                    row.dateCreated = draft.dateCreated
                    row.dateModified = draft.dateModified
                    row.timezone = draft.timezone
                }
            }
        case .gps:
            GPSEditor(rows: selectedRows) { draft in
                applyBatchEdit(to: editor.rowIDs) { row, _ in
                    row.locationName = draft.locationName
                    row.latitude = draft.latitude
                    row.longitude = draft.longitude
                    row.altitude = draft.altitude
                    row.city = draft.city
                    row.province = draft.province
                    row.country = draft.country
                }
            }
        case .keywords:
            KeywordsEditor(rows: selectedRows) { draft in
                applyBatchEdit(to: editor.rowIDs) { row, _ in
                    row.keywords = draft.keywords
                }
            }
        case .copyright:
            CopyrightEditor(rows: selectedRows) { draft in
                applyBatchEdit(to: editor.rowIDs) { row, _ in
                    row.author = draft.author
                    row.copyright = draft.copyright
                    row.credit = draft.credit
                    row.license = draft.license
                    row.website = draft.website
                    row.email = draft.email
                }
            }
        }
    }

    private var currentSortColumn: SortColumn {
        SortColumn(rawValue: storedSortColumn) ?? .fileName
    }

    private var visibleRowIDs: Set<BatchMetadataRow.ID> {
        Set(filteredRows.map(\.id))
    }

    private var selectAllSystemImage: String {
        guard !filteredRows.isEmpty else {
            return "square"
        }

        let selectedVisibleCount = filteredRows.filter { selection.contains($0.id) }.count
        if selectedVisibleCount == 0 {
            return "square"
        }
        if selectedVisibleCount == filteredRows.count {
            return "checkmark.square.fill"
        }
        return "minus.square.fill"
    }

    private var selectAllForegroundStyle: Color {
        selectAllSystemImage == "square" ? .secondary : .accentColor
    }

    private var filteredRows: [BatchMetadataRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return rows.filter { row in
            let matchesSearch = query.isEmpty || [
                row.fileName,
                row.title,
                row.keywords,
                row.locationName
            ].contains { $0.lowercased().contains(query) }

            guard matchesSearch else {
                return false
            }

            return activeFilters.allSatisfy { filter in
                switch filter {
                case .missingGPS: !row.hasGPS
                case .missingCopyright: !row.hasCopyright
                case .missingKeywords: !row.hasKeywords
                case .modified: row.hasDraftChanges
                case .selected: selection.contains(row.id)
                case .heic: ["HEIC", "HEIF"].contains(row.fileExtension)
                case .jpeg: ["JPG", "JPEG"].contains(row.fileExtension)
                }
            }
        }
    }

    private var tableWidth: CGFloat {
        SortColumn.allCases.reduce(0) { $0 + width(for: $1) }
    }

    private var rowHeight: CGFloat {
        max(42, thumbnailSize + 12)
    }

    private var summaryText: String {
        let selectedCount = selection.count
        let changedCount = rows.filter(\.hasDraftChanges).count

        if rows.isEmpty {
            return "Choose a folder with supported photos."
        }

        return "\(filteredRows.count) of \(rows.count) photos • \(selectedCount) selected • \(changedCount) modified"
    }

    private func width(for column: SortColumn) -> CGFloat {
        switch column {
        case .selected: 42
        case .thumbnail: max(64, thumbnailSize + 24)
        case .fileName: 270
        case .title: 190
        case .dateTime: 160
        case .gps: 210
        case .keywords: 190
        case .copyright: 190
        case .metadata: 130
        case .status: 160
        }
    }

    private func binding(for rowID: BatchMetadataRow.ID) -> Binding<BatchMetadataRow>? {
        guard let index = rows.firstIndex(where: { $0.id == rowID }) else {
            return nil
        }

        return $rows[index]
    }

    private func selectRow(_ row: BatchMetadataRow) {
        if selection.contains(row.id) {
            selection.remove(row.id)
        } else {
            selection.insert(row.id)
        }
    }

    private func toggleVisibleSelection() {
        let visibleIDs = visibleRowIDs
        guard !visibleIDs.isEmpty else {
            return
        }

        if visibleIDs.isSubset(of: selection) {
            selection.subtract(visibleIDs)
        } else {
            selection.formUnion(visibleIDs)
        }
    }

    private func openEditor(_ kind: EditorKind, from rowID: BatchMetadataRow.ID) {
        editorSheet = ActiveEditor(kind: kind, rowIDs: targetRowIDs(for: rowID))
    }

    private func targetRowIDs(for rowID: BatchMetadataRow.ID) -> [BatchMetadataRow.ID] {
        let targetSet = selection.isEmpty ? Set([rowID]) : selection
        return rows.map(\.id).filter { targetSet.contains($0) }
    }

    private func rowsForEditing(_ rowIDs: [BatchMetadataRow.ID]) -> [BatchMetadataRow] {
        rows.filter { rowIDs.contains($0.id) }
    }

    private func applyBatchEdit(
        to rowIDs: [BatchMetadataRow.ID],
        update: (inout BatchMetadataRow, Int) -> Void
    ) {
        pushUndoSnapshot()

        for (offset, rowID) in rowIDs.enumerated() {
            guard let index = rows.firstIndex(where: { $0.id == rowID }) else {
                continue
            }

            update(&rows[index], offset)
        }
    }

    private func pushUndoSnapshot() {
        undoStack.append(rows)
        redoStack.removeAll()
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    private func undo() {
        guard let previous = undoStack.popLast() else {
            return
        }

        redoStack.append(rows)
        rows = previous
    }

    private func redo() {
        guard let next = redoStack.popLast() else {
            return
        }

        undoStack.append(rows)
        rows = next
    }

    private func rowBackground(for row: BatchMetadataRow) -> Color {
        if selection.contains(row.id) {
            return Color.accentColor.opacity(0.16)
        }
        if row.status.isFailure {
            return Color.red.opacity(0.08)
        }
        if row.hasDraftChanges {
            return Color.yellow.opacity(0.12)
        }
        return Color.clear
    }

    private func statusIcon(for row: BatchMetadataRow) -> String {
        if row.status.isFailure {
            return "xmark.circle.fill"
        }
        if row.hasDraftChanges {
            return "circle.fill"
        }
        if !row.hasGPS || !row.hasCopyright || !row.hasDate {
            return "exclamationmark.triangle.fill"
        }
        if row.status == .saved {
            return "checkmark.circle.fill"
        }
        return "checkmark.circle"
    }

    private func statusColor(for row: BatchMetadataRow) -> Color {
        if row.status.isFailure {
            return .red
        }
        if row.hasDraftChanges {
            return .orange
        }
        if !row.hasGPS || !row.hasCopyright || !row.hasDate {
            return .yellow
        }
        return .secondary
    }

    private func statusText(for row: BatchMetadataRow) -> String {
        if row.status.isFailure {
            return row.status.displayText
        }
        if row.hasDraftChanges {
            return "Modified"
        }
        if !row.hasGPS {
            return "Missing GPS"
        }
        if !row.hasCopyright {
            return "Missing Copyright"
        }
        if !row.hasDate {
            return "Missing Date"
        }
        return row.status == .saved ? "Saved" : "Ready"
    }

    private func sortRows(by column: SortColumn) {
        if currentSortColumn == column {
            isSortAscending.toggle()
        } else {
            storedSortColumn = column.rawValue
            isSortAscending = true
        }

        rows.sort { lhs, rhs in
            let result: ComparisonResult = switch column {
            case .selected:
                (selection.contains(lhs.id) ? "0" : "1").compare(selection.contains(rhs.id) ? "0" : "1")
            case .thumbnail:
                lhs.fileName.localizedStandardCompare(rhs.fileName)
            case .fileName:
                lhs.fileName.localizedStandardCompare(rhs.fileName)
            case .title:
                lhs.title.localizedStandardCompare(rhs.title)
            case .dateTime:
                lhs.dateTaken.localizedStandardCompare(rhs.dateTaken)
            case .gps:
                lhs.locationName.localizedStandardCompare(rhs.locationName)
            case .keywords:
                lhs.keywords.localizedStandardCompare(rhs.keywords)
            case .copyright:
                lhs.copyright.localizedStandardCompare(rhs.copyright)
            case .metadata:
                lhs.completenessPercent == rhs.completenessPercent
                    ? .orderedSame
                    : (lhs.completenessPercent < rhs.completenessPercent ? .orderedAscending : .orderedDescending)
            case .status:
                statusText(for: lhs).localizedStandardCompare(statusText(for: rhs))
            }

            return isSortAscending ? result == .orderedAscending : result == .orderedDescending
        }
    }
}

private struct BatchRenameDraft {
    var prefix: String
    var placeholder: String

    func fileName(for offset: Int, originalExtension: String) -> String {
        "\(prefix)\(formattedNumber(offset + 1)).\(originalExtension)"
    }

    func formattedNumber(_ value: Int) -> String {
        switch placeholder {
        case "{0001}", "{####}":
            String(format: "%04d", value)
        default:
            String(format: "%03d", value)
        }
    }
}

private struct TitleDraft {
    var title: String
    var headline: String
    var numberingEnabled: Bool

    func title(for offset: Int) -> String {
        guard numberingEnabled else {
            return title
        }

        return "\(title) \(String(format: "%03d", offset + 1))"
    }
}

private struct DateTimeDraft {
    var dateTaken: String
    var dateCreated: String
    var dateModified: String
    var timezone: String
}

private struct GPSDraft {
    var locationName: String
    var latitude: String
    var longitude: String
    var altitude: String
    var city: String
    var province: String
    var country: String
}

private struct KeywordsDraft {
    var keywords: String
}

private struct CopyrightDraft {
    var author: String
    var copyright: String
    var credit: String
    var license: String
    var website: String
    var email: String
}

private struct BatchRenameEditor: View {
    let rows: [BatchMetadataRow]
    let onApply: (BatchRenameDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BatchRenameDraft

    init(rows: [BatchMetadataRow], onApply: @escaping (BatchRenameDraft) -> Void) {
        self.rows = rows
        self.onApply = onApply
        let defaultPrefix = rows.first?.photoFile.url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: #"\d+$"#, with: "", options: .regularExpression)
            ?? "Photo_"
        _draft = State(initialValue: BatchRenameDraft(prefix: defaultPrefix, placeholder: "{001}"))
    }

    var body: some View {
        BatchEditorShell(title: "Batch Rename", selectionCount: rows.count, onDone: apply) {
            TextField("Prefix", text: $draft.prefix)
            Picker("Running Number", selection: $draft.placeholder) {
                Text("{001}").tag("{001}")
                Text("{0001}").tag("{0001}")
                Text("{####}").tag("{####}")
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 5) {
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(previewNames, id: \.self) { name in
                    Text(name)
                        .font(.caption.monospaced())
                }
            }
            Text("Supported placeholders: {001}, {0001}, {####}")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var previewNames: [String] {
        let sampleRows = rows.isEmpty ? [nil, nil, nil] : Array(rows.prefix(3)).map(Optional.some)
        return sampleRows.enumerated().map { offset, row in
            draft.fileName(for: offset, originalExtension: row?.photoFile.fileExtension ?? "jpg")
        }
    }

    private func apply() {
        onApply(draft)
        dismiss()
    }
}

private struct TitleEditor: View {
    let rows: [BatchMetadataRow]
    let onApply: (TitleDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TitleDraft

    init(rows: [BatchMetadataRow], onApply: @escaping (TitleDraft) -> Void) {
        self.rows = rows
        self.onApply = onApply
        let first = rows.first
        _draft = State(initialValue: TitleDraft(
            title: first?.title ?? "",
            headline: first?.headline ?? "",
            numberingEnabled: false
        ))
    }

    var body: some View {
        BatchEditorShell(title: "Title", selectionCount: rows.count, onDone: apply) {
            TextField("Title", text: $draft.title)
            TextField("Headline", text: $draft.headline)
            Toggle("Add sequential numbering to Title", isOn: $draft.numberingEnabled)
                .toggleStyle(.checkbox)
                .font(.caption)
        }
    }

    private func apply() {
        onApply(draft)
        dismiss()
    }
}

private struct DateTimeEditor: View {
    let rows: [BatchMetadataRow]
    let onApply: (DateTimeDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DateTimeDraft

    init(rows: [BatchMetadataRow], onApply: @escaping (DateTimeDraft) -> Void) {
        self.rows = rows
        self.onApply = onApply
        let first = rows.first
        _draft = State(initialValue: DateTimeDraft(
            dateTaken: first?.dateTaken ?? "",
            dateCreated: first?.dateCreated ?? "",
            dateModified: first?.dateModified ?? "",
            timezone: first?.timezone ?? ""
        ))
    }

    var body: some View {
        BatchEditorShell(title: "Date / Time", selectionCount: rows.count, onDone: apply) {
            Text("Normally leave unchanged. Edit only when repairing metadata.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.10), in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Date Taken", text: $draft.dateTaken)
            TextField("Date Created", text: $draft.dateCreated)
            TextField("Date Modified", text: $draft.dateModified)
            TextField("Timezone", text: $draft.timezone)
        }
    }

    private func apply() {
        onApply(draft)
        dismiss()
    }
}

private struct GPSEditor: View {
    let rows: [BatchMetadataRow]
    let onApply: (GPSDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var metadata: PhotoMetadata

    init(rows: [BatchMetadataRow], onApply: @escaping (GPSDraft) -> Void) {
        self.rows = rows
        self.onApply = onApply
        _metadata = State(initialValue: rows.first?.metadataForSaving ?? .sample)
    }

    var body: some View {
        BatchEditorShell(title: "GPS", selectionCount: rows.count, onDone: apply, width: 680) {
            GPSInspectorView(metadata: $metadata)
                .frame(minHeight: 330)
            Divider()
            TextField("Location", text: $metadata.locationName, axis: .vertical)
                .lineLimit(2...5)
            TextField("Latitude", text: $metadata.latitude)
            TextField("Longitude", text: $metadata.longitude)
            TextField("Altitude", text: $metadata.altitude)
            TextField("City", text: $metadata.city)
            TextField("Province / State", text: $metadata.province)
            TextField("Country", text: $metadata.country)
        }
    }

    private func apply() {
        onApply(GPSDraft(
            locationName: metadata.locationName,
            latitude: metadata.latitude,
            longitude: metadata.longitude,
            altitude: metadata.altitude,
            city: metadata.city,
            province: metadata.province,
            country: metadata.country
        ))
        dismiss()
    }
}

private struct KeywordsEditor: View {
    let rows: [BatchMetadataRow]
    let onApply: (KeywordsDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: KeywordsDraft

    init(rows: [BatchMetadataRow], onApply: @escaping (KeywordsDraft) -> Void) {
        self.rows = rows
        self.onApply = onApply
        _draft = State(initialValue: KeywordsDraft(keywords: rows.first?.keywords ?? ""))
    }

    var body: some View {
        BatchEditorShell(title: "Keywords", selectionCount: rows.count, onDone: apply) {
            TextField("Keywords", text: $draft.keywords, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private func apply() {
        onApply(draft)
        dismiss()
    }
}

private struct CopyrightEditor: View {
    let rows: [BatchMetadataRow]
    let onApply: (CopyrightDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CopyrightDraft

    init(rows: [BatchMetadataRow], onApply: @escaping (CopyrightDraft) -> Void) {
        self.rows = rows
        self.onApply = onApply
        let first = rows.first
        _draft = State(initialValue: CopyrightDraft(
            author: first?.author ?? "",
            copyright: first?.copyright ?? "",
            credit: first?.credit ?? "",
            license: first?.license ?? "",
            website: first?.website ?? "",
            email: first?.email ?? ""
        ))
    }

    var body: some View {
        BatchEditorShell(title: "Copyright", selectionCount: rows.count, onDone: apply) {
            TextField("Author", text: $draft.author)
            TextField("Copyright", text: $draft.copyright)
            TextField("Credit", text: $draft.credit)
            TextField("License", text: $draft.license)
            TextField("Website", text: $draft.website)
            TextField("Email", text: $draft.email)
        }
    }

    private func apply() {
        onApply(draft)
        dismiss()
    }
}

private struct BatchEditorShell<Content: View>: View {
    let title: String
    let selectionCount: Int
    let onDone: () -> Void
    var width: CGFloat = 520
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text("\(selectionCount) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save", action: onDone)
                    .buttonStyle(.borderedProminent)
            }

            content()
                .textFieldStyle(.roundedBorder)
        }
        .padding(22)
        .frame(width: width)
    }
}

private enum BatchThumbnailCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for id: URL, data: Data) -> NSImage {
        let key = id.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image = NSImage(data: data) ?? NSImage()
        cache.setObject(image, forKey: key)
        return image
    }
}

private extension BatchMetadataRow.Status {
    var isFailure: Bool {
        if case .failed = self {
            return true
        }

        return false
    }
}
