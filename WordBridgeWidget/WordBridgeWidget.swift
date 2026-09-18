import WidgetKit
import SwiftUI

// Shared model for widget
struct WidgetEntry: TimelineEntry {
    var date: Date
    var lastQuery: String?
    var lastTranslation: String?
    var isListening: Bool = false
}

struct WidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), lastQuery: "adapt", lastTranslation: "अनुकूल होना")
    }
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60*15)))
        completion(timeline)
    }
    private func loadEntry() -> WidgetEntry {
        // Read from App Group UserDefaults or file
        if let defaults = UserDefaults(suiteName: "group.com.wordbridge.app"),
           let q = defaults.string(forKey: "widget_lastQuery") {
            let t = defaults.string(forKey: "widget_lastTranslation")
            return WidgetEntry(date: Date(), lastQuery: q, lastTranslation: t)
        }
        // Fallback file in group container
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wordbridge.app")?.appendingPathComponent("WidgetCache.json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONDecoder().decode([String:String].self, from: data) {
            return WidgetEntry(date: Date(), lastQuery: json["q"], lastTranslation: json["t"])
        }
        return WidgetEntry(date: Date(), lastQuery: nil, lastTranslation: nil)
    }
}

struct WordBridgeWidgetEntryView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            lockCircular
        case .accessoryRectangular:
            lockRectangular
        case .accessoryInline:
            lockInline
        default:
            homeView
        }
    }

    var homeView: some View {
        ZStack {
            Color(.secondarySystemBackground)
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill").font(.caption2).foregroundColor(.blue)
                    Text("WordBridge").font(.caption2.weight(.semibold)).foregroundColor(.secondary)
                    Spacer()
                }
                if let q = entry.lastQuery {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(q).font(.callout.weight(.bold)).lineLimit(1)
                        if let t = entry.lastTranslation {
                            Text(t).font(.caption).foregroundColor(.secondary).lineLimit(1)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Tap 🎙 to speak").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                HStack(spacing: 8) {
                    Link(destination: URL(string: "wordbridge://listen")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill").font(.caption2)
                            Text("Listen").font(.caption2.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Link(destination: URL(string: "wordbridge://open")!) {
                        Text("Open").font(.caption2).foregroundColor(.blue)
                    }
                    Spacer()
                }
            }
            .padding(12)
        }
        .widgetURL(URL(string: "wordbridge://listen"))
    }

    var lockCircular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "mic.fill").font(.body)
                if let q = entry.lastQuery {
                    Text(q).font(.caption2.weight(.bold)).lineLimit(1)
                }
            }
        }
        .widgetURL(URL(string: "wordbridge://listen"))
    }

    var lockRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.circle.fill").font(.title3).foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text("WordBridge").font(.caption2.weight(.semibold)).foregroundColor(.secondary)
                if let q = entry.lastQuery {
                    Text(q).font(.caption.weight(.bold)).lineLimit(1)
                    if let t = entry.lastTranslation {
                        Text(t).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    }
                } else {
                    Text("Tap to speak").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .widgetURL(URL(string: "wordbridge://listen"))
    }

    var lockInline: some View {
        HStack(spacing: 4) {
            Image(systemName: "mic.fill")
            Text(entry.lastQuery ?? "WordBridge — tap to listen")
        }
        .widgetURL(URL(string: "wordbridge://listen"))
    }
}

struct WordBridgeWidget: Widget {
    let kind = "WordBridgeWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            WordBridgeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("WordBridge Mic")
        .description("Tap 🎙 to listen and show meaning instantly — even from Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct WordBridgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        WordBridgeWidget()
    }
}
