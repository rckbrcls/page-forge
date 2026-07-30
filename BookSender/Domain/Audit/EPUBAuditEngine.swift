import Foundation

struct EPUBAuditEngine: EPUBAuditing {
    private let limits: SafetyLimits
    private let xmlParser: any BoundedXMLParsing

    init(
        limits: SafetyLimits = .standard,
        xmlParser: any BoundedXMLParsing = BoundedXMLParser()
    ) {
        self.limits = limits
        self.xmlParser = xmlParser
    }

    func audit(
        _ archive: any EPUBArchiveReading,
        source: StagedFileReference
    ) async throws -> AuditReport {
        let entries: [ArchiveEntryDescriptor]
        do {
            entries = try await archive.preflight(source, limits: limits)
        } catch let failure as SanitizedFailure {
            return report([archiveFinding(for: failure)])
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw unexpectedAuditFailure()
        }

        var findings: [HealthFinding] = []
        let files = entries.filter { !$0.isDirectory }
        let paths = Set(files.map(\.path))
        do {
            findings.append(
                contentsOf: try await auditMimetype(files, archive: archive)
            )
        } catch let failure as SanitizedFailure {
            return report([archiveFinding(for: failure)])
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw unexpectedAuditFailure()
        }

        let packagePath: String
        if !paths.contains("META-INF/container.xml") {
            let packages = paths.filter { $0.lowercased().hasSuffix(".opf") }
            if packages.count == 1, let package = packages.first {
                findings.append(
                    finding(
                        .containerMissing,
                        .error,
                        .automatic(ruleID: "repair.container"),
                        evidence: ["package": package]
                    )
                )
                packagePath = package
            } else {
                findings.append(
                    finding(
                        .containerMissing,
                        .error,
                        packages.isEmpty ? .notApplicable : .manualReview
                    )
                )
                if packages.isEmpty {
                    findings.append(
                        finding(.packageMissing, .error, .notApplicable)
                    )
                } else {
                    findings.append(
                        finding(.packageAmbiguous, .error, .manualReview)
                    )
                }
                return report(findings)
            }
        } else {
            do {
                let containerData = try await archive.data(
                    for: "META-INF/container.xml",
                    maximumBytes: limits.maximumXMLBytes
                )
                let container = try await xmlParser.parse(
                    containerData,
                    limits: limits
                )
                guard container.rootName.hasSuffix("container") else {
                    findings.append(
                        finding(
                            .containerInvalid,
                            .error,
                            .manualReview,
                            location: "META-INF/container.xml"
                        )
                    )
                    return report(findings)
                }
                let packagePaths = container.elements.compactMap {
                    $0.name.hasSuffix("rootfile")
                        ? $0.attributes["full-path"]
                        : nil
                }
                let uniquePackages = Array(Set(packagePaths))
                guard uniquePackages.count == 1,
                      let selected = uniquePackages.first
                else {
                    findings.append(
                        finding(
                            uniquePackages.isEmpty
                                ? .packageMissing
                                : .packageAmbiguous,
                            .error,
                            uniquePackages.isEmpty
                                ? .notApplicable
                                : .manualReview
                        )
                    )
                    return report(findings)
                }
                guard paths.contains(selected) else {
                    findings.append(
                        finding(
                            .packageMissing,
                            .error,
                            .notApplicable,
                            location: selected
                        )
                    )
                    return report(findings)
                }
                packagePath = selected
            } catch let failure as SanitizedFailure {
                findings.append(
                    xmlFinding(
                        failure,
                        fallback: .containerInvalid,
                        location: "META-INF/container.xml"
                    )
                )
                return report(findings)
            } catch {
                findings.append(
                    finding(
                        .containerInvalid,
                        .error,
                        .manualReview,
                        location: "META-INF/container.xml"
                    )
                )
                return report(findings)
            }
        }

        findings.append(
            contentsOf: await auditPackage(
                packagePath,
                paths: paths,
                archive: archive
            )
        )
        findings.append(
            contentsOf: await auditEncryption(paths: paths, archive: archive)
        )
        return report(deduplicated(findings))
    }

