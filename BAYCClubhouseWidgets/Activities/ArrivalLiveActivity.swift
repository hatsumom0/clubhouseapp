import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Arrival Countdown Live Activity Widget

struct ArrivalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ArrivalActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            ArrivalLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arriving")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text(context.attributes.memberName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if context.state.status == .arrived {
                            Image(systemName: "hand.wave.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        } else {
                            Text("\(context.state.etaMinutes)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                            Text("min")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: context.state.status.icon)
                            .foregroundColor(.cyan)
                        Text(context.state.status.rawValue)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Spacer()

                        if context.attributes.guestCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                Text("+\(context.attributes.guestCount)")
                                    .font(.caption)
                            }
                            .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundColor(.cyan)
            } compactTrailing: {
                if context.state.status == .arrived {
                    Image(systemName: "hand.wave.fill")
                        .foregroundColor(.green)
                } else {
                    Text("\(context.state.etaMinutes)m")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)
                }
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundColor(.cyan)
            }
        }
    }
}

// MARK: - Lock Screen View

struct ArrivalLockScreenView: View {
    let context: ActivityViewContext<ArrivalActivityAttributes>

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }
    private var brandDark: Color { Color(red: 0.1, green: 0.1, blue: 0.18) }
    private var accentCyan: Color { Color(red: 0.2, green: 0.8, blue: 0.9) }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Status icon and info
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundColor(accentCyan)

                    Text("BAYC Clubhouse")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Status
                HStack(spacing: 6) {
                    Image(systemName: context.state.status.icon)
                        .font(.subheadline)
                    Text(context.state.status.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(statusColor)

                // Guest count
                if context.attributes.guestCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(context.attributes.guestCount) guest\(context.attributes.guestCount == 1 ? "" : "s")")
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // Right: ETA countdown
            if context.state.status == .arrived {
                VStack(spacing: 4) {
                    Image(systemName: "hand.wave.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("Welcome!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            } else {
                VStack(spacing: 2) {
                    Text("\(context.state.etaMinutes)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(accentCyan)
                    Text("minutes")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [brandDark, Color(red: 0.05, green: 0.15, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var statusColor: Color {
        switch context.state.status {
        case .notifying: return .orange
        case .confirmed: return accentCyan
        case .almostThere: return .yellow
        case .arrived: return .green
        }
    }
}

// MARK: - Preview

#Preview("Arrival Lock Screen", as: .content, using: ArrivalActivityAttributes(
    memberId: "member123",
    memberName: "CryptoApe",
    guestCount: 2,
    specialRequests: nil
)) {
    ArrivalLiveActivity()
} contentStates: {
    ArrivalActivityAttributes.ContentState(
        etaMinutes: 8,
        status: .confirmed,
        confirmedAt: Date()
    )
}
