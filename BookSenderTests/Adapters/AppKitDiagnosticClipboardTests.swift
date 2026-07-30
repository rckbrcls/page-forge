import Testing
@testable import BookSender

@MainActor
struct AppKitDiagnosticClipboardTests {
    @Test
    func clearsBeforeEveryPlainTextWriteWithoutReading() throws {
        let recorder = ClipboardOperationRecorder()
        let clipboard = AppKitDiagnosticClipboard(
            clear: {
                recorder.operations.append("clear")
                return 1
            },
            writePlainText: { text in
                recorder.operations.append("write:\(text)")
                return true
            }
        )

        try clipboard.write(DiagnosticCopy(text: "safe-one"))
        try clipboard.write(DiagnosticCopy(text: "safe-two"))

        #expect(
            recorder.operations == [
                "clear",
                "write:safe-one",
                "clear",
                "write:safe-two",
            ]
        )
    }

    @Test
    func returnsTypedFailureWhenPasteboardRejectsText() {
        let clipboard = AppKitDiagnosticClipboard(
            clear: { 0 },
            writePlainText: { _ in false }
        )

        #expect(throws: DiagnosticClipboardError.writeFailed) {
            try clipboard.write(DiagnosticCopy(text: "safe"))
        }
    }
}

@MainActor
private final class ClipboardOperationRecorder {
    var operations: [String] = []
}
