import AppKit
import Combine
import Foundation

@MainActor
final class MainViewModel: ObservableObject {
    @Published var selectedItemID: PhotoLibraryItem.ID? {
        didSet {
            guard !isRestoringSelection else {
                return
            }

            if detailMode == .batchEdit, let selectedItemID {
                guard let selectedItem else {
                    updateMetadataForSelection()
                    return
                }

                if case .folder = selectedItem.kind {
                    if hasUnsavedBatchChanges {
                        pendingBatchFolderSelectionID = selectedItemID
                        isRestoringSelection = true
                        self.selectedItemID = oldValue
                        isRestoringSelection = false
                        isShowingBatchExitAlert = true
                        return
                    }

                    selectedBatchFolderID = selectedItemID
                    prepareBatchRows()
                    loadBatchMetadata()
                    return
                }

                if hasUnsavedBatchChanges {
                    pendingBatchExitSelectionID = selectedItemID
                    isRestoringSelection = true
                    self.selectedItemID = oldValue
                    isRestoringSelection = false
                    isShowingBatchExitAlert = true
                    return
                }

                detailMode = .singleFile
                batchLoadTask?.cancel()
            } else if selectedItemID != nil {
                detailMode = .singleFile
                batchLoadTask?.cancel()
            }

            updateMetadataForSelection()
        }
    }

    @Published private(set) var detailMode: AppDetailMode = .singleFile
    @Published var metadata = PhotoMetadata.sample
    @Published var batchRows: [BatchMetadataRow] = []
    @Published var selectedBatchRowIDs: Set<BatchMetadataRow.ID> = []
    @Published private(set) var selectedBatchFolderID: PhotoLibraryItem.ID?
    @Published var isShowingBatchExitAlert = false
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var isScanning = false
    @Published private(set) var isReadingMetadata = false
    @Published private(set) var isSavingMetadata = false
    @Published private(set) var isBatchLoading = false
    @Published private(set) var isBatchSaving = false
    @Published private(set) var failedMetadataField: EditableMetadataField?

    @Published private(set) var libraryItems: [PhotoLibraryItem] = []

    private let folderBookmarkService = FolderBookmarkService()
    private let metadataReaderService = PhotoMetadataReaderService()
    private let metadataWriterService = PhotoMetadataWriterService()
    private let fileRenameService = FileRenameService()
    private var folderScanTask: Task<Void, Never>?
    private var metadataReadTask: Task<Void, Never>?
    private var metadataSaveTask: Task<Void, Never>?
    private var batchLoadTask: Task<Void, Never>?
    private var batchSaveTask: Task<Void, Never>?
    private var lastSavedMetadata: PhotoMetadata?
    private var securityScopedFolderURL: URL?
    private var didStartSecurityScopedFolderAccess = false
    private var isRestoringSelection = false
    private var pendingBatchExitSelectionID: PhotoLibraryItem.ID?
    private var pendingBatchFolderSelectionID: PhotoLibraryItem.ID?
    private var shouldLeaveBatchEditWithoutSelection = false

    deinit {
        folderScanTask?.cancel()
        metadataReadTask?.cancel()
        metadataSaveTask?.cancel()
        batchLoadTask?.cancel()
        batchSaveTask?.cancel()
        MainActor.assumeIsolated {
            stopAccessingCurrentFolder()
        }
    }

    init() {
        Task {
            await reopenLastFolderIfPossible()
        }
    }

    var selectedItem: PhotoLibraryItem? {
        guard let selectedItemID else {
            return nil
        }

        return libraryItems.firstItem(withID: selectedItemID)
    }

    var sidebarLibraryItems: [PhotoLibraryItem] {
        detailMode == .batchEdit ? libraryItems.foldersOnly() : libraryItems
    }

    var hasUnsavedBatchChanges: Bool {
        batchRows.contains(where: \.hasDraftChanges)
    }

    var hasUnsavedSingleChanges: Bool {
        guard detailMode == .singleFile, let lastSavedMetadata else {
            return false
        }

        return metadata != lastSavedMetadata
    }

