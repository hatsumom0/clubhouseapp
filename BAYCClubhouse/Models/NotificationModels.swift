import Foundation
import ActivityKit

// MARK: - Notification Preferences

struct NotificationPreferences: Codable {
    // Push notification toggles
    var eventReminders: Bool = true
    var eventReminderTiming: [ReminderTiming] = [.oneHour, .fifteenMinutes]
    var reservationConfirmations: Bool = true
    var memberOffers: Bool = true
    var clubAnnouncements: Bool = true
    var tableReadyAlerts: Bool = true
    var valetUpdates: Bool = true
    var rsvpUpdates: Bool = true
    var lockerExpirationWarnings: Bool = true

    // Live Activity toggles
    var enableValetLiveActivity: Bool = true
    var enableArrivalLiveActivity: Bool = true
    var enableEventLiveActivity: Bool = true
    var enableClubhouseLiveActivity: Bool = true
    var enableReservationLiveActivity: Bool = true
    var enableLockerLiveActivity: Bool = true
    var enableFoodOrderLiveActivity: Bool = true

    // Quiet hours
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()

    enum ReminderTiming: String, Codable, CaseIterable, Identifiable {
        case oneDay = "1_day"
        case oneHour = "1_hour"
        case thirtyMinutes = "30_min"
        case fifteenMinutes = "15_min"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .oneDay: return "1 day before"
            case .oneHour: return "1 hour before"
            case .thirtyMinutes: return "30 minutes before"
            case .fifteenMinutes: return "15 minutes before"
            }
        }

        var timeInterval: TimeInterval {
            switch self {
            case .oneDay: return 86400
            case .oneHour: return 3600
            case .thirtyMinutes: return 1800
            case .fifteenMinutes: return 900
            }
        }
    }
}

// MARK: - Notification Payload

struct BAYCNotificationPayload: Codable {
    let type: NotificationType
    let title: String
    let body: String
    let data: NotificationData?

    enum NotificationType: String, Codable {
        case eventReminder = "event_reminder"
        case reservationConfirmation = "reservation_confirmation"
        case memberOffer = "member_offer"
        case clubAnnouncement = "club_announcement"
        case tableReady = "table_ready"
        case valetUpdate = "valet_update"
        case rsvpUpdate = "rsvp_update"
        case lockerExpiration = "locker_expiration"
        case arrivalConfirmation = "arrival_confirmation"
    }

    struct NotificationData: Codable {
        let eventId: String?
        let reservationId: String?
        let valetTicket: String?
        let lockerId: String?
        let deepLink: String?
        let imageUrl: String?
    }
}

// MARK: - Local Notification Identifiers

enum LocalNotificationIdentifier {
    static func eventReminder(eventId: UUID, timing: NotificationPreferences.ReminderTiming) -> String {
        "event_reminder_\(eventId.uuidString)_\(timing.rawValue)"
    }

    static func lockerExpiration(lockerId: UUID) -> String {
        "locker_expiration_\(lockerId.uuidString)"
    }

    static func reservationReminder(reservationId: UUID) -> String {
        "reservation_reminder_\(reservationId.uuidString)"
    }

    static func tableReady(reservationId: UUID) -> String {
        "table_ready_\(reservationId.uuidString)"
    }
}

// MARK: - Notification Categories

enum NotificationCategory: String {
    case eventReminder = "EVENT_REMINDER"
    case reservationReminder = "RESERVATION_REMINDER"
    case valetUpdate = "VALET_UPDATE"
    case lockerExpiration = "LOCKER_EXPIRATION"
    case tableReady = "TABLE_READY"
    case clubAnnouncement = "CLUB_ANNOUNCEMENT"
}

// MARK: - Notification Actions

enum NotificationAction: String {
    // Event actions
    case viewEvent = "VIEW_EVENT"
    case cancelRSVP = "CANCEL_RSVP"

    // Valet actions
    case viewValetStatus = "VIEW_VALET_STATUS"
    case cancelValet = "CANCEL_VALET"

    // Locker actions
    case viewLocker = "VIEW_LOCKER"
    case renewLocker = "RENEW_LOCKER"

    // Reservation actions
    case viewReservation = "VIEW_RESERVATION"
    case checkIn = "CHECK_IN"
}

// MARK: - Activity Attributes

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

// Food Order Live Activity
struct FoodOrderActivityAttributes: ActivityAttributes {
    let orderId: String
    let location: String
    let itemCount: Int

    struct ContentState: Codable, Hashable {
        let status: String
        let progressPercent: Double
        let currentlyWorking: [WorkingItemState]
        let estimatedMinutes: Int
        let deliveredCount: Int
        let totalCount: Int

        struct WorkingItemState: Codable, Hashable {
            let itemName: String
            let staffName: String
            let staffRole: String

            var emoji: String {
                switch staffRole.lowercased() {
                case "chef": return "👨‍🍳"
                case "bartender": return "🍸"
                case "server": return "🧑‍🍳"
                default: return "👤"
                }
            }
        }

        var statusIcon: String {
            switch status {
            case "Order Received": return "checkmark.circle.fill"
            case "Working On It": return "flame.fill"
            case "On the Way": return "figure.walk"
            case "Delivered": return "hand.thumbsup.fill"
            default: return "circle"
            }
        }

        var statusColor: String {
            switch status {
            case "Order Received": return "3498db"
            case "Working On It": return "f39c12"
            case "On the Way": return "9b59b6"
            case "Delivered": return "27ae60"
            default: return "95a5a6"
            }
        }
    }
}