    private func auditMimetype(
        _ entries: [ArchiveEntryDescriptor],
        archive: any EPUBArchiveReading
    ) async throws -> [HealthFinding] {
        guard let mimetype = entries.first(where: { $0.path == "mimetype" }) else {
            return [
                finding(
                    .mimetypeMissing,
                    .error,
                    .automatic(ruleID: "repair.mimetype")
                ),
            ]
        }

        var findings: [HealthFinding] = []
        if entries.first?.path != "mimetype" {
            findings.append(
                finding(
                    .mimetypeNotFirst,
                    .error,
                    .automatic(ruleID: "repair.mimetype")
                )
            )
        }
        if mimetype.compressionMethod != 0 {
            findings.append(
                finding(
                    .mimetypeCompressed,
                    .error,
                    .automatic(ruleID: "repair.mimetype")
                )
            )
        }
        let data = try await archive.data(for: mimetype.path, maximumBytes: 64)
        if data != Data("application/epub+zip".utf8) {
            findings.append(
                finding(
                    .mimetypeInvalid,
                    .error,
                    .automatic(ruleID: "repair.mimetype")
                )
            )
        }
        return findings
    }

    private func auditPackage(
        _ packagePath: String,
        paths: Set<String>,
        archive: any EPUBArchiveReading
    ) async -> [HealthFinding] {
        let package: XMLDocumentProjection
        do {
            let data = try await archive.data(
                for: packagePath,
                maximumBytes: limits.maximumXMLBytes
            )
            package = try await xmlParser.parse(data, limits: limits)
        } catch let failure as SanitizedFailure {
            return [
                xmlFinding(
                    failure,
                    fallback: .packageInvalid,
                    location: packagePath
                ),
            ]
        } catch {
            return [
                finding(
                    .packageInvalid,
                    .error,
                    .manualReview,
                    location: packagePath
                ),
            ]
        }

        guard package.rootName.hasSuffix("package") else {
            return [
                finding(
                    .packageInvalid,
                    .error,
                    .manualReview,
                    location: packagePath
                ),
            ]
        }

        var findings: [HealthFinding] = []
        let packageDirectory = (packagePath as NSString).deletingLastPathComponent
        let manifestItems = package.elements.filter { $0.name.hasSuffix("item") }
        guard !manifestItems.isEmpty else {
            return [
                finding(
                    .packageInvalid,
                    .error,
                    .manualReview,
                    location: packagePath
                ),
            ]
        }
        var IDs = Set<String>()
        for item in manifestItems {
            guard let identifier = item.attributes["id"],
                  let href = item.attributes["href"],
                  let declaredType = item.attributes["media-type"],
                  IDs.insert(identifier).inserted
            else {
                findings.append(
                    finding(
                        .packageInvalid,
                        .error,
                        .manualReview,
                        location: packagePath
                    )
                )
                continue
            }

            if isRemote(href) {
                findings.append(
                    finding(
                        .remoteReference,
                        .critical,
                        .forbidden,
                        location: packagePath
                    )
                )
                continue
            }
            guard let resolved = resolve(href, relativeTo: packageDirectory) else {
                findings.append(
                    finding(
                        .referenceMissing,
                        .error,
                        .manualReview,
                        location: packagePath
                    )
                )
                continue
            }
            if !paths.contains(resolved) {
                let canonicalMatches = paths.filter {
                    $0.precomposedStringWithCanonicalMapping.lowercased()
                        == resolved.precomposedStringWithCanonicalMapping.lowercased()
                }
                let basename = (resolved as NSString).lastPathComponent
                let suffixMatches = paths.filter {
                    ($0 as NSString).lastPathComponent == basename
                }
                let matches = canonicalMatches.isEmpty
                    ? suffixMatches
                    : canonicalMatches
                findings.append(
                    finding(
                        matches.count > 1
                            ? .referenceAmbiguous
                            : .referenceMissing,
                        .error,
                        .manualReview,
                        location: resolved
                    )
                )
            }

            let normalizedDeclaredType = normalizedMediaType(declaredType)
            if let expectation = mediaTypeExpectation(for: resolved),
               !expectation.compatible.contains(normalizedDeclaredType) {
                findings.append(
                    finding(
                        .manifestMediaTypeMismatch,
                        .error,
                        .manualReview,
                        location: resolved,
                        evidence: [
                            "declared": declaredType,
                            "expected": expectation.preferred,
                        ]
                    )
                )
            }
            let properties = item.attributes["properties"]?.lowercased() ?? ""
            if scriptMediaTypes.contains(normalizedDeclaredType)
                || properties.split(separator: " ").contains("scripted") {
                findings.append(
                    finding(
                        .activeContent,
                        .critical,
                        .forbidden,
                        location: resolved
                    )
                )
            }
        }

        for itemReference in package.elements where
            itemReference.name.hasSuffix("itemref") {
            guard let identifier = itemReference.attributes["idref"],
                  IDs.contains(identifier)
            else {
                findings.append(
                    finding(
                        .referenceMissing,
                        .error,
                        .manualReview,
                        location: packagePath
                    )
                )
                continue
            }
        }

        for element in package.elements {
            if element.attributes.values.contains(where: isRemote) {
                findings.append(
                    finding(
                        .remoteReference,
                        .critical,
                        .forbidden,
                        location: packagePath
                    )
                )
            }
        }
        return findings
    }

