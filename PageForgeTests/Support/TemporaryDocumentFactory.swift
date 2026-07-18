import Foundation

final class TemporaryDocumentFactory {
    let directoryURL: URL

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("pageforge-documents-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    deinit {
        try? fileManager.removeItem(at: directoryURL)
    }

    func makeEPUB(named name: String = "book.epub") throws -> URL {
        try makeFile(named: name, contents: Data("epub fixture".utf8))
    }

    func makeMOBI(named name: String = "book.mobi") throws -> URL {
        try makeFile(named: name, contents: Data("mobi fixture".utf8))
    }

    func makePDF(named name: String = "book.pdf") throws -> URL {
        try makeFile(named: name, contents: Data("%PDF-1.4\n% PageForge fixture\n".utf8))
    }

    func makeUnsupportedFile(named name: String = "notes.txt") throws -> URL {
        try makeFile(named: name, contents: Data("unsupported fixture".utf8))
    }

    func duplicatePath(of url: URL) -> URL {
        URL(fileURLWithPath: url.path).standardizedFileURL
    }

    func makeUnreadableFile(named name: String = "unreadable.epub") throws -> URL {
        let url = try makeEPUB(named: name)
        try fileManager.setAttributes([.posixPermissions: 0], ofItemAtPath: url.path)
        return url
    }

    @discardableResult
    func makeFile(named name: String, contents: Data) throws -> URL {
        let url = directoryURL.appendingPathComponent(name, isDirectory: false)
        try contents.write(to: url, options: .atomic)
        return url
    }
}
