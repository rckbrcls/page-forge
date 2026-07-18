import Foundation

struct ReadinessService {
    private let conversionService: ConversionService
    private let repairService: RepairService

    init(
        conversionService: ConversionService = ConversionService(),
        repairService: RepairService = RepairService()
    ) {
        self.conversionService = conversionService
        self.repairService = repairService
    }

    func audit(source: URL) throws -> ReadinessReport {
        let input = try FilePathValidator.requireExistingFile(source)
        let ext = input.pathExtension.lowercased()
        if ext == "mobi" {
            return makeReport(
                inputPath: input,
                issues: [
                    ReadinessIssue(
                        code: "mobi_conversion_needed",
                        severity: .fixable,
                        message: "MOBI files must be converted to EPUB before Kindle readiness can be audited.",
                        path: input.lastPathComponent
                    ),
                ]
            )
        }
        if ext != "epub" {
            return makeReport(
                inputPath: input,
                issues: [
                    ReadinessIssue(
                        code: "unsupported_format",
                        severity: .error,
                        message: "Readiness Doctor supports EPUB and MOBI files.",
                        path: input.lastPathComponent
                    ),
                ]
            )
        }
        return try auditEPUB(input)
    }

    func prepare(
        source: URL,
        output: URL? = nil,
        outputDirectory: URL? = nil,
        overwrite: Bool = false,
        onProgress: ((String) -> Void)? = nil
    ) throws -> ReadinessReport {
        let input = try FilePathValidator.requireExistingFile(source)
        let ext = input.pathExtension.lowercased()
        guard ext == "epub" || ext == "mobi" else {
            return makeReport(
                inputPath: input,
                issues: [
                    ReadinessIssue(
                        code: "unsupported_format",
                        severity: .error,
                        message: "Readiness Doctor supports EPUB and MOBI files.",
                        path: input.lastPathComponent
                    ),
                ]
            )
        }

        if ext == "mobi" {
            return try prepareMOBI(
                input,
                output: output,
                outputDirectory: outputDirectory,
                overwrite: overwrite,
                onProgress: onProgress
            )
        }

        let initial = try audit(source: input)
        if initial.status == .blocked {
            return initial
        }

        let outputPath = try FilePathValidator.prepareOutput(
            OutputPathBuilder.resolve(
                preferred: output,
                outputDirectory: outputDirectory,
                defaultURL: OutputPathBuilder.kindleReadyEPUB(for: input)
            ),
            overwrite: overwrite
        )

        onProgress?("Repairing EPUB for Kindle")
        _ = try repairService.repair(
            source: input,
            mode: .safe,
            output: outputPath,
            overwrite: true,
            onProgress: onProgress
        )
        let final = try audit(source: outputPath)
        return withOutput(final, inputPath: input, outputPath: outputPath)
    }

