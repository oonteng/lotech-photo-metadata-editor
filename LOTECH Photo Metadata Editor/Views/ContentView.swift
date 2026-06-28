import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationTitle("")
        } detail: {
            VStack(spacing: 0) {
                switch viewModel.detailMode {
                case .singleFile:
                    MetadataEditorView(
                        item: viewModel.selectedItem,
                        metadata: $viewModel.metadata,
                        failedField: viewModel.failedMetadataField,
                        saveErrorMessage: viewModel.statusMessage,
                        isEditingEnabled: viewModel.selectedItem?.photoFile?.supportsMetadataWriting ?? false,
                        hasUnsavedChanges: viewModel.hasUnsavedSingleChanges,
                        isSaving: viewModel.isSavingMetadata,
                        onCommitField: viewModel.commitMetadataField,
                        onSaveChanges: viewModel.saveSingleChanges
                    )
                    .ignoresSafeArea(.container, edges: .top)
                case .batchEdit:
                    BatchEditView(
                        rows: $viewModel.batchRows,
                        selection: $viewModel.selectedBatchRowIDs,
                        isLoading: viewModel.isBatchLoading,
                        isSaving: viewModel.isBatchSaving,
                        hasDraftChanges: viewModel.hasUnsavedBatchChanges,
                        onSave: viewModel.saveBatchChanges,
                        onDiscard: viewModel.discardBatchChanges,
                        onReload: viewModel.reloadBatchMetadata,
                        onOpenSingleEdit: viewModel.openSingleEdit
                    )
                    .ignoresSafeArea(.container, edges: .top)
                }
                Divider()
                StatusBarView(message: viewModel.statusMessage)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
        }
        .navigationTitle("")
        .alert("Save unsaved batch edits?", isPresented: $viewModel.isShowingBatchExitAlert) {
            Button("Save Changes") {
                viewModel.saveBatchChangesAndLeave()
            }
            Button("Discard", role: .destructive) {
                viewModel.discardBatchChangesAndLeave()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelBatchExit()
            }
        } message: {
            Text("You have unsaved batch edits. Save before leaving?")
        }
        .background(WindowTitleHider())
    }
}

#Preview {
    ContentView()
}

private struct WindowTitleHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        window?.title = ""
        window?.titleVisibility = .hidden
    }
}
