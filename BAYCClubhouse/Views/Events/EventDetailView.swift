import SwiftUI

struct EventDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatManager: ChatManager
    @StateObject private var eventManager = EventManager.shared
    @State var event: ClubEvent
    @State private var showingRSVPOptions = false
    @State private var isRSVPLoading = false
    @State private var showingTokenProof = false
    @State private var tokenProofVerified = false
    @State private var isVerifyingToken = false
    @State private var verificationFailed = false

    private var userTier: MembershipTier {
        authViewModel.membershipTier
    }

    private var needsTokenProof: Bool {
        event.requiresTokenProof && !tokenProofVerified && event.rsvpStatus == .notResponded
    }

    private var canAccessEvent: Bool {
        guard let requiredTier = event.requiredMembershipTier else { return true }
        switch requiredTier {
        case .black:
            return userTier == .black
        case .platinum:
            return true // Both tiers can access platinum events
        }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f3460")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Exclusive event badge
                    if event.isExclusiveEvent {
                        ExclusiveEventBadge(event: event, userTier: userTier)
                    }

                    // Hero Header
                    EventHeroHeader(event: event)

                    // Quick Info Cards
                    EventQuickInfoSection(event: event)

                    // Description
                    EventDescriptionSection(event: event)

                    // Organizer
                    EventOrganizerSection(organizer: event.organizer)

                    // Attendees
                    EventAttendeesSection(event: event)

                    // Concierge Button
                    EventConciergeButton(event: event)

                    // TokenProof or RSVP Button
                    if needsTokenProof {
                        TokenProofButton(
                            event: event,
                            isVerifying: $isVerifyingToken,
                            showingTokenProof: $showingTokenProof,
                            canAccess: canAccessEvent
                        )
                    } else {
                        RSVPButton(
                            event: $event,
                            showingOptions: $showingRSVPOptions,
                            isLoading: $isRSVPLoading
                        )
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.visible)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Share event
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "f39c12"))
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("RSVP Options", isPresented: $showingRSVPOptions, titleVisibility: .visible) {
            Button("Going") {
                updateRSVP(.going)
            }
            Button("Maybe") {
                updateRSVP(.maybe)
            }
            Button("Not Going") {
                updateRSVP(.declined)
            }
            if event.spotsLeft == 0 && event.rsvpStatus != .going {
                Button("Join Waitlist") {
                    updateRSVP(.waitlist)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingTokenProof) {
            TokenProofVerificationView(
                event: event,
                userTier: userTier,
                isVerifying: $isVerifyingToken,
                verified: $tokenProofVerified,
                failed: $verificationFailed
            )
        }
    }

    private func updateRSVP(_ status: ClubEvent.RSVPStatus) {
        isRSVPLoading = true
        // Update via EventManager to sync across app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                event.rsvpStatus = status
                eventManager.rsvp(to: event.id, status: status)
            }
            isRSVPLoading = false
        }
    }
}

// MARK: - Exclusive Event Badge

struct ExclusiveEventBadge: View {
    let event: ClubEvent
    let userTier: MembershipTier

