import SwiftUI
import TeletypeSDK

private let chatColors = ["#0084ff", "#34c759", "#ff3b30", "#7c3aed", "#ffcc00"]
private let localeOrder = ["en", "ru"]

enum Session: Equatable {
    case boot
    case setup
    case connecting
    case ready
}

enum SetupError: Equatable {
    case format, snippet, channel, connection
}

enum OpenSelect: Equatable {
    case position, scale
}

struct RootView: View {
    @State private var session: Session = .boot
    @State private var externalId = ""
    @State private var draftId = ""
    @State private var setupError: SetupError?
    @State private var uiLocale = getSystemLanguage() == "ru" ? "ru" : "en"
    @State private var chatTitle = ""
    @State private var primaryColor = DEFAULT_PRIMARY_COLOR
    @State private var chatBackground = DEFAULT_CHAT_BACKGROUND
    @State private var buttonPosition: ChatButtonPosition = .right
    @State private var buttonScale: ChatButtonScale = 100
    @State private var openSelect: OpenSelect?
    @StateObject private var holder = ClientHolder()

    private var t: DemoStrings { getDemoStrings(uiLocale) }
    private var resolvedTitle: String {
        let trimmed = chatTitle.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? t.chatTitle : trimmed
    }

    var body: some View {
        Group {
            switch session {
            case .boot, .connecting:
                connectingScreen
            case .setup:
                setupScreen
            case .ready:
                if let controller = holder.controller {
                    readyView(controller)
                } else {
                    setupScreen
                }
            }
        }
        .task { await boot() }
    }

    @ViewBuilder
    private func readyView(_ controller: TeletypeController) -> some View {
        ReadySwitcher(controller: controller) {
            ChatScreen(
                controller: controller,
                onClose: { controller.client.hide() },
                onAttachmentPress: { await pickAttachment() }
            )
        } home: {
            homeView(controller)
        }
    }

    private func homeView(_ controller: TeletypeController) -> some View {
        ZStack(alignment: buttonPosition == .left ? .bottomLeading : .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(t.screenTitle)
                        .font(.system(size: 28, weight: .heavy))
                    Text(t.screenSubtitle.replacingOccurrences(of: "{unread}", with: "\(controller.state.unreadCount)"))
                        .foregroundColor(Color(hex: "#666666"))
                        .padding(.bottom, 8)

                    appearanceFields

                    Button(t.openChat) { controller.client.show() }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("openChatButton")

                    Button(t.clearCache) { Task { await clearCache() } }
                        .buttonStyle(DangerButtonStyle())

                    Button(t.languageButton.replacingOccurrences(of: "{lang}", with: uiLocale.uppercased())) {
                        cycleLocale()
                    }
                    .buttonStyle(OutlineButtonStyle())
                    .accessibilityIdentifier("languageButton")
                }
                .padding(24)
                .padding(.top, 36)
                .padding(.bottom, 128)
            }

            ChatWidget(
                controller: controller,
                position: buttonPosition,
                scale: buttonScale,
                bottom: 40
            )

            if let openSelect {
                selectOverlay(openSelect)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var appearanceFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.chatTitleLabel).font(.system(size: 16, weight: .bold))
            TextField(t.chatTitlePlaceholder, text: $chatTitle)
                .textFieldStyle(DemoFieldStyle())
                .accessibilityIdentifier("chatTitleField")
                .onChange(of: chatTitle) { value in
                    UserDefaults.standard.set(value, forKey: DemoStorageKey.title)
                    holder.controller?.client.setTitle(resolvedTitle)
                }

