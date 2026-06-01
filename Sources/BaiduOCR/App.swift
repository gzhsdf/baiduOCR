import SwiftUI

@main
struct BaiduOCRApp: App {
    @State private var viewModel = OCRViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 920, minHeight: 550)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentMinSize)
    }
}
