import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: OCRViewModel

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                ToolbarView(viewModel: viewModel)
                Divider()

                // Options bar
                OptionsBar(viewModel: viewModel)
                Divider()

                if viewModel.isBatchMode {
                    // Two-column layout
                    HStack(spacing: 0) {
                        BatchSidebarView(viewModel: viewModel)
                        Divider()
                        mainArea
                    }
                } else {
                    mainArea
                }

                // Status bar
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(viewModel.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if viewModel.cropRect != nil {
                        Text("已选区")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    Text("⌘↩ 识别")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            // Settings overlay
            if viewModel.showSettings {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { }

                SettingsView(viewModel: viewModel)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 20)
                    .frame(minWidth: 420)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSettings)
    }

    private var mainArea: some View {
        VStack(spacing: 8) {
            ImageDropView(viewModel: viewModel)
                .frame(maxHeight: .infinity)

            OCRResultView(viewModel: viewModel)
                .frame(height: 220)
        }
        .padding(8)
    }

    private var statusColor: Color {
        if viewModel.isProcessing { return .yellow }
        if viewModel.errorMessage != nil { return .red }
        if viewModel.isBatchMode { return .blue }
        return .green
    }
}

struct OptionsBar: View {
    @Bindable var viewModel: OCRViewModel

    var body: some View {
        HStack(spacing: 16) {
            Toggle("自动复制", isOn: $viewModel.autoCopyResult)
                .toggleStyle(.switch)
                .controlSize(.small)

            Toggle("自动剪切", isOn: $viewModel.autoCutResult)
                .toggleStyle(.switch)
                .controlSize(.small)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
