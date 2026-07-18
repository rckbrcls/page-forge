import Foundation

struct ConversionRequest: Equatable, Sendable {
    var source: EbookSource
    var target: ConversionTarget
    var outputPath: URL?
    var overwrite: Bool
}

struct ConversionResult: Equatable, Sendable {
    var inputPath: URL
    var outputPath: URL
    var intermediatePath: URL?
}

struct RepairRequest: Equatable, Sendable {
    var source: EbookSource
    var mode: RepairMode
    var outputPath: URL?
    var overwrite: Bool
}

struct RepairResult: Equatable, Sendable {
    var inputPath: URL
    var outputPath: URL
    var mode: RepairMode
}
