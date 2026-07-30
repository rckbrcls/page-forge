import CryptoKit
import Foundation
import ZIPFoundation

enum FixtureFactory {
    struct TLSIdentityFixture: Sendable {
        let certificateDER: Data
        let privateKeyDER: Data
        let serverName: String
    }

    enum SMTPTranscript: String, CaseIterable, Sendable {
        case implicitTLSPlainSuccess
        case startTLSLoginSuccess
        case multilineGreeting
        case missingStartTLS
        case authenticationRejected
        case recipientRejected
        case connectionLostBeforeData
        case connectionLostDuringData
        case finalReplyMissing
    }

    enum EPUBVariant: String, CaseIterable {
        case validEPUB2
        case validEPUB3
        case epub2LegacyTrueTypeMediaType
        case missingMimetype
        case invalidMimetype
        case lateMimetype
        case compressedMimetype
        case missingContainer
        case invalidContainer
        case missingPackage
        case invalidPackage
        case ambiguousPackage
        case mediaTypeMismatch
        case missingReference
        case ambiguousReference
        case encryptedContent
        case activeContent
        case textJavaScriptActiveContent
        case remoteReference
        case pathTraversal
        case absolutePath
        case duplicateNormalizedPath
        case symbolicLink
        case unsupportedCompression
        case encryptedArchive
        case directoryEntry
        case expansionRatio
        case externalEntity
        case deepXML
        case excessiveXML
        case archiveSizeBoundary
    }

