import AVFoundation
import Foundation
import GifKit
import ImageIO
import Testing

@Suite("GifConverter")
struct GifConverterTests {
    let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @Test("converts a video to a looping GIF at the chosen frame rate and width", arguments: [
        (AVFileType.mp4, "mp4"),
        (AVFileType.mov, "mov")
    ])
    func convertsVideo(fileType: AVFileType, fileExtension: String) async throws {
        let video = try await makeVideo(named: "clip.\(fileExtension)", fileType: fileType, size: CGSize(width: 640, height: 360), seconds: 2)
        let gif = GifConverter.outputURL(for: video)

        try await GifConverter.convert(video, to: gif, settings: GifSettings(framesPerSecond: 10, maxWidth: 320))

        let source = try #require(CGImageSourceCreateWithURL(gif as CFURL, nil))
        #expect(CGImageSourceGetCount(source) == 20)
        let frame = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(frame.width == 320)
        #expect(frame.height == 180)
        let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        #expect(gifProperties?[kCGImagePropertyGIFLoopCount] as? Int == 0)
    }

    @Test("keeps the original size when no maximum width is set")
    func keepsOriginalSize() async throws {
        let video = try await makeVideo(named: "small.mov", fileType: .mov, size: CGSize(width: 160, height: 120), seconds: 1)
        let gif = GifConverter.outputURL(for: video)

        try await GifConverter.convert(video, to: gif, settings: GifSettings(framesPerSecond: 5, maxWidth: nil))

        let source = try #require(CGImageSourceCreateWithURL(gif as CFURL, nil))
        let frame = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(frame.width == 160)
        #expect(frame.height == 120)
    }

    @Test("keeps portrait phone recordings upright")
    func rotatedVideo() async throws {
        let video = try await makeVideo(named: "phone.mov", fileType: .mov, size: CGSize(width: 640, height: 360), seconds: 1,
                                        transform: CGAffineTransform(rotationAngle: .pi / 2))
        let gif = GifConverter.outputURL(for: video)

        try await GifConverter.convert(video, to: gif, settings: GifSettings(framesPerSecond: 5, maxWidth: 180))

        let source = try #require(CGImageSourceCreateWithURL(gif as CFURL, nil))
        let frame = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(frame.width == 180)
        #expect(frame.height == 320)
    }

    @Test("names the GIF after the video without overwriting an existing GIF")
    func outputNaming() throws {
        let video = folder.appendingPathComponent("holiday.mov")
        #expect(GifConverter.outputURL(for: video).lastPathComponent == "holiday.gif")

        FileManager.default.createFile(atPath: folder.appendingPathComponent("holiday.gif").path, contents: Data())
        #expect(GifConverter.outputURL(for: video).lastPathComponent == "holiday 2.gif")
    }

    @Test("accepts videos and rejects other files")
    func supportedFiles() {
        #expect(GifConverter.canConvert(URL(fileURLWithPath: "/tmp/a.mp4")))
        #expect(GifConverter.canConvert(URL(fileURLWithPath: "/tmp/a.mov")))
        #expect(GifConverter.canConvert(URL(fileURLWithPath: "/tmp/a.m4v")))
        #expect(!GifConverter.canConvert(URL(fileURLWithPath: "/tmp/a.png")))
        #expect(!GifConverter.canConvert(URL(fileURLWithPath: "/tmp/a.txt")))
    }

    @Test("reports a missing video track instead of writing a GIF")
    func rejectsNonVideo() async throws {
        let notVideo = folder.appendingPathComponent("broken.mov")
        try Data("not a video".utf8).write(to: notVideo)
        let gif = folder.appendingPathComponent("broken.gif")

        await #expect(throws: (any Error).self) {
            try await GifConverter.convert(notVideo, to: gif, settings: GifSettings())
        }
        #expect(!FileManager.default.fileExists(atPath: gif.path))
    }

    /// Writes a short H.264 clip of solid colour frames that change over time.
    private func makeVideo(named name: String, fileType: AVFileType, size: CGSize, seconds: Int,
                           transform: CGAffineTransform = .identity) async throws -> URL {
        let url = folder.appendingPathComponent(name)
        let fps: Int32 = 30
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ])
        input.transform = transform
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        writer.add(input)
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<(Int(fps) * seconds) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            let pool = try #require(adaptor.pixelBufferPool)
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            let pixels = try #require(buffer)
            CVPixelBufferLockBaseAddress(pixels, [])
            let shade = UInt8(frame * 255 / (Int(fps) * seconds))
            memset(CVPixelBufferGetBaseAddress(pixels), Int32(shade), CVPixelBufferGetDataSize(pixels))
            CVPixelBufferUnlockBaseAddress(pixels, [])
            adaptor.append(pixels, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }
        input.markAsFinished()
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }
}
