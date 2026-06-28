import Foundation

nonisolated enum SavePipelineDiagnostic {
    static func log(_ message: String) {
        #if DEBUG
        print("[SavePipeline] \(message)")
        #endif
    }
}
