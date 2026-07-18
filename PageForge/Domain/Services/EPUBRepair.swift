import Foundation

enum EPUBRepair {
    static func repairStructure(source: URL, output: URL) throws {
        let (_, entries) = try EPUBInspection.readEntries(from: source)
        var working = entries

        let (opfPath, containerData) = try locatePackageDocument(entries: working)
        working[EPUBConstants.containerPath] = EPUBArchiveEntry(
            name: EPUBConstants.containerPath,
            data: containerData
        )

        guard var opfEntry = working[opfPath] else {
            throw DomainError.repair("EPUB does not contain an OPF package document.")
        }
        opfEntry.data = try normalizeAndValidateOPF(
            opfPath: opfPath,
            opfData: opfEntry.data,
            entryNames: Set(working.keys)
        )
        working[opfPath] = opfEntry

        try writeEPUB(entries: working, to: output)
    }

    private static func locatePackageDocument(
        entries: [String: EPUBArchiveEntry]
    ) throws -> (String, Data) {
        let opfPaths = entries.keys.filter { $0.lowercased().hasSuffix(".opf") }.sorted()
        guard !opfPaths.isEmpty else {
            throw DomainError.repair("EPUB does not contain an OPF package document.")
        }

        if let container = entries[EPUBConstants.containerPath],
           let packagePath = EPUBInspection.packagePath(fromContainer: container.data),
           entries[packagePath] != nil {
            return (packagePath, container.data)
        }

        if opfPaths.count == 1 {
            let packagePath = opfPaths[0]
            return (packagePath, containerXML(packagePath: packagePath))
        }

        throw DomainError.repair(
            "EPUB container is missing or invalid and multiple OPF files were found."
        )
    }

    private static func containerXML(packagePath: String) -> Data {
        let escaped = packagePath
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="\(escaped)" media-type="\(EPUBConstants.opfMediaType)"/>
          </rootfiles>
        </container>
        """
        return Data(xml.utf8)
    }

    private static func normalizeAndValidateOPF(
        opfPath: String,
        opfData: Data,
        entryNames: Set<String>
    ) throws -> Data {
        guard let xml = String(data: opfData, encoding: .utf8) else {
            throw DomainError.repair("OPF package document is invalid XML: \(opfPath)")
        }
        if !xml.contains("<package") && !xml.contains(":package") {
            throw DomainError.repair("OPF package document has an invalid root: \(opfPath)")
        }
        guard EPUBInspection.extractElement(named: "manifest", from: xml) != nil else {
            throw DomainError.repair("OPF package document has no manifest: \(opfPath)")
        }
        guard EPUBInspection.extractElement(named: "spine", from: xml) != nil else {
            throw DomainError.repair("OPF package document has no spine: \(opfPath)")
        }

        // For safe mode we rewrite container and keep OPF bytes when structurally present.
        // Media-type normalization is best-effort via string replace for known mismatches.
        var updated = xml
        let items = EPUBInspection.allElements(named: "item", in: xml)
        for item in items {
            guard let href = EPUBInspection.extractAttribute(named: "href", in: item) else { continue }
            guard let contentPath = try? EPUBInspection.resolveHref(opfPath: opfPath, href: href) else { continue }
            guard entryNames.contains(contentPath) else {
                throw DomainError.repair("OPF spine/manifest references missing content: \(contentPath)")
            }
            if let expected = EPUBInspection.knownMediaType(for: contentPath),
               let current = EPUBInspection.extractAttribute(named: "media-type", in: item),
               current != expected {
                updated = updated.replacingOccurrences(
                    of: "media-type=\"\(current)\"",
                    with: "media-type=\"\(expected)\""
                )
            }
        }
        return Data(updated.utf8)
    }

    private static func writeEPUB(entries: [String: EPUBArchiveEntry], to output: URL) throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-epub-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        // Write mimetype first as stored later via zip -X0
        let mimetypeURL = tempRoot.appendingPathComponent("mimetype")
        try EPUBConstants.mimetypeData.write(to: mimetypeURL)

        for (name, entry) in entries where name != "mimetype" {
            let dest = tempRoot.appendingPathComponent(name)
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try entry.data.write(to: dest)
        }

        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }

        // Create zip with mimetype stored uncompressed first, then remaining files.
        let process1 = Process()
        process1.currentDirectoryURL = tempRoot
        process1.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process1.arguments = ["-X0", output.path, "mimetype"]
        try process1.run()
        process1.waitUntilExit()
        guard process1.terminationStatus == 0 else {
            throw DomainError.repair("Failed writing EPUB mimetype entry.")
        }

        let process2 = Process()
        process2.currentDirectoryURL = tempRoot
        process2.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process2.arguments = ["-Xr9D", output.path, ".", "-x", "mimetype"]
        try process2.run()
        process2.waitUntilExit()
        guard process2.terminationStatus == 0 else {
            throw DomainError.repair("Failed writing EPUB archive.")
        }
    }
}
