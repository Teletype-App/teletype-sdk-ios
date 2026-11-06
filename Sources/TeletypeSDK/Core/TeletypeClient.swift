import Foundation

public struct TeletypeConfig {
    public var teletypeExternalId: String
    public var mode: TeletypeMode
    public var environment: TeletypeEnvironmentOverrides?
    public var storage: KeyValueStore?
    public var soundEnabled: Bool
    public var socketOptions: [String: Any]
    public var locale: String?
    public var translations: TeletypeTranslations?
    public var title: String?
    public var primaryColor: String?
    public var chatBackground: ChatBackground
    public var device: [String: String]

    public init(
        teletypeExternalId: String,
        mode: TeletypeMode = DEFAULT_MODE,
        environment: TeletypeEnvironmentOverrides? = nil,
        storage: KeyValueStore? = nil,
        soundEnabled: Bool = false,
        socketOptions: [String: Any] = [:],
        locale: String? = nil,
        translations: TeletypeTranslations? = nil,
        title: String? = nil,
        primaryColor: String? = nil,
        chatBackground: ChatBackground = DEFAULT_CHAT_BACKGROUND,
        device: [String: String] = [:]
    ) {
        self.teletypeExternalId = teletypeExternalId
        self.mode = mode
        self.environment = environment
        self.storage = storage
        self.soundEnabled = soundEnabled
        self.socketOptions = socketOptions
        self.locale = locale
        self.translations = translations
        self.title = title
        self.primaryColor = primaryColor
        self.chatBackground = chatBackground
        self.device = device
    }
}

public struct TeletypeState: Equatable {
    public var ready: Bool
    public var opened: Bool
    public var connection: ConnectionState
    public var messages: [Message]
    public var operators: [Operator]
    public var channels: [ChannelMessenger]
    public var config: WidgetConfigData?
    public var unreadCount: Int
    public var operatorTyping: Bool
    public var draft: String
    public var title: String
    public var primaryColor: String
    public var chatBackground: ChatBackground
    public var locale: String
    public var strings: TeletypeStrings
}

/// Headless, framework-agnostic chat engine. Owns the socket + REST lifecycle.
public final class TeletypeClient {
    public let externalId: String
    public let env: TeletypeEnvironment

    private var _locale: String
    private var _strings: TeletypeStrings
    private var _title: String
    private var _primaryColor: String?
    private var _chatBackground: ChatBackground
    private var translations: TeletypeTranslations?

    private let api: ApiClient
    private let socket: SocketClient
    private let storage: TeletypeStorage
    private let emitter = TypedEventEmitter()

    private var soundEnabled: Bool
    private var device: [String: String]

    private var _ready = false
    private var _opened = false
    private var _connection: ConnectionState = .disconnected
    private var _messages: [Message] = []
    private var _operators: [Operator] = []
    private var _channels: [ChannelMessenger] = []
    private var _config: WidgetConfigData?
    private var _unreadCount = 0
    private var _operatorTyping = false
    private var _draft = ""

    private var personId = ""
    private var _appealId = ""
    private var personData: [String: Any]?
    private var personAdditionalInfo = AdditionalPersonInfo()
    private var greetingSent = false
    private var messageWasSent = false
    private var banned = false

    private var pendingMessages: [Message] = []
    private var messagesInPending: [Message] = []
    private var receivedTimeouts: [String: DispatchWorkItem] = [:]
    private var initialized = false
    private var listenersBound = false

    public init(_ config: TeletypeConfig) {
        self.externalId = config.teletypeExternalId
        self.env = getEnvironment(config.mode).merging(config.environment)
        self.soundEnabled = config.soundEnabled
        self.device = config.device
        self.translations = config.translations
        let resolved = resolveStrings(locale: config.locale, translations: config.translations)
        self._locale = resolved.language
        self._strings = resolved.strings
        self._title = config.title ?? DEFAULT_CHAT_TITLE
        self._primaryColor = config.primaryColor
        self._chatBackground = config.chatBackground
        self.api = ApiClient(env: env, externalId: config.teletypeExternalId)
        self.socket = SocketClient(
            url: env.wsUrl,
            options: ["forceNew": true].merging(config.socketOptions) { _, new in new },
            debug: env.mode == "dev"
        )
        self.storage = TeletypeStorage(apiId: config.teletypeExternalId, backend: config.storage)
    }

