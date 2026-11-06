import SwiftUI
import UIKit

public struct TeletypeTheme: Equatable {
    public var primaryColor: Color
    public var onPrimaryColor: Color
    public var backgroundColor: Color
    public var headerTextColor: Color
    public var headerSubTextColor: Color
    public var ownBubbleColor: Color
    public var ownTextColor: Color
    public var operatorBubbleColor: Color
    public var operatorTextColor: Color
    public var mutedColor: Color
    public var borderColor: Color
    public var inputBackground: Color
    public var inputTextColor: Color
    public var badgeColor: Color
    public var badgeTextColor: Color
    public var bubbleRadius: CGFloat
    public var buttonSize: CGFloat

    public init(
        primaryColor: Color = Color(hex: DEFAULT_PRIMARY_COLOR),
        onPrimaryColor: Color = .white,
        backgroundColor: Color = Color(hex: "#f4f6f8"),
        headerTextColor: Color = .white,
        headerSubTextColor: Color = Color.white.opacity(0.9),
        ownBubbleColor: Color = Color(hex: DEFAULT_PRIMARY_COLOR),
        ownTextColor: Color = .white,
        operatorBubbleColor: Color = Color(hex: "#eceef1"),
        operatorTextColor: Color = Color(hex: "#1a1a1a"),
        mutedColor: Color = Color(hex: "#8a949e"),
        borderColor: Color = Color(hex: "#e3e8ee"),
        inputBackground: Color = .white,
        inputTextColor: Color = Color(hex: "#1a1a1a"),
        badgeColor: Color = Color(hex: "#ff3b30"),
        badgeTextColor: Color = .white,
        bubbleRadius: CGFloat = 20,
        buttonSize: CGFloat = 60
    ) {
        self.primaryColor = primaryColor
        self.onPrimaryColor = onPrimaryColor
        self.backgroundColor = backgroundColor
        self.headerTextColor = headerTextColor
        self.headerSubTextColor = headerSubTextColor
        self.ownBubbleColor = ownBubbleColor
        self.ownTextColor = ownTextColor
        self.operatorBubbleColor = operatorBubbleColor
        self.operatorTextColor = operatorTextColor
        self.mutedColor = mutedColor
        self.borderColor = borderColor
        self.inputBackground = inputBackground
        self.inputTextColor = inputTextColor
        self.badgeColor = badgeColor
        self.badgeTextColor = badgeTextColor
        self.bubbleRadius = bubbleRadius
        self.buttonSize = buttonSize
    }

    public static func merge(primaryFromConfig: String?, overrides: TeletypeTheme? = nil) -> TeletypeTheme {
        var base = TeletypeTheme()
        if let hex = primaryFromConfig, !hex.isEmpty {
            let color = Color(hex: hex)
            base.primaryColor = color
            base.ownBubbleColor = color
        }
        return overrides ?? base
    }
}

extension Color {
    public init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        if cleaned.count == 6 {
            self.init(
                red: Double((rgb >> 16) & 0xFF) / 255,
                green: Double((rgb >> 8) & 0xFF) / 255,
                blue: Double(rgb & 0xFF) / 255
            )
        } else {
            self.init(red: 0, green: 0.52, blue: 1)
        }
    }

    public func uiColor() -> UIColor { UIColor(self) }
}

enum TeletypeAssets {
    static func image(named name: String, subdirectory: String? = nil) -> UIImage? {
        let bundle = Bundle.module
        if let url = bundle.url(forResource: name, withExtension: "png", subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: "png")
        {
            return UIImage(contentsOfFile: url.path)
        }
        return UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    static func background(_ id: ChatBackground) -> UIImage? {
        switch id {
        case ChatBackgrounds.doodle: return image(named: "doodle", subdirectory: "backgrounds")
        case ChatBackgrounds.circles: return image(named: "circles", subdirectory: "backgrounds")
        case ChatBackgrounds.scribbles: return image(named: "scribbles", subdirectory: "backgrounds")
        default: return nil
        }
    }

    static func backgroundThumb(_ id: ChatBackground) -> UIImage? {
        switch id {
        case ChatBackgrounds.doodle: return image(named: "doodle-thumb", subdirectory: "backgrounds")
        case ChatBackgrounds.circles: return image(named: "circles-thumb", subdirectory: "backgrounds")
        case ChatBackgrounds.scribbles: return image(named: "scribbles-thumb", subdirectory: "backgrounds")
        default: return nil
        }
    }

    static var chatButtonIcon: UIImage? {
        image(named: "icon", subdirectory: "ChatButton")
            ?? image(named: "icon@2x", subdirectory: "ChatButton")
    }
}
