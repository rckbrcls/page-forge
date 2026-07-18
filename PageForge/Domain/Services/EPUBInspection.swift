import Foundation

enum EPUBConstants {
    static let mimetypeValue = "application/epub+zip"
    static let mimetypeData = Data(mimetypeValue.utf8)
    static let containerPath = "META-INF/container.xml"
    static let opfMediaType = "application/oebps-package+xml"
    static let maxSendBytes = 200 * 1024 * 1024
    static let maxHTMLEntryBytes = 30 * 1024 * 1024
    static let maxHTMLFileCount = 300
    static let htmlSuffixes: Set<String> = ["htm", "html", "xhtml"]
    static let fontSuffixes: Set<String> = ["otf", "ttf", "woff", "woff2"]
    static let knownMediaTypes: [String: String] = [
        "css": "text/css",
        "gif": "image/gif",
        "htm": "application/xhtml+xml",
        "html": "application/xhtml+xml",
        "jpeg": "image/jpeg",
        "jpg": "image/jpeg",
        "js": "text/javascript",
        "ncx": "application/x-dtbncx+xml",
        "otf": "font/otf",
        "png": "image/png",
        "svg": "image/svg+xml",
        "ttf": "font/ttf",
        "woff": "font/woff",
        "woff2": "font/woff2",
        "xhtml": "application/xhtml+xml",
    ]
}

struct EPUBArchiveEntry: Equatable {
    var name: String
    var data: Data
}

enum EPUBInspection {
    static func readEntries(from url: URL) throws -> (orderedNames: [String], entries: [String: EPUBArchiveEntry]) {
        let list = try runCapture(
            executable: "/usr/bin/unzip",
            arguments: ["-Z", "-1", url.path]
        )
        let names = list
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasSuffix("/") }

        if names.isEmpty {
            throw DomainError.repair("EPUB archive has no content entries.")
        }

        var ordered: [String] = []
        var map: [String: EPUBArchiveEntry] = [:]
        for name in names {
            if isUnsafeArchivePath(name) {
                continue
            }
            let data = try runData(
                executable: "/usr/bin/unzip",
                arguments: ["-p", url.path, name]
            )
            ordered.append(name)
            map[name] = EPUBArchiveEntry(name: name, data: data)
        }

        if map.isEmpty {
            throw DomainError.repair("Input EPUB is not a valid ZIP archive: \(url.lastPathComponent)")
        }
        return (ordered, map)
    }

    static func isUnsafeArchivePath(_ value: String) -> Bool {
        if value.contains("\\") || value.hasPrefix("/") { return true }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        return parts.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty })
    }

    static func normalizeArchivePath(_ value: String) throws -> String {
        if isUnsafeArchivePath(value) {
            throw DomainError.repair("EPUB contains an unsafe path: \(value)")
        }
        var parts = value.split(separator: "/").map(String.init)
        parts = parts.filter { $0 != "." }
        if parts.contains("..") || parts.isEmpty {
            throw DomainError.repair("EPUB contains an unsafe path: \(value)")
        }
        return parts.joined(separator: "/")
    }

    static func localName(_ tag: String) -> String {
        if let idx = tag.lastIndex(of: "}") {
            return String(tag[tag.index(after: idx)...])
        }
        return tag
    }

    static func packagePath(fromContainer data: Data) -> String? {
        guard let xml = String(data: data, encoding: .utf8) else { return nil }
        return extractAttribute(named: "full-path", in: xml)
    }

    static func extractAttribute(named name: String, in text: String) -> String? {
        for quote in ["\"", "'"] {
            let pattern = "\(name)=\(quote)"
            guard let start = text.range(of: pattern) else { continue }
            let rest = text[start.upperBound...]
            guard let end = rest.firstIndex(of: Character(quote)) else { continue }
            let value = String(rest[..<end])
            if !value.isEmpty { return value }
        }
        return nil
    }

    static func resolveHref(opfPath: String, href: String) throws -> String {
        if href.contains("://") {
            throw DomainError.repair("OPF manifest href is external: \(href)")
        }
        let cleaned = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first
            .map(String.init) ?? href
        let decoded = cleaned.removingPercentEncoding ?? cleaned
        if decoded.isEmpty {
            throw DomainError.repair("OPF manifest href is empty: \(opfPath)")
        }
        if isUnsafeArchivePath(decoded) {
            throw DomainError.repair("OPF manifest href is unsafe: \(href)")
        }
        let dir = (opfPath as NSString).deletingLastPathComponent
        let joined: String
        if dir.isEmpty || dir == "." {
            joined = decoded
        } else {
            joined = (dir as NSString).appendingPathComponent(decoded)
        }
        return try normalizeArchivePath(joined.replacingOccurrences(of: "\\", with: "/"))
    }

    static func knownMediaType(for path: String) -> String? {
        let ext = (path as NSString).pathExtension.lowercased()
        return EPUBConstants.knownMediaTypes[ext]
    }

    static func firstChildXML(parent: String, childLocalName: String) -> String? {
        // naive extraction of first child element block
        let open = "<\(childLocalName)"
        guard let start = parent.range(of: open) else {
            // try with namespace prefix-less already
            if let startNs = parent.range(of: ":\(childLocalName)", options: .caseInsensitive) {
                // find previous <
                var idx = startNs.lowerBound
                while idx > parent.startIndex {
                    let prev = parent.index(before: idx)
                    if parent[prev] == "<" {
                        let from = prev
                        if let end = parent.range(of: "</", range: from..<parent.endIndex) {
                            // incomplete - fallthrough
                            _ = end
                        }
                        break
                    }
                    idx = prev
                }
            }
            return extractElement(named: childLocalName, from: parent)
        }
        _ = start
        return extractElement(named: childLocalName, from: parent)
    }

    static func extractElement(named localName: String, from xml: String) -> String? {
        // Match <localName ...> ... </localName> or prefix:localName
        let pattern = #"<([A-Za-z0-9_]*:)?\#(localName)(\s[^>]*)?>([\s\S]*?)</([A-Za-z0-9_]*:)?\#(localName)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        guard let match = regex.firstMatch(in: xml, options: [], range: range),
              let full = Range(match.range, in: xml) else { return nil }
        return String(xml[full])
    }

    static func elementInnerXML(_ element: String) -> String {
        guard let gt = element.firstIndex(of: ">") else { return element }
        let afterOpen = element.index(after: gt)
        guard let closeStart = element.range(of: "</", options: .backwards)?.lowerBound else {
            return String(element[afterOpen...])
        }
        return String(element[afterOpen..<closeStart])
    }

    static func allElements(named localName: String, in xml: String) -> [String] {
        let pattern = #"<([A-Za-z0-9_]*:)?\#(localName)(\s[^>]*)?>([\s\S]*?)</([A-Za-z0-9_]*:)?\#(localName)>|<([A-Za-z0-9_]*:)?\#(localName)(\s[^>]*)?/>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        return regex.matches(in: xml, options: [], range: range).compactMap { match in
            Range(match.range, in: xml).map { String(xml[$0]) }
        }
    }

    private static func runCapture(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        let err = Pipe()
        process.standardOutput = pipe
        process.standardError = err
        do {
            try process.run()
        } catch {
            throw DomainError.repair("Input EPUB is not a valid ZIP archive.")
        }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw DomainError.repair(message.isEmpty ? "Input EPUB is not a valid ZIP archive." : message)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func runData(executable: String, arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        let err = Pipe()
        process.standardOutput = pipe
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            throw DomainError.repair("Failed reading EPUB entry.")
        }
        return data
    }
}
