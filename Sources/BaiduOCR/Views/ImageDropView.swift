import SwiftUI
import UniformTypeIdentifiers

struct ImageDropView: View {
    @Bindable var viewModel: OCRViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundColor(.secondary.opacity(0.3))

            if let image = viewModel.currentImage {
                ImageRegionSelector(
                    image: image,
                    cropRect: viewModel.cropRect,
                    zoomScale: viewModel.zoomScale,
                    rotationAngle: viewModel.rotationAngle,
                    panOffset: viewModel.panOffset,
                    invertScrollY: viewModel.invertScrollY,
                    onRegionSelected: { rect in
                        viewModel.cropRect = rect
                        viewModel.statusText = "选区已设定 (\(Int(rect.width)) x \(Int(rect.height)))"
                    },
                    onClear: {
                        viewModel.clearCropRect()
                    },
                    onZoomChanged: { scale in
                        viewModel.zoomScale = scale
                    },
                    onPanChanged: { offset in
                        viewModel.panOffset = offset
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(4)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("拖拽图片到此处，或点击选择文件")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { openFile() }
            }
        }
        .dropDestination(for: URL.self) { items, _ in
            if let url = items.first {
                viewModel.loadImage(from: url)
            }
            return true
        }
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
}
