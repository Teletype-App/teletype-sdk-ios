import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

public enum AttachmentPicker {
    /// Action sheet: photo library (images / videos) or the system file picker.
    @MainActor
    public static func pick(strings: TeletypeStrings = .fallback) async -> PickedAttachment? {
        guard let source = await pickSource(strings: strings) else { return nil }
        switch source {
        case .photo:
            return await pickFromLibrary(filter: .images)
        case .video:
            return await pickFromLibrary(filter: .videos)
        case .file:
            return await DocumentPicker.pick()
        }
    }

    private enum Source { case photo, video, file }

    @MainActor
    private static func pickSource(strings: TeletypeStrings) async -> Source? {
        await withCheckedContinuation { cont in
            guard let presenter = topPresenter() else {
                cont.resume(returning: nil)
                return
            }
            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            sheet.addAction(UIAlertAction(title: strings.attachPhoto, style: .default) { _ in
                cont.resume(returning: .photo)
            })
            sheet.addAction(UIAlertAction(title: strings.attachVideo, style: .default) { _ in
                cont.resume(returning: .video)
            })
            sheet.addAction(UIAlertAction(title: strings.attachFile, style: .default) { _ in
                cont.resume(returning: .file)
            })
            sheet.addAction(UIAlertAction(title: strings.cancel, style: .cancel) { _ in
                cont.resume(returning: nil)
            })
            if let pop = sheet.popoverPresentationController {
                pop.sourceView = presenter.view
                pop.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.maxY - 48,
                    width: 1,
                    height: 1
                )
            }
            presenter.present(sheet, animated: true)
        }
    }

    @MainActor
    private static func pickFromLibrary(filter: PHPickerFilter) async -> PickedAttachment? {
        await withCheckedContinuation { cont in
            var config = PHPickerConfiguration()
            config.filter = filter
            config.selectionLimit = 1
            let coordinator = PhotoCoordinator { file in
                cont.resume(returning: file)
            }
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = coordinator
            PickerRetain.shared.retain(coordinator)
            guard let presenter = topPresenter() else {
                cont.resume(returning: nil)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                presenter.present(picker, animated: true)
            }
        }
    }
}

func topPresenter() -> UIViewController? {
    guard let root = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)?
        .rootViewController
    else { return nil }
    var presenter = root
    while let presented = presenter.presentedViewController {
        presenter = presented
    }
    return presenter
}

final class PickerRetain {
    static let shared = PickerRetain()
    private var items: [ObjectIdentifier: AnyObject] = [:]
    func retain(_ object: AnyObject) { items[ObjectIdentifier(object)] = object }
    func release(_ object: AnyObject) { items[ObjectIdentifier(object)] = nil }
}

private final class PhotoCoordinator: NSObject, PHPickerViewControllerDelegate {
    let completion: (PickedAttachment?) -> Void
    init(_ completion: @escaping (PickedAttachment?) -> Void) {
        self.completion = completion
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        PickerRetain.shared.release(self)
        guard let provider = results.first?.itemProvider else {
            completion(nil)
            return
        }
        Task {
            let file = await Self.load(provider)
            await MainActor.run { completion(file) }
        }
    }

    private static func load(_ provider: NSItemProvider) async -> PickedAttachment? {
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            return await loadFile(provider, type: UTType.movie, fallbackName: "video.mp4", mime: "video/mp4")
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if let image = await loadImage(provider) {
                return writeImage(image)
            }
            return await loadFile(provider, type: UTType.image, fallbackName: "image.jpg", mime: "image/jpeg")
        }
        return await loadFile(provider, type: UTType.item, fallbackName: "file", mime: "application/octet-stream")
    }

    private static func loadImage(_ provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { cont in
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                cont.resume(returning: nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                cont.resume(returning: object as? UIImage)
            }
        }
    }

    private static func writeImage(_ image: UIImage) -> PickedAttachment? {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("teletype-\(UUID().uuidString).jpg")
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        try? data.write(to: dest)
        return PickedAttachment(
            uri: dest.absoluteString,
            name: dest.lastPathComponent,
            type: "image/jpeg",
            size: data.count,
            width: Double(image.size.width * image.scale),
            height: Double(image.size.height * image.scale)
        )
    }

    private static func loadFile(
        _ provider: NSItemProvider,
        type: UTType,
        fallbackName: String,
        mime: String
    ) async -> PickedAttachment? {
        await withCheckedContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                guard let url else {
                    cont.resume(returning: nil)
                    return
                }
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("teletype-\(UUID().uuidString)-\(url.lastPathComponent)")
                try? FileManager.default.copyItem(at: url, to: dest)
                let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.intValue
                let ut = UTType(filenameExtension: dest.pathExtension)
                let resolvedMime = ut?.preferredMIMEType ?? mime
                var preview: String?
                if messageTypeFromFile(name: dest.lastPathComponent, type: resolvedMime) == .video {
                    if let thumb = thumbnailSync(url: dest) {
                        let thumbURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("teletype-thumb-\(UUID().uuidString).jpg")
                        try? thumb.jpegData(compressionQuality: 0.8)?.write(to: thumbURL)
                        preview = thumbURL.absoluteString
                    }
                }
                cont.resume(returning: PickedAttachment(
                    uri: dest.absoluteString,
                    name: url.lastPathComponent.isEmpty ? fallbackName : url.lastPathComponent,
                    type: resolvedMime,
                    size: size,
                    previewUri: preview
                ))
            }
        }
    }

    private static func thumbnailSync(url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let cg = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
        return UIImage(cgImage: cg)
    }
}
