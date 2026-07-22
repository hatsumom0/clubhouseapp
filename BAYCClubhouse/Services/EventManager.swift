import SwiftUI
import Combine

// MARK: - Membership Tier

enum MembershipTier: String, CaseIterable {
    case black = "Black"      // BAYC holders - Centurion level
    case platinum = "Platinum" // MAYC holders

    var displayName: String { rawValue }

    var color: Color {
        switch self {
        case .black: return Color(hex: "1a1a1a")
        case .platinum: return Color(hex: "E5E4E2")
        }
    }

    var accentColor: Color {
        switch self {
        case .black: return Color(hex: "f39c12")
        case .platinum: return Color(hex: "8b5cf6")
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .black:
            return [Color(hex: "1a1a1a"), Color(hex: "2d2d2d"), Color(hex: "1a1a1a")]
        case .platinum:
            return [Color(hex: "E5E4E2"), Color(hex: "B4B4B4"), Color(hex: "E5E4E2")]
        }
    }

    var textColor: Color {
        switch self {
        case .black: return .white
        case .platinum: return Color(hex: "1a1a2e")
        }
    }

    var badgeIcon: String {
        switch self {
        case .black: return "crown.fill"
        case .platinum: return "star.fill"
        }
    }
}

// MARK: - Reservation Model

struct Reservation: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let date: Date
    let endDate: Date?
    let location: String
    let locationDetail: String?
    let guests: Int
    let icon: String
    var status: ReservationStatus
    let category: ReservationCategory

    enum ReservationStatus: String {
        case confirmed = "Confirmed"
        case pending = "Pending"
        case cancelled = "Cancelled"

        var color: Color {
            switch self {
            case .confirmed: return .green
            case .pending: return Color(hex: "f39c12")
            case .cancelled: return .red
            }
        }
    }

    enum ReservationCategory: String, CaseIterable {
        case lounge = "Lounge"
        case dining = "Dining"
        case spa = "Spa"
        case fitness = "Fitness"
        case pool = "Pool"

        var color: Color {
            switch self {
            case .lounge: return Color(hex: "9b59b6")
            case .dining: return Color(hex: "e74c3c")
            case .spa: return Color(hex: "1abc9c")
            case .fitness: return Color(hex: "e67e22")
            case .pool: return Color(hex: "3498db")
            }
        }

        var icon: String {
            switch self {
            case .lounge: return "sofa.fill"
            case .dining: return "fork.knife"
            case .spa: return "sparkles"
            case .fitness: return "dumbbell.fill"
            case .pool: return "figure.pool.swim"
            }
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var timeStr = formatter.string(from: date)
        if let end = endDate {
            timeStr += " - \(formatter.string(from: end))"
        }
        return timeStr
    }
}

// MARK: - Event Manager

@MainActor
class EventManager: ObservableObject {
    static let shared = EventManager()

    @Published var events: [ClubEvent] = []
    @Published var mySchedule: [ClubEvent] = [] // Events user is attending
    @Published var reservations: [Reservation] = [] // User's reservations
    @Published var tokenProofVerified: Bool = false
    @Published var isVerifyingToken: Bool = false

    init() {
        loadEvents()
        loadMockReservations()
    }

