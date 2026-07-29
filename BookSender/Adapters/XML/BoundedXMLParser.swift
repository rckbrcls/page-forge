import Foundation

struct BoundedXMLParser: BoundedXMLParsing {
    func parse(_ data: Data, limits: SafetyLimits) async throws -> XMLDocumentProjection {
        try Task.checkCancellation()
        guard data.count <= limits.maximumXMLBytes else { throw failure("xml.byte-limit") }
        let lowercase = String(decoding: data.prefix(8_192), as: UTF8.self).lowercased()
        guard !lowercase.contains("<!doctype"), !lowercase.contains("<!entity") else {
            throw failure("xml.external-entity")
        }

        return try await Task.detached(priority: .utility) {
            let delegate = ProjectionDelegate(limits: limits)
            let parser = XMLParser(data: data)
            parser.shouldProcessNamespaces = true
            parser.shouldReportNamespacePrefixes = true
            parser.shouldResolveExternalEntities = false
            parser.delegate = delegate
            guard parser.parse(), let rootName = delegate.rootName else {
                throw delegate.failure ?? self.failure("xml.invalid")
            }
            return XMLDocumentProjection(
                rootName: rootName,
                namespaces: delegate.namespaces,
                elements: delegate.elements
            )
        }.value
    }

    private func failure(_ code: String) -> SanitizedFailure {
        SanitizedFailure(
            family: .xml,
            code: code,
            message: "This EPUB contains XML that cannot be processed safely.",
            recoveryAction: .reviewBook
        )
    }
}

private final class ProjectionDelegate: NSObject, XMLParserDelegate, @unchecked Sendable {
    let limits: SafetyLimits
    var rootName: String?
    var namespaces: [String: String] = [:]
    var elements: [XMLElementProjection] = []
    var failure: SanitizedFailure?

    private var depth = 0
    private var elementCount = 0
    private var currentName: String?
    private var currentAttributes: [String: String] = [:]
    private var currentText = ""

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
        if Task.isCancelled {
            reject(parser, code: "xml.cancelled")
            return
        }
        depth += 1
        elementCount += 1
        guard depth <= limits.maximumXMLDepth,
              elementCount <= limits.maximumXMLElements,
              attributeDict.count <= limits.maximumXMLAttributesPerElement
        else {
            reject(parser, code: "xml.structure-limit")
            return
        }
        let name = qName ?? elementName
        rootName = rootName ?? name
        currentName = name
        currentAttributes = attributeDict
        currentText = ""
        if attributeDict.values.contains(where: { value in
            let lower = value.lowercased()
            return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("file:")
        }) {
            reject(parser, code: "xml.remote-reference")
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard failure == nil else { return }
        currentText.append(string)
        if currentText.utf8.count > limits.maximumXMLTextBytes {
            reject(parser, code: "xml.text-limit")
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if let currentName {
            elements.append(
                XMLElementProjection(
                    name: currentName,
                    attributes: currentAttributes,
                    text: currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        currentName = nil
        currentAttributes = [:]
        currentText = ""
        depth -= 1
    }

    func parser(
        _ parser: XMLParser,
        resolveExternalEntityName name: String,
        systemID: String?
    ) -> Data? {
        reject(parser, code: "xml.external-entity")
        return nil
    }

    private func reject(_ parser: XMLParser, code: String) {
        failure = SanitizedFailure(
            family: .xml,
            code: code,
            message: "This EPUB contains XML that cannot be processed safely.",
            recoveryAction: .reviewBook
        )
        parser.abortParsing()
    }
}
