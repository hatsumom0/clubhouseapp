import Foundation
import UserNotifications
import UIKit
import Combine

// MARK: - Notification Service

@MainActor
class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()

    // MARK: - Published Properties

    @Published var isAuthorized: Bool = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var deviceToken: String?
    @Published var preferences: NotificationPreferences

    // MARK: - Private Properties

    private let notificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private override init() {
        // Load saved preferences
        if let data = UserDefaults.standard.data(forKey: "notificationPreferences"),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            self.preferences = prefs
        } else {
            self.preferences = NotificationPreferences()
        }

        super.init()
        setupNotificationCategories()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound, .providesAppNotificationSettings]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            if granted {
                await MainActor.run {
                    registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { settings in
            Task { @MainActor in
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Device Token Management

    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString

        // Send to backend for storage
        Task {
            await registerDeviceWithBackend(token: tokenString)
        }
    }

    private func registerDeviceWithBackend(token: String) async {
        // In production, this would send the token to your server
        print("Device token registered: \(token.prefix(20))...")
    }

    // MARK: - Notification Categories & Actions

    private func setupNotificationCategories() {
        // Event Reminder Category
        let viewEventAction = UNNotificationAction(
            identifier: NotificationAction.viewEvent.rawValue,
            title: "View Event",
            options: [.foreground]
        )
        let cancelRSVPAction = UNNotificationAction(
            identifier: NotificationAction.cancelRSVP.rawValue,
            title: "Cancel RSVP",
            options: [.destructive]
        )
        let eventCategory = UNNotificationCategory(
            identifier: NotificationCategory.eventReminder.rawValue,
            actions: [viewEventAction, cancelRSVPAction],
            intentIdentifiers: [],
            options: []
        )

        // Valet Update Category
        let viewValetAction = UNNotificationAction(
            identifier: NotificationAction.viewValetStatus.rawValue,
            title: "View Status",
            options: [.foreground]
        )
        let valetCategory = UNNotificationCategory(
            identifier: NotificationCategory.valetUpdate.rawValue,
            actions: [viewValetAction],
            intentIdentifiers: [],
            options: []
        )

        // Locker Expiration Category
        let viewLockerAction = UNNotificationAction(
            identifier: NotificationAction.viewLocker.rawValue,
            title: "View Locker",
            options: [.foreground]
        )
        let renewLockerAction = UNNotificationAction(
            identifier: NotificationAction.renewLocker.rawValue,
            title: "Renew",
            options: [.foreground]
        )
        let lockerCategory = UNNotificationCategory(
            identifier: NotificationCategory.lockerExpiration.rawValue,
            actions: [viewLockerAction, renewLockerAction],
            intentIdentifiers: [],
            options: []
        )

        // Table Ready Category
        let checkInAction = UNNotificationAction(
            identifier: NotificationAction.checkIn.rawValue,
            title: "Check In",
            options: [.foreground]
        )
        let tableReadyCategory = UNNotificationCategory(
            identifier: NotificationCategory.tableReady.rawValue,
            actions: [checkInAction],
            intentIdentifiers: [],
            options: []
        )

        // Reservation Reminder Category
        let viewReservationAction = UNNotificationAction(
            identifier: NotificationAction.viewReservation.rawValue,
            title: "View Reservation",
            options: [.foreground]
        )
        let reservationCategory = UNNotificationCategory(
            identifier: NotificationCategory.reservationReminder.rawValue,
            actions: [viewReservationAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            eventCategory,
            valetCategory,
            lockerCategory,
            tableReadyCategory,
            reservationCategory
        ])
    }

    // MARK: - Event Reminder Scheduling

    func scheduleEventReminders(for event: ClubEvent) {
        guard preferences.eventReminders else { return }

        for timing in preferences.eventReminderTiming {
            let triggerDate = event.date.addingTimeInterval(-timing.timeInterval)
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Event Reminder"
            content.body = "\(event.title) starts \(timing.displayName.replacingOccurrences(of: " before", with: ""))"
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.eventReminder.rawValue
            content.userInfo = [
                "type": BAYCNotificationPayload.NotificationType.eventReminder.rawValue,
                "eventId": event.id.uuidString,
                "deepLink": "bayc://event/\(event.id.uuidString)"
            ]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                repeats: false
            )

            let identifier = LocalNotificationIdentifier.eventReminder(eventId: event.id, timing: timing)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            notificationCenter.add(request) { error in
                if let error = error {
                    print("Failed to schedule event reminder: \(error)")
                }
            }
        }
    }

    func cancelEventReminders(for eventId: UUID) {
        let identifiers = NotificationPreferences.ReminderTiming.allCases.map {
            LocalNotificationIdentifier.eventReminder(eventId: eventId, timing: $0)
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Locker Expiration Warning

    func scheduleLockerExpirationWarning(locker: LockerAssignment) {
        guard preferences.lockerExpirationWarnings,
              let expiresAt = locker.expiresAt else { return }

        // Warn 2 hours before expiration
        let warningTime = expiresAt.addingTimeInterval(-7200)
        guard warningTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Locker Expiring Soon"
        content.body = "Your locker \(locker.displayNumber) expires in 2 hours."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.lockerExpiration.rawValue
        content.userInfo = [
            "type": BAYCNotificationPayload.NotificationType.lockerExpiration.rawValue,
            "lockerId": locker.id.uuidString,
            "deepLink": "bayc://access/locker"
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: warningTime),
            repeats: false
        )

        let identifier = LocalNotificationIdentifier.lockerExpiration(lockerId: locker.id)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule locker expiration: \(error)")
            }
        }
    }

    func cancelLockerExpirationWarning(lockerId: UUID) {
        let identifier = LocalNotificationIdentifier.lockerExpiration(lockerId: lockerId)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Reservation Reminders

    func scheduleReservationReminder(reservation: Reservation) {
        guard preferences.reservationConfirmations else { return }

        // Remind 30 minutes before
        let reminderTime = reservation.date.addingTimeInterval(-1800)
        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Reservation Reminder"
        content.body = "Your \(reservation.title) starts in 30 minutes at \(reservation.location)"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.reservationReminder.rawValue
        content.userInfo = [
            "type": BAYCNotificationPayload.NotificationType.reservationConfirmation.rawValue,
            "reservationId": reservation.id.uuidString,
            "deepLink": "bayc://reservation/\(reservation.id.uuidString)"
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime),
            repeats: false
        )

        let identifier = LocalNotificationIdentifier.reservationReminder(reservationId: reservation.id)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule reservation reminder: \(error)")
            }
        }
    }

    func cancelReservationReminder(reservationId: UUID) {
        let identifier = LocalNotificationIdentifier.reservationReminder(reservationId: reservationId)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Immediate Notifications

    func sendTableReadyNotification(reservationId: UUID, tableNumber: String?, location: String) {
        guard preferences.tableReadyAlerts else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your Table is Ready!"
        if let table = tableNumber {
            content.body = "Table \(table) at \(location) is ready for you."
        } else {
            content.body = "Your table at \(location) is ready for you."
        }
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.tableReady.rawValue
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "type": BAYCNotificationPayload.NotificationType.tableReady.rawValue,
            "reservationId": reservationId.uuidString,
            "deepLink": "bayc://reservation/\(reservationId.uuidString)"
        ]

        let identifier = LocalNotificationIdentifier.tableReady(reservationId: reservationId)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        notificationCenter.add(request)
    }

    func sendValetUpdateNotification(ticketNumber: String, status: String, message: String) {
        guard preferences.valetUpdates else { return }

        let content = UNMutableNotificationContent()
        content.title = "Valet Update - \(ticketNumber)"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.valetUpdate.rawValue
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "type": BAYCNotificationPayload.NotificationType.valetUpdate.rawValue,
            "valetTicket": ticketNumber,
            "deepLink": "bayc://access/valet"
        ]

        let request = UNNotificationRequest(
            identifier: "valet_\(ticketNumber)_\(status)",
            content: content,
            trigger: nil
        )

        notificationCenter.add(request)
    }

    // MARK: - Space Booking Notifications

    func scheduleSpaceBookingReminder(booking: SpaceBooking) {
        // Remind 30 minutes before
        let reminderTime = booking.startTime.addingTimeInterval(-1800)
        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Space Booking Reminder"
        content.body = "Your \(booking.displayName) booking starts in 30 minutes"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.reservationReminder.rawValue
        content.userInfo = [
            "type": "spaceBookingReminder",
            "bookingId": booking.id.uuidString,
            "deepLink": "bayc://booking/\(booking.id.uuidString)"
        ]

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime),
            repeats: false
        )

        let identifier = "spaceBooking_\(booking.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule space booking reminder: \(error)")
            }
        }
    }

    func cancelSpaceBookingReminder(bookingId: UUID) {
        let identifier = "spaceBooking_\(bookingId.uuidString)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Generic Local Notification

    func sendLocalNotification(title: String, body: String, categoryIdentifier: String = "") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if !categoryIdentifier.isEmpty {
            content.categoryIdentifier = categoryIdentifier
        }

        let identifier = "local_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        notificationCenter.add(request)
    }

    // MARK: - Food Order Notifications

    func sendFoodOrderNotification(orderId: UUID, status: FoodOrder.OrderStatus, message: String? = nil) {
        let content = UNMutableNotificationContent()

        switch status {
        case .received:
            content.title = "Order Received"
            content.body = message ?? "We've received your order and are getting it ready!"
        case .preparing:
            content.title = "Preparing Your Order"
            content.body = message ?? "Our team is working on your order"
        case .enRoute:
            content.title = "Order On The Way"
            content.body = message ?? "Your order is being delivered to you!"
        case .delivered:
            content.title = "Order Delivered"
            content.body = message ?? "Enjoy your order!"
        default:
            return
        }

        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "type": "foodOrderUpdate",
            "orderId": orderId.uuidString,
            "deepLink": "bayc://order/\(orderId.uuidString)"
        ]

        let identifier = "foodOrder_\(orderId.uuidString)_\(status.rawValue)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        notificationCenter.add(request)
    }

    // MARK: - Preferences Management

    func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "notificationPreferences")
        }
    }

    // MARK: - Quiet Hours Check

    func isInQuietHours() -> Bool {
        guard preferences.quietHoursEnabled else { return false }

        let now = Date()
        let calendar = Calendar.current

        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let startComponents = calendar.dateComponents([.hour, .minute], from: preferences.quietHoursStart)
        let endComponents = calendar.dateComponents([.hour, .minute], from: preferences.quietHoursEnd)

        guard let nowMinutes = nowComponents.hour.map({ $0 * 60 + (nowComponents.minute ?? 0) }),
              let startMinutes = startComponents.hour.map({ $0 * 60 + (startComponents.minute ?? 0) }),
              let endMinutes = endComponents.hour.map({ $0 * 60 + (endComponents.minute ?? 0) }) else {
            return false
        }

        if startMinutes <= endMinutes {
            // Same day range (e.g., 9am to 5pm)
            return nowMinutes >= startMinutes && nowMinutes < endMinutes
        } else {
            // Overnight range (e.g., 10pm to 8am)
            return nowMinutes >= startMinutes || nowMinutes < endMinutes
        }
    }

    // MARK: - Push Notification Handling

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
        guard let type = userInfo["type"] as? String else {
            completion(.noData)
            return
        }

        switch type {
        case BAYCNotificationPayload.NotificationType.valetUpdate.rawValue:
            LiveActivityManager.shared.updateValetActivityFromPush(userInfo)

        case BAYCNotificationPayload.NotificationType.tableReady.rawValue:
            LiveActivityManager.shared.updateReservationActivityFromPush(userInfo)

        case BAYCNotificationPayload.NotificationType.eventReminder.rawValue:
            // Refresh event data if needed
            break

        default:
            break
        }

        completion(.newData)
    }

    // MARK: - Clear All Notifications

    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    func clearDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        Task { @MainActor in
            // Handle action buttons
            switch actionIdentifier {
            case NotificationAction.viewEvent.rawValue,
                 NotificationAction.viewValetStatus.rawValue,
                 NotificationAction.viewLocker.rawValue,
                 NotificationAction.viewReservation.rawValue,
                 NotificationAction.checkIn.rawValue:
                // Handle deep linking
                if let deepLink = userInfo["deepLink"] as? String,
                   let url = URL(string: deepLink) {
                    await UIApplication.shared.open(url)
                }

            case NotificationAction.cancelRSVP.rawValue:
                if let eventIdString = userInfo["eventId"] as? String,
                   let eventId = UUID(uuidString: eventIdString) {
                    // Cancel RSVP through EventManager
                    print("Would cancel RSVP for event: \(eventId)")
                }

            case NotificationAction.cancelValet.rawValue:
                // Cancel valet through ClubAccessService
                ClubAccessService.shared.cancelValetRequest()

            case UNNotificationDefaultActionIdentifier:
                // User tapped the notification itself
                if let deepLink = userInfo["deepLink"] as? String,
                   let url = URL(string: deepLink) {
                    await UIApplication.shared.open(url)
                }

            default:
                break
            }
        }

        completionHandler()
    }
}
