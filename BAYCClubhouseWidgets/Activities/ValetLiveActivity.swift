import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Valet Live Activity Widget

struct ValetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ValetActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            ValetLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    ValetExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ValetExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ValetExpandedBottom(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ValetExpandedCenter(context: context)
                }
            } compactLeading: {
                // Compact leading
                Image(systemName: "car.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                // Compact trailing
                Text(context.state.status.rawValue)
                    .font(.caption2)
                    .foregroundColor(.orange)
            } minimal: {
                // Minimal (when multiple activities)
                Image(systemName: context.state.status.icon)
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Lock Screen View

struct ValetLockScreenView: View {
    let context: ActivityViewContext<ValetActivityAttributes>

    private var brandGold: Color { Color(red: 0.95, green: 0.61, blue: 0.07) }
    private var brandDark: Color { Color(red: 0.1, green: 0.1, blue: 0.18) }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundColor(brandGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("BAYC Valet")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                    Text(context.attributes.ticketNumber)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                Spacer()

                // Status badge
                Text(context.state.status.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(brandDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(brandGold)
                    .clipShape(Capsule())
            }

            // Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [brandGold, Color.orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * context.state.progressPercent, height: 8)
                    }
                }
                .frame(height: 8)

                // Progress steps
                HStack {
                    ForEach(progressSteps, id: \.0) { step, icon in
                        HStack(spacing: 4) {
                            Image(systemName: icon)
                                .font(.system(size: 10))
                            if step != "Here" {
                                Text(step)
                                    .font(.system(size: 9))
                            }
                        }
                        .foregroundColor(isStepActive(step) ? brandGold : .white.opacity(0.4))

                        if step != "Here" {
                            Spacer()
                        }
                    }
                }
            }

            // Vehicle info
            HStack {
                Text(context.attributes.vehicleDescription)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                if let valet = context.state.valetName {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(valet)
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.6))
                }

                if let eta = context.state.estimatedMinutes, eta > 0 {
                    Text("~\(eta) min")
                        .font(.caption)
                        .foregroundColor(brandGold)
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

    private var progressSteps: [(String, String)] {
        [
            ("Request", "clock.fill"),
            ("Received", "checkmark.circle.fill"),
            ("Fetching", "figure.walk"),
            ("On Way", "car.fill"),
            ("Here", "key.fill")
        ]
    }

    private func isStepActive(_ step: String) -> Bool {
        let stepOrder = ["Request", "Received", "Fetching", "On Way", "Here"]
        let statusOrder: [ValetActivityAttributes.ContentState.ValetLiveStatus] = [
            .requesting, .received, .fetching, .onTheWay, .here
        ]

        guard let stepIndex = stepOrder.firstIndex(of: step),
              let statusIndex = statusOrder.firstIndex(of: context.state.status) else {
            return false
        }

        return stepIndex <= statusIndex
    }
}

// MARK: - Dynamic Island Expanded Views

struct ValetExpandedLeading: View {
    let context: ActivityViewContext<ValetActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Ticket")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(context.attributes.ticketNumber)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.orange)
        }
    }
}

struct ValetExpandedTrailing: View {
    let context: ActivityViewContext<ValetActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let eta = context.state.estimatedMinutes, eta > 0 {
                Text("ETA")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                Text("\(eta) min")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            } else {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
        }
    }
}

struct ValetExpandedCenter: View {
    let context: ActivityViewContext<ValetActivityAttributes>

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: context.state.status.icon)
                .font(.title)
                .foregroundColor(.orange)

            Text(context.state.status.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

struct ValetExpandedBottom: View {
    let context: ActivityViewContext<ValetActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: geo.size.width * context.state.progressPercent, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(context.attributes.vehicleDescription)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if let valet = context.state.valetName {
                    Text(valet)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Valet Lock Screen", as: .content, using: ValetActivityAttributes(
    ticketNumber: "VL-847",
    vehicleDescription: "Black Tesla Model S",
    memberId: "member123"
)) {
    ValetLiveActivity()
} contentStates: {
    ValetActivityAttributes.ContentState(
        status: .fetching,
        progressPercent: 0.5,
        estimatedMinutes: 5,
        valetName: "Carlos M.",
        lastUpdated: Date()
    )
}
