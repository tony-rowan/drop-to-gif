import Foundation
import GifKit
import Observation

@MainActor
@Observable
final class ConversionQueue {
    struct Job: Identifiable {
        enum State {
            case queued
            case converting(progress: Double)
            case finished(URL, at: Date)
            case failed(String)
        }

        let id = UUID()
        let source: URL
        var state: State = .queued

        var isFinished: Bool {
            switch state {
            case .finished, .failed: true
            case .queued, .converting: false
            }
        }
    }

    var jobs: [Job] = []
    var settings = GifSettings()
    private var isProcessing = false

    var hasFinishedJobs: Bool { jobs.contains(where: \.isFinished) }

    func add(_ urls: [URL]) {
        for url in urls {
            if GifConverter.canConvert(url) {
                jobs.append(Job(source: url))
            } else {
                jobs.append(Job(source: url, state: .failed("Not a supported video file.")))
            }
        }
        Task { await processQueue() }
    }

    func clearFinished() {
        jobs.removeAll(where: \.isFinished)
    }

    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        while let index = jobs.firstIndex(where: { if case .queued = $0.state { true } else { false } }) {
            let id = jobs[index].id
            let source = jobs[index].source
            let destination = GifConverter.outputURL(for: source)
            update(id, to: .converting(progress: 0))
            do {
                try await GifConverter.convert(source, to: destination, settings: settings) { fraction in
                    Task { @MainActor [weak self] in self?.reportProgress(fraction, for: id) }
                }
                update(id, to: .finished(destination, at: .now))
            } catch {
                update(id, to: .failed(error.localizedDescription))
            }
        }
    }

    private func reportProgress(_ fraction: Double, for id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }), case .converting = job.state else { return }
        update(id, to: .converting(progress: fraction))
    }

    private func update(_ id: UUID, to state: Job.State) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = state
    }
}
