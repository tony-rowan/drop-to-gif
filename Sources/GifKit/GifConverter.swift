import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct GifSettings: Sendable, Equatable {
    public var framesPerSecond: Int
    /// Frames wider than this are scaled down, keeping the aspect ratio. `nil` keeps the original size.
    public var maxWidth: Int?

    public init(framesPerSecond: Int = 15, maxWidth: Int? = 480) {
        self.framesPerSecond = framesPerSecond
        self.maxWidth = maxWidth
    }
}

public enum GifConverterError: LocalizedError, Equatable {
    case noVideoTrack
    case couldNotCreateDestination
    case noFramesDecoded
    case couldNotFinalise

    public var errorDescription: String? {
        switch self {
        case .noVideoTrack: "The file has no video track."
        case .couldNotCreateDestination: "Couldn't create the GIF file."
        case .noFramesDecoded: "No frames could be read from the video."
        case .couldNotFinalise: "Couldn't finish writing the GIF file."
        }
    }
}

public enum GifConverter {
    /// Whether the file at `url` looks like a video AVFoundation can read (MP4, MOV, M4V, …).
    public static func canConvert(_ url: URL) -> Bool {
        let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
            ?? UTType(filenameExtension: url.pathExtension)
        return type?.conforms(to: .movie) ?? false
    }

    /// A `.gif` URL beside `source` that doesn't clash with an existing file.
    public static func outputURL(for source: URL) -> URL {
        let folder = source.deletingLastPathComponent()
        let name = source.deletingPathExtension().lastPathComponent
        var candidate = folder.appendingPathComponent(name).appendingPathExtension("gif")
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) \(suffix)").appendingPathExtension("gif")
            suffix += 1
        }
        return candidate
    }

    public static func convert(
        _ source: URL,
        to destination: URL,
        settings: GifSettings,
        progress: @Sendable (Double) -> Void = { _ in }
    ) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GifConverterError.noVideoTrack
        }
        let duration = try await asset.load(.duration).seconds
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)

        let fps = Double(max(settings.framesPerSecond, 1))
        let frameInterval = 1 / fps
        let frameCount = max(1, Int(duration * fps))
        let times = (0..<frameCount).map { CMTime(seconds: Double($0) * frameInterval, preferredTimescale: 600) }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let tolerance = CMTime(seconds: frameInterval / 2, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        let displaySize = naturalSize.applying(transform)
        let displayWidth = abs(displaySize.width), displayHeight = abs(displaySize.height)
        if let maxWidth = settings.maxWidth, displayWidth > CGFloat(maxWidth) {
            let scale = CGFloat(maxWidth) / displayWidth
            generator.maximumSize = CGSize(width: CGFloat(maxWidth), height: (displayHeight * scale).rounded())
        }

        guard let gif = CGImageDestinationCreateWithURL(
            destination as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else {
            throw GifConverterError.couldNotCreateDestination
        }
        CGImageDestinationSetProperties(gif, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameInterval,
                kCGImagePropertyGIFUnclampedDelayTime: frameInterval
            ]
        ] as CFDictionary

        do {
            // The destination expects exactly `frameCount` images, so a frame that fails to
            // decode is filled with the previous one (or the next good one, if it's at the start).
            var previous: CGImage?
            var leadingFailures = 0
            var processed = 0
            for await result in generator.images(for: times) {
                try Task.checkCancellation()
                if let image = try? result.image {
                    for _ in 0...leadingFailures {
                        CGImageDestinationAddImage(gif, image, frameProperties)
                    }
                    leadingFailures = 0
                    previous = image
                } else if let previous {
                    CGImageDestinationAddImage(gif, previous, frameProperties)
                } else {
                    leadingFailures += 1
                }
                processed += 1
                progress(Double(processed) / Double(frameCount))
            }
            try Task.checkCancellation()
            guard previous != nil else { throw GifConverterError.noFramesDecoded }
            guard CGImageDestinationFinalize(gif) else { throw GifConverterError.couldNotFinalise }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
