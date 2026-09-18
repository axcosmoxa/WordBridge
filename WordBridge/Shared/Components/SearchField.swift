import SwiftUI

struct SearchField: View {
    @Binding var text: String
    var onSubmit: () -> Void
    var onMic: () -> Void
    var isRecording: Bool
    var language: WordLanguage

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    TextField("Type a word or sentence...", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body)
                        .accessibilityLabel("Search field")
                        .accessibilityHint("Type English or Hindi word, phrase or sentence")
                        .onSubmit { onSubmit() }
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("Clear search")
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))

                Menu {
                    Button(action: { NotificationCenter.default.post(name: Notification.Name("SetVoiceLangEN"), object: nil) }) {
                        Label("English Voice", systemImage: "a")
                    }
                    Button(action: { NotificationCenter.default.post(name: Notification.Name("SetVoiceLangHI"), object: nil) }) {
                        Label("Hindi Voice", systemImage: "character.book.closed")
                    }
                } label: {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isRecording ? .white : .blue)
                        .frame(width: 44, height: 44)
                        .background(isRecording ? Color.red : Color(.secondarySystemBackground))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))
                } primaryAction: {
                    onMic()
                }
                .accessibilityLabel(isRecording ? "Stop recording" : "Voice search")
                .accessibilityHint("Tap to speak, press and hold to change language")
            }
            if !text.isEmpty && language != .unknown {
                HStack {
                    Text(language == .hindi ? "हिंदी detected" : "English detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .accessibilityLabel(language == .hindi ? "Hindi detected" : "English detected")
            }
        }
    }
}
