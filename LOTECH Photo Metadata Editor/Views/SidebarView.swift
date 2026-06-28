import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Photo Metadata Editor")
                    .font(.title3.weight(.semibold))
                Text("by LOTECH Co.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            Button(action: viewModel.openFolder) {
                Label("Open Folder", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 12)

            List(selection: $viewModel.selectedItemID) {
                Section("Library") {
                    Picker(
                        "Mode",
                        selection: Binding(
                            get: { viewModel.detailMode },
                            set: { mode in
                                switch mode {
                                case .singleFile:
                                    viewModel.showSingleEdit()
                                case .batchEdit:
                                    viewModel.showBatchEdit()
                                }
                            }
                        )
                    ) {
                        Text("Single Edit").tag(AppDetailMode.singleFile)
                        Text("Batch Edit").tag(AppDetailMode.batchEdit)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.vertical, 2)

                    OutlineGroup(viewModel.sidebarLibraryItems, children: \.children) { item in
                        Label(item.name, systemImage: item.kind.systemImageName)
                            .tag(item.id)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 290)
    }
}
