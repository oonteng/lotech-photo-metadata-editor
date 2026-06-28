import AppKit
import SwiftUI

@main
struct LOTECH_Photo_Metadata_EditorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About LOTECH Photo Metadata Editor") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "LOTECH Photo Metadata Editor",
                        .applicationVersion: "1.0.0",
                        .version: "1.0.0"
                    ])
                }
            }
        }
    }
}
