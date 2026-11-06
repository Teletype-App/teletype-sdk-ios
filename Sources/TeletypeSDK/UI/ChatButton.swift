import SwiftUI

public struct ChatButton: View {
    @ObservedObject var controller: TeletypeController
    public var position: ChatButtonPosition
    public var scale: ChatButtonScale
    public var bottom: CGFloat
    public var side: CGFloat
    public var backgroundColor: Color?
    public var onPress: (() -> Void)?

    public init(
        controller: TeletypeController,
        position: ChatButtonPosition = .right,
        scale: ChatButtonScale = 100,
        bottom: CGFloat = 24,
        side: CGFloat = 20,
        backgroundColor: Color? = nil,
        onPress: (() -> Void)? = nil
    ) {
        self.controller = controller
        self.position = position
        self.scale = CHAT_BUTTON_SCALES.contains(scale) ? scale : 100
        self.bottom = bottom
        self.side = side
        self.backgroundColor = backgroundColor
        self.onPress = onPress
    }

    private var factor: CGFloat { CGFloat(scale) / 100 }
    private var size: CGFloat { 60 * factor }
    private var color: Color {
        backgroundColor ?? Color(hex: controller.state.primaryColor)
    }

    public var body: some View {
        let pos = position

        Button {
            if let onPress {
                onPress()
            } else {
                controller.client.toggle()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .shadow(color: color.opacity(0.35), radius: 15, x: 0, y: 10)
                    .overlay {
                        if let icon = TeletypeAssets.chatButtonIcon {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 38 * factor, height: 41 * factor)
                        } else {
                            ChatButtonShape()
                                .fill(Color.white)
                                .frame(width: 32 * factor, height: 34 * factor)
                        }
                    }

                if controller.state.unreadCount > 0 && !controller.state.opened {
                    Text(controller.state.unreadCount > 99 ? "99+" : "\(controller.state.unreadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Color(hex: "#ff3b30"))
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                        .scaleEffect(factor)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, bottom)
        .padding(pos == .left ? .leading : .trailing, side)
        .accessibilityIdentifier("chatFabButton")
    }
}

public struct ChatWidget: View {
    @ObservedObject var controller: TeletypeController
    public var hideButton: Bool
    public var position: ChatButtonPosition
    public var scale: ChatButtonScale
    public var bottom: CGFloat

    public init(
        controller: TeletypeController,
        hideButton: Bool = false,
        position: ChatButtonPosition = .right,
        scale: ChatButtonScale = 100,
        bottom: CGFloat = 40
    ) {
        self.controller = controller
        self.hideButton = hideButton
        self.position = position
        self.scale = scale
        self.bottom = bottom
    }

    public var body: some View {
        if hideButton {
            EmptyView()
        } else {
            ChatButton(
                controller: controller,
                position: position,
                scale: scale,
                bottom: bottom
            )
        }
    }
}

struct ChatButtonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.addEllipse(in: CGRect(x: 0, y: 0, width: w, height: h * 0.88))
        path.move(to: CGPoint(x: w * 0.18, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.18, y: h))
        path.addLine(to: CGPoint(x: w * 0.38, y: h * 0.86))
        path.closeSubpath()
        return path
    }
}
