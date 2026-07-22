import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Clubhouse Live Activity Widget (At-Club Experience)

struct ClubhouseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClubhouseActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            ClubhouseLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(context.attributes.memberName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Membership tier badge
                    Text(context.attributes.membershipTier)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tierColor(context.attributes.membershipTier))
                        .clipShape(Capsule())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        // Locker info
                        if let locker = context.state.lockerNumber {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                Text(locker)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.blue)
                        }

                        // Next event
                        if let eventTitle = context.state.nextEventTitle,
                           let eventTime = context.state.nextEventTime {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(eventTitle)
                                    .font(.caption)
                                    .lineLimit(1)
                                Text(formatTime(eventTime))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: "building.2.fill")
                    .foregroundColor(tierColor(context.attributes.membershipTier))
            } compactTrailing: {
                if let locker = context.state.lockerNumber {
                    HStack(spacing: 2) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text(locker)
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } minimal: {
                Image(systemName: "building.2.fill")
                    .foregroundColor(tierColor(context.attributes.membershipTier))
            }
        }
    }

    private func tierColor(_ tier: String) -> Color {
        tier.lowercased() == "black" ? Color(red: 0.95, green: 0.61, blue: 0.07) : Color.purple
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Lock Screen View

struct ClubhouseLockScreenView: View {
    let context: ActivityViewContext<ClubhouseActivityAttributes>

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }
    private var brandDark: Color { Color(red: 0.1, green: 0.1, blue: 0.18) }

    private var tierColor: Color {
        context.attributes.membershipTier.lowercased() == "black" ? brandGold : .purple
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BAYC MIAMI CLUBHOUSE")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.6))

                    Text("Welcome, \(context.attributes.memberName)")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Spacer()

                // Membership badge
                HStack(spacing: 4) {
                    Image(systemName: tierBadgeIcon)
                        .font(.caption2)
                    Text(context.attributes.membershipTier)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(context.attributes.membershipTier.lowercased() == "black" ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tierColor)
                .clipShape(Capsule())
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Info cards
            HStack(spacing: 12) {
                // Locker card
                if let locker = context.state.lockerNumber,
                   let floor = context.state.lockerFloor {
                    InfoCard(
                        icon: "lock.fill",
                        title: "Locker",
                        value: locker,
                        subtitle: floor,
                        color: .blue
                    )
                }

                // Next event card
                if let eventTitle = context.state.nextEventTitle,
                   let eventTime = context.state.nextEventTime {
                    InfoCard(
                        icon: "calendar",
                        title: "Next Event",
                        value: eventTitle,
                        subtitle: formatTime(eventTime),
                        color: tierColor
                    )
                }

                // Check-in time
                if let checkIn = context.state.checkInTime {
                    InfoCard(
                        icon: "clock.fill",
                        title: "Checked In",
                        value: formatTime(checkIn),
                        subtitle: "Today",
                        color: .green
                    )
                }
            }
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

    private var tierBadgeIcon: String {
        context.attributes.membershipTier.lowercased() == "black" ? "crown.fill" : "star.fill"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Info Card Component

struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(color)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Preview

#Preview("Clubhouse Lock Screen", as: .content, using: ClubhouseActivityAttributes(
    memberId: "member123",
    memberName: "CryptoApe",
    membershipTier: "Black"
)) {
    ClubhouseLiveActivity()
} contentStates: {
    ClubhouseActivityAttributes.ContentState(
        nextEventTitle: "Sunset Yoga",
        nextEventTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
        nextEventLocation: "Pool Deck",
        lockerNumber: "A42",
        lockerFloor: "Main Floor",
        currentEventCount: 5,
        isAtClubhouse: true,
        checkInTime: Date()
    )
}
