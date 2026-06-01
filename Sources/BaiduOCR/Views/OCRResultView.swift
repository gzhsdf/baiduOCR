import SwiftUI

struct OCRResultView: View {
    @Bindable var viewModel: OCRViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("识别结果")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.copyResult() }) {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.ocrResult.isEmpty)
                Button(action: { viewModel.clearAll() }) {
                    Label("清除", systemImage: "trash")
                }
                .disabled(viewModel.currentImage == nil && viewModel.ocrResult.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            Divider()

            // Result content
            ScrollView {
                if viewModel.isProcessing {
                    HStack {
                        Spacer()
                        ProgressView("正在识别...")
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding(.top, 30)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.ocrResult.isEmpty {
                    Text("识别结果将显示在这里")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text(viewModel.ocrResult)
                        .font(viewModel.selectedOCRType == .table ? .system(.body, design: .monospaced) : .body)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