    private var canAccess: Bool {
        guard let requiredTier = event.requiredMembershipTier else { return true }
        switch requiredTier {
        case .black:
            return userTier == .black
        case .platinum:
            return true
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.requiresTokenProof ? "checkmark.shield.fill" : "crown.fill")
                .font(.system(size: 18))
                .foregroundColor(canAccess ? Color(hex: "f39c12") : .red.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                if let tier = event.requiredMembershipTier {
                    Text("\(tier.displayName) Members Only")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                if event.requiresTokenProof {
                    Text(canAccess ? "TokenProof verification required" : "Your tier doesn't have access")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(canAccess ? .white.opacity(0.6) : .red.opacity(0.8))
                }
            }

            Spacer()

            if canAccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(canAccess ? Color(hex: "f39c12").opacity(0.15) : Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(canAccess ? Color(hex: "f39c12").opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - TokenProof Button

struct TokenProofButton: View {
    let event: ClubEvent
    @Binding var isVerifying: Bool
    @Binding var showingTokenProof: Bool
    let canAccess: Bool

    var body: some View {
        Button {
            if canAccess {
                showingTokenProof = true
            }
        } label: {
            HStack(spacing: 12) {
                if isVerifying {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: canAccess ? "checkmark.shield.fill" : "lock.fill")
                        .font(.system(size: 18, weight: .semibold))

                    Text(canAccess ? "Verify with TokenProof" : "Black Tier Required")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: canAccess
                                    ? [Color(hex: "8b5cf6"), Color(hex: "6366f1")]
                                    : [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: canAccess ? Color(hex: "8b5cf6").opacity(0.4) : Color.clear, radius: 15, y: 8)
        }
        .disabled(!canAccess || isVerifying)
    }
}

// MARK: - TokenProof Verification View

struct TokenProofVerificationView: View {
    @Environment(\.dismiss) var dismiss
    let event: ClubEvent
    let userTier: MembershipTier
    @Binding var isVerifying: Bool
    @Binding var verified: Bool
    @Binding var failed: Bool

    @State private var verificationStep = 0
    @State private var animateCheckmark = false

    var body: some View {
        ZStack {
            Color(hex: "1a1a2e")
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                Spacer()

                // TokenProof Logo
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: Color(hex: "8b5cf6").opacity(0.5), radius: 20, y: 10)

                        if verified {
                            Image(systemName: "checkmark")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(animateCheckmark ? 1 : 0.5)
                                .opacity(animateCheckmark ? 1 : 0)
                        } else if failed {
                            Image(systemName: "xmark")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                    }

                    Text(verified ? "Verified!" : failed ? "Verification Failed" : "TokenProof")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(verified
                         ? "Your \(userTier.displayName) membership has been verified"
                         : failed
                         ? "Unable to verify your eligibility"
                         : "Verifying your NFT ownership")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                // Verification Steps
                if !verified && !failed {
                    VStack(spacing: 16) {
                        VerificationStepRow(
                            step: 1,
                            title: "Connecting to wallet",
                            isComplete: verificationStep >= 1,
                            isCurrent: verificationStep == 0
                        )

                        VerificationStepRow(
                            step: 2,
                            title: "Checking NFT ownership",
                            isComplete: verificationStep >= 2,
                            isCurrent: verificationStep == 1
                        )

                        VerificationStepRow(
                            step: 3,
                            title: "Verifying eligibility",
                            isComplete: verificationStep >= 3,
                            isCurrent: verificationStep == 2
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)
                }

                Spacer()

                // Action Button
                if verified {
                    Button {
                        dismiss()
                    } label: {
                        Text("Continue to RSVP")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "2ecc71"), Color(hex: "27ae60")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .padding(.horizontal, 40)
                } else if failed {
                    Button {
                        // Retry verification
                        failed = false
                        verificationStep = 0
                        startVerification()
                    } label: {
                        Text("Try Again")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    .padding(.horizontal, 40)
                }

                Text(verified
                     ? "You can now RSVP to this exclusive event"
                     : "Powered by TokenProof secure verification")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            startVerification()
        }
    }

    private func startVerification() {
        isVerifying = true

        // Simulate verification steps
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { verificationStep = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { verificationStep = 2 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { verificationStep = 3 }

            // Check if user's tier meets requirement
            let canAccess: Bool
            if let requiredTier = event.requiredMembershipTier {
                canAccess = (requiredTier == .black && userTier == .black) || requiredTier == .platinum
            } else {
                canAccess = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isVerifying = false
                if canAccess {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        verified = true
                        animateCheckmark = true
                    }
                } else {
                    withAnimation {
                        failed = true
                    }
                }
            }
        }
    }
}

struct VerificationStepRow: View {
    let step: Int
    let title: String
    let isComplete: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color(hex: "2ecc71") : isCurrent ? Color(hex: "8b5cf6") : Color.white.opacity(0.2))
                    .frame(width: 32, height: 32)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else if isCurrent {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                } else {
                    Text("\(step)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Text(title)
                .font(.system(size: 14, weight: isComplete || isCurrent ? .semibold : .regular, design: .rounded))
                .foregroundColor(isComplete || isCurrent ? .white : .white.opacity(0.5))

            Spacer()
        }
    }
}

// MARK: - Hero Header

struct EventHeroHeader: View {
    let event: ClubEvent

    var body: some View {
        VStack(spacing: 16) {
            // Category badge and icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [event.category.color, event.category.color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: event.category.color.opacity(0.5), radius: 15, y: 8)

                Image(systemName: event.imageSystemName)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            // Category badge
            Text(event.category.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(event.category.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(event.category.color.opacity(0.2))
                )

            // Title
            Text(event.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Date and Time
            VStack(spacing: 4) {
                Text(formattedDate)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(formattedTime)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.top, 20)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: event.date)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        var timeString = formatter.string(from: event.date)
        if let endDate = event.endDate {
            timeString += " - " + formatter.string(from: endDate)
        }
        return timeString
    }
}

// MARK: - Quick Info Section

struct EventQuickInfoSection: View {
    let event: ClubEvent

    var body: some View {
        HStack(spacing: 12) {
            QuickInfoCard(
                icon: "mappin.circle.fill",
                title: "Location",
                value: event.location,
                color: Color(hex: "e74c3c")
            )

            QuickInfoCard(
                icon: "person.2.fill",
                title: "Spots Left",
                value: "\(event.spotsLeft)/\(event.totalSpots)",
                color: event.spotsLeft <= 5 ? .red : Color(hex: "2ecc71")
            )
        }
    }
}

struct QuickInfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Description Section

struct EventDescriptionSection: View {
    let event: ClubEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About This Event")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(event.description)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)

            // Location details
            if let locationDetail = event.locationDetail {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "f39c12"))

                    Text(locationDetail)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Organizer Section

struct EventOrganizerSection: View {
    let organizer: EventOrganizer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hosted By")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: organizer.avatarSystemName)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(organizer.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(organizer.role)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Color(hex: "8b5cf6"))
                }

                Spacer()

                Button {
                    // Message organizer
                } label: {
                    Image(systemName: "message.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "f39c12"))
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color(hex: "f39c12").opacity(0.2))
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Attendees Section

struct EventAttendeesSection: View {
    let event: ClubEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Who's Going")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text("\(event.totalSpots - event.spotsLeft) attending")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Attendee avatars
            HStack(spacing: -12) {
                ForEach(Array(event.attendees.prefix(5).enumerated()), id: \.element.id) { index, attendee in
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "f39c12").opacity(0.8), Color(hex: "e74c3c").opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "1a1a2e"), lineWidth: 3)
                            )

                        Text(String(attendee.name.prefix(1)))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .zIndex(Double(5 - index))
                }

                if event.attendees.count > 5 {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "2d2d44"))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "1a1a2e"), lineWidth: 3)
                            )

                        Text("+\(event.attendees.count - 5)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()
            }

            // Attendee names
            if !event.attendees.isEmpty {
                Text(attendeeNamesString)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var attendeeNamesString: String {
        let names = event.attendees.prefix(3).map { $0.name }
        if event.attendees.count > 3 {
            return names.joined(separator: ", ") + " and \(event.attendees.count - 3) others"
        }
        return names.joined(separator: ", ")
    }
}

// MARK: - Event Concierge Button

struct EventConciergeButton: View {
    @EnvironmentObject var chatManager: ChatManager
    let event: ClubEvent

    var body: some View {
        VStack(spacing: 12) {
            Button {
                // Open chat with event context - concierge will automatically provide info about this event
                chatManager.openChatWithEventContext(event)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 18))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Message Concierge")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))

                        Text("Ask questions or request special arrangements")
                            .font(.system(size: 11, design: .rounded))
                            .opacity(0.7)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }

            Button {
                // Request human concierge
                chatManager.openChat()
                chatManager.sendMessage("I'd like to speak with a human concierge about the \(event.title) event")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 14))

                    Text("Request Human Concierge")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - RSVP Button

struct RSVPButton: View {
    @Binding var event: ClubEvent
    @Binding var showingOptions: Bool
    @Binding var isLoading: Bool

    var body: some View {
        Button {
            showingOptions = true
        } label: {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: rsvpIcon)
                        .font(.system(size: 18, weight: .semibold))

                    Text(buttonText)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    // Liquid Glass base
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)

                    // Gradient overlay
                    RoundedRectangle(cornerRadius: 20)
                        .fill(buttonGradient)

                    // Glass border
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear, .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: shadowColor, radius: 15, y: 8)
        }
        .disabled(isLoading)
    }

