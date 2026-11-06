import XCTest
import UIKit

final class TeletypeSDKExampleUITests: XCTestCase {
    // A real channel id is not kept in the repo. Pass one via the
    // TELETYPE_TEST_EXTERNAL_ID env var (point it to a test/demo channel):
    //   TELETYPE_TEST_EXTERNAL_ID=<id> xcodebuild test -project example/TeletypeSDKExample.xcodeproj -scheme TeletypeSDKExample
    private let snippetTemplate = #"""
    <script>if(!window._teletypeWidget){window._teletypeWidget = window._teletypeWidget || {};!function(){var t = document.getElementsByTagName("app-teletype-root");if (t.length > 0 && _teletypeWidget.init)return;var d = new Date().getTime();var n = document.createElement("script"),c = document.getElementsByTagName("script")[0];n.id = "teletype-widget-embed",n.src = "https://widget.teletypeapp.com/init.js?_=" + d,n.async = !0,n.setAttribute("data-embed-version", "0.1");c.parentNode.insertBefore(n, c);}();document.addEventListener("teletype.ready", function(){console.log("Teletype ready")});window.teletypeExternalId = "%@";}</script>
    """#

    private func snippet() throws -> String {
        let id = ProcessInfo.processInfo.environment["TELETYPE_TEST_EXTERNAL_ID"] ?? ""
        try XCTSkipIf(
            id.isEmpty,
            "Set TELETYPE_TEST_EXTERNAL_ID to the external id of a test Teletype channel to run these UI tests"
        )
        return String(format: snippetTemplate, id)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testButtonSelectDropdowns() throws {
        let app = XCUIApplication()
        app.launch()

        try connectIfNeeded(app)
        XCTAssertTrue(app.buttons["openChatButton"].waitForExistence(timeout: 40))

        if app.buttons["buttonPositionSelect"].isHittable == false {
            app.swipeUp()
        }
        saveScreenshot(app, name: "50-select-fields")

        tapIfExists(app.buttons["buttonPositionSelect"])
        let leftOption = app.descendants(matching: .any)["selectOption-Внизу слева"]
        let leftEn = app.descendants(matching: .any)["selectOption-Bottom left"]
        XCTAssertTrue(
            leftOption.waitForExistence(timeout: 3) || leftEn.waitForExistence(timeout: 1),
            "Position modal should show options"
        )
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "51-position-modal")
        if leftOption.exists {
            leftOption.tap()
        } else {
            leftEn.tap()
        }
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "52-position-left")

        tapIfExists(app.buttons["buttonScaleSelect"])
        XCTAssertTrue(app.descendants(matching: .any)["selectOption-70%"].waitForExistence(timeout: 3), "Scale modal should show options")
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "53-scale-modal")
        app.descendants(matching: .any)["selectOption-70%"].tap()
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "54-scale-70")
    }

    func testSettingsAndMedia() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-media"]
        app.launch()

        try connectIfNeeded(app)
        let openChat = app.buttons["openChatButton"]
        XCTAssertTrue(openChat.waitForExistence(timeout: 40))
        saveScreenshot(app, name: "10-home")

        tapIfExists(app.buttons["colorSwatch-#34c759"])
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "11-color-green")

        tapIfExists(app.buttons["colorSwatch-#ff3b30"])
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "12-color-red")

        if app.buttons["background-doodle"].isHittable == false {
            app.swipeUp()
        }
        tapIfExists(app.buttons["background-doodle"])
        Thread.sleep(forTimeInterval: 0.3)

        tapIfExists(app.buttons["buttonPositionSelect"])
        let left = app.descendants(matching: .any)["selectOption-Внизу слева"]
        let leftEn = app.descendants(matching: .any)["selectOption-Bottom left"]
        XCTAssertTrue(left.waitForExistence(timeout: 3) || leftEn.waitForExistence(timeout: 1))
        Thread.sleep(forTimeInterval: 0.3)
        saveScreenshot(app, name: "13-position-modal")
        if left.exists { left.tap() } else { leftEn.tap() }
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "13-position-left")

        tapIfExists(app.buttons["buttonScaleSelect"])
        XCTAssertTrue(app.descendants(matching: .any)["selectOption-70%"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.3)
        saveScreenshot(app, name: "14-scale-modal")
        app.descendants(matching: .any)["selectOption-70%"].tap()
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "14-scale-70")

        let lang = app.buttons["languageButton"]
        if lang.exists { lang.tap() }
        Thread.sleep(forTimeInterval: 0.4)
        saveScreenshot(app, name: "15-language-switched")

        openChat.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chatScreen"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 0.8)
        saveScreenshot(app, name: "16-chat-red-doodle")

        sendAndViewImage(app)
        sendAndViewVideo(app)
        sendAndViewFile(app)
    }

    private func sendAndViewImage(_ app: XCUIApplication) {
        tapAttach(app)
        saveScreenshot(app, name: "20-send-image")
        tapSendOnSheet(app)
        XCTAssertTrue(app.descendants(matching: .any)["mediaImage"].waitForExistence(timeout: 30), "Image bubble should appear after upload")
        Thread.sleep(forTimeInterval: 1.2)
        saveScreenshot(app, name: "21-image-in-chat")
        app.descendants(matching: .any)["mediaImage"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["mediaViewer"].waitForExistence(timeout: 6)
            || app.buttons["mediaCloseButton"].waitForExistence(timeout: 6),
            "Image viewer should open"
        )
        Thread.sleep(forTimeInterval: 0.6)
        saveScreenshot(app, name: "22-image-viewer")
        if app.buttons["mediaCloseButton"].exists {
            app.buttons["mediaCloseButton"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.buttons["Закрыть"].exists {
            app.buttons["Закрыть"].tap()
        }
        Thread.sleep(forTimeInterval: 0.4)
    }

    private func sendAndViewVideo(_ app: XCUIApplication) {
        tapAttach(app)
        saveScreenshot(app, name: "30-send-video")
        tapSendOnSheet(app)
        XCTAssertTrue(app.descendants(matching: .any)["mediaVideo"].waitForExistence(timeout: 30), "Video bubble should appear after upload")
        Thread.sleep(forTimeInterval: 1.2)
        saveScreenshot(app, name: "31-video-in-chat")
        app.descendants(matching: .any)["mediaVideo"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["mediaVideoPlayer"].waitForExistence(timeout: 8)
            || app.buttons["mediaCloseButton"].waitForExistence(timeout: 8),
            "Video player should open"
        )
        Thread.sleep(forTimeInterval: 2.5)
        saveScreenshot(app, name: "32-video-player")
        if app.buttons["mediaCloseButton"].exists {
            app.buttons["mediaCloseButton"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.buttons["Закрыть"].exists {
            app.buttons["Закрыть"].tap()
        }
        Thread.sleep(forTimeInterval: 0.4)
    }

    private func sendAndViewFile(_ app: XCUIApplication) {
        tapAttach(app)
        saveScreenshot(app, name: "40-send-file")
        tapSendOnSheet(app)
        XCTAssertTrue(app.descendants(matching: .any)["mediaFile"].waitForExistence(timeout: 30), "File bubble should appear after upload")
        Thread.sleep(forTimeInterval: 1.0)
        saveScreenshot(app, name: "41-file-in-chat")
        app.descendants(matching: .any)["mediaFile"].tap()
        Thread.sleep(forTimeInterval: 2.0)
        saveScreenshot(app, name: "42-file-preview")
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else if app.buttons["Готово"].exists {
            app.buttons["Готово"].tap()
        } else {
            app.swipeDown()
        }
    }

    private func tapSendOnSheet(_ app: XCUIApplication) {
        let send = app.buttons["sendAttachmentButton"]
        if send.waitForExistence(timeout: 6) {
            send.tap()
            return
        }
        let labeled = app.buttons["Send"].exists ? app.buttons["Send"] : app.buttons["Отправить"]
        XCTAssertTrue(labeled.waitForExistence(timeout: 4), "Send button should appear on the attachment sheet")
        labeled.tap()
    }

    private func tapAttach(_ app: XCUIApplication) {
        let attach = app.descendants(matching: .any)["attachButton"]
        if !attach.waitForExistence(timeout: 6) {
            let paperclip = app.buttons["Attach"]
            if paperclip.waitForExistence(timeout: 2) {
                paperclip.tap()
                return
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.93)).tap()
            return
        }
        attach.tap()
    }

    private func connectIfNeeded(_ app: XCUIApplication) throws {
        let field = app.textViews["externalIdField"]
        let connect = app.buttons["connectButton"]
        let openChat = app.buttons["openChatButton"]
        if openChat.waitForExistence(timeout: 8) { return }
        if field.waitForExistence(timeout: 8) {
            field.tap()
            field.typeText(try snippet())
            XCTAssertTrue(connect.waitForExistence(timeout: 5))
            connect.tap()
        }
    }

    private func tapIfExists(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 2) {
            if element.isHittable {
                element.tap()
            } else {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
        }
    }

    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? FileManager.default.createDirectory(
            atPath: "/tmp/teletype-sdk-ui",
            withIntermediateDirectories: true
        )
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/teletype-sdk-ui/\(name).png"))
    }
}