    func auditFolder(
        folder: URL,
        prepare: Bool,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)? = nil
    ) throws -> ReadinessBatchResult {
        let inputDir = try FilePathValidator.requireExistingDirectory(folder)
        if prepare {
            guard let outputDirectory else {
                throw DomainError.validation("Batch prepare requires an output directory.")
            }
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }

        let listing = try FolderEnumerator.files(in: inputDir, extensions: ["epub", "mobi"])
        var reports: [ReadinessReport] = []
        var failures: [BatchFailure] = []

        for file in listing.eligible {
            do {
                if prepare {
                    reports.append(
                        try self.prepare(
                            source: file,
                            outputDirectory: outputDirectory,
                            overwrite: overwrite,
                            onProgress: onProgress
                        )
                    )
                } else {
                    reports.append(try audit(source: file))
                }
            } catch {
                failures.append(BatchFailure(path: file, message: error.localizedDescription))
            }
        }
        return ReadinessBatchResult(reports: reports, skipped: listing.skipped, failures: failures)
    }

    private func prepareMOBI(
        _ input: URL,
        output: URL?,
        outputDirectory: URL?,
        overwrite: Bool,
        onProgress: ((String) -> Void)?
    ) throws -> ReadinessReport {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pageforge-readiness-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let converted = tempDir.appendingPathComponent("\(input.deletingPathExtension().lastPathComponent).epub")
        onProgress?("Converting MOBI to EPUB")
        _ = try conversionService.convertToEPUB(source: input, output: converted, overwrite: true, onProgress: onProgress)

        let convertedReport = try audit(source: converted)
        if convertedReport.status == .blocked {
            return makeReport(inputPath: input, issues: convertedReport.issues, convertedFrom: input)
        }

        let outputPath = try FilePathValidator.prepareOutput(
            OutputPathBuilder.resolve(
                preferred: output,
                outputDirectory: outputDirectory,
                defaultURL: OutputPathBuilder.kindleReadyEPUB(for: input)
            ),
            overwrite: overwrite
        )
        onProgress?("Repairing converted EPUB for Kindle")
        _ = try repairService.repair(
            source: converted,
            mode: .safe,
            output: outputPath,
            overwrite: true,
            onProgress: onProgress
        )
        let final = try audit(source: outputPath)
        return withOutput(final, inputPath: input, outputPath: outputPath, convertedFrom: input)
    }

    private func auditEPUB(_ inputPath: URL) throws -> ReadinessReport {
        var issues: [ReadinessIssue] = []
        let orderedNames: [String]
        let entries: [String: EPUBArchiveEntry]
        do {
            (orderedNames, entries) = try EPUBInspection.readEntries(from: inputPath)
        } catch {
            return makeReport(
                inputPath: inputPath,
                issues: [
                    ReadinessIssue(
                        code: "invalid_zip",
                        severity: .error,
                        message: "Input EPUB is not a valid ZIP archive.",
                        path: inputPath.lastPathComponent
                    ),
                ]
            )
        }

        auditMimetype(orderedNames: orderedNames, entries: entries, issues: &issues)
        if let opfPath = selectOPF(entries: entries, issues: &issues) {
            auditOPF(opfPath: opfPath, opfData: entries[opfPath]?.data ?? Data(), entryNames: Set(entries.keys), issues: &issues)
        }
        auditKindleHeuristics(inputPath: inputPath, entries: entries, issues: &issues)
        return makeReport(inputPath: inputPath, issues: issues)
    }

    private func auditMimetype(
        orderedNames: [String],
        entries: [String: EPUBArchiveEntry],
        issues: inout [ReadinessIssue]
    ) {
        guard let mimetype = entries["mimetype"] else {
            issues.append(
                ReadinessIssue(
                    code: "mimetype_missing",
                    severity: .fixable,
                    message: "EPUB mimetype entry is missing.",
                    path: "mimetype"
                )
            )
            return
        }
        if orderedNames.first != "mimetype" {
            issues.append(
                ReadinessIssue(
                    code: "mimetype_position",
                    severity: .fixable,
                    message: "EPUB mimetype entry should be the first archive entry.",
                    path: "mimetype"
                )
            )
        }
        if mimetype.data != EPUBConstants.mimetypeData {
            issues.append(
                ReadinessIssue(
                    code: "mimetype_value",
                    severity: .fixable,
                    message: "EPUB mimetype entry has the wrong value.",
                    path: "mimetype"
                )
            )
        }
    }

    private func selectOPF(
        entries: [String: EPUBArchiveEntry],
        issues: inout [ReadinessIssue]
    ) -> String? {
        let opfPaths = entries.keys.filter { $0.lowercased().hasSuffix(".opf") }.sorted()
        if opfPaths.isEmpty {
            issues.append(
                ReadinessIssue(
                    code: "opf_missing",
                    severity: .error,
                    message: "EPUB does not contain an OPF package document."
                )
            )
            return nil
        }

        if let container = entries[EPUBConstants.containerPath] {
            if let packagePath = EPUBInspection.packagePath(fromContainer: container.data),
               entries[packagePath] != nil {
                return packagePath
            }
            if opfPaths.count == 1 {
                issues.append(
                    ReadinessIssue(
                        code: "container_invalid",
                        severity: .fixable,
                        message: "EPUB container is invalid but a single OPF document was found.",
                        path: EPUBConstants.containerPath
                    )
                )
                return opfPaths[0]
            }
            issues.append(
                ReadinessIssue(
                    code: "container_ambiguous",
                    severity: .error,
                    message: "EPUB container is missing or invalid and multiple OPF documents were found.",
                    path: EPUBConstants.containerPath
                )
            )
            return nil
        }

        if opfPaths.count == 1 {
            issues.append(
                ReadinessIssue(
                    code: "container_missing",
                    severity: .fixable,
                    message: "EPUB container is missing but a single OPF document was found.",
                    path: EPUBConstants.containerPath
                )
            )
            return opfPaths[0]
        }

        issues.append(
            ReadinessIssue(
                code: "container_ambiguous",
                severity: .error,
                message: "EPUB container is missing and multiple OPF documents were found.",
                path: EPUBConstants.containerPath
            )
        )
        return nil
    }

    private func auditOPF(
        opfPath: String,
        opfData: Data,
        entryNames: Set<String>,
        issues: inout [ReadinessIssue]
    ) {
        guard let xml = String(data: opfData, encoding: .utf8) else {
            issues.append(
                ReadinessIssue(
                    code: "opf_invalid_xml",
                    severity: .error,
                    message: "OPF package document is invalid XML.",
                    path: opfPath
                )
            )
            return
        }
        if !xml.contains("package") {
            issues.append(
                ReadinessIssue(
                    code: "opf_invalid_root",
                    severity: .error,
                    message: "OPF package document has an invalid root element.",
                    path: opfPath
                )
            )
            return
        }

        let manifest = EPUBInspection.extractElement(named: "manifest", from: xml)
        let spine = EPUBInspection.extractElement(named: "spine", from: xml)
        let metadata = EPUBInspection.extractElement(named: "metadata", from: xml)

        if manifest == nil {
            issues.append(
                ReadinessIssue(
                    code: "manifest_missing",
                    severity: .error,
                    message: "OPF package document has no manifest.",
                    path: opfPath
                )
            )
        }
        if spine == nil {
            issues.append(
                ReadinessIssue(
                    code: "spine_missing",
                    severity: .error,
                    message: "OPF package document has no spine.",
                    path: opfPath
                )
            )
        }
        guard let manifestXML = manifest, let spineXML = spine else { return }

        var hasCover = false
        let items = EPUBInspection.allElements(named: "item", in: manifestXML)
        var manifestByID: [String: String] = [:]
        for item in items {
            let itemID = EPUBInspection.extractAttribute(named: "id", in: item)
            let href = EPUBInspection.extractAttribute(named: "href", in: item)
            guard let itemID, let href else {
                issues.append(
                    ReadinessIssue(
                        code: "manifest_item_incomplete",
                        severity: .error,
                        message: "OPF manifest has an item without id or href.",
                        path: opfPath
                    )
                )
                continue
            }
            manifestByID[itemID] = href
            let properties = EPUBInspection.extractAttribute(named: "properties", in: item) ?? ""
            if properties.contains("cover-image") || itemID.lowercased() == "cover" || itemID.lowercased() == "cover-image" {
                hasCover = true
            }
            do {
                let contentPath = try EPUBInspection.resolveHref(opfPath: opfPath, href: href)
                if let expected = EPUBInspection.knownMediaType(for: contentPath),
                   let mediaType = EPUBInspection.extractAttribute(named: "media-type", in: item),
                   mediaType != expected {
                    issues.append(
                        ReadinessIssue(
                            code: "opf_media_type",
                            severity: .fixable,
                            message: "OPF manifest item has a media type that does not match its file extension.",
                            path: contentPath
                        )
                    )
                }
                if !entryNames.contains(contentPath) {
                    issues.append(
                        ReadinessIssue(
                            code: "manifest_missing_content",
                            severity: .error,
                            message: "OPF manifest references missing content.",
                            path: contentPath
                        )
                    )
                }
            } catch {
                issues.append(
                    ReadinessIssue(
                        code: "manifest_unsafe_href",
                        severity: .error,
                        message: error.localizedDescription,
                        path: href
                    )
                )
            }
        }

        for itemref in EPUBInspection.allElements(named: "itemref", in: spineXML) {
            guard let idref = EPUBInspection.extractAttribute(named: "idref", in: itemref) else {
                issues.append(
                    ReadinessIssue(
                        code: "spine_itemref_missing_idref",
                        severity: .error,
                        message: "OPF spine has an itemref without idref.",
                        path: opfPath
                    )
                )
                continue
            }
            guard let href = manifestByID[idref] else {
                issues.append(
                    ReadinessIssue(
                        code: "spine_missing_manifest_item",
                        severity: .error,
                        message: "OPF spine references a missing manifest item.",
                        path: idref
                    )
                )
                continue
            }
            do {
                let contentPath = try EPUBInspection.resolveHref(opfPath: opfPath, href: href)
                if !entryNames.contains(contentPath) {
                    issues.append(
                        ReadinessIssue(
                            code: "spine_missing_content",
                            severity: .error,
                            message: "OPF spine references missing content.",
                            path: contentPath
                        )
                    )
                }
            } catch {
                issues.append(
                    ReadinessIssue(
                        code: "spine_unsafe_href",
                        severity: .error,
                        message: error.localizedDescription,
                        path: href
                    )
                )
            }
        }

        let title = metadata.flatMap { EPUBInspection.extractElement(named: "title", from: $0) } ?? ""
        let creator = metadata.flatMap { EPUBInspection.extractElement(named: "creator", from: $0) } ?? ""
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                ReadinessIssue(
                    code: "metadata_title_missing",
                    severity: .warning,
                    message: "Book title metadata is missing.",
                    path: opfPath
                )
            )
        }
        if creator.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                ReadinessIssue(
                    code: "metadata_author_missing",
                    severity: .warning,
                    message: "Book author metadata is missing.",
                    path: opfPath
                )
            )
        }
        if !hasCover {
            issues.append(
                ReadinessIssue(
                    code: "cover_missing",
                    severity: .warning,
                    message: "No cover image was declared in the OPF manifest.",
                    path: opfPath
                )
            )
        }
    }

    private func auditKindleHeuristics(
        inputPath: URL,
        entries: [String: EPUBArchiveEntry],
        issues: inout [ReadinessIssue]
    ) {
        if let size = try? inputPath.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > EPUBConstants.maxSendBytes {
            issues.append(
                ReadinessIssue(
                    code: "send_to_kindle_size",
                    severity: .warning,
                    message: "File is larger than the 200 MB Send to Kindle wireless transfer limit.",
                    path: inputPath.lastPathComponent
                )
            )
        }

        var htmlCount = 0
        for (name, entry) in entries {
            let ext = (name as NSString).pathExtension.lowercased()
            if EPUBConstants.htmlSuffixes.contains(ext) {
                htmlCount += 1
                if entry.data.count > EPUBConstants.maxHTMLEntryBytes {
                    issues.append(
                        ReadinessIssue(
                            code: "html_entry_size",
                            severity: .warning,
                            message: "HTML content file is larger than Amazon's 30 MB guidance.",
                            path: name
                        )
                    )
                }
            }
            if EPUBConstants.fontSuffixes.contains(ext), entry.data.isEmpty {
                issues.append(
                    ReadinessIssue(
                        code: "empty_font_file",
                        severity: .warning,
                        message: "Font file is empty.",
                        path: name
                    )
                )
            }
        }
        if htmlCount > EPUBConstants.maxHTMLFileCount {
            issues.append(
                ReadinessIssue(
                    code: "html_file_count",
                    severity: .warning,
                    message: "EPUB contains more than 300 HTML/XHTML files."
                )
            )
        }
    }

    private func makeReport(
        inputPath: URL,
        issues: [ReadinessIssue],
        outputPath: URL? = nil,
        convertedFrom: URL? = nil
    ) -> ReadinessReport {
        ReadinessReport(
            inputPath: inputPath,
            status: status(for: issues),
            issues: issues,
            outputPath: outputPath,
            convertedFrom: convertedFrom
        )
    }

    private func withOutput(
        _ report: ReadinessReport,
        inputPath: URL,
        outputPath: URL,
        convertedFrom: URL? = nil
    ) -> ReadinessReport {
        var copy = report
        copy.inputPath = inputPath
        copy.outputPath = outputPath
        copy.convertedFrom = convertedFrom
        return copy
    }

    private func status(for issues: [ReadinessIssue]) -> ReadinessStatus {
        if issues.contains(where: { $0.severity == .error }) {
            return .blocked
        }
        if issues.contains(where: { $0.severity == .fixable }) {
            return .needsFixes
        }
        return .ready
    }
}