    private func loadMockReservations() {
        let today = Date()
        let calendar = Calendar.current

        reservations = [
            Reservation(
                id: UUID(),
                title: "Private Lounge",
                description: "Exclusive private lounge booking with premium bottle service. Perfect for small gatherings and celebrations.",
                date: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: today)!,
                endDate: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: today),
                location: "VIP Lounge",
                locationDetail: "2nd Floor, East Wing",
                guests: 4,
                icon: "sofa.fill",
                status: .confirmed,
                category: .lounge
            ),
            Reservation(
                id: UUID(),
                title: "Rooftop Bar Table",
                description: "Reserved table at the rooftop bar with stunning views of the Miami skyline. Complimentary appetizers included.",
                date: calendar.date(byAdding: .day, value: 3, to: today)!.addingTimeInterval(21 * 3600),
                endDate: calendar.date(byAdding: .day, value: 4, to: today)!.addingTimeInterval(0 * 3600),
                location: "Rooftop Bar",
                locationDetail: "5th Floor",
                guests: 6,
                icon: "wineglass.fill",
                status: .pending,
                category: .dining
            ),
            Reservation(
                id: UUID(),
                title: "Personal Training",
                description: "One-on-one training session with our certified personal trainer. Customized workout plan included.",
                date: calendar.date(byAdding: .day, value: 5, to: today)!.addingTimeInterval(8 * 3600),
                endDate: calendar.date(byAdding: .day, value: 5, to: today)!.addingTimeInterval(9 * 3600),
                location: "Fitness Center",
                locationDetail: "3rd Floor, Training Area",
                guests: 1,
                icon: "dumbbell.fill",
                status: .confirmed,
                category: .fitness
            ),
            Reservation(
                id: UUID(),
                title: "Couples Massage",
                description: "Relaxing couples massage in our premium spa suite. Includes aromatherapy and champagne.",
                date: calendar.date(byAdding: .day, value: 7, to: today)!.addingTimeInterval(14 * 3600),
                endDate: calendar.date(byAdding: .day, value: 7, to: today)!.addingTimeInterval(15.5 * 3600),
                location: "Spa & Wellness Center",
                locationDetail: "4th Floor, Couples Suite",
                guests: 2,
                icon: "sparkles",
                status: .confirmed,
                category: .spa
            )
        ]
    }

    // MARK: - Reservation Functions

    func cancelReservation(_ reservationId: UUID) {
        guard let index = reservations.firstIndex(where: { $0.id == reservationId }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            reservations[index].status = .cancelled
        }
    }

    func removeReservation(_ reservationId: UUID) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            reservations.removeAll { $0.id == reservationId }
        }
    }

    var activeReservations: [Reservation] {
        reservations.filter { $0.status != .cancelled && $0.date > Date().addingTimeInterval(-3600) }
            .sorted { $0.date < $1.date }
    }

    private func loadEvents() {
        events = ClubEvent.sampleEvents
        // Filter events user is already attending
        updateMySchedule()
    }

    private func updateMySchedule() {
        mySchedule = events.filter { $0.rsvpStatus == .going || $0.rsvpStatus == .maybe }
            .sorted { $0.date < $1.date }
    }

    // MARK: - RSVP Functions

    func rsvp(to eventId: UUID, status: ClubEvent.RSVPStatus) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }
        let event = events[index]
        let previousStatus = event.rsvpStatus

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Update spots based on status change
            updateSpotsForRSVPChange(eventIndex: index, from: previousStatus, to: status)

            events[index].rsvpStatus = status
            updateMySchedule()
        }

        // Handle notifications based on status
        if status == .going || status == .maybe {
            // Schedule event reminders
            NotificationService.shared.scheduleEventReminders(for: event)
        } else {
            // Cancel event reminders if declining
            NotificationService.shared.cancelEventReminders(for: eventId)

            // End any active Live Activity for this event
            Task {
                await LiveActivityManager.shared.endEventActivity(eventId: eventId)
            }
        }

        // Persist to UserDefaults
        saveRSVPStatus(eventId: eventId, status: status)
    }

    /// Updates spotsLeft when RSVP status changes
    private func updateSpotsForRSVPChange(eventIndex: Int, from previousStatus: ClubEvent.RSVPStatus, to newStatus: ClubEvent.RSVPStatus) {
        let wasConfirmed = previousStatus == .going
        let isNowConfirmed = newStatus == .going

        // If status didn't change in terms of confirmation, no spot change needed
        if wasConfirmed == isNowConfirmed { return }

        if isNowConfirmed {
            // User is confirming attendance - reduce available spots
            if events[eventIndex].spotsLeft > 0 {
                events[eventIndex].spotsLeft -= 1
            }
        } else {
            // User is no longer confirmed - release their spot
            events[eventIndex].spotsLeft += 1
            // Ensure we don't exceed total spots
            if events[eventIndex].spotsLeft > events[eventIndex].totalSpots {
                events[eventIndex].spotsLeft = events[eventIndex].totalSpots
            }
        }
    }

    /// Check if spots are available for an event
    func hasSpotsAvailable(for eventId: UUID) -> Bool {
        guard let event = events.first(where: { $0.id == eventId }) else { return false }
        // If user is already going, they have a spot
        if event.rsvpStatus == .going { return true }
        return event.spotsLeft > 0
    }

    /// Check if event is fully booked
    func isEventFullyBooked(_ eventId: UUID) -> Bool {
        guard let event = events.first(where: { $0.id == eventId }) else { return true }
        return event.spotsLeft <= 0 && event.rsvpStatus != .going
    }

    func addToSchedule(_ event: ClubEvent) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        let previousStatus = events[index].rsvpStatus

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Update spots (going from previous status to .going)
            updateSpotsForRSVPChange(eventIndex: index, from: previousStatus, to: .going)

            events[index].rsvpStatus = .going
            updateMySchedule()
        }

        // Schedule event reminders
        NotificationService.shared.scheduleEventReminders(for: event)

        saveRSVPStatus(eventId: event.id, status: .going)
    }

    func removeFromSchedule(_ eventId: UUID) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else { return }
        let previousStatus = events[index].rsvpStatus

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Update spots (going from previous status to .notResponded)
            updateSpotsForRSVPChange(eventIndex: index, from: previousStatus, to: .notResponded)

            events[index].rsvpStatus = .notResponded
            updateMySchedule()
        }

        // Cancel event reminders
        NotificationService.shared.cancelEventReminders(for: eventId)

        // End any active Live Activity for this event
        Task {
            await LiveActivityManager.shared.endEventActivity(eventId: eventId)
        }

        saveRSVPStatus(eventId: eventId, status: .notResponded)
    }

    func getEvent(by id: UUID) -> ClubEvent? {
        events.first { $0.id == id }
    }

    func getEventByTitle(_ title: String) -> ClubEvent? {
        events.first { $0.title.lowercased().contains(title.lowercased()) }
    }

    // MARK: - Live Activity Functions

    /// Start a Live Activity countdown for an event
    func startEventCountdown(_ event: ClubEvent) {
        Task {
            try? await LiveActivityManager.shared.startEventActivity(event: event)
        }
    }

    /// End a Live Activity for an event
    func endEventCountdown(_ eventId: UUID) {
        Task {
            await LiveActivityManager.shared.endEventActivity(eventId: eventId)
        }
    }

    /// Check if there's an active Live Activity for an event
    func hasActiveEventActivity(_ eventId: UUID) -> Bool {
        LiveActivityManager.shared.hasActiveEventActivity(for: eventId)
    }

    // MARK: - TokenProof Verification

    func verifyTokenProof(for event: ClubEvent, userTier: MembershipTier, completion: @escaping (Bool) -> Void) {
        isVerifyingToken = true

        // Simulate TokenProof verification delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isVerifyingToken = false

            // Check if user's tier meets event requirement
            let verified: Bool
            if let requiredTier = event.requiredMembershipTier {
                switch requiredTier {
                case .black:
                    verified = userTier == .black
                case .platinum:
                    verified = true // Platinum events allow both tiers
                }
            } else {
                verified = true // No tier requirement
            }

            self?.tokenProofVerified = verified
            completion(verified)
        }
    }

    // MARK: - Persistence

    private func saveRSVPStatus(eventId: UUID, status: ClubEvent.RSVPStatus) {
        var savedRSVPs = UserDefaults.standard.dictionary(forKey: "event_rsvps") as? [String: String] ?? [:]
        savedRSVPs[eventId.uuidString] = status.rawValue
        UserDefaults.standard.set(savedRSVPs, forKey: "event_rsvps")
    }

    func loadSavedRSVPs() {
        guard let savedRSVPs = UserDefaults.standard.dictionary(forKey: "event_rsvps") as? [String: String] else { return }

        for (eventIdString, statusString) in savedRSVPs {
            guard let eventId = UUID(uuidString: eventIdString),
                  let status = ClubEvent.RSVPStatus(rawValue: statusString),
                  let index = events.firstIndex(where: { $0.id == eventId }) else { continue }

            // Update spots for confirmed attendees (going from .notResponded to saved status)
            let previousStatus = events[index].rsvpStatus
            updateSpotsForRSVPChange(eventIndex: index, from: previousStatus, to: status)

            events[index].rsvpStatus = status
        }
        updateMySchedule()
    }
}

// MARK: - TokenProof Service (Mock)

class TokenProofService {
    static let shared = TokenProofService()

    struct VerificationResult {
        let isEligible: Bool
        let tokenId: String?
        let collectionName: String?
    }

    func verifyEligibility(
        walletAddress: String,
        requiredCollection: String,
        completion: @escaping (VerificationResult) -> Void
    ) {
        // Simulate TokenProof API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Mock: Always return eligible for demo
            completion(VerificationResult(
                isEligible: true,
                tokenId: "1234",
                collectionName: requiredCollection
            ))
        }
    }

    func openTokenProofApp(for eventId: String) {
        // In production, this would open the TokenProof app via deep link
        // URL scheme: tokenproof://verify?event=\(eventId)
        print("Opening TokenProof for event: \(eventId)")
    }
}
