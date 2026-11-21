import Foundation

extension AssetConverterBridge: @unchecked Sendable {}

final class NativeAssetConverterService: AssetConverting {
    init() {}

    func convert(
        request: ConversionRequest,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws -> ConversionResult {
        try Task.checkCancellation()

        let fm = FileManager.default
        try fm.createDirectory(at: request.outputDirectory, withIntermediateDirectories: true)

        let baseName = request.inputURL.deletingPathExtension().lastPathComponent
        let ext = request.inputURL.pathExtension
        let suffix: String
        let nativePreset: AssetConverterPreset

        switch request.blockMode {
        case .block4x4:
            suffix = "_astc4x4"
            nativePreset = .quality
        case .block6x6:
            suffix = "_astc6x6"
            nativePreset = .balanced
        case .block8x8:
            suffix = "_astc8x8"
            nativePreset = .fast
        }

        let outputURL = request.outputDirectory
            .appendingPathComponent("\(baseName)\(suffix)")
            .appendingPathExtension(ext)

        if fm.fileExists(atPath: outputURL.path) {
            try fm.removeItem(at: outputURL)
        }

        let inputPath = request.inputURL.path
        let outputPath = outputURL.path
        let bridge = AssetConverterBridge()

        do {
            try await withTaskCancellationHandler {
                try await Task.detached(priority: .userInitiated) {
                    try bridge.convert(
                        inputPath: inputPath,
                        outputPath: outputPath,
                        preset: nativePreset,
                        progress: { fraction, stage in
                            progress(fraction, stage)
                        }
                    )
                }.value
            } onCancel: {
                bridge.cancel()
            }
        } catch let error as NSError
            where error.domain == AssetConverterBridgeErrorDomain
            && error.code == AssetConverterBridgeErrorCode.cancelled.rawValue {
            throw CancellationError()
        }

        guard fm.fileExists(atPath: outputURL.path) else {
            throw ConverterError.outputMissing
        }

        return ConversionResult(outputURL: outputURL, texturesConverted: 1)
    }
}
