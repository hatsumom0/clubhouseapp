import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Event Countdown Live Activity Widget

struct EventLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            EventLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.category.uppercased())
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(context.attributes.eventTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.hasStarted {
                        VStack(spacing: 2) {
                            Text("NOW")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(context.state.countdownText)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(context.state.isStartingSoon ? .orange : .white)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Location
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(context.attributes.location)
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        // Attendees
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("\(context.state.attendeeCount)")
                                .font(.caption)
                            if context.state.spotsLeft > 0 && context.state.spotsLeft < 5 {
                                Text("(\(context.state.spotsLeft) left)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.imageSystemName)
                    .foregroundColor(categoryColor(context.attributes.category))
            } compactTrailing: {
                if context.state.hasStarted {
                    Text("NOW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else {
                    Text(context.state.countdownText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(context.state.isStartingSoon ? .orange : .white)
                }
            } minimal: {
                Image(systemName: context.attributes.imageSystemName)
                    .foregroundColor(categoryColor(context.attributes.category))
            }
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "social": return .blue
        case "dining": return .orange
        case "wellness": return .green
        case "spa": return .purple
        case "fitness": return .red
        case "exclusive": return Color(red: 0.95, green: 0.61, blue: 0.07)
        case "party": return .pink
        default: return .cyan
        }
    }
}

// MARK: - Lock Screen View

struct EventLockScreenView: View {
    let context: ActivityViewContext<EventActivityAttributes>

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }
    private var brandDark: Color { Color(red: 0.1, green: 0.1, blue: 0.18) }

    private var categoryColor: Color {
        switch context.attributes.category.lowercased() {
        case "social": return .blue
        case "dining": return .orange
        case "wellness": return .green
        case "spa": return .purple
        case "fitness": return .red
        case "exclusive": return brandGold
        case "party": return .pink
        default: return .cyan
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Event icon and info
            VStack(alignment: .leading, spacing: 8) {
                // Category badge
                HStack(spacing: 6) {
                    Image(systemName: context.attributes.imageSystemName)
                        .font(.caption)
                    Text(context.attributes.category.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(0.5)
                }
                .foregroundColor(categoryColor)

                // Event title
                Text(context.attributes.eventTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Location and time
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(context.attributes.location)
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(formatTime(context.state.startTime))
                            .font(.caption)
                    }
                }
                .foregroundColor(.white.opacity(0.6))

                // Attendee info
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(context.state.attendeeCount) attending")
                        .font(.caption)

                    if context.state.spotsLeft > 0 && context.state.spotsLeft < 10 {
                        Text("\(context.state.spotsLeft) spots left")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Right: Countdown
            VStack(spacing: 4) {
                if context.state.hasStarted {
                    VStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("HAPPENING")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("NOW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                } else {
                    VStack(spacing: 2) {
                        if context.state.minutesUntilStart >= 60 {
                            let hours = context.state.minutesUntilStart / 60
                            let mins = context.state.minutesUntilStart % 60
                            Text("\(hours)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(context.state.isStartingSoon ? .orange : categoryColor)
                            Text("hr \(mins)m")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Text("\(context.state.minutesUntilStart)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(context.state.isStartingSoon ? .orange : categoryColor)
                            Text("minutes")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    if context.state.isStartingSoon {
                        Text("Starting Soon!")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                    }
                }
            }
            .frame(minWidth: 80)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [brandDark, Color(red: 0.09, green: 0.13, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Event Lock Screen", as: .content, using: EventActivityAttributes(
    eventId: "event123",
    eventTitle: "Sunset Yoga & Meditation",
    location: "Pool Deck",
    category: "Wellness",
    imageSystemName: "figure.yoga"
)) {
    EventLiveActivity()
} contentStates: {
    EventActivityAttributes.ContentState(
        startTime: Calendar.current.date(byAdding: .minute, value: 25, to: Date())!,
        endTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
        minutesUntilStart: 25,
        attendeeCount: 12,
        spotsLeft: 3,
        isStartingSoon: true,
        hasStarted: false
    )
}
