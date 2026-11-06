import AVFoundation
import UIKit
import TeletypeSDK

enum UITestMedia {
    private static var queue: [String] = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitest-media") {
            return ["image", "video", "file"]
        }
        if let idx = args.firstIndex(of: "-uitest-fixture"), args.indices.contains(idx + 1) {
            return [args[idx + 1]]
        }
        return []
    }()

    private static let videoLock = NSLock()

    static func prepareIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-uitest-media")
            || ProcessInfo.processInfo.arguments.contains("-uitest-fixture")
        else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = video()
        }
    }

    static func nextFixture() -> PickedAttachment? {
        guard !queue.isEmpty else { return nil }
        return make(queue.removeFirst())
    }

    static func make(_ kind: String) -> PickedAttachment? {
        switch kind {
        case "image": return image()
        case "video": return video()
        case "file": return file()
        default: return nil
        }
    }

    private static func image() -> PickedAttachment {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("teletype-uitest.jpg")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480))
        let img = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 170, y: 90, width: 300, height: 300)).fill()
            UIColor.systemBlue.setFill()
            UIBezierPath(ovalIn: CGRect(x: 250, y: 170, width: 140, height: 140)).fill()
        }
        let data = img.jpegData(compressionQuality: 0.85) ?? Data()
        try? data.write(to: url)
        return PickedAttachment(
            uri: url.absoluteString,
            name: "teletype-test.jpg",
            type: "image/jpeg",
            size: data.count,
            width: 640,
            height: 480
        )
    }

    private static func file() -> PickedAttachment {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("teletype-uitest.txt")
        let body = "Teletype SDK UI test file\n"
        try? body.write(to: url, atomically: true, encoding: .utf8)
        let size = (try? Data(contentsOf: url).count) ?? body.utf8.count
        return PickedAttachment(
            uri: url.absoluteString,
            name: "teletype-test.txt",
            type: "text/plain",
            size: size
        )
    }

    private static func video() -> PickedAttachment {
        videoLock.lock()
        defer { videoLock.unlock() }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("teletype-uitest.mp4")
        if !FileManager.default.fileExists(atPath: url.path) {
            writeTestVideo(to: url)
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
        var preview: String?
        if let thumb = videoThumb(url) {
            let thumbURL = FileManager.default.temporaryDirectory.appendingPathComponent("teletype-uitest-thumb.jpg")
            try? thumb.jpegData(compressionQuality: 0.8)?.write(to: thumbURL)
            preview = thumbURL.absoluteString
        }
        return PickedAttachment(
            uri: url.absoluteString,
            name: "teletype-test.mp4",
            type: "video/mp4",
            size: size,
            width: 320,
            height: 240,
            previewUri: preview
        )
    }

    private static func videoThumb(_ url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cg = try? generator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func writeTestVideo(to url: URL) {
        try? FileManager.default.removeItem(at: url)
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            return
        }
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320,
            AVVideoHeightKey: 240,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: 320,
            kCVPixelBufferHeightKey as String: 240,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { return }
        writer.add(input)
        guard writer.startWriting() else { return }
        writer.startSession(atSourceTime: .zero)

        let frames = 24
        let fps: Int32 = 12
        for i in 0..<frames {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            guard let buffer = pixelBuffer(index: i, width: 320, height: 240) else { continue }
            let time = CMTime(value: CMTimeValue(i), timescale: fps)
            adaptor.append(buffer, withPresentationTime: time)
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        _ = done.wait(timeout: .now() + 8)
    }

    private static func pixelBuffer(index: Int, width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &buffer
        )
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) {
            let t = CGFloat(index) / 24
            ctx.setFillColor(UIColor(red: 0.1, green: 0.35 + 0.4 * t, blue: 0.9, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.setFillColor(UIColor.white.cgColor)
            let size = 40 + 80 * t
            ctx.fillEllipse(in: CGRect(x: 80 + 60 * t, y: 60, width: size, height: size))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