    private var rsvpIcon: String {
        switch event.rsvpStatus {
        case .notResponded:
            return event.spotsLeft == 0 ? "clock.fill" : "calendar.badge.plus"
        case .going:
            return "checkmark.circle.fill"
        case .maybe:
            return "questionmark.circle.fill"
        case .declined:
            return "xmark.circle.fill"
        case .waitlist:
            return "clock.fill"
        case .pendingVerification:
            return "checkmark.shield.fill"
        }
    }

    private var buttonText: String {
        switch event.rsvpStatus {
        case .notResponded:
            return event.spotsLeft == 0 ? "Join Waitlist" : "RSVP Now"
        case .going:
            return "You're Going!"
        case .maybe:
            return "Maybe Going"
        case .declined:
            return "Not Going"
        case .waitlist:
            return "On Waitlist"
        case .pendingVerification:
            return "Verify to RSVP"
        }
    }

    private var buttonGradient: LinearGradient {
        switch event.rsvpStatus {
        case .notResponded:
            return LinearGradient(
                colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .going:
            return LinearGradient(
                colors: [Color(hex: "2ecc71"), Color(hex: "27ae60")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .maybe:
            return LinearGradient(
                colors: [Color(hex: "f39c12"), Color(hex: "e67e22")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .declined:
            return LinearGradient(
                colors: [Color(hex: "7f8c8d"), Color(hex: "95a5a6")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .waitlist:
            return LinearGradient(
                colors: [Color(hex: "9b59b6"), Color(hex: "8e44ad")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pendingVerification:
            return LinearGradient(
                colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        switch event.rsvpStatus {
        case .notResponded:
            return Color(hex: "f39c12").opacity(0.4)
        case .going:
            return Color(hex: "2ecc71").opacity(0.4)
        case .maybe:
            return Color(hex: "f39c12").opacity(0.3)
        case .declined:
            return Color.gray.opacity(0.2)
        case .waitlist:
            return Color(hex: "9b59b6").opacity(0.3)
        case .pendingVerification:
            return Color(hex: "8b5cf6").opacity(0.4)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EventDetailView(event: ClubEvent.sampleEvents[0])
    }
}