    private func auditEncryption(
        paths: Set<String>,
        archive: any EPUBArchiveReading
    ) async -> [HealthFinding] {
        guard paths.contains("META-INF/encryption.xml") else { return [] }
        do {
            let data = try await archive.data(
                for: "META-INF/encryption.xml",
                maximumBytes: limits.maximumXMLBytes
            )
            let projection = try await xmlParser.parse(data, limits: limits)
            let algorithms = projection.elements.compactMap {
                $0.name.hasSuffix("EncryptionMethod")
                    ? $0.attributes["Algorithm"]
                    : nil
            }
            let permittedFontAlgorithms: Set<String> = [
                "http://www.idpf.org/2008/embedding",
                "http://ns.adobe.com/pdf/enc#RC",
            ]
            guard !algorithms.isEmpty,
                  algorithms.allSatisfy(permittedFontAlgorithms.contains)
            else {
                return [
                    finding(
                        .encryptedContent,
                        .critical,
                        .forbidden,
                        location: "META-INF/encryption.xml"
                    ),
                ]
            }
            return []
        } catch {
            return [
                finding(
                    .encryptedContent,
                    .critical,
                    .forbidden,
                    location: "META-INF/encryption.xml"
                ),
            ]
        }
    }

    private func resolve(_ href: String, relativeTo directory: String) -> String? {
        let pathPart = href.split(separator: "#", maxSplits: 1)
            .first
            .map(String.init) ?? href
        let decoded = pathPart.removingPercentEncoding ?? pathPart
        let combined = directory.isEmpty ? decoded : "\(directory)/\(decoded)"
        let components = combined.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        var normalized: [Substring] = []
        for component in components {
            if component == "." || component.isEmpty {
                continue
            }
            if component == ".." {
                guard !normalized.isEmpty else { return nil }
                normalized.removeLast()
            } else {
                normalized.append(component)
            }
        }
        return normalized.joined(separator: "/")
    }

    private func isRemote(_ value: String) -> Bool {
        guard let scheme = URLComponents(string: value)?.scheme?.lowercased()
        else {
            return value.lowercased().hasPrefix("//")
        }
        return ["http", "https", "ftp", "file", "data", "javascript"]
            .contains(scheme)
    }

