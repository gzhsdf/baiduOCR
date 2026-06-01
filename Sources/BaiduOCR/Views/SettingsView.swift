import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: OCRViewModel
    @State private var apiKeyInput: String = ""
    @State private var secretKeyInput: String = ""
    @State private var isTesting: Bool = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case apiKey, secretKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("百度智能云 OCR 设置")
                    .font(.headline)
                Spacer()
                Button("关闭") {
                    viewModel.showSettings = false
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("API Key").font(.subheadline)
                TextField("请输入 API Key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .apiKey)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Secret Key").font(.subheadline)
                TextField("请输入 Secret Key", text: $secretKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .secretKey)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("手势").font(.subheadline)
                Toggle("双指滑动上下反转", isOn: $viewModel.invertScrollY)
                    .onChange(of: viewModel.invertScrollY) {
                        viewModel.saveCredentials()
                    }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button(action: testConnection) {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }
                    Text("测试连接")
                }
                .disabled(apiKeyOrSecretEmpty || isTesting)

                Spacer()

                Button("取消") {
                    viewModel.showSettings = false
                }

                Button("保存") {
                    viewModel.apiKey = apiKeyInput
                    viewModel.secretKey = secretKeyInput
                    viewModel.saveCredentials()
                    viewModel.showSettings = false
                }
                .disabled(apiKeyOrSecretEmpty)
                .keyboardShortcut(.return)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .onAppear {
            apiKeyInput = viewModel.apiKey
            secretKeyInput = viewModel.secretKey
            focusedField = .apiKey
        }
    }

    private var apiKeyOrSecretEmpty: Bool {
        apiKeyInput.isEmpty || secretKeyInput.isEmpty
    }

    private func testConnection() {
        isTesting = true
        viewModel.errorMessage = nil
        viewModel.apiKey = apiKeyInput
        viewModel.secretKey = secretKeyInput
        viewModel.testConnection()

        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                isTesting = false
            }
        }
    }
}