    public var appealId: String { _appealId }
    public var locale: String { _locale }
    public var strings: TeletypeStrings { _strings }
    public var title: String { _title }

    public var primaryColor: String {
        _primaryColor ?? _config?.backgroundColor ?? DEFAULT_PRIMARY_COLOR
    }

    public var chatBackground: ChatBackground { _chatBackground }

    public var state: TeletypeState {
        TeletypeState(
            ready: _ready,
            opened: _opened,
            connection: _connection,
            messages: _messages,
            operators: _operators,
            channels: _channels,
            config: _config,
            unreadCount: _unreadCount,
            operatorTyping: _operatorTyping,
            draft: _draft,
            title: _title,
            primaryColor: primaryColor,
            chatBackground: _chatBackground,
            locale: _locale,
            strings: _strings
        )
    }

    public func getMessages() -> [Message] { _messages }

    @discardableResult
    public func on(_ name: TeletypeEventName, _ listener: @escaping (TeletypeEvent) -> Void) -> UUID {
        emitter.on(name, listener)
    }

    public func off(_ name: TeletypeEventName, id: UUID) {
        emitter.off(name, id: id)
    }

    public func setLocale(_ locale: String? = nil, translations: TeletypeTranslations? = nil) {
        if let translations {
            self.translations = (self.translations ?? [:]).merging(translations) { _, new in new }
        }
        let resolved = resolveStrings(locale: locale, translations: self.translations)
        _locale = resolved.language
        _strings = resolved.strings
        emitter.emit(.localeChanged(_locale))
    }

    public func setTitle(_ title: String) {
        _title = title
        emitter.emit(.appearanceChanged)
    }

    public func setPrimaryColor(_ color: String?) {
        _primaryColor = color
        emitter.emit(.appearanceChanged)
    }

    public func setChatBackground(_ background: ChatBackground) {
        _chatBackground = background
        emitter.emit(.appearanceChanged)
    }

    public func initialize() async {
        await self.`init`()
    }

    /// Load storage + config + history and prepare the socket. Idempotent.
    public func `init`() async {
        if initialized { return }
        initialized = true

        await storage.hydrate([
            StorageKeys.personId,
            StorageKeys.appealId,
            StorageKeys.config,
            StorageKeys.configSaveTime,
            StorageKeys.pendingMessages,
            StorageKeys.popupState,
            StorageKeys.widgetInteracted,
        ])

        personId = storage.get(StorageKeys.personId, default: "")
        _appealId = storage.get(StorageKeys.appealId, default: "")
        if let raw = storage.getAny(StorageKeys.pendingMessages) {
            if let list = decodeJSON(raw, as: [Message].self) {
                pendingMessages = list.map { msg in
                    var m = msg
                    m.status = .failed
                    return m
                }
            }
        }

        do {
            let response = try await loadConfig()
            applyConfig(response)
        } catch {
            emitter.emit(.error(error))
        }

        if !_appealId.isEmpty {
            await loadHistory()
        }

        _ready = true
        emitter.emit(.ready)
        publishMessages()

        if !_appealId.isEmpty || !pendingMessages.isEmpty {
            ensureConnected()
        }
    }

    private func loadConfig() async throws -> Any {
        let saveTime = storage.get(StorageKeys.configSaveTime, default: 0.0)
        let cached = storage.getAny(StorageKeys.config)
        let expired = Date().timeIntervalSince1970 * 1000 - saveTime > CONFIG_LIFETIME * 1000
        if let cached, !expired {
            return cached
        }
        let fresh = try await api.getConfig()
        if isUsableConfigResponse(fresh) {
            storage.set(StorageKeys.config, fresh)
            storage.set(StorageKeys.configSaveTime, Date().timeIntervalSince1970 * 1000)
        }
        return fresh
    }