    func openFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Open Folder"
        panel.message = "Choose a folder containing photo files."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }

        loadFolder(at: folderURL, rememberFolder: true)
    }

    private func updateMetadataForSelection() {
        guard detailMode == .singleFile else {
            metadataReadTask?.cancel()
            isReadingMetadata = false
            return
        }

        guard let photoFile = selectedItem?.photoFile else {
            metadataReadTask?.cancel()
            isReadingMetadata = false
            lastSavedMetadata = nil
            return
        }

        metadata = photoFile.metadata
        lastSavedMetadata = photoFile.metadata
        isReadingMetadata = true
        statusMessage = "Loading metadata"

        metadataReadTask?.cancel()
        metadataReadTask = Task {
            do {
                let loadedMetadata = try await metadataReaderService.metadata(for: photoFile)

                guard !Task.isCancelled else {
                    return
                }

                metadata = loadedMetadata
                lastSavedMetadata = loadedMetadata
                failedMetadataField = nil
                failedMetadataField = nil
                isReadingMetadata = false
                statusMessage = loadedMetadata.previewImageData == nil
                    ? "Metadata loaded"
                    : "Metadata and preview loaded"
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                metadata = photoFile.metadata
                lastSavedMetadata = photoFile.metadata
                isReadingMetadata = false
                statusMessage = error.localizedDescription
            }
        }
    }

    func showBatchEdit() {
        guard detailMode != .batchEdit else {
            return
        }

        detailMode = .batchEdit
        metadataReadTask?.cancel()
        selectedBatchFolderID = selectedItemFolderID ?? libraryItems.first?.id
        isRestoringSelection = true
        selectedItemID = selectedBatchFolderID
        isRestoringSelection = false
        failedMetadataField = nil
        prepareBatchRows()
        loadBatchMetadata()
    }

    func showSingleEdit() {
        leaveBatchEdit()
    }

    func openSingleEdit(for rowID: BatchMetadataRow.ID) {
        batchLoadTask?.cancel()
        detailMode = .singleFile
        selectedItemID = rowID
    }

    func leaveBatchEdit() {
        guard detailMode == .batchEdit else {
            return
        }

        if hasUnsavedBatchChanges {
            shouldLeaveBatchEditWithoutSelection = true
            isShowingBatchExitAlert = true
            return
        }

        batchLoadTask?.cancel()
        detailMode = .singleFile
        selectedItemID = nil
        statusMessage = "Ready"
        updateMetadataForSelection()
    }

    func reloadBatchMetadata() {
        prepareBatchRows()
        loadBatchMetadata()
    }

    func discardBatchChanges() {
        batchRows = batchRows.map { row in
            var updatedRow = row
            updatedRow.discardDraftChanges()
            return updatedRow
        }
        statusMessage = "Batch changes discarded"
    }

    func cancelBatchExit() {
        pendingBatchExitSelectionID = nil
        pendingBatchFolderSelectionID = nil
        shouldLeaveBatchEditWithoutSelection = false
        isShowingBatchExitAlert = false
    }

    func discardBatchChangesAndLeave() {
        discardBatchChanges()
        leaveBatchEditAfterResolvingDrafts()
    }

    func saveBatchChangesAndLeave() {
        saveBatchChanges {
            self.leaveBatchEditAfterResolvingDrafts()
        }
    }

    func saveBatchChanges() {
        saveBatchChanges(completion: nil)
    }

    private func saveBatchChanges(completion: (() -> Void)?) {
        guard hasUnsavedBatchChanges, !isBatchSaving else {
            completion?()
            return
        }

        batchSaveTask?.cancel()
        isBatchSaving = true
        statusMessage = "Saving batch changes"

        batchSaveTask = Task {
            var savedCount = 0
            var failedCount = 0

            for rowID in batchRows.filter(\.hasDraftChanges).map(\.id) {
                guard let rowIndex = batchRows.firstIndex(where: { $0.id == rowID }) else {
                    continue
                }

                batchRows[rowIndex].status = .saving
                let row = batchRows[rowIndex]

                do {
                    try await metadataWriterService.save(metadata: row.metadataForSaving, to: row.photoFile)

                    var savedPhotoFile = row.photoFile
                    if row.fileName != row.photoFile.fileName {
                        let renamedURL = try fileRenameService.rename(photoFile: row.photoFile, to: row.fileName)
                        savedPhotoFile = PhotoFile(url: renamedURL)
                        libraryItems = libraryItems.replacingPhotoFile(oldURL: row.photoFile.url, with: savedPhotoFile)
                    }

                    let reloadedMetadata = try await metadataReaderService.metadata(for: savedPhotoFile)

                    guard !Task.isCancelled else {
                        return
                    }

                    var savedRow = BatchMetadataRow(photoFile: savedPhotoFile)
                    savedRow.applyLoadedMetadata(reloadedMetadata)
                    savedRow.status = .saved
                    batchRows[rowIndex] = savedRow

                    if selectedBatchRowIDs.remove(rowID) != nil {
                        selectedBatchRowIDs.insert(savedRow.id)
                    }

                    savedCount += 1
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    batchRows[rowIndex].status = .failed(error.localizedDescription)
                    failedCount += 1
                }
            }

            isBatchSaving = false

            if failedCount > 0 {
                statusMessage = "\(savedCount) saved, \(failedCount) failed"
            } else {
                statusMessage = savedCount == 0 ? "No batch changes to save" : "Batch changes saved"
                completion?()
            }
        }
    }

    private func prepareBatchRows() {
        batchLoadTask?.cancel()
        selectedBatchRowIDs = []
        let batchFolder = selectedBatchFolder ?? libraryItems.first
        batchRows = batchFolder?.directPhotoFilesForBatchEditing().map(BatchMetadataRow.init(photoFile:)) ?? []

        if batchRows.isEmpty {
            statusMessage = "No supported photo files in this folder"
        } else {
            statusMessage = "Batch edit ready"
        }
    }

    private func loadBatchMetadata() {
        guard !batchRows.isEmpty else {
            return
        }

        batchLoadTask?.cancel()
        isBatchLoading = true
        statusMessage = "Loading batch metadata"

        batchLoadTask = Task {
            for rowID in batchRows.map(\.id) {
                guard let rowIndex = batchRows.firstIndex(where: { $0.id == rowID }) else {
                    continue
                }

                batchRows[rowIndex].status = .loading
                let photoFile = batchRows[rowIndex].photoFile

                do {
                    let loadedMetadata = try await metadataReaderService.metadata(for: photoFile)

                    guard !Task.isCancelled else {
                        return
                    }

                    batchRows[rowIndex].applyLoadedMetadata(loadedMetadata)
                } catch {
                    guard !Task.isCancelled else {
                        return
                    }

                    batchRows[rowIndex].status = .failed(error.localizedDescription)
                }
            }

            isBatchLoading = false
            statusMessage = "Batch metadata loaded"
        }
    }

    private func leaveBatchEditAfterResolvingDrafts() {
        if let pendingBatchFolderSelectionID {
            self.pendingBatchFolderSelectionID = nil
            pendingBatchExitSelectionID = nil
            isShowingBatchExitAlert = false
            selectedBatchFolderID = pendingBatchFolderSelectionID
            isRestoringSelection = true
            selectedItemID = pendingBatchFolderSelectionID
            isRestoringSelection = false
            prepareBatchRows()
            loadBatchMetadata()
            return
        }

        if shouldLeaveBatchEditWithoutSelection {
            shouldLeaveBatchEditWithoutSelection = false
            pendingBatchExitSelectionID = nil
            pendingBatchFolderSelectionID = nil
            isShowingBatchExitAlert = false
            batchLoadTask?.cancel()
            detailMode = .singleFile
            selectedItemID = nil
            statusMessage = "Ready"
            updateMetadataForSelection()
            return
        }

        guard let pendingBatchExitSelectionID else {
            isShowingBatchExitAlert = false
            return
        }

        self.pendingBatchExitSelectionID = nil
        pendingBatchFolderSelectionID = nil
        isShowingBatchExitAlert = false
        detailMode = .singleFile
        selectedItemID = pendingBatchExitSelectionID
    }

    func commitMetadataField(_ field: EditableMetadataField) {
        if field == .fileName {
            commitFileName()
            return
        }

        guard
            let photoFile = selectedItem?.photoFile,
            photoFile.supportsMetadataWriting,
            !isReadingMetadata,
            metadata.value(for: field) != lastSavedMetadata?.value(for: field)
        else {
            if selectedItem?.photoFile?.supportsMetadataWriting == false {
                statusMessage = "This file format is read-only in this version"
            }
            return
        }

        let metadataSnapshot = metadata
        let previousSaveTask = metadataSaveTask
        isSavingMetadata = true
        failedMetadataField = nil
        statusMessage = "Saving \(field.displayName)"

        metadataSaveTask = Task {
            await previousSaveTask?.value

            do {
                try await metadataWriterService.save(metadata: metadataSnapshot, to: photoFile)
                let reloadedMetadata = try await metadataReaderService.metadata(for: photoFile)

                guard !Task.isCancelled else {
                    return
                }

                if selectedItemID == photoFile.url {
                    metadata = reloadedMetadata
                    lastSavedMetadata = reloadedMetadata
                    failedMetadataField = nil
                    isSavingMetadata = false
                    statusMessage = "Metadata saved"
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                isSavingMetadata = false
                failedMetadataField = field
                statusMessage = error.localizedDescription
            }
        }
    }

    func saveSingleChanges() {
        guard
            let photoFile = selectedItem?.photoFile,
            photoFile.supportsMetadataWriting,
            !isReadingMetadata,
            metadata != lastSavedMetadata
        else {
            if selectedItem?.photoFile?.supportsMetadataWriting == false {
                statusMessage = "This file format is read-only in this version"
            }
            return
        }

        let metadataSnapshot = metadata
        let previousSaveTask = metadataSaveTask
        isSavingMetadata = true
        failedMetadataField = nil
        statusMessage = "Saving metadata"

        metadataSaveTask = Task {
            await previousSaveTask?.value

            do {
                try await metadataWriterService.save(metadata: metadataSnapshot, to: photoFile)
                let reloadedMetadata = try await metadataReaderService.metadata(for: photoFile)

                guard !Task.isCancelled else {
                    return
                }

                if selectedItemID == photoFile.url {
                    metadata = reloadedMetadata
                    lastSavedMetadata = reloadedMetadata
                    failedMetadataField = nil
                    isSavingMetadata = false
                    statusMessage = "Metadata saved"
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                isSavingMetadata = false
                statusMessage = error.localizedDescription
            }
        }
    }

    private func commitFileName() {
        guard
            let photoFile = selectedItem?.photoFile,
            photoFile.supportsMetadataWriting,
            metadata.fileName != lastSavedMetadata?.fileName
        else {
            if selectedItem?.photoFile?.supportsMetadataWriting == false {
                statusMessage = "This file format is read-only in this version"
            }
            return
        }

        isSavingMetadata = true
        failedMetadataField = nil
        statusMessage = "Renaming file"

        do {
            let renamedURL = try fileRenameService.rename(photoFile: photoFile, to: metadata.fileName)
            var renamedFile = PhotoFile(url: renamedURL)
            let renamedMetadata = metadata.renamedFileMetadata(for: renamedFile)
            renamedFile.metadata = renamedMetadata

            libraryItems = libraryItems.replacingPhotoFile(
                oldURL: photoFile.url,
                with: renamedFile
            )
            metadata = renamedMetadata
            lastSavedMetadata = renamedMetadata
            selectedItemID = renamedURL
            isSavingMetadata = false
            statusMessage = "File renamed"
        } catch {
            metadata.fileName = lastSavedMetadata?.fileName ?? photoFile.fileName
            failedMetadataField = .fileName
            isSavingMetadata = false
            statusMessage = error.localizedDescription
        }
    }

    private func reopenLastFolderIfPossible() async {
        guard
            let folderURL = folderBookmarkService.restoredFolderURL(),
            folderExists(at: folderURL)
        else {
            return
        }

        loadFolder(at: folderURL, rememberFolder: false)
    }

    private func loadFolder(
        at folderURL: URL,
        rememberFolder: Bool,
        selectAfterLoad: PhotoLibraryItem.ID? = nil
    ) {
        metadataReadTask?.cancel()
        metadataSaveTask?.cancel()
        folderScanTask?.cancel()
        batchLoadTask?.cancel()
        batchSaveTask?.cancel()
        failedMetadataField = nil
        isReadingMetadata = false
        isSavingMetadata = false
        isBatchLoading = false
        isBatchSaving = false
        batchRows = []
        selectedBatchRowIDs = []
        selectedBatchFolderID = nil
        isScanning = true
        statusMessage = "Scanning folder"
        let folderBrowserService = FolderBrowserService()
        startAccessingFolder(folderURL)

        folderScanTask = Task {
            do {
                let rootItem = try await Task.detached(priority: .userInitiated) {
                    try Task.checkCancellation()
                    return try folderBrowserService.libraryTree(for: folderURL)
                }.value

                guard !Task.isCancelled else {
                    return
                }

                if detailMode == .batchEdit {
                    libraryItems = [rootItem]
                    selectedBatchFolderID = rootItem.id
                    isRestoringSelection = true
                    selectedItemID = rootItem.id
                    isRestoringSelection = false
                } else {
                    libraryItems = [rootItem]
                    selectedItemID = selectAfterLoad
                }
                lastSavedMetadata = nil
                isScanning = false
                if detailMode == .batchEdit {
                    prepareBatchRows()
                    loadBatchMetadata()
                } else {
                    statusMessage = rootItem.photoFileCount == 0
                        ? "No supported photo files found"
                        : "Folder opened"
                }

                if rememberFolder {
                    try? folderBookmarkService.saveFolder(folderURL)
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                isScanning = false
                statusMessage = error.localizedDescription
            }
        }
    }

    private func folderExists(at folderURL: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    private func startAccessingFolder(_ folderURL: URL) {
        stopAccessingCurrentFolder()
        securityScopedFolderURL = folderURL
        didStartSecurityScopedFolderAccess = folderURL.startAccessingSecurityScopedResource()
        SavePipelineDiagnostic.log("Folder security scope started: \(didStartSecurityScopedFolderAccess) path=\(folderURL.path)")
    }

    private func stopAccessingCurrentFolder() {
        guard didStartSecurityScopedFolderAccess, let securityScopedFolderURL else {
            self.securityScopedFolderURL = nil
            didStartSecurityScopedFolderAccess = false
            return
        }

        securityScopedFolderURL.stopAccessingSecurityScopedResource()
        self.securityScopedFolderURL = nil
        didStartSecurityScopedFolderAccess = false
    }
}

private extension MainViewModel {
    var selectedItemFolderID: PhotoLibraryItem.ID? {
        guard let selectedItemID, let item = libraryItems.firstItem(withID: selectedItemID) else {
            return nil
        }

        guard case .folder = item.kind else {
            return nil
        }

        return selectedItemID
    }

    var selectedBatchFolder: PhotoLibraryItem? {
        guard let selectedBatchFolderID else {
            return nil
        }

        return libraryItems.firstItem(withID: selectedBatchFolderID)
    }
}

private extension PhotoLibraryItem {
    var photoFileCount: Int {
        let childCount = children?.reduce(0) { partialResult, item in
            partialResult + item.photoFileCount
        } ?? 0

        return isPhotoFile ? childCount + 1 : childCount
    }
}
