import SwiftUI
import UniformTypeIdentifiers

public struct ChatScreen: View {
    @ObservedObject var controller: TeletypeController
    public var showClose: Bool
    public var onClose: (() -> Void)?
    public var placeholder: String?
    public var title: String?
    public var onAttachmentPress: (() async -> PickedAttachment?)?

    @State private var pendingFile: PickedAttachment?
    @FocusState private var composerFocused: Bool

    public init(
        controller: TeletypeController,
        showClose: Bool = true,
        onClose: (() -> Void)? = nil,
        placeholder: String? = nil,
        title: String? = nil,
        onAttachmentPress: (() async -> PickedAttachment?)? = nil
    ) {
        self.controller = controller
        self.showClose = showClose
        self.onClose = onClose
        self.placeholder = placeholder
        self.title = title
        self.onAttachmentPress = onAttachmentPress
    }

    private var theme: TeletypeTheme {
        .merge(primaryFromConfig: controller.state.primaryColor)
    }

    private var headerTitle: String {
        if let title { return title }
        return controller.state.title
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            MessageListView(
                messages: controller.state.messages,
                theme: theme,
                strings: controller.state.strings,
                language: controller.state.locale,
                chatBackground: controller.state.chatBackground,
                operatorTyping: controller.state.operatorTyping,
                onRate: { value, tempId in
                    controller.client.rateAppeal(value, formTempId: tempId)
                },
                onRetry: { tempId in
                    controller.client.retryMessage(tempId)
                }
            )
            ComposerView(
                theme: theme,
                placeholder: placeholder ?? controller.state.strings.composerPlaceholder,
                text: Binding(
                    get: { controller.state.draft },
                    set: { controller.client.setMessage($0) }
                ),
                onSend: { text in
                    controller.client.sendMessage(text)
                    controller.client.setMessage("")
                },
                onTyping: { controller.client.startTyping($0) },
                onStopTyping: { controller.client.stopTyping() },
                onAttachmentPress: onAttachmentPress == nil ? nil : {
                    Task {
                        if let file = await onAttachmentPress?() {
                            pendingFile = file
                        }
                    }
                }
            )
            .focused($composerFocused)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .accessibilityIdentifier("chatScreen")
        .sheet(item: Binding(
            get: { pendingFile.map { IdentifiedFile($0) } },
            set: { pendingFile = $0?.file }
        )) { item in
            ModalSendFile(
                file: item.file,
                theme: theme,
                strings: controller.state.strings,
                onClose: { pendingFile = nil },
                onSend: { picked in
                    pendingFile = nil
                    Task { try? await controller.client.uploadFile(picked) }
                }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            if showClose {
                Button {
                    if let onClose { onClose() } else { controller.client.hide() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.headerTextColor)
                        .frame(width: 40, height: 40)
                }
                .accessibilityIdentifier("chatBackButton")
            }
            Text(headerTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.headerTextColor)
                .lineLimit(1)
                .accessibilityIdentifier("chatHeaderTitle")
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(theme.primaryColor)
    }
}

private struct IdentifiedFile: Identifiable {
    let id = UUID()
    let file: PickedAttachment
    init(_ file: PickedAttachment) { self.file = file }
}