    static func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(component: "BookSenderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    static func makePDF(valid: Bool = true, in directory: URL) throws -> URL {
        let url = directory.appending(component: valid ? "valid.pdf" : "invalid.pdf")
        let data = valid
            ? Data("%PDF-1.7\n1 0 obj\n<<>>\nendobj\n%%EOF\n".utf8)
            : Data("not a pdf".utf8)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func makeEPUB(
        _ variant: EPUBVariant,
        in directory: URL
    ) throws -> URL {
        let url = directory.appending(component: "\(variant.rawValue).epub")
        if variant == .unsupportedCompression {
            try rawArchive(
                entries: [
                    RawEntry(
                        path: "mimetype",
                        data: Data("application/epub+zip".utf8),
                        compressionMethod: 99
                    ),
                ]
            ).write(to: url)
            return url
        }
        if variant == .encryptedArchive {
            try rawArchive(
                entries: [
                    RawEntry(
                        path: "mimetype",
                        data: Data("application/epub+zip".utf8),
                        compressionMethod: 0,
                        flags: 0x0001
                    ),
                ]
            ).write(to: url)
            return url
        }
        if variant == .expansionRatio {
            try rawArchive(
                entries: [
                    RawEntry(
                        path: "mimetype",
                        data: Data([0x00]),
                        compressionMethod: 8,
                        compressedSize: 1,
                        uncompressedSize: 1_000
                    ),
                ]
            ).write(to: url)
            return url
        }

        let archive = try Archive(url: url, accessMode: .create)
        let fixedDate = Date(timeIntervalSince1970: 978_307_200)
        let mimetype = variant == .invalidMimetype
            ? Data("application/zip".utf8)
            : Data("application/epub+zip".utf8)

        if variant == .lateMimetype {
            try add(
                Data(containerXML().utf8),
                path: "META-INF/container.xml",
                to: archive,
                date: fixedDate
            )
        }
        if variant != .missingMimetype {
            try add(
                mimetype,
                path: "mimetype",
                to: archive,
                date: fixedDate,
                compression: variant == .compressedMimetype ? .deflate : .none
            )
        }
        if variant == .directoryEntry {
            try archive.addEntry(
                with: "OEBPS/",
                type: .directory,
                uncompressedSize: Int64(0),
                modificationDate: fixedDate,
                provider: { _, _ in Data() }
            )
        }

        if variant != .missingContainer && variant != .lateMimetype {
            let container: String
            switch variant {
            case .invalidContainer:
                container = "<container><rootfiles>"
            case .ambiguousPackage:
                container = containerXML(
                    packagePaths: ["OEBPS/content.opf", "OPS/other.opf"]
                )
            case .externalEntity:
                container = """
                    <!DOCTYPE container [<!ENTITY x SYSTEM "file:///etc/passwd">]>
                    <container>&x;</container>
                    """
            case .deepXML:
                container = String(repeating: "<a>", count: 140)
                    + String(repeating: "</a>", count: 140)
            case .excessiveXML:
                container = "<container><rootfiles>"
                    + "<rootfile full-path=\"OEBPS/content.opf\"/>"
                    + "</rootfiles>"
                    + String(repeating: "<item/>", count: 100_001)
                    + "</container>"
            case .missingPackage:
                container = containerXML(
                    packagePaths: ["OEBPS/missing.opf"]
                )
            default:
                container = containerXML()
            }
            try add(
                Data(container.utf8),
                path: "META-INF/container.xml",
                to: archive,
                date: fixedDate
            )
        }

        let version = variant == .validEPUB2
            || variant == .epub2LegacyTrueTypeMediaType
            ? "2.0"
            : "3.0"
        let package = variant == .invalidPackage
            ? "<package><manifest>"
            : packageXML(version: version, variant: variant)
        if variant != .missingPackage {
            try add(
                Data(package.utf8),
                path: "OEBPS/content.opf",
                to: archive,
                date: fixedDate
            )
        }
        if variant == .ambiguousPackage {
            try add(
                Data(package.utf8),
                path: "OPS/other.opf",
                to: archive,
                date: fixedDate
            )
        }

        let chapter = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml"><body><p>Book Sender fixture.</p></body></html>
            """
        if variant == .textJavaScriptActiveContent {
            try add(
                Data("document.body.textContent = 'fixture';".utf8),
                path: "OEBPS/script.js",
                to: archive,
                date: fixedDate
            )
        } else if variant != .missingReference && variant != .ambiguousReference {
            try add(
                Data(chapter.utf8),
                path: "OEBPS/chapter.xhtml",
                to: archive,
                date: fixedDate
            )
        }
        if variant == .epub2LegacyTrueTypeMediaType {
            try add(
                Data("fixture-font".utf8),
                path: "OEBPS/Fonts/book.ttf",
                to: archive,
                date: fixedDate
            )
        }
        if variant == .ambiguousReference {
            try add(
                Data(chapter.utf8),
                path: "ONE/chapter.xhtml",
                to: archive,
                date: fixedDate
            )
            try add(
                Data(chapter.utf8),
                path: "TWO/chapter.xhtml",
                to: archive,
                date: fixedDate
            )
        }
        if variant == .encryptedContent {
            let encryption = """
                <?xml version="1.0" encoding="UTF-8"?>
                <encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
                  <EncryptedData>
                    <EncryptionMethod Algorithm="urn:unsupported:drm"/>
                  </EncryptedData>
                </encryption>
                """
            try add(
                Data(encryption.utf8),
                path: "META-INF/encryption.xml",
                to: archive,
                date: fixedDate
            )
        }
        if variant == .archiveSizeBoundary {
            try add(
                Data(repeating: 0x41, count: 4_096),
                path: "OEBPS/boundary.bin",
                to: archive,
                date: fixedDate,
                compression: .none
            )
        }
        switch variant {
        case .pathTraversal:
            try add(
                Data("escape".utf8),
                path: "../escape.xhtml",
                to: archive,
                date: fixedDate
            )
        case .absolutePath:
            try add(
                Data("absolute".utf8),
                path: "/absolute.xhtml",
                to: archive,
                date: fixedDate
            )
        case .duplicateNormalizedPath:
            try add(
                Data("duplicate".utf8),
                path: "oebps/CHAPTER.xhtml",
                to: archive,
                date: fixedDate
            )
        case .symbolicLink:
            try archive.addEntry(
                with: "OEBPS/link",
                type: .symlink,
                uncompressedSize: Int64(17),
                modificationDate: fixedDate,
                provider: { position, size in
                    Data("OEBPS/chapter.xhtml".utf8)
                        .subdata(in: Int(position)..<Int(position) + size)
                }
            )
        default:
            break
        }
        return url
    }

    static func digest(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func definitionDigest(_ id: String) -> String {
        SHA256.hash(data: Data(id.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func localhostTLSIdentity() throws -> TLSIdentityFixture {
        let certificate = """
            MIIBgTCCASagAwIBAgIBATAKBggqhkjOPQQDAjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwHhcNMjYwNzI5MTc0OTQ5WhcNMzYwNzI2MTc0OTQ5WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARQ6Qr/mX9RHqfnus3R9xLyV77VLdZqD9Acr2/cPAtb6kkhQ5ytS5/ohT0VDdmyDM8B6U1rt1tfmvku1mVpjHZso2kwZzAdBgNVHQ4EFgQU2BQ7jvBbF899XocorhikUAoaaEIwHwYDVR0jBBgwFoAU2BQ7jvBbF899XocorhikUAoaaEIwDwYDVR0TAQH/BAUwAwEB/zAUBgNVHREEDTALgglsb2NhbGhvc3QwCgYIKoZIzj0EAwIDSQAwRgIhAP7F71ADGtXbm/SlzCNbA1TXA6ilY917WKKTTN1eP0p7AiEAg+MY1WgN9WtrwRvU4lO9ntcwFgkwLM2Fh2RBH0KtavQ=
            """
        let privateKey = """
            MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg23yPZaI8z6tHeW8qoTZUIXg99ZYCRxZxcyD9WMfSpjmhRANCAARQ6Qr/mX9RHqfnus3R9xLyV77VLdZqD9Acr2/cPAtb6kkhQ5ytS5/ohT0VDdmyDM8B6U1rt1tfmvku1mVpjHZs
            """
        guard
            let certificateDER = Data(
                base64Encoded: certificate.replacingOccurrences(
                    of: "\\s+",
                    with: "",
                    options: .regularExpression
                )
            ),
            let privateKeyDER = Data(
                base64Encoded: privateKey.replacingOccurrences(
                    of: "\\s+",
                    with: "",
                    options: .regularExpression
                )
            )
        else {
            throw FixtureError.invalidEmbeddedTLSIdentity
        }
        return TLSIdentityFixture(
            certificateDER: certificateDER,
            privateKeyDER: privateKeyDER,
            serverName: "localhost"
        )
    }

    static func smtpTranscript(_ transcript: SMTPTranscript) -> [String] {
        switch transcript {
        case .implicitTLSPlainSuccess:
            return [
                "S: 220 localhost ESMTP",
                "C: EHLO localhost",
                "S: 250-localhost",
                "S: 250-AUTH PLAIN LOGIN",
                "S: 250 SIZE 52428800",
                "C: AUTH PLAIN <redacted>",
                "S: 235 2.7.0 Authentication successful",
                "C: MAIL FROM:<sender@example.test>",
                "S: 250 2.1.0 Ok",
                "C: RCPT TO:<reader@kindle.com>",
                "S: 250 2.1.5 Ok",
                "C: DATA",
                "S: 354 End data with <CR><LF>.<CR><LF>",
                "C: <streamed-message>",
                "S: 250 2.0.0 Accepted",
                "C: QUIT",
                "S: 221 2.0.0 Bye",
            ]
        case .startTLSLoginSuccess:
            return [
                "S: 220 localhost ESMTP",
                "C: EHLO localhost",
                "S: 250-localhost",
                "S: 250 STARTTLS",
                "C: STARTTLS",
                "S: 220 2.0.0 Ready to start TLS",
                "C: <tls-upgrade>",
                "C: EHLO localhost",
                "S: 250-localhost",
                "S: 250 AUTH LOGIN",
                "C: AUTH LOGIN",
                "S: 334 VXNlcm5hbWU6",
                "C: <redacted-username>",
                "S: 334 UGFzc3dvcmQ6",
                "C: <redacted-password>",
                "S: 235 2.7.0 Authentication successful",
            ] + Array(smtpTranscript(.implicitTLSPlainSuccess).dropFirst(6))
        case .multilineGreeting:
            return [
                "S: 220-localhost ESMTP",
                "S: 220 PIPELINING",
            ]
        case .missingStartTLS:
            return [
                "S: 220 localhost ESMTP",
                "C: EHLO localhost",
                "S: 250 AUTH PLAIN",
            ]
        case .authenticationRejected:
            return smtpTranscript(.implicitTLSPlainSuccess)
                .map { $0.hasPrefix("S: 235") ? "S: 535 5.7.8 Authentication rejected" : $0 }
        case .recipientRejected:
            return smtpTranscript(.implicitTLSPlainSuccess)
                .map { $0.hasPrefix("S: 250 2.1.5") ? "S: 550 5.1.1 Recipient rejected" : $0 }
        case .connectionLostBeforeData:
            return Array(smtpTranscript(.implicitTLSPlainSuccess).prefix(11))
                + ["S: <connection-closed>"]
        case .connectionLostDuringData:
            return Array(smtpTranscript(.implicitTLSPlainSuccess).prefix(13))
                + ["S: <connection-closed>"]
        case .finalReplyMissing:
            return Array(smtpTranscript(.implicitTLSPlainSuccess).prefix(13))
                + ["S: <timeout>"]
        }
    }

    static func smtpReply(
        code: Int,
        lines: [String]
    ) -> Data {
        precondition((200...599).contains(code))
        precondition(!lines.isEmpty)
        let encoded = lines.enumerated().map { index, line in
            let separator = index == lines.indices.last ? " " : "-"
            return "\(code)\(separator)\(line)\r\n"
        }.joined()
        return Data(encoded.utf8)
    }

    private static func packageXML(
        version: String,
        variant: EPUBVariant
    ) -> String {
        let href: String
        switch variant {
        case .missingReference:
            href = "missing.xhtml"
        case .ambiguousReference:
            href = "chapter.xhtml"
        case .remoteReference:
            href = "https://example.invalid/chapter.xhtml"
        case .textJavaScriptActiveContent:
            href = "script.js"
        default:
            href = "chapter.xhtml"
        }
        let mediaType: String
        switch variant {
        case .mediaTypeMismatch:
            mediaType = "image/png"
        case .textJavaScriptActiveContent:
            mediaType = "text/javascript"
        default:
            mediaType = "application/xhtml+xml"
        }
        let scripted = variant == .activeContent ? " properties=\"scripted\"" : ""
        let legacyFont = variant == .epub2LegacyTrueTypeMediaType
            ? """
                <item id="book-font" href="Fonts/book.ttf" media-type="application/x-font-ttf"/>
              """
            : ""
        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <package xmlns="http://www.idpf.org/2007/opf" version="\(version)" unique-identifier="book-id">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="book-id">fixture</dc:identifier>
                <dc:title>Fixture</dc:title>
                <dc:language>en</dc:language>
              </metadata>
              <manifest>
                <item id="chapter" href="\(href)" media-type="\(mediaType)"\(scripted)/>
                \(legacyFont)
              </manifest>
              <spine><itemref idref="chapter"/></spine>
            </package>
            """
    }

    private static func containerXML(
        packagePaths: [String] = ["OEBPS/content.opf"]
    ) -> String {
        let rootfiles = packagePaths.map {
            "<rootfile full-path=\"\($0)\" media-type=\"application/oebps-package+xml\"/>"
        }.joined()
        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles>\(rootfiles)</rootfiles>
            </container>
            """
    }

    private static func add(
        _ data: Data,
        path: String,
        to archive: Archive,
        date: Date,
        compression: CompressionMethod = .none
    ) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            modificationDate: date,
            compressionMethod: compression,
            provider: { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            }
        )
    }

    private struct RawEntry {
        let path: String
        let data: Data
        let compressionMethod: UInt16
        var flags: UInt16 = 0x0800
        var compressedSize: UInt32? = nil
        var uncompressedSize: UInt32? = nil
    }

    private static func rawArchive(entries: [RawEntry]) throws -> Data {
        var output = Data()
        var central = Data()
        var offsets: [UInt32] = []

        for entry in entries {
            let name = Data(entry.path.utf8)
            let offset = UInt32(output.count)
            offsets.append(offset)
            let checksum = crc32(entry.data)
            output.appendLE(UInt32(0x0403_4B50))
            output.appendLE(UInt16(20))
            output.appendLE(entry.flags)
            output.appendLE(entry.compressionMethod)
            output.appendLE(UInt16(0))
            output.appendLE(UInt16(0))
            output.appendLE(checksum)
            output.appendLE(entry.compressedSize ?? UInt32(entry.data.count))
            output.appendLE(entry.uncompressedSize ?? UInt32(entry.data.count))
            output.appendLE(UInt16(name.count))
            output.appendLE(UInt16(0))
            output.append(name)
            output.append(entry.data)
        }

        for (index, entry) in entries.enumerated() {
            let name = Data(entry.path.utf8)
            central.appendLE(UInt32(0x0201_4B50))
            central.appendLE(UInt16(0x0314))
            central.appendLE(UInt16(20))
            central.appendLE(entry.flags)
            central.appendLE(entry.compressionMethod)
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(crc32(entry.data))
            central.appendLE(entry.compressedSize ?? UInt32(entry.data.count))
            central.appendLE(entry.uncompressedSize ?? UInt32(entry.data.count))
            central.appendLE(UInt16(name.count))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt16(0))
            central.appendLE(UInt32(0x81A4_0000))
            central.appendLE(offsets[index])
            central.append(name)
        }

        let centralOffset = UInt32(output.count)
        output.append(central)
        output.appendLE(UInt32(0x0605_4B50))
        output.appendLE(UInt16(0))
        output.appendLE(UInt16(0))
        output.appendLE(UInt16(entries.count))
        output.appendLE(UInt16(entries.count))
        output.appendLE(UInt32(central.count))
        output.appendLE(centralOffset)
        output.appendLE(UInt16(0))
        return output
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = crc & 1 == 1
                    ? (crc >> 1) ^ 0xEDB8_8320
                    : crc >> 1
            }
        }
        return crc ^ UInt32.max
    }

    enum FixtureError: Error {
        case invalidEmbeddedTLSIdentity
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
