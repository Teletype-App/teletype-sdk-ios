import AVKit
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

enum MediaKind {
    case image, video, audio, file
}

private let imageExts: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp"]
private let videoExts: Set<String> = ["mp4", "mov", "m4v", "webm", "mkv", "avi", "3gp"]
private let audioExts: Set<String> = ["mp3", "m4a", "aac", "wav", "ogg", "oga", "flac", "opus", "amr", "caf"]

func getExt(_ nameOrUrl: String) -> String {
    getExtension(nameOrUrl)
}

func attachmentUrl(_ message: Message) -> String {
    message.attachmentUrl ?? message.attachment ?? ""
}

func attachmentName(_ message: Message) -> String {
    if let name = message.attachment, !name.lowercased().hasPrefix("http") {
        return name
    }
    let fromUrl = (message.attachmentUrl ?? "").split(separator: "?").first.map(String.init) ?? ""
    return fromUrl.split(separator: "/").last.map(String.init) ?? "file"
}

func mediaFileURL(_ string: String?) -> URL? {
    guard let string, !string.isEmpty else { return nil }
    if string.hasPrefix("file://") { return URL(string: string) }
    if string.hasPrefix("http://") || string.hasPrefix("https://") { return URL(string: string) }
    if string.hasPrefix("/") { return URL(fileURLWithPath: string) }
    return URL(string: string)
}

func resolveMediaKind(_ message: Message) -> MediaKind? {
    let type: MessageType? = message.messageType == .gif ? .image : message.messageType
    switch type {
    case .image: return .image
    case .video: return .video
    case .audio: return .audio
    case .attachment:
        let name = message.attachment ?? ""
        let url = message.attachmentUrl ?? ""
        return kindFromExt(getExt(name)) ?? kindFromExt(getExt(url)) ?? .file
    default:
        if message.attachmentUrl != nil || message.attachment != nil {
            let name = message.attachment ?? ""
            let url = message.attachmentUrl ?? ""
            return kindFromExt(getExt(name)) ?? kindFromExt(getExt(url)) ?? .file
        }
        return nil
    }
}

private func kindFromExt(_ ext: String) -> MediaKind? {
    if imageExts.contains(ext) { return .image }
    if videoExts.contains(ext) { return .video }
    if audioExts.contains(ext) { return .audio }
    return nil
}

func formatDuration(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "00:00" }
    let total = Int(seconds)
    let m = total / 60
    let s = total % 60
    return String(format: "%02d:%02d", m, s)
}

enum FileCache {
    static var root: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("teletype-sdk", isDirectory: true)
    }

    static func path(fileName: String, id: String?) -> URL {
        let safe = fileName.replacingOccurrences(of: "/", with: "_")
        return root
            .appendingPathComponent(id ?? "anon", isDirectory: true)
            .appendingPathComponent(safe)
    }

    static func getCached(fileName: String, id: String?) -> URL? {
        let url = path(fileName: fileName, id: id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func ensureCached(remote: String, fileName: String, id: String?) async throws -> URL {
        if let cached = getCached(fileName: fileName, id: id) { return cached }
        try FileManager.default.createDirectory(at: path(fileName: fileName, id: id).deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let src = mediaFileURL(remote) else { throw TeletypeError.uploadFailed }
        if src.isFileURL {
            let dest = path(fileName: fileName, id: id)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
            return dest
        }
        let (temp, _) = try await URLSession.shared.download(from: src)
        let dest = path(fileName: fileName, id: id)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: temp, to: dest)
        return dest
    }
}

@MainActor
func loadUIImage(from url: URL?) async -> UIImage? {
    guard let url else { return nil }
    if url.isFileURL {
        return UIImage(contentsOfFile: url.path)
    }
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        return UIImage(data: data)
    } catch {
        return nil
    }
}

func videoThumbnail(from url: URL?) async -> UIImage? {
    guard let url else { return nil }
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 640, height: 640)
    do {
        let cg = try await generator.image(at: .zero).image
        return UIImage(cgImage: cg)
    } catch {
        return nil
    }
}

struct MediaImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(Color.gray.opacity(0.2))
                    .overlay(ProgressView())
            }
        }
        .task(id: url?.absoluteString) {
            image = await loadUIImage(from: url)
        }
    }
}

struct MessageTypeImageView: View {
    let message: Message
    let strings: TeletypeStrings
    @State private var fullscreen = false

    private var previewURL: URL? {
        mediaFileURL(message.attachmentPreviewUrl) ?? mediaFileURL(attachmentUrl(message))
    }

    private var fullURL: URL? {
        mediaFileURL(attachmentUrl(message)) ?? previewURL
    }

