import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Provider

struct BAYCProvider: TimelineProvider {
    func placeholder(in context: Context) -> BAYCWidgetEntry {
        BAYCWidgetEntry(date: Date(), memberName: "Member", nextEvent: "Sunset Lounge", eventTime: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BAYCWidgetEntry) -> Void) {
        let entry = BAYCWidgetEntry(
            date: Date(),
            memberName: "Member",
            nextEvent: "Sunset Lounge",
            eventTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BAYCWidgetEntry>) -> Void) {
        let currentDate = Date()
        let entry = BAYCWidgetEntry(
            date: currentDate,
            memberName: "Member",
            nextEvent: "Sunset Lounge",
            eventTime: Calendar.current.date(byAdding: .hour, value: 2, to: currentDate) ?? currentDate
        )

        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Entry

struct BAYCWidgetEntry: TimelineEntry {
    let date: Date
    let memberName: String
    let nextEvent: String?
    let eventTime: Date?
}

// MARK: - Widget Views

struct BAYCWidgetEntryView: View {
    var entry: BAYCProvider.Entry
    @Environment(\.widgetFamily) var family

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }
    private var brandDark: Color { Color(red: 0.1, green: 0.1, blue: 0.18) }

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    var smallWidget: some View {
        ZStack {
            LinearGradient(
                colors: [brandDark, Color(red: 0.09, green: 0.13, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                // Logo placeholder
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(brandGold)

                Text("BAYC")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("CLUBHOUSE")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(brandGold)
            }
        }
    }

    var mediumWidget: some View {
        ZStack {
            LinearGradient(
                colors: [brandDark, Color(red: 0.09, green: 0.13, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                // Left: Logo
                VStack(spacing: 4) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(brandGold)

                    Text("BAYC")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 80)

                // Right: Next event
                VStack(alignment: .leading, spacing: 6) {
                    Text("NEXT EVENT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(brandGold)

                    if let event = entry.nextEvent {
                        Text(event)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    if let time = entry.eventTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text(time, style: .relative)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Widget Configuration

struct BAYCClubhouseWidget: Widget {
    let kind: String = "BAYCClubhouseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BAYCProvider()) { entry in
            BAYCWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("BAYC Clubhouse")
        .description("Quick access to your clubhouse membership.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    BAYCClubhouseWidget()
} timeline: {
    BAYCWidgetEntry(date: Date(), memberName: "Member", nextEvent: "Sunset Lounge", eventTime: Date())
}

#Preview(as: .systemMedium) {
    BAYCClubhouseWidget()
} timeline: {
    BAYCWidgetEntry(date: Date(), memberName: "Member", nextEvent: "Sunset Lounge", eventTime: Date())
}
