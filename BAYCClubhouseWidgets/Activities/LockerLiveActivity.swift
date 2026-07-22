import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Locker Live Activity Widget

struct LockerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockerActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockerLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    LockerExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    LockerExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LockerExpandedBottom(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    LockerExpandedCenter(context: context)
                }
            } compactLeading: {
                // Compact leading - locker icon
                Image(systemName: "lock.fill")
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.85))
            } compactTrailing: {
                // Compact trailing - locker number
                Text(context.attributes.lockerNumber)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            } minimal: {
                // Minimal (when multiple activities)
                Image(systemName: context.state.status.icon)
                    .foregroundColor(statusColor(context.state.status))
            }
        }
    }

    private func statusColor(_ status: LockerActivityAttributes.ContentState.LockerLiveStatus) -> Color {
        switch status {
        case .active: return Color(red: 0.2, green: 0.6, blue: 0.85)
        case .expiringSoon: return Color(red: 0.95, green: 0.61, blue: 0.07)
        case .expired: return Color(red: 0.91, green: 0.3, blue: 0.24)
        }
    }
}

// MARK: - Lock Screen View

struct LockerLockScreenView: View {
    let context: ActivityViewContext<LockerActivityAttributes>

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }
    private var brandDark: Color { Color(red: 0.1, green: 0.1, blue: 0.18) }
    private var lockerBlue: Color { Color(red: 0.2, green: 0.6, blue: 0.85) }

    private var statusColor: Color {
        switch context.state.status {
        case .active: return lockerBlue
        case .expiringSoon: return brandGold
        case .expired: return Color(red: 0.91, green: 0.3, blue: 0.24)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundColor(lockerBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("BAYC Locker")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                    Text(context.attributes.memberName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: context.state.status.icon)
                        .font(.caption2)
                    Text(context.state.status.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(brandDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor)
                .clipShape(Capsule())
            }

            // Locker Info Card
            HStack(spacing: 20) {
                // Locker Number
                VStack(spacing: 4) {
                    Text("LOCKER")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))

                    Text(context.attributes.lockerNumber)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(context.attributes.floor)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(width: 90)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 60)

                // Access Code
                VStack(spacing: 4) {
                    Text("CODE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))

                    if context.state.showCode {
                        Text(context.state.accessCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(brandGold)
                    } else {
                        Text("••••")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    Text("Tap to reveal in app")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(lockerBlue.opacity(0.3), lineWidth: 1)
                    )
            )

            // Expiration Info
            if let expiresAt = context.state.expiresAt {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption2)

                    if context.state.isExpiringSoon {
                        HStack(spacing: 0) {
                            Text("Expires soon: ")
                            Text(context.state.expiryText)
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                    } else {
                        Text("Expires: \(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                    }

                    Spacer()
                }
                .foregroundColor(context.state.isExpiringSoon ? brandGold : .white.opacity(0.6))
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
}

// MARK: - Dynamic Island Expanded Views

struct LockerExpandedLeading: View {
    let context: ActivityViewContext<LockerActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Locker")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(context.attributes.lockerNumber)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.85))
        }
    }
}

struct LockerExpandedTrailing: View {
    let context: ActivityViewContext<LockerActivityAttributes>

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Code")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            if context.state.showCode {
                Text(context.state.accessCode)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(brandGold)
            } else {
                Text("••••")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

struct LockerExpandedCenter: View {
    let context: ActivityViewContext<LockerActivityAttributes>

    private func statusColor(_ status: LockerActivityAttributes.ContentState.LockerLiveStatus) -> Color {
        switch status {
        case .active: return Color(red: 0.2, green: 0.6, blue: 0.85)
        case .expiringSoon: return Color(red: 0.95, green: 0.61, blue: 0.07)
        case .expired: return Color(red: 0.91, green: 0.3, blue: 0.24)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: context.state.status.icon)
                .font(.title)
                .foregroundColor(statusColor(context.state.status))

            Text(context.state.status.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

struct LockerExpandedBottom: View {
    let context: ActivityViewContext<LockerActivityAttributes>

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }

    var body: some View {
        HStack {
            // Floor info
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                Text(context.attributes.floor)
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.7))

            Spacer()

            // Expiry time
            if context.state.isExpiringSoon {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(context.state.expiryText)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(brandGold)
            } else if let _ = context.state.expiresAt {
                Text(context.state.expiryText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Preview

#Preview("Locker Lock Screen - Active", as: .content, using: LockerActivityAttributes(
    lockerId: "locker123",
    lockerNumber: "A42",
    floor: "Main Floor",
    section: "A",
    memberId: "member123",
    memberName: "Ape #1234"
)) {
    LockerLiveActivity()
} contentStates: {
    LockerActivityAttributes.ContentState(
        accessCode: "7329",
        assignedTime: Date(),
        expiresAt: Date().addingTimeInterval(18000), // 5 hours from now
        status: .active,
        minutesUntilExpiry: 300,
        showCode: false
    )
}

#Preview("Locker Lock Screen - Expiring", as: .content, using: LockerActivityAttributes(
    lockerId: "locker123",
    lockerNumber: "B17",
    floor: "Upper Floor",
    section: "B",
    memberId: "member123",
    memberName: "Ape #5678"
)) {
    LockerLiveActivity()
} contentStates: {
    LockerActivityAttributes.ContentState(
        accessCode: "4851",
        assignedTime: Date().addingTimeInterval(-21600), // 6 hours ago
        expiresAt: Date().addingTimeInterval(3600), // 1 hour from now
        status: .expiringSoon,
        minutesUntilExpiry: 60,
        showCode: true
    )
}
