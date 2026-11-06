import SwiftUI

struct MessageListView: View {
    let messages: [Message]
    let theme: TeletypeTheme
    let strings: TeletypeStrings
    let language: String
    let chatBackground: ChatBackground
    let operatorTyping: Bool
    var onRate: (ConversationRating, String) -> Void
    var onRetry: (String) -> Void

    @State private var nearBottom = true
    @State private var newIncoming = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 8)
                        ForEach(messages, id: \.listId) { message in
                            MessageBubbleView(
                                message: message,
                                theme: theme,
                                strings: strings,
                                language: language,
                                onRate: onRate,
                                onRetry: onRetry
                            )
                            .id(message.listId)
                        }
                        if operatorTyping {
                            TypingIndicatorView(theme: theme)
                                .id("typing")
                        }
                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last, last.isOwn == true || nearBottom {
                        newIncoming = 0
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    } else if let last = messages.last, last.isOwn != true {
                        newIncoming += 1
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            if newIncoming > 0 || !nearBottom {
                Button {
                    nearBottom = true
                    newIncoming = 0
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.33))
                        .frame(width: 38, height: 38)
                        .background(Color(hex: "#f7f7f7").opacity(0.85))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            }
        }
        .background {
            if let img = TeletypeAssets.background(chatBackground) {
                Image(uiImage: img)
                    .resizable(resizingMode: .tile)
                    .ignoresSafeArea()
            } else {
                theme.backgroundColor
            }
        }
    }
}

struct TypingIndicatorView: View {
    let theme: TeletypeTheme
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(theme.mutedColor)
                    .frame(width: 7, height: 7)
                    .offset(y: phase == i ? -4 : 0)
                    .opacity(phase == i ? 1 : 0.4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.operatorBubbleColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.bubbleRadius))
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
