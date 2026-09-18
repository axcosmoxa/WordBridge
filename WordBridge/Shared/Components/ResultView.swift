import SwiftUI

struct ResultView: View {
    var entry: WordEntry
    var teacherMode: Bool
    var isSaved: Bool
    var onSave: () -> Void
    var onCopy: () -> Void

    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Word + pron + TTS
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.query)
                        .font(.title.weight(.bold))
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)
                    if let pron = entry.phonetic ?? entry.pronunciation {
                        Text(pron)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let pos = entry.partOfSpeech {
                        Text(pos)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                            .textCase(.lowercase)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Button {
                    if let audio = entry.audioURL, !audio.isEmpty {
                        TTSService.shared.playAudioURL(audio)
                    } else {
                        let lang = entry.language == .hindi ? "hi-IN" : "en-US"
                        TTSService.shared.speak(entry.query, language: lang)
                    }
                    Haptics.light()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Play pronunciation")
                .buttonStyle(.plain)
            }

            Divider()

            // Hindi/English equivalent - priority
            if let trans = entry.translation, !trans.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.language == .hindi ? "English" : "हिंदी")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(trans)
                        .font(.title3.weight(.medium))
                        .foregroundColor(.primary)
                }
            }

            if let def = entry.simpleDefinition ?? entry.definition {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meaning")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(def)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Contextual meaning if sentence
            if let ctx = entry.contextualMeaning, let hi = entry.contextualHindi {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Here it means")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(ctx).font(.callout).foregroundColor(.primary)
                    Text(hi).font(.callout).foregroundColor(.primary)
                    Text("Hindi: \(hi)").font(.caption).foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if !entry.synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text("Similar words")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    FlowLayout(spacing: 8) {
                        ForEach(entry.synonyms, id: \.self) { w in
                            Text(w)
                                .font(.callout)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
                        }
                    }
                    // Subtle usage hints for known words
                    if entry.query.lowercased() == "big" {
                        usageHint
                    }
                }
            }

            if let ex = entry.example {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    Text("Example")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(ex).font(.callout).foregroundColor(.primary).italic()
                    if let hiEx = entry.exampleTranslation {
                        Text(hiEx).font(.callout).foregroundColor(.secondary)
                    }
                }
            }

            // Explain simply
            if let enSimple = entry.explainSimplyEnglish, let hiSimple = entry.explainSimplyHindi {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    Text("Explain simply")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(enSimple).font(.body)
                    Text(hiSimple).font(.body).foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Teacher mode
            if teacherMode, let tEn = entry.teacherExplanation {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    Label("For a child", systemImage: "face.smiling")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text(tEn).font(.callout)
                    if let tHi = entry.teacherExplanationHindi {
                        Text(tHi).font(.callout).foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: { onSave(); Haptics.success() }) {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "star.fill" : "star")
                        .font(.callout.weight(.medium))
                        .foregroundColor(isSaved ? .yellow : .blue)
                }
                .accessibilityLabel(isSaved ? "Unsave word" : "Save word")
                .buttonStyle(.plain)

                Button(action: { onCopy(); Haptics.light() }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Copy meaning")
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(scheme == .dark ? 0 : 0.06), radius: 12, x: 0, y: 4)
        .transition(.opacity)
    }

    var usageHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BIG — General and common.").font(.caption).foregroundColor(.secondary)
            Text("LARGE — More formal or factual.").font(.caption).foregroundColor(.secondary)
            Text("HUGE — Very large.").font(.caption).foregroundColor(.secondary)
            Text("ENORMOUS — Extremely large.").font(.caption).foregroundColor(.secondary)
        }
    }
}

// Simple flow layout for synonyms
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (idx, pos) in result.positions.enumerated() {
            subviews[idx].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }
    func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        var positions: [CGPoint] = []
        var maxHeight: CGFloat = 0
        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)
            if x + sz.width > maxW {
                x = 0; y += rowH + spacing; rowH = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowH = max(rowH, sz.height)
            x += sz.width + spacing
            maxHeight = max(maxHeight, y + rowH)
        }
        return (CGSize(width: maxW, height: maxHeight), positions)
    }
}
