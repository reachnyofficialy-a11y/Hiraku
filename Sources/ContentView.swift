import SwiftUI
import UniformTypeIdentifiers
struct ContentView: View {
    @StateObject private var viewModel = ConverterViewModel()
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Selected File")
                        .font(.headline)
                    Text(viewModel.selectedFileName ?? "No .unity3d or .zip selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                Picker("ASTC Block Size", selection: $viewModel.selectedMode) {
                    ForEach(ASTCBlockMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    isPickerPresented = true
                } label: {
                    Label("Pick Bundle File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isImporting || viewModel.isConverting)

                Button {
                    viewModel.convertFile()
                } label: {
                    Label(
                        viewModel.isConverting ? "Converting..." : "Convert to iOS (ASTC)",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.inputFileURL == nil || viewModel.isConverting || viewModel.isImporting)

                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: viewModel.progress)
                    Text(viewModel.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                if let outputURL = viewModel.outputFileURL {
                    ShareLink(item: outputURL) {
                        Label("Export Converted File", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("CADENZZA")
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [.data, .archive],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await viewModel.importFile(from: url)
                        }
                    }
                case .failure(let error):
                    viewModel.present(error)
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
