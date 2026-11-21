import Foundation

extension ConverterViewModel {
    func importFile(from url: URL) async {
        let ext = url.pathExtension.lowercased()
        guard ext == "unity3d" || ext == "zip" else {
            present(ConverterError.unsupportedFileType(ext))
            return
        }

        isImporting = true
        statusMessage = "Importing file..."
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
            isImporting = false
        }

        let root = workspaceRoot
        do {
            let staged = try await Task.detached(priority: .userInitiated) {
                try Self.stageCopy(of: url, into: root)
            }.value
            resetOutputState()
            removeStagedInput()
            inputFileURL = staged
            inputFileSize = Self.fileSize(at: staged)
            progress = 0
            statusMessage = "Ready to convert."
        } catch {
            statusMessage = "Import failed."
            present(error)
        }
    }

    func convertFile() {
        guard !isConverting else { return }
        guard let input = inputFileURL else {
            present(ConverterError.noInputSelected)
            return
        }

        resetOutputState()
        isConverting = true
        progress = 0
        statusMessage = "Preparing..."

        let request = ConversionRequest(
            inputURL: input,
            outputDirectory: workspaceRoot
                .appendingPathComponent("Outputs", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true),
            blockMode: selectedMode
        )
        let converter = self.converter
        let startedAt = Date()

        conversionTask = Task { [weak self] in
            do {
                let result = try await converter.convert(request: request) { fraction, message in
                    Task { @MainActor [weak self] in
                        self?.applyProgress(fraction: fraction, message: message)
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self?.finish(result: result, request: request, startedAt: startedAt)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.handleCancellation()
                }
            } catch {
                await MainActor.run {
                    self?.handleFailure(error)
                }
            }
        }
    }
}
