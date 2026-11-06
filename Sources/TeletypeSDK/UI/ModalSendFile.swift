import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct ModalSendFile: View {
    let file: LocalFile
    let theme: TeletypeTheme
    let strings: TeletypeStrings
    var onClose: () -> Void
    var onSend: (LocalFile) -> Void

    private var kind: MessageType { messageTypeFromFile(file) }

    private var title: String {
        switch kind {
        case .image: return strings.sendImage
        case .video: return strings.sendVideo
        case .audio: return strings.sendAudio
        default: return strings.sendFile
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                preview
                Text(file.name)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                if let size = file.size {
                    Text(formatBytes(size, strings: strings))
                        .foregroundColor(theme.mutedColor)
                }
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.cancel, action: onClose)
                        .accessibilityIdentifier("cancelAttachmentButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(strings.send) { onSend(file) }
                        .fontWeight(.bold)
                        .accessibilityIdentifier("sendAttachmentButton")
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch kind {
        case .image:
            MediaImageView(url: localURL, contentMode: .fit)
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("sendImagePreview")
        case .video:
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
                    .frame(height: 200)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }
            .accessibilityIdentifier("sendVideoPreview")
        default:
            Image(systemName: "doc.fill")
                .font(.system(size: 56))
                .foregroundColor(theme.mutedColor)
                .padding(.top, 24)
        }
    }

    private var localURL: URL? {
        if file.uri.hasPrefix("file://") { return URL(string: file.uri) }
        return URL(fileURLWithPath: file.uri)
    }
}

public enum DocumentPicker {
    /// Present a system document picker and return the first selected file.
    @MainActor
    public static func pick() async -> PickedAttachment? {
        await withCheckedContinuation { cont in
            let coordinator = Coordinator { file in
                cont.resume(returning: file)
            }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
            picker.allowsMultipleSelection = false
            picker.delegate = coordinator
            CoordinatorStore.shared.retain(coordinator)
            guard let presenter = topPresenter() else {
                cont.resume(returning: nil)
                return
            }
            presenter.present(picker, animated: true)
        }
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (PickedAttachment?) -> Void
        init(_ completion: @escaping (PickedAttachment?) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            CoordinatorStore.shared.release(self)
            guard let url = urls.first else {
                completion(nil)
                return
            }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("teletype-\(UUID().uuidString)-\(url.lastPathComponent)")
            try? FileManager.default.copyItem(at: url, to: dest)
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.intValue
            let type = UTType(filenameExtension: dest.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            completion(PickedAttachment(
                uri: dest.absoluteString,
                name: url.lastPathComponent,
                type: type,
                size: size
            ))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            CoordinatorStore.shared.release(self)
            completion(nil)
        }
    }
}

private final class CoordinatorStore {
    static let shared = CoordinatorStore()
    private var items: [ObjectIdentifier: DocumentPicker.Coordinator] = [:]
    func retain(_ c: DocumentPicker.Coordinator) { items[ObjectIdentifier(c)] = c }
    func release(_ c: DocumentPicker.Coordinator) { items[ObjectIdentifier(c)] = nil }
}
