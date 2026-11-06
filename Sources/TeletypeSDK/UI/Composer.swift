import SwiftUI

struct ComposerView: View {
    let theme: TeletypeTheme
    var placeholder: String
    @Binding var text: String
    var onSend: (String) -> Void
    var onTyping: (String) -> Void
    var onStopTyping: () -> Void
    var onAttachmentPress: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...6)
                .font(.system(size: 16))
                .foregroundColor(theme.inputTextColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .onChange(of: text) { newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onStopTyping()
                    } else {
                        onTyping(newValue)
                    }
                }

            Button {
                onAttachmentPress?()
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundColor(theme.mutedColor)
                    .padding(6)
            }
            .disabled(onAttachmentPress == nil)
            .opacity(onAttachmentPress == nil ? 0.4 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("attachButton")
            .accessibilityLabel("Attach")
            .accessibilityAddTraits(.isButton)

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSend(trimmed)
                    text = ""
                    onStopTyping()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(theme.onPrimaryColor)
                        .frame(width: 42, height: 42)
                        .background(theme.primaryColor)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(theme.inputBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.borderColor)
                .frame(height: 0.5)
        }
    }
}
