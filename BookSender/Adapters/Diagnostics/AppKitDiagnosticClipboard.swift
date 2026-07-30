import AppKit

struct AppKitDiagnosticClipboard: DiagnosticClipboard {
    typealias Clear = @MainActor @Sendable () -> Int
    typealias WritePlainText = @MainActor @Sendable (String) -> Bool

    private let clear: Clear
    private let writePlainText: WritePlainText

    init() {
        clear = {
            NSPasteboard.general.clearContents()
        }
        writePlainText = { text in
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    init(
        clear: @escaping Clear,
        writePlainText: @escaping WritePlainText
    ) {
        self.clear = clear
        self.writePlainText = writePlainText
    }

    @MainActor
    func write(_ copy: DiagnosticCopy) throws {
        _ = clear()
        guard writePlainText(copy.text) else {
            throw DiagnosticClipboardError.writeFailed
        }
    }
}