    private func applyConfig(_ response: Any) {
        guard isUsableConfigResponse(response),
              let dict = response as? [String: Any],
              let dataRaw = dict["data"],
              let data = decodeJSON(dataRaw, as: WidgetConfigData.self)
                ?? decodeJSON(camelKeys(dataRaw), as: WidgetConfigData.self)
        else { return }
        _config = data
        _operators = (data.operators ?? []).filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        _channels = data.channels ?? []
        if let enabled = data.soundEnabled {
            soundEnabled = enabled
        }
        emitter.emit(.config(data))
    }

    private func loadHistory() async {
        do {
            let res = try await api.getHistory(appealId: _appealId)
            let dict = res as? [String: Any]
            let rawList = dict?["data"]
            var history: [Message] = []
            if let list = rawList as? [Any] {
                history = list.compactMap { message(from: $0) }
            }
            for i in history.indices {
                history[i].unread = history[i].seen == nil ? false : !(history[i].seen ?? false)
                history[i].emojiOnly = isEmojiOnly((history[i].message ?? "").trimmingCharacters(in: .whitespaces))
            }
            let merged = history.reversed() + pendingMessages
            setMessages(Array(merged), fromHistory: true)
        } catch {
            emitter.emit(.error(error))
        }
    }

    public func ensureConnected() {
        socket.ensureCreated()
        if !listenersBound {
            bindSocket()
            listenersBound = true
        }
        socket.connect()
    }

