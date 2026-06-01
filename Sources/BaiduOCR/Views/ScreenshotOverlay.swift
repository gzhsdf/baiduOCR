import AppKit

/// Uses the system's native `screencapture -i` for interactive region selection.
/// No custom overlay window, no NSViewRepresentable — pure, reliable Process approach.
enum ScreenshotTool {
    static func capture() -> NSImage? {
        let tmpFile = NSTemporaryDirectory() + "baidu_ocr_screenshot_\(UUID().uuidString).png"

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", tmpFile]
        task.launch()
        task.waitUntilExit()

        guard task.terminationStatus == 0 else { return nil }
        let image = NSImage(contentsOfFile: tmpFile)
        try? FileManager.default.removeItem(atPath: tmpFile)
        return image
    }
}