            Text(t.chatColorLabel).font(.system(size: 16, weight: .bold))
            HStack(spacing: 10) {
                ForEach(chatColors, id: \.self) { color in
                    Button {
                        primaryColor = color
                        UserDefaults.standard.set(color, forKey: DemoStorageKey.color)
                        holder.controller?.client.setPrimaryColor(color)
                    } label: {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(hex: color))
                            .frame(width: 52, height: 52)
                            .overlay {
                                if color.lowercased() == primaryColor.lowercased() {
                                    Text("✓").foregroundColor(.white).font(.system(size: 22, weight: .bold))
                                }
                            }
                    }
                    .accessibilityIdentifier("colorSwatch-\(color)")
                }
            }
            .padding(.bottom, 8)

            Text(t.chatBackgroundLabel).font(.system(size: 16, weight: .bold))
            HStack(spacing: 8) {
                ForEach(ChatBackgrounds.picker, id: \.self) { id in
                    Button {
                        chatBackground = id
                        UserDefaults.standard.set(id, forKey: DemoStorageKey.background)
                        holder.controller?.client.setChatBackground(id)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                            if let thumb = backgroundThumb(id) {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                        .frame(height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(id == chatBackground ? Color(hex: "#0084ff") : Color(hex: "#d0d5da"), lineWidth: 1.5)
                        )
                    }
                    .accessibilityIdentifier("background-\(id)")
                }
            }

            Text(t.buttonPositionLabel).font(.system(size: 16, weight: .bold))
            DemoSelectField(
                valueLabel: buttonPosition == .left ? t.buttonPositionLeft : t.buttonPositionRight,
                accessibilityId: "buttonPositionSelect"
            ) {
                openSelect = .position
            }

            Text(t.buttonScaleLabel).font(.system(size: 16, weight: .bold))
            DemoSelectField(
                valueLabel: "\(buttonScale)%",
                accessibilityId: "buttonScaleSelect"
            ) {
                openSelect = .scale
            }
        }
    }

    @ViewBuilder
    private func selectOverlay(_ kind: OpenSelect) -> some View {
        switch kind {
        case .position:
            DemoSelectOverlay(
                title: t.buttonPositionLabel,
                options: [
                    (ChatButtonPosition.right, t.buttonPositionRight),
                    (.left, t.buttonPositionLeft),
                ],
                selected: buttonPosition,
                onSelect: { value in
                    buttonPosition = value
                    UserDefaults.standard.set(value.rawValue, forKey: DemoStorageKey.buttonPos)
                    openSelect = nil
                },
                onClose: { openSelect = nil }
            )
        case .scale:
            DemoSelectOverlay(
                title: t.buttonScaleLabel,
                options: CHAT_BUTTON_SCALES.reversed().map { ($0, "\($0)%") },
                selected: buttonScale,
                onSelect: { value in
                    buttonScale = value
                    UserDefaults.standard.set(value, forKey: DemoStorageKey.buttonScale)
                    openSelect = nil
                },
                onClose: { openSelect = nil }
            )
        }
    }

    private var setupScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(t.screenTitle).font(.system(size: 28, weight: .heavy))
                Text(t.setupTitle).foregroundColor(Color(hex: "#666666"))
                Text(t.setupHint).foregroundColor(Color(hex: "#888888")).padding(.top, -8)

                Button(t.languageButton.replacingOccurrences(of: "{lang}", with: uiLocale.uppercased())) {
                    cycleLocale()
                }
                .buttonStyle(OutlineButtonStyle())
                .accessibilityIdentifier("languageButton")

                TextEditor(text: $draftId)
                    .frame(height: 125)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(setupError == nil ? Color(hex: "#d0d5da") : Color(hex: "#e5352b"), lineWidth: 1)
                    )
                    .accessibilityIdentifier("externalIdField")
                    .onChange(of: draftId) { _ in setupError = nil }

                let parsed = extractTeletypeExternalId(draftId)
                if isTeletypeExternalId(parsed) {
                    Text(t.parsedId.replacingOccurrences(of: "{id}", with: parsed))
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#5f6368"))
                }
                if let err = setupErrorText {
                    Text(err).foregroundColor(Color(hex: "#e5352b")).font(.system(size: 14))
                }

                Button(t.connect) { Task { await connect(draftId) } }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("connectButton")
                    .opacity(draftId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                    .disabled(draftId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
            .padding(.top, 36)
        }
        .background(Color.white.ignoresSafeArea())
    }

    private var connectingScreen: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text(t.connecting).foregroundColor(Color(hex: "#666666"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }

    private var setupErrorText: String? {
        switch setupError {
        case .snippet: return t.snippetMissingId
        case .channel: return t.invalidChannel
        case .connection: return t.connectionFailed
        case .format: return t.invalidExternalId
        case nil: return nil
        }
    }

    private func cycleLocale() {
        let idx = localeOrder.firstIndex(of: uiLocale) ?? 0
        uiLocale = localeOrder[(idx + 1) % localeOrder.count]
        holder.controller?.client.setLocale(uiLocale, translations: demoTranslations)
    }

    private func pickAttachment() async -> PickedAttachment? {
        if let fixture = UITestMedia.nextFixture() {
            return fixture
        }
        return await AttachmentPicker.pick(strings: holder.controller?.state.strings ?? .fallback)
    }

    private func boot() async {
        let defaults = UserDefaults.standard
        if let storedTitle = defaults.string(forKey: DemoStorageKey.title) { chatTitle = storedTitle }
        if let storedColor = defaults.string(forKey: DemoStorageKey.color) { primaryColor = storedColor }
        if let storedBg = defaults.string(forKey: DemoStorageKey.background), isChatBackground(storedBg) {
            chatBackground = storedBg
        }
        if let storedPos = defaults.string(forKey: DemoStorageKey.buttonPos),
           let pos = ChatButtonPosition(rawValue: storedPos)
        {
            buttonPosition = pos
        }
        let storedScale = defaults.integer(forKey: DemoStorageKey.buttonScale)
        if CHAT_BUTTON_SCALES.contains(storedScale) { buttonScale = storedScale }

        let isUITest = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let stored = isUITest ? "" : (defaults.string(forKey: DemoStorageKey.externalId) ?? "")
        let parsed = extractTeletypeExternalId(stored)
        if parsed.isEmpty {
            draftId = stored
            session = .setup
            return
        }
        if !isTeletypeExternalId(parsed) {
            draftId = stored
            setupError = .format
            session = .setup
            return
        }
        draftId = parsed
        await verifyAndEnter(parsed)
    }

    private func connect(_ raw: String) async {
        let parsed = extractTeletypeExternalId(raw)
        if parsed.isEmpty {
            setupError = looksLikeSnippet(raw) ? .snippet : .format
            return
        }
        if !isTeletypeExternalId(parsed) {
            setupError = .format
            return
        }
        draftId = parsed
        await verifyAndEnter(parsed)
    }

    private func verifyAndEnter(_ id: String) async {
        setupError = nil
        session = .connecting
        holder.drop()

        let client = TeletypeClient(TeletypeConfig(
            teletypeExternalId: id,
            mode: .dev,
            soundEnabled: true,
            locale: uiLocale,
            translations: demoTranslations,
            title: resolvedTitle,
            primaryColor: primaryColor,
            chatBackground: chatBackground
        ))
        do {
            await client.`init`()
            if client.state.config == nil { throw TeletypeError.channel }
            try await client.waitUntilConnected(timeoutMs: 15000)
            print("[teletype-demo] connected to \(id)")
            UserDefaults.standard.set(id, forKey: DemoStorageKey.externalId)
            holder.attach(client)
            externalId = id
            session = .ready
        } catch {
            print("[teletype-demo] connect failed: \(error)")
            client.destroy()
            setupError = (error as? TeletypeError) == .channel ? .channel : .connection
            draftId = id
            externalId = ""
            session = .setup
        }
    }

    private func clearCache() async {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("teletype-") || key == DemoStorageKey.externalId {
            defaults.removeObject(forKey: key)
        }
        holder.drop()
        externalId = ""
        draftId = ""
        setupError = nil
        session = .setup
    }

    private func looksLikeSnippet(_ input: String) -> Bool {
        input.range(of: #"<\s*script|teletypeExternalId|widget\.teletype"#, options: .regularExpression) != nil
    }

    private func backgroundThumb(_ id: String) -> UIImage? {
        ChatBackgroundImages.thumb(id)
    }
}

private struct DemoSelectField: View {
    let valueLabel: String
    let accessibilityId: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(valueLabel)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#111111"))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("▼")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#111111"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#d0d5da"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }
}

private struct DemoSelectOverlay<Value: Hashable>: View {
    let title: String
    let options: [(Value, String)]
    let selected: Value
    var onSelect: (Value) -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityIdentifier("selectOverlay")

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#111111"))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ForEach(options, id: \.0) { value, label in
                    let active = value == selected
                    Button {
                        onSelect(value)
                    } label: {
                        Text(label)
                            .font(.system(size: 16, weight: active ? .semibold : .regular))
                            .foregroundColor(Color(hex: "#111111"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(active ? Color(hex: "#f3f4f6") : Color.clear)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
                    .accessibilityIdentifier("selectOption-\(label)")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .frame(maxWidth: 340)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 8)
            .padding(24)
        }
    }
}

/// Observes `TeletypeController` so `opened` changes re-render the host.
private struct ReadySwitcher<Chat: View, Home: View>: View {
    @ObservedObject var controller: TeletypeController
    @ViewBuilder var chat: () -> Chat
    @ViewBuilder var home: () -> Home

    var body: some View {
        if controller.state.opened {
            chat()
        } else {
            home()
        }
    }
}

@MainActor
final class ClientHolder: ObservableObject {
    @Published var controller: TeletypeController?

    func attach(_ client: TeletypeClient) {
        controller = TeletypeController(client: client)
    }

    func drop() {
        controller?.destroy()
        controller = nil
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(hex: "#0084ff").opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(hex: "#0084ff"))
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#0084ff"), lineWidth: 1))
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(hex: "#e5352b").opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DemoFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#d0d5da"), lineWidth: 1))
    }
}