    var body: some View {
        Button { fullscreen = true } label: {
            MediaImageView(url: previewURL)
                .frame(width: 220, height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("mediaImage")
        .accessibilityLabel("Image")
        .accessibilityAddTraits(.isButton)
        .fullScreenCover(isPresented: $fullscreen) {
            ZStack {
                Color.black.ignoresSafeArea()
                MediaImageView(url: fullURL, contentMode: .fit)
                    .padding(.top, 44)
                    .accessibilityIdentifier("mediaViewer")
                VStack {
                    HStack {
                        Spacer()
                        Button(strings.mediaClose) { fullscreen = false }
                            .foregroundColor(.white)
                            .padding()
                            .accessibilityIdentifier("mediaCloseButton")
                    }
                    Spacer()
                }
            }
        }
    }
}

struct MessageTypeVideoView: View {
    let message: Message
    let strings: TeletypeStrings
    @State private var player: AVPlayer?
    @State private var showPlayer = false
    @State private var thumb: UIImage?
    @State private var opening = false

    private var url: URL? { mediaFileURL(attachmentUrl(message)) }
    private var previewURL: URL? { mediaFileURL(message.attachmentPreviewUrl) }

    var body: some View {
        Button {
            Task { await open() }
        } label: {
            ZStack {
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 160)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 220, height: 160)
                }
                if opening {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .shadow(radius: 6)
                }
            }
            .frame(width: 220, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("mediaVideo")
        .accessibilityLabel("Video")
        .accessibilityAddTraits(.isButton)
        .task(id: attachmentUrl(message)) {
            if let previewURL, let img = await loadUIImage(from: previewURL) {
                thumb = img
            } else {
                thumb = await videoThumbnail(from: url)
            }
        }
        .fullScreenCover(isPresented: $showPlayer, onDismiss: {
            player?.pause()
            player = nil
        }) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                if let player {
                    PlayerControllerView(player: player)
                        .ignoresSafeArea()
                        .onAppear { player.play() }
                        .accessibilityIdentifier("mediaVideoPlayer")
                }
                Button(strings.mediaClose) { showPlayer = false }
                    .foregroundColor(.white)
                    .padding()
                    .accessibilityIdentifier("mediaCloseButton")
            }
            .background(Color.black.ignoresSafeArea())
        }
    }

    private func open() async {
        opening = true
        defer { opening = false }
        let local = try? await FileCache.ensureCached(
            remote: attachmentUrl(message),
            fileName: attachmentName(message),
            id: message.attachmentId ?? message.tempId
        )
        let playURL = local ?? url
        guard let playURL else { return }
        await MainActor.run {
            let item = AVPlayer(url: playURL)
            player = item
            showPlayer = true
        }
    }
}

struct PlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}

struct MessageTypeAudioView: View {
    let message: Message
    let theme: TeletypeTheme
    let strings: TeletypeStrings
    @State private var player: AVPlayer?
    @State private var playing = false
    @State private var duration: Double = 0
    @State private var position: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Button {
                toggle()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .foregroundColor(theme.ownTextColor)
                    .frame(width: 36, height: 36)
                    .background(theme.primaryColor)
                    .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(attachmentName(message))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(formatDuration(playing ? position : duration))
                    .font(.system(size: 12))
                    .foregroundColor(theme.mutedColor)
            }
        }
        .padding(10)
        .onDisappear { player?.pause() }
    }

    private func toggle() {
        if player == nil, let url = mediaFileURL(attachmentUrl(message)) {
            player = AVPlayer(url: url)
        }
        guard let player else { return }
        if playing {
            player.pause()
            playing = false
        } else {
            player.play()
            playing = true
        }
    }
}

struct MessageTypeFileView: View {
    let message: Message
    let theme: TeletypeTheme
    let strings: TeletypeStrings
    let isOwn: Bool
    @State private var opening = false

    var body: some View {
        Button {
            Task { await open() }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(isOwn ? Color.white.opacity(0.2) : Color.black.opacity(0.08))
                    Image(systemName: "doc.fill")
                        .foregroundColor(isOwn ? .white : theme.operatorTextColor)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachmentName(message))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isOwn ? theme.ownTextColor : theme.operatorTextColor)
                        .lineLimit(2)
                    if let size = message.size {
                        Text(formatBytes(size, strings: strings))
                            .font(.system(size: 12))
                            .foregroundColor(theme.mutedColor)
                    }
                }
                if opening { ProgressView() }
            }
            .padding(10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mediaFile")
        .accessibilityLabel("File")
    }

    private func open() async {
        opening = true
        defer { opening = false }
        do {
            let local = try await FileCache.ensureCached(
                remote: attachmentUrl(message),
                fileName: attachmentName(message),
                id: message.attachmentId ?? message.tempId
            )
            await MainActor.run { presentQuickLook(local) }
        } catch {
            if let url = mediaFileURL(attachmentUrl(message)) {
                await MainActor.run { UIApplication.shared.open(url) }
            }
        }
    }
}

private final class QuickLookPresenter: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    let url: URL
    init(url: URL) { self.url = url }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        url as QLPreviewItem
    }

    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        PickerRetain.shared.release(self)
    }
}

@MainActor
private func presentQuickLook(_ url: URL) {
    let presenter = QuickLookPresenter(url: url)
    PickerRetain.shared.retain(presenter)
    let controller = QLPreviewController()
    controller.dataSource = presenter
    controller.delegate = presenter
    controller.view.accessibilityIdentifier = "filePreview"
    topPresenter()?.present(controller, animated: true)
}
