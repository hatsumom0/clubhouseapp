import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Reservation Ready Live Activity Widget

struct ReservationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReservationActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            ReservationLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reservation")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(context.attributes.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.status == .ready {
                        VStack(spacing: 2) {
                            Image(systemName: "bell.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("READY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    } else if let table = context.state.tableNumber {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Table")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            Text(table)
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    } else if let mins = context.state.minutesUntilReady {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("\(mins)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("min")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
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

                        // Party size
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("Party of \(context.attributes.partySize)")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
            } compactLeading: {
                Image(systemName: statusIcon(context.state.status))
                    .foregroundColor(statusColor(context.state.status))
            } compactTrailing: {
                if context.state.status == .ready {
                    Text("READY")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                } else if let mins = context.state.minutesUntilReady {
                    Text("\(mins)m")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            } minimal: {
                Image(systemName: statusIcon(context.state.status))
                    .foregroundColor(statusColor(context.state.status))
            }
        }
    }

    private func statusIcon(_ status: ReservationActivityAttributes.ContentState.ReservationLiveStatus) -> String {
        status.icon
    }

    private func statusColor(_ status: ReservationActivityAttributes.ContentState.ReservationLiveStatus) -> Color {
        switch status {
        case .upcoming: return .blue
        case .preparingTable: return .orange
        case .ready: return .green
        case .seated: return .purple
        }
    }
}

// MARK: - Lock Screen View

struct ReservationLockScreenView: View {
    let context: ActivityViewContext<ReservationActivityAttributes>

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }
    private var brandDark: Color { Color(red: 0.1, green: 0.1, blue: 0.18) }

    private var statusColor: Color {
        switch context.state.status {
        case .upcoming: return .blue
        case .preparingTable: return .orange
        case .ready: return .green
        case .seated: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Reservation info
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.title3)
                        .foregroundColor(brandGold)

                    Text("BAYC Reservation")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Title
                Text(context.attributes.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Location and party size
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(context.attributes.location)
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("Party of \(context.attributes.partySize)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.white.opacity(0.6))

                // Status badge
                HStack(spacing: 6) {
                    Image(systemName: context.state.status.icon)
                        .font(.caption)
                    Text(context.state.status.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)

                    if let table = context.state.tableNumber {
                        Text("Table \(table)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(statusColor)
            }

            Spacer()

            // Right: Status display
            VStack(spacing: 4) {
                if context.state.status == .ready {
                    VStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                        Text("TABLE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("READY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                } else if context.state.status == .seated {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundColor(.purple)
                        Text("ENJOY!")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                } else if let mins = context.state.minutesUntilReady, mins > 0 {
                    VStack(spacing: 2) {
                        Text("\(mins)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                        Text("minutes")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    VStack(spacing: 4) {
                        Text(formatTime(context.state.scheduledTime))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(statusColor)
                        Text("Scheduled")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
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

#Preview("Reservation Lock Screen - Ready", as: .content, using: ReservationActivityAttributes(
    reservationId: "res123",
    title: "Private Rooftop Lounge",
    location: "Level 3 - Skybar",
    partySize: 4
)) {
    ReservationLiveActivity()
} contentStates: {
    ReservationActivityAttributes.ContentState(
        scheduledTime: Date(),
        status: .ready,
        minutesUntilReady: 0,
        tableNumber: "VIP-7"
    )
}

#Preview("Reservation Lock Screen - Upcoming", as: .content, using: ReservationActivityAttributes(
    reservationId: "res123",
    title: "Oceanfront Dining",
    location: "Main Restaurant",
    partySize: 2
)) {
    ReservationLiveActivity()
} contentStates: {
    ReservationActivityAttributes.ContentState(
        scheduledTime: Calendar.current.date(byAdding: .minute, value: 15, to: Date())!,
        status: .upcoming,
        minutesUntilReady: 15,
        tableNumber: nil
    )
}
