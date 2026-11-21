import Foundation
import Combine

enum ASTCBlockMode: String, CaseIterable, Identifiable {
    case block4x4
    case block6x6
    case block8x8

    var id: String { rawValue }

    var title: String {
        switch self {
        case .block4x4: return "4x4"
        case .block6x6: return "6x6"
        case .block8x8: return "8x8"
        }
    }
}

struct ConversionRequest {
    let inputURL: URL
    let outputDirectory: URL
    let blockMode: ASTCBlockMode
}

struct ConversionResult {
    let outputURL: URL
    let texturesConverted: Int
}

enum ConverterError: LocalizedError {
    case unsupportedFileType(String)
    case noInputSelected
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return "Unsupported file type: .\(ext)"
        case .noInputSelected:
            return "Please select a .unity3d or .zip file first."
        case .outputMissing:
            return "Converted output file was not created."
        }
    }
}

protocol AssetConverting {
    func convert(
        request: ConversionRequest,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> ConversionResult
}

@MainActor
final class ConverterViewModel: ObservableObject {
    @Published var selectedMode: ASTCBlockMode = .block6x6
    @Published var isImporting: Bool = false
    @Published var isConverting: Bool = false
    @Published var progress: Double = 0
    @Published var statusMessage: String = "Select a bundle to begin."
    @Published var errorMessage: String?
    @Published var inputFileURL: URL?
    @Published var inputFileSize: Int64 = 0
    @Published var outputFileURL: URL?

    var conversionTask: Task<Void, Never>?
    let converter: AssetConverting

    var selectedFileName: String? {
        inputFileURL?.lastPathComponent
    }

    var workspaceRoot: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("CADENZZAWorkspace", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init(converter: AssetConverting = NativeAssetConverterService()) {
        self.converter = converter
    }

    func resetOutputState() {
        outputFileURL = nil
        errorMessage = nil
    }

    func removeStagedInput() {
        if let current = inputFileURL {
            try? FileManager.default.removeItem(at: current)
            inputFileURL = nil
        }
    }

    func applyProgress(fraction: Double, message: String) {
        progress = min(max(fraction, 0), 1)
        statusMessage = message
    }

    func finish(result: ConversionResult, request: ConversionRequest, startedAt: Date) {
        isConverting = false
        progress = 1.0
        outputFileURL = result.outputURL
        statusMessage = "Converted (\(result.texturesConverted) texture(s) processed)."
    }

    func handleCancellation() {
        isConverting = false
        progress = 0
        statusMessage = "Conversion cancelled."
    }

    func handleFailure(_ error: Error) {
        isConverting = false
        statusMessage = "Conversion failed."
        present(error)
    }

    func present(_ error: Error) {
        errorMessage = error.localizedDescription
    }

    nonisolated static func stageCopy(of sourceURL: URL, into root: URL) throws -> URL {
        let stagingDir = root.appendingPathComponent("Inputs", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let dest = stagingDir.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest
    }

    nonisolated static func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}
