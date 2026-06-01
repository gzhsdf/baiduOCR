import SwiftUI

struct BatchSidebarView: View {
    @Bindable var viewModel: OCRViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("图片列表")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(viewModel.batchImages.count) 张")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(viewModel.batchImages.enumerated()), id: \.element.id) { index, item in
                        BatchItemRow(
                            item: item,
                            isSelected: viewModel.selectedBatchIndex == index
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectBatchItem(index)
                        }
                    }
                }
                .padding(4)
            }

            Divider()

            // Batch button
            VStack(spacing: 6) {
                Button(action: { viewModel.processBatch() }) {
                    Label("批量识别全部", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .disabled(viewModel.isProcessing || viewModel.batchImages.isEmpty)

                Button(action: { openFolder() }) {
                    Label("更换文件夹", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .disabled(viewModel.isProcessing)
            }
            .padding(8)
        }
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func openFolder() {
        viewModel.openFolder()
    }
}

struct BatchItemRow: View {
    let item: BatchImageItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Thumbnail
            if let thumb = item.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay {
                        ProgressView().scaleEffect(0.5)
                    }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Status indicator
            statusIcon
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Circle().fill(Color.secondary).frame(width: 6, height: 6)
        case .processing:
            ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption2)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption2)
        }
    }
}