    private func mediaTypeExpectation(for path: String) -> MediaTypeExpectation? {
        switch (path as NSString).pathExtension.lowercased() {
        case "xhtml", "html", "htm":
            expectation("application/xhtml+xml")
        case "css":
            expectation("text/css")
        case "ncx":
            expectation("application/x-dtbncx+xml")
        case "svg":
            expectation("image/svg+xml")
        case "jpg", "jpeg":
            expectation("image/jpeg")
        case "png":
            expectation("image/png")
        case "gif":
            expectation("image/gif")
        case "otf":
            expectation(
                "font/otf",
                compatible: [
                    "application/font-sfnt",
                    "application/vnd.ms-opentype",
                    "application/x-font-opentype",
                ]
            )
        case "ttf":
            expectation(
                "font/ttf",
                compatible: [
                    "application/font-sfnt",
                    "application/x-font-ttf",
                ]
            )
        case "woff":
            expectation(
                "font/woff",
                compatible: [
                    "application/font-woff",
                    "application/x-font-woff",
                ]
            )
        case "woff2":
            expectation("font/woff2")
        case "js":
            expectation(
                "application/javascript",
                compatible: Array(scriptMediaTypes)
            )
        default: nil
        }
    }

    private var scriptMediaTypes: Set<String> {
        [
            "application/ecmascript",
            "application/javascript",
            "text/javascript",
        ]
    }

    private func normalizedMediaType(_ value: String) -> String {
        let baseType = value.split(separator: ";", maxSplits: 1).first
            .map(String.init) ?? value
        return baseType
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func expectation(
        _ preferred: String,
        compatible: [String] = []
    ) -> MediaTypeExpectation {
        MediaTypeExpectation(
            preferred: preferred,
            compatible: Set(compatible).union([preferred])
        )
    }

    private func archiveFinding(for failure: SanitizedFailure) -> HealthFinding {
        let code: FindingCode
        switch failure.code {
        case .archiveUnsafePath: code = .archiveUnsafePath
        case .archiveDuplicatePath: code = .archiveDuplicatePath
        case .archiveEncrypted: code = .archiveEncrypted
        case .archiveUnsupportedEntry: code = .archiveUnsupportedEntry
        default: code = .archiveLimitExceeded
        }
        return finding(code, .critical, .forbidden)
    }

    private func xmlFinding(
        _ failure: SanitizedFailure,
        fallback: FindingCode,
        location: String
    ) -> HealthFinding {
        let unsafeCodes: Set<DiagnosticCode> = [
            .xmlByteLimit,
            .xmlExternalEntity,
            .xmlStructureLimit,
            .xmlTextLimit,
            .xmlTimeout,
            .xmlCancelled,
        ]
        if unsafeCodes.contains(failure.code) {
            return finding(
                .xmlUnsafe,
                .critical,
                .forbidden,
                location: location
            )
        }
        return finding(
            fallback,
            .error,
            .manualReview,
            location: location
        )
    }

    private func deduplicated(
        _ findings: [HealthFinding]
    ) -> [HealthFinding] {
        var keys = Set<String>()
        return findings.filter {
            keys.insert(
                "\($0.code.rawValue)|\($0.location ?? "")|\($0.messageKey)"
            ).inserted
        }
    }

    private func report(_ findings: [HealthFinding]) -> AuditReport {
        AuditReport(id: UUID(), findings: findings, inspectedAt: Date())
    }

    private func unexpectedAuditFailure() -> SanitizedFailure {
        SanitizedFailure(
            family: .audit,
            code: .unexpectedAudit,
            message: "The EPUB structural audit stopped unexpectedly.",
            recoveryAction: .reviewBook,
            evidence: DiagnosticEvidence(
                phase: .structuralAudit,
                retryDisposition: .reviewBook
            )
        )
    }

    private func finding(
        _ code: FindingCode,
        _ severity: FindingSeverity,
        _ repairability: Repairability,
        location: String? = nil,
        evidence: [String: String] = [:]
    ) -> HealthFinding {
        HealthFinding(
            id: UUID(),
            code: code,
            severity: severity,
            location: location,
            messageKey: code.rawValue.lowercased(),
            repairability: repairability,
            evidence: evidence
        )
    }
}

private struct MediaTypeExpectation {
    let preferred: String
    let compatible: Set<String>
}
