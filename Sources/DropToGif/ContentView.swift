import GifKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var queue: ConversionQueue
    @State private var isTargeted = false
    @State private var isImporting = false

    var body: some View {
        VStack(spacing: 16) {
            dropZone
            settings
            if !queue.jobs.isEmpty {
                jobList
            }
        }
        .padding(20)
        .frame(width: 460)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { queue.add(urls) }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack")
                .font(.system(size: 44))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            Text("Drop MP4 or MOV files here")
                .font(.headline)
            Text("GIFs are saved next to the original")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Choose Files…") { isImporting = true }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isTargeted ? Color.accentColor : .secondary.opacity(0.5),
                              style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
        )
        .dropDestination(for: URL.self) { urls, _ in
            queue.add(urls)
            return !urls.isEmpty
        } isTargeted: { isTargeted = $0 }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    private var settings: some View {
        HStack {
            Picker("Frame rate", selection: $queue.settings.framesPerSecond) {
                ForEach([10, 15, 20, 25], id: \.self) { Text("\($0) fps").tag($0) }
            }
            Picker("Width", selection: $queue.settings.maxWidth) {
                ForEach([320, 480, 640, 800], id: \.self) { Text("\($0) px").tag(Int?.some($0)) }
                Text("Original").tag(Int?.none)
            }
        }
        .fixedSize()
    }

    private var jobList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Conversions").font(.headline)
                Spacer()
                Button("Clear Finished") { queue.clearFinished() }
                    .disabled(!queue.hasFinishedJobs)
            }
            ScrollView {
                VStack(spacing: Self.rowSpacing) {
                    ForEach(queue.jobs) { JobRow(job: $0) }
                }
            }
            // The window is sized to its content's minimum height, and a ScrollView's minimum is zero,
            // so the list needs an explicit height or its rows are squashed out of sight.
            .frame(height: listHeight)
        }
    }

    private static let rowSpacing: CGFloat = 8
    private static let maxVisibleRows = 4

    private var listHeight: CGFloat {
        let rows = CGFloat(min(queue.jobs.count, Self.maxVisibleRows))
        return rows * JobRow.height + max(rows - 1, 0) * Self.rowSpacing
    }
}
