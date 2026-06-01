import SwiftUI

struct ToolbarView: View {
    @Bindable var viewModel: OCRViewModel

    var body: some View {
        HStack(spacing: 12) {
            Button(action: captureScreenshot) {
                Label("截图", systemImage: "camera.viewfinder")
            }
            .controlSize(.large)
            .disabled(viewModel.isProcessing)

            Button(action: openFile) {
                Label("打开", systemImage: "folder")
            }
            .controlSize(.large)
            .disabled(viewModel.isProcessing)

            Button(action: { viewModel.loadImageFromClipboard() }) {
                Label("粘贴", systemImage: "doc.on.clipboard")
            }
            .controlSize(.large)
            .disabled(viewModel.isProcessing)

            Button(action: openFolder) {
                Label("批量", systemImage: "folder.fill.badge.plus")
            }
            .controlSize(.large)
            .disabled(viewModel.isProcessing)

            Divider()
                .frame(height: 24)

            Picker("识别类型", selection: $viewModel.selectedOCRType) {
                ForEach(OCRType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Button(action: performOCR) {
                Label("开始识别", systemImage: "text.viewfinder")
                    .frame(minWidth: 80)
            }
            .controlSize(.large)
            .disabled(viewModel.currentImage == nil || viewModel.isProcessing)
            .keyboardShortcut(.return, modifiers: .command)

            Spacer()

            // Rotation controls (only when image loaded)
            if viewModel.currentImage != nil {
                Button(action: { viewModel.rotationAngle -= 90 }) {
                    Image(systemName: "rotate.left")
                }
                .help("左转 90°")

                Button(action: { viewModel.rotationAngle += 90 }) {
                    Image(systemName: "rotate.right")
                }
                .help("右转 90°")

                Button(action: { viewModel.resetTransform() }) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("重置视图")
            }

            if viewModel.isBatchMode {
                Text("批量模式")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }

            Button(action: { viewModel.showSettings = true }) {
                Label("设置", systemImage: "gearshape")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .bmp, .tiff, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                viewModel.loadImage(from: url)
            }
        }
    }

    private func openFolder() {
        viewModel.openFolder()
    }

    private func captureScreenshot() {
        viewModel.startScreenshot()
    }

    private func performOCR() {
        viewModel.performOCR()
    }
}
