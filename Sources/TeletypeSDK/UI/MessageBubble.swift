import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let theme: TeletypeTheme
    let strings: TeletypeStrings
    let language: String
    var onRate: (ConversationRating, String) -> Void
    var onRetry: (String) -> Void

    private var isOwn: Bool { message.isOwn == true }
    private var mediaKind: MediaKind? { resolveMediaKind(message) }
    private var isVisualMedia: Bool { mediaKind == .image || mediaKind == .video }
    private var emojiOnly: Bool { message.emojiOnly == true && message.messageType == .text }

    private let ratings: [(ConversationRating, String)] = [
        (.unsatisfactory, "😡"),
        (.bad, "🙁"),
        (.satisfactory, "😐"),
        (.good, "🙂"),
        (.excellent, "😍"),
    ]

    var body: some View {
        if message.formType == .rating {
            ratingForm
        } else {
            bubble
        }
    }

    private var ratingForm: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text(strings.ratingTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.operatorTextColor)
                HStack {
                    ForEach(ratings, id: \.0) { item in
                        Button {
                            onRate(item.0, message.tempId)
                        } label: {
                            Text(item.1)
                                .font(.system(size: 26))
                                .padding(6)
                                .background(message.ratingValue == item.0 ? theme.primaryColor : Color.clear)
                                .clipShape(Circle())
                        }
                        .disabled(message.ratingValue != nil)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(theme.operatorBubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: theme.bubbleRadius))
            Spacer(minLength: 48)
        }
        .padding(.leading, 12)
        .padding(.vertical, 5)
    }

    private var bubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isOwn {
                avatar
            } else {
                Spacer(minLength: 48)
            }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 5) {
                Group {
                    switch mediaKind {
                    case .image:
                        MessageTypeImageView(message: message, strings: strings)
                    case .video:
                        MessageTypeVideoView(message: message, strings: strings)
                    case .audio:
                        MessageTypeAudioView(message: message, theme: theme, strings: strings)
                    case .file:
                        MessageTypeFileView(message: message, theme: theme, strings: strings, isOwn: isOwn)
                    case nil:
                        if emojiOnly {
                            Text(message.message ?? "")
                                .font(.system(size: 44))
                        } else {
                            linkified(message.message ?? "", color: isOwn ? theme.ownTextColor : theme.operatorTextColor)
                        }
                    }
                }
                .padding(.horizontal, (emojiOnly || isVisualMedia || mediaKind == .file) ? 0 : 15)
                .padding(.vertical, (emojiOnly || isVisualMedia || mediaKind == .file) ? 0 : 11)
                .background(bubbleBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.bubbleRadius, style: .continuous))
                .overlay {
                    if uploading {
                        Color.black.opacity(0.5)
                            .overlay(Text("\(message.progress ?? 0)%").foregroundColor(.white).fontWeight(.bold))
                            .clipShape(RoundedRectangle(cornerRadius: theme.bubbleRadius))
                    }
                }

                meta
            }
            .frame(maxWidth: isVisualMedia ? 250 : .infinity, alignment: isOwn ? .trailing : .leading)

            if isOwn {
                EmptyView()
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.leading, isOwn ? 48 : 12)
        .padding(.trailing, isOwn ? 8 : 48)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
    }

    private var bubbleBackground: Color {
        if emojiOnly || isVisualMedia { return .clear }
        return isOwn ? theme.ownBubbleColor : theme.operatorBubbleColor
    }

    private var uploading: Bool {
        isOwn && (message.progress ?? 100) < 100 && message.errorMessage == nil
    }

    private var failed: Bool {
        isOwn && message.status == .failed && message.errorMessage == nil
    }

    private var avatar: some View {
        Group {
            if let urlStr = message.avatar ?? message.from?.avatar, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 34, height: 34)
                .clipShape(Circle())
            } else {
                Color.clear.frame(width: 34, height: 34)
            }
        }
    }

    private var meta: some View {
        Group {
            if failed {
                Button(strings.messageFailed) { onRetry(message.tempId) }
                    .font(.system(size: 12.5))
                    .foregroundColor(theme.badgeColor)
            } else {
                Text(statusLabel)
                    .font(.system(size: 12.5))
                    .foregroundColor(theme.mutedColor)
            }
        }
        .padding(.horizontal, 4)
    }

    private var statusLabel: String {
        let time = formatRelativeTime(message.date?.date, language: language, strings: strings)
        if !isOwn { return time }
        if let err = message.errorMessage {
            if err == "fileSizeError" { return strings.fileSizeError }
            if err == "fileFormatNotAllowed" { return strings.fileFormatNotAllowed }
            return strings.uploadFailed
        }
        if let p = message.progress, p < 100, message.errorMessage == nil {
            return "\(strings.uploading) (\(p)%)"
        }
        if message.status == .sending { return strings.messageSending }
        if message.status == .failed { return strings.messageFailed }
        let state = message.seen == true ? strings.messageSeen : strings.messageDelivered
        return time.isEmpty ? state : "\(time). \(state)"
    }

    @ViewBuilder
    private func linkified(_ text: String, color: Color) -> some View {
        let urls = extractUrls(text)
        if urls.isEmpty {
            Text(text).foregroundColor(color).font(.system(size: 16))
        } else {
            Text(attributed(text, urls: urls, color: color))
                .font(.system(size: 16))
        }
    }

    private func attributed(_ text: String, urls: [String], color: Color) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = color
        for url in urls {
            if let range = result.range(of: url), let u = URL(string: url) {
                result[range].link = u
                result[range].underlineStyle = .single
            }
        }
        return result
    }
}
