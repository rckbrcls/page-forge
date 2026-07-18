import Foundation

enum FolderEnumerator {
    static func files(
        in folder: URL,
        extensions: Set<String>
    ) throws -> (eligible: [URL], skipped: [URL]) {
        let directory = try FilePathValidator.requireExistingDirectory(folder)
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var eligible: [URL] = []
        var skipped: [URL] = []
        for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else {
                skipped.append(url)
                continue
            }
            if extensions.contains(url.pathExtension.lowercased()) {
                eligible.append(url)
            } else {
                skipped.append(url)
            }
        }
        return (eligible, skipped)
    }
}
