import Foundation
import ActivityKit

// MARK: - Activity Attributes
// These are shared between the main app and widget extension

// Valet Live Activity
struct ValetActivityAttributes: ActivityAttributes {
    let ticketNumber: String
    let vehicleDescription: String
    let memberId: String

    struct ContentState: Codable, Hashable {
        let status: ValetLiveStatus
        let progressPercent: Double
        let estimatedMinutes: Int?
        let valetName: String?
        let lastUpdated: Date

        enum ValetLiveStatus: String, Codable {
            case requesting = "Requesting"
            case received = "Received"
            case fetching = "Fetching Car"
            case onTheWay = "On the Way"
            case here = "Here"

            var icon: String {
                switch self {
                case .requesting: return "clock.fill"
                case .received: return "checkmark.circle.fill"
                case .fetching: return "figure.walk"
                case .onTheWay: return "car.fill"
                case .here: return "key.fill"
                }
            }

            var progressValue: Double {
                switch self {
                case .requesting: return 0.1
                case .received: return 0.25
                case .fetching: return 0.5
                case .onTheWay: return 0.75
                case .here: return 1.0
                }
            }
        }
    }
}

// Arrival Countdown Live Activity
struct ArrivalActivityAttributes: ActivityAttributes {
    let memberId: String
    let memberName: String
    let guestCount: Int
    let specialRequests: String?

    struct ContentState: Codable, Hashable {
        let etaMinutes: Int
        let status: ArrivalLiveStatus
        let confirmedAt: Date?

        enum ArrivalLiveStatus: String, Codable {
            case notifying = "Notifying Club"
            case confirmed = "Confirmed"
            case almostThere = "Almost There"
            case arrived = "Welcome!"

            var icon: String {
                switch self {
                case .notifying: return "bell.fill"
                case .confirmed: return "checkmark.circle.fill"
                case .almostThere: return "location.fill"
                case .arrived: return "hand.wave.fill"
                }
            }
        }
    }
}

// Clubhouse Activity (while at club)
struct ClubhouseActivityAttributes: ActivityAttributes {
    let memberId: String
    let memberName: String
    let membershipTier: String

    struct ContentState: Codable, Hashable {
        let nextEventTitle: String?
        let nextEventTime: Date?
        let nextEventLocation: String?
        let lockerNumber: String?
        let lockerFloor: String?
        let currentEventCount: Int
        let isAtClubhouse: Bool
        let checkInTime: Date?
    }
}

// Event Countdown Live Activity
struct EventActivityAttributes: ActivityAttributes {
    let eventId: String
    let eventTitle: String
    let location: String
    let category: String
    let imageSystemName: String

    struct ContentState: Codable, Hashable {
        let startTime: Date
        let endTime: Date?
        let minutesUntilStart: Int
        let attendeeCount: Int
        let spotsLeft: Int
        let isStartingSoon: Bool
        let hasStarted: Bool

        var countdownText: String {
            if hasStarted {
                return "Now"
            } else if minutesUntilStart < 60 {
                return "\(minutesUntilStart)m"
            } else {
                let hours = minutesUntilStart / 60
                let mins = minutesUntilStart % 60
                return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            }
        }
    }
}

// Reservation Ready Live Activity
struct ReservationActivityAttributes: ActivityAttributes {
    let reservationId: String
    let title: String
    let location: String
    let partySize: Int

    struct ContentState: Codable, Hashable {
        let scheduledTime: Date
        let status: ReservationLiveStatus
        let minutesUntilReady: Int?
        let tableNumber: String?

        enum ReservationLiveStatus: String, Codable {
            case upcoming = "Upcoming"
            case preparingTable = "Preparing"
            case ready = "Ready"
            case seated = "Seated"

            var icon: String {
                switch self {
                case .upcoming: return "clock.fill"
                case .preparingTable: return "sparkles"
                case .ready: return "bell.fill"
                case .seated: return "checkmark.seal.fill"
                }
            }
        }
    }
}

// Locker Live Activity (while at clubhouse with active locker)
struct LockerActivityAttributes: ActivityAttributes {
    let lockerId: String
    let lockerNumber: String
    let floor: String
    let section: String
    let memberId: String
    let memberName: String

    struct ContentState: Codable, Hashable {
        let accessCode: String
        let assignedTime: Date
        let expiresAt: Date?
        let status: LockerLiveStatus
        let minutesUntilExpiry: Int?
        let showCode: Bool

        var isExpiringSoon: Bool {
            guard let minutes = minutesUntilExpiry else { return false }
            return minutes <= 120 // 2 hours warning
        }

        var expiryText: String {
            guard let minutes = minutesUntilExpiry else { return "No expiry" }
            if minutes < 60 {
                return "\(minutes)m left"
            } else {
                let hours = minutes / 60
                let mins = minutes % 60
                return mins > 0 ? "\(hours)h \(mins)m left" : "\(hours)h left"
            }
        }

        enum LockerLiveStatus: String, Codable {
            case active = "Active"
            case expiringSoon = "Expiring Soon"
            case expired = "Expired"

            var icon: String {
                switch self {
                case .active: return "lock.fill"
                case .expiringSoon: return "exclamationmark.triangle.fill"
                case .expired: return "lock.slash.fill"
                }
            }

            var color: String {
                switch self {
                case .active: return "3498db"
                case .expiringSoon: return "f39c12"
                case .expired: return "e74c3c"
                }
            }
        }
    }
}