    public func waitUntilConnected(timeoutMs: Int = 15000) async throws {
        if _connection == .connected { return }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var settled = false
            var token: UUID?
            let timeout = DispatchWorkItem {
                guard !settled else { return }
                settled = true
                if let token { self.emitter.off(.connectionChanged, id: token) }
                cont.resume(throwing: TeletypeError.socketTimeout)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: timeout)
            token = on(.connectionChanged) { event in
                guard case .connectionChanged(let state) = event, state == .connected else { return }
                guard !settled else { return }
                settled = true
                timeout.cancel()
                if let token { self.emitter.off(.connectionChanged, id: token) }
                cont.resume()
            }
            ensureConnected()
            if _connection == .connected, !settled {
                settled = true
                timeout.cancel()
                if let token { self.emitter.off(.connectionChanged, id: token) }
                cont.resume()
            }
        }
    }

    private func bindSocket() {
        socket.off()
        let debug = env.mode == "dev"

        socket.onConnect { [weak self] in
            guard let self else { return }
            if debug { print("[teletype][ws] • connect") }
            self._connection = .connected
            self.emitter.emit(.connectionChanged(.connected))
            self.handleConnect()
        }
        socket.onDisconnect { [weak self] in
            guard let self else { return }
            if debug { print("[teletype][ws] • disconnect") }
            self._connection = .disconnected
            self.emitter.emit(.connectionChanged(.disconnected))
        }
        socket.on(WsEvent.initDataToPerson) { [weak self] raw in
            guard let self else { return }
            let data = (camelKeys(raw) as? [String: Any]) ?? (raw as? [String: Any]) ?? [:]
            if let pid = stringVal(data["personId"]) ?? stringVal((raw as? [String: Any])?["person_id"]), !pid.isEmpty {
                self.personId = pid
                self.storage.set(StorageKeys.personId, pid)
                if let personData = self.personData {
                    self.setUserData(personData)
                }
            }
            if let aid = stringVal(data["appealId"]) ?? stringVal((raw as? [String: Any])?["appeal_id"]), !aid.isEmpty {
                if self._appealId.isEmpty, !self.messagesInPending.isEmpty {
                    self.messagesInPending.forEach { self.emitMessage($0) }
                    self.messagesInPending = []
                }
                self.setAppealId(aid)
            }
        }
        socket.on(WsEvent.messageFromClient) { [weak self] raw in
            guard let self, var data = message(from: raw) else { return }
            self.handleIncomingMessage(&data)
            self.emitter.emit(.messageReceived(data))
        }
        socket.on(WsEvent.operatorTyping) { [weak self] _ in
            self?.setOperatorTyping(true)
        }
        socket.on(WsEvent.operatorStopTyping) { [weak self] _ in
            self?.setOperatorTyping(false)
        }
        socket.on(WsEvent.operatorStatusChange) { [weak self] raw in
            guard let self else { return }
            let data = raw as? [String: Any] ?? [:]
            let clientId = stringVal(data["client_id"]) ?? stringVal(data["clientId"])
            let online = boolVal(data["online"]) ?? false
            if let idx = self._operators.firstIndex(where: { $0.id == clientId }) {
                self._operators[idx].isOnline = online
            }
        }
        socket.on(WsEvent.appealStatusChange) { [weak self] raw in
            guard let self else { return }
            let data = raw as? [String: Any] ?? [:]
            let status = intVal(data["status"]) ?? 0
            if status == APPEAL_STATUS_CLOSED, !self.banned {
                self.createRatingForm()
                self.emitter.emit(.dialogClosed(DialogClosedPayload(status: status)))
            }
        }
        socket.on(WsEvent.received) { [weak self] raw in
            self?.handleReceived(raw as? [String: Any] ?? [:])
        }
        socket.on(WsEvent.seen) { [weak self] raw in
            let data = raw as? [String: Any] ?? [:]
            self?.handleSeen(data)
        }
    }

    private func handleConnect() {
        if !personId.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                self.socket.emit(WsEvent.authPerson, snakeKeys([
                    "widgetId": self.externalId,
                    "id": self.personId,
                ]))
            }
        }
    }

    private func handleIncomingMessage(_ data: inout Message, unread: Bool = true) {
        setOperatorTyping(false)
        if data.date == nil { data.date = .now() }
        data.unread = unread && !_opened
        data.isOwn = false
        data.emojiOnly = data.emojiOnly ?? isEmojiOnly((data.message ?? "").trimmingCharacters(in: .whitespaces))
        data.message = data.originalMessage ?? data.message
        _messages.append(data)
        setMessages(_messages)
        if let aid = data.appealId, aid != _appealId {
            setAppealId(aid)
            emitter.emit(.appealStarted(data))
        }
    }

    private func handleReceived(_ data: [String: Any]) {
        banned = boolVal(data["banned"]) ?? false
        let camel = (camelKeys(data) as? [String: Any]) ?? data
        guard let tempId = stringVal(camel["tempId"]) ?? stringVal(data["temp_id"]) else { return }
        let newId = stringVal(camel["id"]) ?? stringVal(data["id"])
        let appealId = stringVal(camel["appealId"]) ?? stringVal(data["appeal_id"])

        receivedTimeouts[tempId]?.cancel()
        receivedTimeouts[tempId] = nil

        if let appealId, _appealId != appealId {
            setAppealId(appealId)
        }

        if let idx = _messages.firstIndex(where: { !($0.fromInvite ?? false) && $0.tempId == tempId }) {
            _messages[idx].id = newId
            if let newId { _messages[idx].tempId = newId }
            _messages[idx].status = .sent
            _messages[idx].appealId = _appealId
            _messages[idx].date = .now()
        }
        removePending(tempId)
        setMessages(_messages)
    }

    private func handleSeen(_ data: [String: Any]) {
        let ids = (data["ids"] as? [Any])?.compactMap { stringVal($0) } ?? []
        let appeal = stringVal(data["appeal_id"]) ?? stringVal(data["appealId"])
        _messages = _messages.map { msg in
            var m = msg
            let byId = ids.contains(m.id ?? "") || ids.contains(m.tempId)
            let byAppeal = ids.isEmpty && appeal != nil && m.appealId == appeal
            if byId || byAppeal {
                m.seen = true
                m.unread = false
            }
            return m
        }
        setMessages(_messages)
    }

    public func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var message = Message(
            tempId: guid(),
            message: trimmed,
            isOwn: true,
            date: .now(),
            messageType: .text,
            emojiOnly: isEmojiOnly(trimmed)
        )
        handleSendMessage(&message)
    }

    public func sendAttachment(_ attachment: UploadedAttachment) {
        var message = Message(
            tempId: guid(),
            attachment: attachment.attachment,
            attachmentUrl: attachment.attachmentUrl,
            attachmentId: attachment.attachmentId,
            isOwn: true,
            date: .now(),
            messageType: attachment.type == .text ? .attachment : attachment.type,
            width: attachment.width,
            height: attachment.height,
            size: attachment.size
        )
        handleSendMessage(&message, save: false)
    }

    public func uploadAttachment(_ file: LocalFile, onProgress: UploadProgressHandler? = nil) async throws -> UploadedAttachment {
        if let size = file.size, size > MAX_UPLOAD_BYTES {
            let error = TeletypeError.fileSizeError
            emitter.emit(.error(error))
            throw error
        }
        if !isAllowedUploadFile(file) {
            let error = TeletypeError.fileFormatNotAllowed
            emitter.emit(.error(error))
            throw error
        }
        let res: UploadFileResponse
        do {
            res = try await api.uploadFile(file, onProgress: onProgress)
        } catch {
            emitter.emit(.error(error))
            throw error
        }
        if res.success == false {
            let detail = res.error?.joined ?? "uploadFailed"
            let error = NSError(domain: "TeletypeSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: detail])
            emitter.emit(.error(error))
            throw error
        }
        let data = res.data
        let attachmentId = data?.attachmentId ?? ""
        let attachmentUrl = data?.attachment ?? data?.attachmentUrl ?? file.uri
        return UploadedAttachment(
            attachment: file.name,
            attachmentId: attachmentId,
            attachmentUrl: attachmentUrl,
            type: messageTypeFromFile(file),
            width: file.width,
            height: file.height,
            size: file.size
        )
    }

    public func uploadFile(_ file: LocalFile) async throws {
        if let size = file.size, size > MAX_UPLOAD_BYTES {
            addAttachmentError(file, "fileSizeError")
            let error = TeletypeError.fileSizeError
            emitter.emit(.error(error))
            throw error
        }
        if !isAllowedUploadFile(file) {
            addAttachmentError(file, "fileFormatNotAllowed")
            let error = TeletypeError.fileFormatNotAllowed
            emitter.emit(.error(error))
            throw error
        }

        let localId = "\(file.name)_\(file.size ?? 0)_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8))"
        var preview = Message(
            tempId: guid(),
            message: "",
            attachment: file.name,
            attachmentUrl: file.uri,
            attachmentPreviewUrl: file.previewUri ?? (messageTypeFromFile(file) == .image ? file.uri : nil),
            attachmentId: localId,
            isOwn: true,
            date: .now(),
            messageType: messageTypeFromFile(file),
            progress: 0,
            width: file.width,
            height: file.height,
            status: .sending,
            size: file.size
        )
        _messages.append(preview)
        setMessages(_messages)

        do {
            let uploaded = try await uploadAttachment(file) { [weak self] pct in
                self?.patchAttachment(localId, MessagePatch(progress: pct))
            }
            patchAttachment(localId, MessagePatch(
                attachmentId: uploaded.attachmentId,
                attachmentUrl: uploaded.attachmentUrl,
                progress: 100
            ))
            sendAttachment(uploaded)
        } catch {
            let code = (error as? TeletypeError)?.rawValue ?? error.localizedDescription
            patchAttachment(localId, MessagePatch(progress: 100, errorMessage: code, status: .failed))
            throw error
        }
    }

    private func addAttachmentError(_ file: LocalFile, _ errorMessage: String) {
        let message = Message(
            tempId: guid(),
            message: "",
            attachment: file.name,
            attachmentPreviewUrl: file.uri,
            attachmentId: "\(file.name)\(file.size ?? 0)",
            isOwn: true,
            date: .now(),
            messageType: messageTypeFromFile(file),
            progress: 100,
            errorMessage: errorMessage,
            status: .failed,
            size: file.size
        )
        _messages.append(message)
        setMessages(_messages)
    }

    private struct MessagePatch {
        var attachmentId: String?
        var attachmentUrl: String?
        var progress: Int?
        var errorMessage: String?
        var status: MessageStatus?
    }

    private func patchAttachment(_ attachmentId: String, _ patch: MessagePatch) {
        _messages = _messages.map { msg in
            guard msg.attachmentId == attachmentId else { return msg }
            var m = msg
            if let v = patch.attachmentId { m.attachmentId = v }
            if let v = patch.attachmentUrl { m.attachmentUrl = v }
            if let v = patch.progress { m.progress = v }
            if let v = patch.errorMessage { m.errorMessage = v }
            if let v = patch.status { m.status = v }
            return m
        }
        setMessages(_messages)
    }

    private func handleSendMessage(_ message: inout Message, save: Bool = true) {
        ensureConnected()
        if !messageWasSent {
            messageWasSent = true
            Task { await sendPersonData() }
        }
        message.status = banned ? .sent : .sending
        message.tempId = guid()

        let userMessages = _messages.filter {
            ($0.isOwn ?? false)
                && $0.errorMessage == nil
                && $0.attachment == nil
                && $0.status != .failed
                && $0.tempId != message.tempId
        }
        let attachmentMessages = _messages.filter {
            ($0.isOwn ?? false)
                && $0.errorMessage == nil
                && $0.attachment != nil
                && $0.status != .failed
                && $0.tempId != message.tempId
        }
        let last = _messages.last
        let hasRating = last?.formType == .rating

        let isFirstMessage =
            _appealId.isEmpty
            && (
                (userMessages.isEmpty && attachmentMessages.isEmpty)
                || hasRating
                || (
                    message.attachment != nil
                    && !attachmentMessages.isEmpty
                    && message.attachment == attachmentMessages[0].attachment
                )
            )

        if let type = message.messageType, type != .text, let attachmentId = message.attachmentId {
            if let previewIdx = _messages.firstIndex(where: { $0.attachmentId == attachmentId }) {
                _messages[previewIdx].tempId = message.tempId
            }
        }

        if save {
            _messages.append(message)
        }
        setMessages(_messages)
        pushPending(message)

        if isFirstMessage || !_appealId.isEmpty {
            emitMessage(message)
        } else {
            messagesInPending.append(message)
        }

        if isFirstMessage {
            emitter.emit(.dialogStarted(message))
        }
        emitter.emit(.messageSent(message))
    }

    private func emitMessage(_ message: Message) {
        ensureConnected()
        let personId = self.personId.isEmpty ? storage.get(StorageKeys.personId, default: "") : self.personId
        var payload: [String: Any] = [
            "external_id": externalId,
            "message": messageAsDict(message),
            "person_id": personId,
            "appeal_id": _appealId,
        ]
        socket.emit(WsEvent.messageFromPerson, snakeKeys(payload))
        armReceivedTimeout(message)
    }

    private func armReceivedTimeout(_ message: Message) {
        guard !banned, !message.tempId.isEmpty else { return }
        receivedTimeouts[message.tempId]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task {
                try? await self.api.reportError([
                    "error": "Did not receive \"received\" event from websockets",
                    "widgetId": self.externalId,
                    "appealId": self._appealId,
                    "personId": self.personId,
                ])
            }
            self._messages = self._messages.map { msg in
                guard msg.tempId == message.tempId else { return msg }
                var m = msg
                m.status = .failed
                return m
            }
            self.setMessages(self._messages)
        }
        receivedTimeouts[message.tempId] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + RECEIVED_ACK_TIMEOUT, execute: work)
    }

    public func retryMessage(_ tempId: String) {
        guard var message = _messages.first(where: { $0.tempId == tempId }) else { return }
        message.status = .sending
        message.errorMessage = nil
        if let idx = _messages.firstIndex(where: { $0.tempId == tempId }) {
            _messages[idx] = message
            setMessages(_messages)
        }
        handleSendMessage(&message, save: false)
    }

    public func setPersonData(_ info: AdditionalPersonInfo) {
        personAdditionalInfo = AdditionalPersonInfo(
            name: info.name ?? personAdditionalInfo.name,
            email: info.email ?? personAdditionalInfo.email,
            avatar: info.avatar ?? personAdditionalInfo.avatar,
            phone: info.phone ?? personAdditionalInfo.phone,
            payload: info.payload ?? personAdditionalInfo.payload
        )
        if !personId.isEmpty {
            Task { await sendPersonData() }
        }
    }

    public func greetingMessages(_ messages: [String], fromBot: Bool = true) {
        guard !greetingSent else { return }
        greetingSent = true
        let operatorAvatar = fromBot ? nil : _operators.first?.avatar
        for text in messages {
            var incoming = Message(
                tempId: guid(),
                message: text,
                avatar: operatorAvatar,
                from: MessageFrom(avatar: operatorAvatar),
                serviceMessage: true
            )
            handleIncomingMessage(&incoming, unread: false)
        }
    }

    public func setMessage(_ text: String) {
        _draft = text
        emitter.emit(.draftChanged(text))
    }

    public func show() { setOpened(true) }
    public func hide() { setOpened(false) }
    public func toggle() { setOpened(!_opened) }

    private func setOpened(_ value: Bool) {
        guard _opened != value else { return }
        _opened = value
        storage.set(StorageKeys.popupState, value)
        emitter.emit(.openChanged(value))
        if value {
            _messages = _messages.map { msg in
                guard !(msg.isOwn ?? false), msg.unread == true else { return msg }
                var m = msg
                m.unread = false
                m.seen = true
                return m
            }
            setMessages(_messages)
            ensureConnected()
            storage.set(StorageKeys.widgetInteracted, true)
            Task {
                let ip = (try? await api.getIp()) ?? ""
                socket.emit(WsEvent.personOpenedWidget, snakeKeys([
                    "channel_id": externalId,
                    "ipAddress": ip,
                    "personId": personId.isEmpty ? "" : personId,
                    "appealId": _appealId,
                    "data": [:] as [String: Any],
                ]))
            }
            markSeen()
            emitter.emit(.opened)
        } else {
            emitter.emit(.closed)
        }
    }

    private func sendPersonData() async {
        let ip = (try? await api.getIp()) ?? ""
        var info: [String: Any] = device
        info["ipAddress"] = ip
        for (k, v) in personAdditionalInfo.asDictionary() { info[k] = v }
        let personData: [String: Any] = [
            "widgetId": externalId,
            "personId": personId,
            "data": info,
        ]
        socket.emit(WsEvent.setPersonData, snakeKeys(personData))
    }

    private func setUserData(_ data: [String: Any]) {
        if !personId.isEmpty {
            socket.emit(WsEvent.setUserData, snakeKeys(["personId": personId, "data": data]))
        } else {
            personData = data
        }
    }

    public func rateAppeal(_ value: ConversationRating, formTempId: String? = nil) {
        socket.emit(WsEvent.personRateAppeal, snakeKeys([
            "appealId": _appealId,
            "data": ["value": value.rawValue],
        ]))
        if let formTempId, let idx = _messages.firstIndex(where: { $0.tempId == formTempId }) {
            _messages[idx].ratingValue = value
            setMessages(_messages)
        }
        emitter.emit(.dialogRated(DialogRatedPayload(id: formTempId ?? "", formValue: value.rawValue)))
    }

    public func clickChannel(_ channel: ChannelMessenger) {
        emitter.emit(.channelClicked(channel))
        Task {
            let ip = (try? await api.getIp()) ?? ""
            socket.emit(WsEvent.personClickWidgetChannel, snakeKeys([
                "widgetId": externalId,
                "personId": personId.isEmpty ? "" : personId,
                "appealId": _appealId,
                "widgetChannelId": channel.id ?? "",
                "data": ["value": channel.name, "ipAddress": ip],
            ]))
        }
    }

    public func markSeen() {
        if !_appealId.isEmpty {
            socket.emit(WsEvent.seen, snakeKeys(["appealId": _appealId]))
        }
    }

    public func startTyping(_ message: String = "") {
        if socket.connected {
            socket.emit(WsEvent.personTyping, ["appealId": _appealId, "message": message])
        }
    }

    public func stopTyping() {
        if socket.connected {
            socket.emit(WsEvent.personStopTyping, ["appealId": _appealId])
        }
    }

    public func notifyLocationChange(_ location: String) {
        Task { try? await api.notifyLocationChange(location) }
    }

    private func createRatingForm() {
        var incoming = Message(tempId: guid(), formType: .rating, serviceMessage: true)
        handleIncomingMessage(&incoming, unread: false)
    }

    private func setAppealId(_ appealId: String) {
        _appealId = appealId
        storage.set(StorageKeys.appealId, appealId)
    }

    private func setOperatorTyping(_ value: Bool) {
        if _operatorTyping != value {
            _operatorTyping = value
            emitter.emit(.operatorTyping(value))
        }
    }

    private func setMessages(_ messages: [Message], fromHistory: Bool = false) {
        _ = fromHistory
        let sent = uniqueBy(messages.filter { ($0.id != nil || !($0.isOwn ?? false)) && !($0.serviceMessage ?? false) }) {
            $0.id ?? $0.tempId
        }
        let pending = uniqueBy(messages.filter { $0.id == nil && $0.formType != .contactButtons }) {
            $0.tempId
        }
        var merged = sent + pending
        merged.sort { a, b in
            let at = parseMillis(a.date?.date) ?? 0
            let bt = parseMillis(b.date?.date) ?? 0
            return at < bt
        }
        var unread = 0
        for m in merged {
            if !(m.isOwn ?? false), m.unread == true { unread += 1 }
        }
        _messages = merged
        setUnreadCount(unread)
        publishMessages()
    }

    private func setUnreadCount(_ count: Int) {
        if _unreadCount != count {
            _unreadCount = count
            emitter.emit(.unreadCountChanged(count))
        }
    }

    private func publishMessages() {
        emitter.emit(.messagesChanged(_messages))
    }

    private func pushPending(_ message: Message) {
        pendingMessages.append(message)
        savePending()
    }

    private func removePending(_ tempId: String) {
        if let idx = pendingMessages.firstIndex(where: { !($0.fromInvite ?? false) && $0.tempId == tempId }) {
            pendingMessages.remove(at: idx)
            savePending()
        }
    }

    private func savePending() {
        let textOnly = pendingMessages.filter { $0.messageType == .text }
        if let data = try? JSONEncoder.teletype.encode(textOnly),
           let obj = try? JSONSerialization.jsonObject(with: data)
        {
            storage.set(StorageKeys.pendingMessages, obj)
        }
    }

    public func destroy() {
        receivedTimeouts.values.forEach { $0.cancel() }
        receivedTimeouts = [:]
        socket.off()
        socket.disconnect()
        emitter.removeAllListeners()
        initialized = false
        listenersBound = false
    }
}

private func isUsableConfigResponse(_ response: Any?) -> Bool {
    guard let dict = response as? [String: Any] else { return false }
    if let success = boolVal(dict["success"]), success == false { return false }
    guard let data = dict["data"] as? [String: Any], !(data is [Any]) else { return false }
    let projectId = stringVal(data["projectId"]) ?? stringVal(data["project_id"])
    let name = stringVal(data["name"])
    return !(projectId ?? "").isEmpty || !(name ?? "").isEmpty
}

private func uniqueBy(_ arr: [Message], key: (Message) -> String) -> [Message] {
    var seen = Set<String>()
    var out: [Message] = []
    for item in arr {
        let k = key(item)
        if !seen.contains(k) {
            seen.insert(k)
            out.append(item)
        }
    }
    return out
}

private func parseMillis(_ iso: String?) -> Double? {
    guard let iso else { return nil }
    if let d = ISO8601DateFormatter.teletype.date(from: iso) { return d.timeIntervalSince1970 }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    if let d = f.date(from: iso) { return d.timeIntervalSince1970 }
    return nil
}
