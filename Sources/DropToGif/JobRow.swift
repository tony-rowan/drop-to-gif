import AppKit
import QuickLookThumbnailing
import SwiftUI

struct JobRow: View {
    /// Rows have a fixed height so the list (and the window) can be sized to fit them.
    static let height: CGFloat = contentHeight + padding * 2
    fileprivate static let contentHeight: CGFloat = 54
    private static let padding: CGFloat = 10

    let job: ConversionQueue.Job

    var body: some View {
        HStack(spacing: 12) {
            VideoThumbnail(url: job.source)
            VStack(alignment: .leading, spacing: 6) {
                Text(job.source.lastPathComponent)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                status
            }
        }
        .frame(height: Self.contentHeight)
        .padding(Self.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
    }

    @ViewBuilder private var status: some View {
        switch job.state {
        case .queued:
            ProgressView(value: 0) {
                EmptyView()
            } currentValueLabel: {
                Text("Waiting…")
            }
        case .converting(let progress):
            ProgressView(value: progress) {
                EmptyView()
            } currentValueLabel: {
                Text("Converting… \(progress, format: .percent.precision(.fractionLength(0)))")
                    .monospacedDigit()
            }
            .animation(.linear(duration: 0.1), value: progress)
        case .finished(let gif, let completedAt):
            HStack {
                Label {
                    Text("Completed at \(completedAt, format: .dateTime.hour().minute())")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                .font(.callout)
                Spacer()
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([gif])
                }
                .controlSize(.small)
            }
        case .failed(let message):
            Label {
                Text(message)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.callout)
            .foregroundStyle(.orange)
        }
    }
}

private struct VideoThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    private let size = CGSize(width: 80, height: JobRow.contentHeight)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "film").foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: url) {
            let request = QLThumbnailGenerator.Request(
                fileAt: url, size: size, scale: NSScreen.main?.backingScaleFactor ?? 2, representationTypes: .thumbnail
            )
            image = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
        }
    }
}
