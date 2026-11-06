# Teletype iOS SDK

Нативный **Swift SDK** для встраивания онлайн-чата [Teletype](https://teletype.app) в приложения iOS.

SDK использует тот же backend-протокол, что и **веб-виджет** Teletype (`/widget`) — REST API + `socket.io` (v2) — но рендерит **нативный SwiftUI**-интерфейс (без WebView). Публичный API повторяет методы веб-виджета `_teletypeWidget.*` и [React Native SDK](https://github.com/teletype/teletype-mobile-sdk-react-native).

> 🇬🇧 English docs: [README.md](./README.md)

---

## Возможности

- Сообщения в реальном времени по `socket.io` v2 (индикатор набора, статусы «доставлено» / «прочитано»)
- Готовые `ChatWidget` (плавающая кнопка) и `ChatScreen` как обычный SwiftUI-экран
- Headless-ядро (`TeletypeClient`) для полностью кастомного UI
- История, офлайн-очередь, авто-переподключение
- Форма оценки оператора, сервисные сообщения, вложения (фото, видео, аудио, файлы)
- Бейдж непрочитанных, события как у веб-`teletype.*`
- Сохранение сессии (person id + appeal id) в `UserDefaults`
- Русский и английский; по умолчанию язык устройства

---

## Требования

- iOS 16+
- Xcode 15+ (Swift 5.9+)
- Swift Package Manager

Зависимость [Socket.IO-Client-Swift](https://github.com/socketio/socket.io-client-swift) подтягивается автоматически и настроена на **протокол socket.io v2**.

---

## Установка

В Xcode: **File → Add Package Dependencies…** и укажите этот репозиторий. Или в `Package.swift`:

```swift
.package(path: "../teletype-sdk-ios")
```

Подключите продукт `TeletypeSDK`.

---

## Быстрый старт

```swift
import TeletypeSDK

let client = TeletypeClient(TeletypeConfig(
    teletypeExternalId: "ВАШ_EXTERNAL_ID",
    mode: .dev,
    title: "Онлайн чат",
    primaryColor: "#0084ff"
))
await client.initialize()

let controller = TeletypeController(client: client)
```

`teletypeExternalId` — external id виджета из скрипта установки канала в кабинете Teletype.

---

## Кластеры: `dev` и `prod`

| `mode` | apiUrl | wsUrl |
| --- | --- | --- |
| `dev` | `https://api.teletypeapp.com/` | `https://websocket-widget.teletypeapp.com` |
| `prod` (по умолчанию) | `https://api.teletype.app/` | `https://websocket-widget.teletype.app/` |

---

## Пример

Демо-приложение в [`example/`](./example) повторяет сценарий React Native demo: ввод external id, оформление, переключение языка, вложения, очистка кэша.

```bash
cd example
xcodegen generate
open TeletypeSDKExample.xcodeproj
```

---

## Лицензия

MIT
