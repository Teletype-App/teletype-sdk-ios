import SwiftUI
import TeletypeSDK

@main
struct TeletypeSDKExampleApp: App {
    init() {
        UITestMedia.prepareIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
