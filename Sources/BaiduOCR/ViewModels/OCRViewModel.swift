import AppKit
import SwiftUI

@MainActor
@Observable
final class OCRViewModel {
    var currentImage: NSImage?
    var ocrResult: String = ""
    var selectedOCRType: OCRType = .generalBasic
    var isProcessing: Bool = false
    var errorMessage: String?
    var statusText: String = "就绪"
    var showSettings: Bool = false

    var apiKey: String = ""
    var secretKey: String = ""

    // Region selection on image
    var cropRect: NSRect? = nil

    // Image transform
    var zoomScale: CGFloat = 1.0
    var rotationAngle: Double = 0  // degrees
    var panOffset: CGPoint = .zero

    // Batch mode
    var batchImages: [BatchImageItem] = []
    var selectedBatchIndex: Int?

    // Options
    var autoCopyResult: Bool = false
    var autoCutResult: Bool = false
    var invertScrollY: Bool = false

    var isBatchMode: Bool { !batchImages.isEmpty }

    private let ocrService = OCRService()

    init() {
        loadCredentials()
        loadOptions()
    }

    // MARK: - Image Input

    func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            errorMessage = "无法加载图片: \(url.lastPathComponent)"
            return
        }
        setNewImage(image)
        statusText = "图片已加载"
        batchImages = []
        selectedBatchIndex = nil
    }

    func loadImageFromClipboard() {
        guard let objects = NSPasteboard.general.readObjects(forClasses: [NSImage.self]),
              let image = objects.first as? NSImage else {
            statusText = "剪贴板中没有图片"
            return
        }
        setNewImage(image)
        statusText = "图片已从剪贴板加载"
        batchImages = []
        selectedBatchIndex = nil
    }

    func startScreenshot() {
        // Uses system-native screencapture -i for interactive region selection
        if let image = ScreenshotTool.capture() {
            setNewImage(image)
            statusText = "截图已加载"
            batchImages = []
            selectedBatchIndex = nil
            NSApp.activate(ignoringOtherApps: true)
        } else {
            statusText = "截图已取消"
        }
    }

    private func setNewImage(_ image: NSImage) {
        currentImage = image
        ocrResult = ""
        errorMessage = nil
        cropRect = nil
        zoomScale = 1.0
        rotationAngle = 0
        panOffset = .zero
    }

    // MARK: - Batch Folder

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.loadImagesFromFolder(url)
            }
        }
    }

    private func loadImagesFromFolder(_ folderURL: URL) {
        let fm = FileManager.default
        let extensions = Set(["png", "jpg", "jpeg", "bmp", "tiff", "tif"])
        guard let files = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
            errorMessage = "无法读取文件夹"
            return
        }
        let imageFiles = files.filter { extensions.contains($0.pathExtension.lowercased()) }
        guard !imageFiles.isEmpty else {
            errorMessage = "文件夹中没有图片文件"
            return
        }

        batchImages = imageFiles.map { url in
            BatchImageItem(url: url, name: url.lastPathComponent)
        }
        // Generate thumbnails
        let items = batchImages
        Task { @MainActor in
            for item in items {
                guard let idx = self.batchImages.firstIndex(where: { $0.id == item.id }) else { continue }
                if let img = NSImage(contentsOf: item.url) {
                    self.batchImages[idx].thumbnail = self.makeThumbnail(img, maxSize: 120)
                }
            }
        }

        // Auto-select first image
        selectBatchItem(0)
        statusText = "已加载 \(batchImages.count) 张图片"
    }

    private func makeThumbnail(_ image: NSImage, maxSize: CGFloat) -> NSImage {
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height, 1)
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: .zero, operation: .copy, fraction: 1)
        thumb.unlockFocus()
        return thumb
    }

    func selectBatchItem(_ index: Int) {
        guard batchImages.indices.contains(index) else { return }
        selectedBatchIndex = index
        let item = batchImages[index]
        if let img = NSImage(contentsOf: item.url) {
            setNewImage(img)
            ocrResult = item.result
            statusText = item.name
        }
    }

    func processBatch() {
        guard !batchImages.isEmpty, !isProcessing else { return }
        guard !apiKey.isEmpty, !secretKey.isEmpty else {
            showSettings = true
            errorMessage = "请先配置 API Key 和 Secret Key"
            return
        }
        isProcessing = true
        errorMessage = nil
        statusText = "批量识别中..."
        processNext()
    }

    private func processNext() {
        guard let idx = batchImages.firstIndex(where: { $0.status == .pending }) else {
            isProcessing = false
            statusText = "批量识别完成"
            processAutoActions()
            return
        }
        batchImages[idx].status = .processing
        selectedBatchIndex = idx
        guard let img = NSImage(contentsOf: batchImages[idx].url) else {
            batchImages[idx].status = .error("无法加载")
            processNext()
            return
        }
        currentImage = img
        let targetImage = cropRect.flatMap { ImageProcessor.crop(img, to: $0) } ?? img

        let type = selectedOCRType
        let key = apiKey
        let secret = secretKey
        let service = ocrService

        Task { @MainActor in
            do {
                let result = try await service.recognize(
                    image: targetImage, type: type, apiKey: key, secretKey: secret
                )
                self.batchImages[idx].result = result
                self.batchImages[idx].status = .done
                self.ocrResult = result
                self.processNext()
            } catch {
                self.batchImages[idx].status = .error(error.localizedDescription)
                self.ocrResult = error.localizedDescription
                self.processNext()
            }
        }
    }

    // MARK: - OCR

    func performOCR() {
        guard let image = currentImage else {
            errorMessage = "请先加载图片"
            return
        }
        guard !apiKey.isEmpty, !secretKey.isEmpty else {
            showSettings = true
            errorMessage = "请先配置 API Key 和 Secret Key"
            return
        }

        isProcessing = true
        errorMessage = nil
        statusText = "正在识别..."
        ocrResult = ""

        let targetImage = cropRect.flatMap { ImageProcessor.crop(image, to: $0) } ?? image
        let type = selectedOCRType
        let key = apiKey
        let secret = secretKey
        let service = ocrService

        Task { @MainActor in
            do {
                let result = try await service.recognize(
                    image: targetImage, type: type, apiKey: key, secretKey: secret
                )
                self.ocrResult = result
                self.statusText = "识别完成"
                self.isProcessing = false

                // Update batch item if in batch mode
                if let idx = self.selectedBatchIndex, self.batchImages.indices.contains(idx) {
                    self.batchImages[idx].result = result
                    self.batchImages[idx].status = .done
                }

                self.processAutoActions()
            } catch {
                self.errorMessage = error.localizedDescription
                self.statusText = "识别失败"
                self.isProcessing = false
            }
        }
    }

    private func processAutoActions() {
        if autoCopyResult, !ocrResult.isEmpty {
            copyResult()
        }
        if autoCutResult, !ocrResult.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(ocrResult, forType: .string)
            statusText = "已剪切到剪贴板"
        }
    }

    // MARK: - Region

    func clearCropRect() {
        cropRect = nil
        statusText = "选区已清除"
    }

    func resetTransform() {
        zoomScale = 1.0
        rotationAngle = 0
        panOffset = .zero
        statusText = "视图已重置"
    }

    // MARK: - Credentials

    func saveCredentials() {
        KeychainHelper.save(key: "baidu_api_key", value: apiKey)
        KeychainHelper.save(key: "baidu_secret_key", value: secretKey)
        saveOptions()
        statusText = "凭证已保存"
    }

    func loadCredentials() {
        apiKey = KeychainHelper.read(key: "baidu_api_key") ?? ""
        secretKey = KeychainHelper.read(key: "baidu_secret_key") ?? ""
    }

    func testConnection() {
        guard !apiKey.isEmpty, !secretKey.isEmpty else {
            errorMessage = "请先填写 API Key 和 Secret Key"
            return
        }
        isProcessing = true
        statusText = "正在测试连接..."

        let key = apiKey
        let secret = secretKey

        Task { @MainActor in
            do {
                let authService = AuthService()
                _ = try await authService.getToken(apiKey: key, secretKey: secret)
                self.statusText = "连接成功"
                self.isProcessing = false
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
                self.statusText = "连接失败"
                self.isProcessing = false
            }
        }
    }

    // MARK: - Options persistence

    private func saveOptions() {
        UserDefaults.standard.set(autoCopyResult, forKey: "auto_copy_result")
        UserDefaults.standard.set(autoCutResult, forKey: "auto_cut_result")
        UserDefaults.standard.set(invertScrollY, forKey: "invert_scroll_y")
    }

    private func loadOptions() {
        autoCopyResult = UserDefaults.standard.bool(forKey: "auto_copy_result")
        autoCutResult = UserDefaults.standard.bool(forKey: "auto_cut_result")
        invertScrollY = UserDefaults.standard.bool(forKey: "invert_scroll_y")
    }

    // MARK: - Helpers

    func copyResult() {
        guard !ocrResult.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ocrResult, forType: .string)
        statusText = "已复制到剪贴板"
    }

    func clearAll() {
        currentImage = nil
        ocrResult = ""
        cropRect = nil
        errorMessage = nil
        statusText = "就绪"
        batchImages = []
        selectedBatchIndex = nil
        zoomScale = 1.0
        rotationAngle = 0
        panOffset = .zero
    }
}
