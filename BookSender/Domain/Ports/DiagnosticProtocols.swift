import Foundation

protocol DiagnosticRecording: Sendable {
    func record(_ event: DiagnosticEvent) async
}

protocol DiagnosticClipboard: Sendable {
    @MainActor
    func write(_ copy: DiagnosticCopy) throws
}

enum DiagnosticClipboardError: Error, Equatable, Sendable {
    case writeFailed
}

struct NoopDiagnosticRecorder: DiagnosticRecording {
    func record(_ event: DiagnosticEvent) async {}
}
