import Foundation

struct EPUBAuditEngine: EPUBAuditing {
    private let limits: SafetyLimits
    private let xmlParser: any BoundedXMLParsing

    init(limits: SafetyLimits = .standard, xmlParser: any BoundedXMLParsing = BoundedXMLParser()) {
        self.limits = limits
        self.xmlParser = xmlParser
    }

    func audit(_ archive: any EPUBArchiveReading) async throws -> AuditReport {
        let placeholder = StagedFileReference(identifier: UUID(), url: URL(filePath: "/"))
        return try await audit(archive, source: placeholder)
    }

    func audit(_ archive: any EPUBArchiveReading, source: StagedFileReference) async throws -> AuditReport {
        let entries = try await archive.preflight(source, limits: limits)
        var findings: [HealthFinding] = []
        let paths = Set(entries.map(\.path))

        if let mimetype = entries.first(where: { $0.path == "mimetype" }) {
            if entries.first?.path != "mimetype" {
                findings.append(finding(.mimetypeNotFirst, .error, .automatic(ruleID: "repair.mimetype")))
            }
            let data = try await archive.data(for: mimetype.path, maximumBytes: 64)
            if data != Data("application/epub+zip".utf8) {
                findings.append(finding(.mimetypeInvalid, .error, .automatic(ruleID: "repair.mimetype")))
            }
        } else {
            findings.append(finding(.mimetypeMissing, .error, .automatic(ruleID: "repair.mimetype")))
        }

        guard paths.contains("META-INF/container.xml") else {
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
            } else {
                findings.append(finding(.containerMissing, .error, .manualReview))
            }
            return report(findings)
        }

        let containerData = try await archive.data(
            for: "META-INF/container.xml",
            maximumBytes: limits.maximumXMLBytes
        )
        let container = try await xmlParser.parse(containerData, limits: limits)
        let packagePaths = container.elements.compactMap { element -> String? in
            guard element.name.hasSuffix("rootfile") else { return nil }
            return element.attributes["full-path"]
        }
        if packagePaths.isEmpty {
            findings.append(finding(.packageMissing, .critical, .forbidden))
        } else if packagePaths.count > 1 {
            findings.append(finding(.packageAmbiguous, .error, .manualReview))
        } else if let packagePath = packagePaths.first, !paths.contains(packagePath) {
            findings.append(finding(.packageMissing, .critical, .forbidden, location: packagePath))
        } else if let packagePath = packagePaths.first {
            let packageData = try await archive.data(for: packagePath, maximumBytes: limits.maximumXMLBytes)
            _ = try await xmlParser.parse(packageData, limits: limits)
        }
        return report(findings)
    }

    private func report(_ findings: [HealthFinding]) -> AuditReport {
        AuditReport(id: UUID(), findings: findings, inspectedAt: Date())
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
