import Foundation

struct BoundedXMLParser: BoundedXMLParsing {
    func parse(
        _ data: Data,
        limits: SafetyLimits
    ) async throws -> XMLDocumentProjection {
        try Task.checkCancellation()
        guard limits.permitsXMLBytes(data.count) else {
            throw failure(.xmlByteLimit)
        }

        guard try !containsForbiddenDeclaration(in: data) else {
            throw failure(.xmlExternalEntity)
        }
        try Task.checkCancellation()

        return try await withThrowingTaskGroup(
            of: XMLDocumentProjection.self
        ) { group in
            group.addTask {
                let delegate = ProjectionDelegate(limits: limits)
                let parser = XMLParser(data: data)
                parser.shouldProcessNamespaces = true
                parser.shouldReportNamespacePrefixes = true
                parser.shouldResolveExternalEntities = false
                parser.delegate = delegate
                guard parser.parse(), let rootName = delegate.rootName else {
                    throw delegate.failure ?? self.failure(.xmlInvalid)
                }
                return XMLDocumentProjection(
                    rootName: rootName,
                    namespaces: delegate.namespaces,
                    elements: delegate.elements
                )
            }
            group.addTask {
                try await Task.sleep(for: limits.operationTimeout)
                throw self.failure(.xmlTimeout)
            }
            guard let projection = try await group.next() else {
                throw self.failure(.xmlInvalid)
            }
            group.cancelAll()
            return projection
        }
    }

    private nonisolated func failure(_ code: DiagnosticCode) -> SanitizedFailure {
        SanitizedFailure(
            family: .xml,
            code: code,
            message: "This EPUB contains XML that cannot be processed safely.",
            recoveryAction: .reviewBook
        )
    }

    private nonisolated func containsForbiddenDeclaration(
        in data: Data
    ) throws -> Bool {
        let chunkSize = 64 * 1_024
        let overlap = 16
        var offset = 0

        while offset < data.count {
            try Task.checkCancellation()
            let lowerBound = max(0, offset - overlap)
            let upperBound = min(data.count, offset + chunkSize)
            let lowercase = String(
                decoding: data[lowerBound..<upperBound],
                as: UTF8.self
            ).lowercased()
            if lowercase.contains("<!doctype")
                || lowercase.contains("<!entity") {
                return true
            }
            offset = upperBound
        }

        return false
    }
}

private final class ProjectionDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {
    private struct Frame {
        let name: String
        let path: [String]
        let attributes: [String: String]
        var text: String
    }

    let limits: SafetyLimits
    var rootName: String?
    var namespaces: [String: String] = [:]
    var elements: [XMLElementProjection] = []
    var failure: SanitizedFailure?

    private var stack: [Frame] = []
    private var elementCount = 0
    private var totalTextBytes = 0

    init(limits: SafetyLimits) {
        self.limits = limits
    }

    func parser(
        _ parser: XMLParser,
        didStartMappingPrefix prefix: String,
        toURI namespaceURI: String
    ) {
        namespaces[prefix] = namespaceURI
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard failure == nil else { return }
        guard !Task.isCancelled else {
            reject(parser, code: .xmlCancelled)
            return
        }

        elementCount += 1
        let name = qName ?? elementName
        let path = stack.map(\.name) + [name]
        guard limits.permitsXMLDepth(path.count),
              limits.permitsXMLElementCount(elementCount),
              limits.permitsXMLAttributeCount(attributeDict.count)
        else {
            reject(parser, code: .xmlStructureLimit)
            return
        }
        rootName = rootName ?? name
        stack.append(
            Frame(
                name: name,
                path: path,
                attributes: attributeDict,
                text: ""
            )
        )
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard failure == nil, !stack.isEmpty else { return }
        guard !Task.isCancelled else {
            reject(parser, code: .xmlCancelled)
            return
        }
        let bytes = string.utf8.count
        let (newTotal, overflow) = totalTextBytes.addingReportingOverflow(bytes)
        guard !overflow,
              limits.permitsXMLTextBytes(newTotal)
        else {
            reject(parser, code: .xmlTextLimit)
            return
        }
        totalTextBytes = newTotal
        stack[stack.count - 1].text.append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard failure == nil, let frame = stack.popLast() else { return }
        elements.append(
            XMLElementProjection(
                name: frame.name,
                path: frame.path,
                attributes: frame.attributes,
                text: frame.text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    func parser(
        _ parser: XMLParser,
        resolveExternalEntityName name: String,
        systemID: String?
    ) -> Data? {
        reject(parser, code: .xmlExternalEntity)
        return nil
    }

    func parser(
        _ parser: XMLParser,
        parseErrorOccurred parseError: Error
    ) {
        if failure == nil {
            failure = sanitizedFailure(.xmlInvalid)
        }
    }

    private func reject(_ parser: XMLParser, code: DiagnosticCode) {
        failure = sanitizedFailure(code)
        parser.abortParsing()
    }

    private func sanitizedFailure(_ code: DiagnosticCode) -> SanitizedFailure {
        SanitizedFailure(
            family: .xml,
            code: code,
            message: "This EPUB contains XML that cannot be processed safely.",
            recoveryAction: .reviewBook
        )
    }
}
