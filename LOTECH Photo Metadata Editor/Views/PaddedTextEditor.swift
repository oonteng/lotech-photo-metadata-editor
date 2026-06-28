import SwiftUI

struct PaddedTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onEditingEnded: () -> Void = {}

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.allowsUndo = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }

        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .textBackgroundColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEditingEnded: onEditingEnded)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>
        private let onEditingEnded: () -> Void

        init(text: Binding<String>, onEditingEnded: @escaping () -> Void) {
            self.text = text
            self.onEditingEnded = onEditingEnded
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
        }

        func textDidEndEditing(_ notification: Notification) {
            onEditingEnded()
        }
    }
}
