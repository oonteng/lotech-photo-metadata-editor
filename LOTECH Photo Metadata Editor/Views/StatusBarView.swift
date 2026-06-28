import SwiftUI

struct StatusBarView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(.bar)
    }
}
