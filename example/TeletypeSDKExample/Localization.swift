import Foundation
import TeletypeSDK

struct DemoStrings {
    var screenTitle: String
    var screenSubtitle: String
    var languageButton: String
    var openChat: String
    var chatTitle: String
    var clearCache: String
    var setupTitle: String
    var setupHint: String
    var externalIdPlaceholder: String
    var connect: String
    var connecting: String
    var parsedId: String
    var invalidExternalId: String
    var snippetMissingId: String
    var invalidChannel: String
    var connectionFailed: String
    var chatTitleLabel: String
    var chatTitlePlaceholder: String
    var chatColorLabel: String
    var chatBackgroundLabel: String
    var buttonPositionLabel: String
    var buttonPositionRight: String
    var buttonPositionLeft: String
    var buttonScaleLabel: String
}

let demoTranslations: TeletypeTranslations = [
    "ru": PartialTeletypeStrings(["statusOffline": "Мы онлайн — ответим сразу"]),
]

func getDemoStrings(_ locale: String) -> DemoStrings {
    let lang = String(locale.prefix(2)).lowercased()
    return lang == "ru" ? .ru : .en
}

extension DemoStrings {
    static let en = DemoStrings(
        screenTitle: "Teletype iOS SDK",
        screenSubtitle: "Native Swift. Unread: {unread}",
        languageButton: "Language: {lang} (tap to switch)",
        openChat: "Open chat",
        chatTitle: "Online chat",
        clearCache: "Clear chat cache",
        setupTitle: "Connect a channel",
        setupHint: "Paste your external id or the whole Teletype install <script> snippet.",
        externalIdPlaceholder: "External id or <script> snippet",
        connect: "Connect",
        connecting: "Connecting…",
        parsedId: "Channel id: {id}",
        invalidExternalId: "This does not look like a Teletype external id. Paste the id or the whole install <script>.",
        snippetMissingId: "Could not find teletypeExternalId in that snippet. Copy the full install script from the dashboard.",
        invalidChannel: "No Teletype channel found for this id.",
        connectionFailed: "Could not reach Teletype. Check the network and try again.",
        chatTitleLabel: "Chat title",
        chatTitlePlaceholder: "Online chat",
        chatColorLabel: "Button and chat color",
        chatBackgroundLabel: "Chat background",
        buttonPositionLabel: "Button position",
        buttonPositionRight: "Bottom right",
        buttonPositionLeft: "Bottom left",
        buttonScaleLabel: "Button scale"
    )

    static let ru = DemoStrings(
        screenTitle: "Teletype iOS SDK",
        screenSubtitle: "Нативный Swift. Непрочитанных: {unread}",
        languageButton: "Язык: {lang} (нажмите, чтобы сменить)",
        openChat: "Открыть чат",
        chatTitle: "Онлайн чат",
        clearCache: "Очистить кэш чата",
        setupTitle: "Подключить канал",
        setupHint: "Вставьте external id или весь <script> сниппет установки Teletype.",
        externalIdPlaceholder: "External id или <script> сниппет",
        connect: "Подключить",
        connecting: "Подключение…",
        parsedId: "Id канала: {id}",
        invalidExternalId: "Это не похоже на Teletype external id. Вставьте id или весь установочный <script>.",
        snippetMissingId: "В сниппете нет teletypeExternalId. Скопируйте полный скрипт установки из кабинета.",
        invalidChannel: "Канал Teletype с таким id не найден.",
        connectionFailed: "Не удалось связаться с Teletype. Проверьте сеть и попробуйте ещё раз.",
        chatTitleLabel: "Название чата",
        chatTitlePlaceholder: "Онлайн чат",
        chatColorLabel: "Цвет кнопки и чата",
        chatBackgroundLabel: "Фон чата",
        buttonPositionLabel: "Расположение кнопки",
        buttonPositionRight: "Внизу справа",
        buttonPositionLeft: "Внизу слева",
        buttonScaleLabel: "Масштаб кнопки"
    )
}

enum DemoStorageKey {
    static let externalId = "teletype_demo_external_id"
    static let title = "teletype_demo_chat_title"
    static let color = "teletype_demo_primary_color"
    static let background = "teletype_demo_chat_background"
    static let buttonPos = "teletype_demo_button_position"
    static let buttonScale = "teletype_demo_button_scale"
}
