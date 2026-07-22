import Foundation
@preconcurrency import ActivityKit
import Combine
import SwiftUI

// MARK: - Live Activity Manager

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    // MARK: - Published Properties

    @Published var activeValetActivity: Activity<ValetActivityAttributes>?
    @Published var activeArrivalActivity: Activity<ArrivalActivityAttributes>?
    @Published var activeClubhouseActivity: Activity<ClubhouseActivityAttributes>?
    @Published var activeEventActivities: [Activity<EventActivityAttributes>] = []
    @Published var activeReservationActivities: [Activity<ReservationActivityAttributes>] = []
    @Published var activeLockerActivity: Activity<LockerActivityAttributes>?
    @Published var activeFoodOrderActivity: Activity<FoodOrderActivityAttributes>?

    @Published var isLiveActivitySupported: Bool = false

    // MARK: - Private Properties

    private var updateTimers: [String: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        checkLiveActivitySupport()
        observeActivityStates()
    }

    private func checkLiveActivitySupport() {
        isLiveActivitySupported = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private func observeActivityStates() {
        Task {
            for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
                await MainActor.run {
                    self.isLiveActivitySupported = enabled
                }
            }
        }
    }

    // MARK: - Valet Live Activity

    func startValetActivity(request: ValetRequest) async throws {
        guard isLiveActivitySupported else {
            print("Live Activities not supported")
            return
        }
        guard NotificationService.shared.preferences.enableValetLiveActivity else { return }

        // End any existing valet activity
        await endValetActivity()

        let attributes = ValetActivityAttributes(
            ticketNumber: request.ticketNumber,
            vehicleDescription: request.vehicleInfo.displayName,
            memberId: request.memberId
        )

        let initialState = ValetActivityAttributes.ContentState(
            status: .requesting,
            progressPercent: 0.1,
            estimatedMinutes: 10,
            valetName: nil,
            lastUpdated: Date()
        )

        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(600))

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: .token
            )
            self.activeValetActivity = activity
            print("Started valet Live Activity: \(activity.id)")

            // Monitor push token updates
            Task {
                for await token in activity.pushTokenUpdates {
                    let tokenString = token.map { String(format: "%02x", $0) }.joined()
                    await sendActivityPushTokenToServer(activityId: activity.id, token: tokenString, type: "valet")
                }
            }
        } catch {
            print("Failed to start valet activity: \(error)")
            throw error
        }
    }

    func updateValetActivity(status: ValetActivityAttributes.ContentState.ValetLiveStatus, valetName: String? = nil, estimatedMinutes: Int? = nil) async {
        guard let activity = activeValetActivity else { return }

        let newState = ValetActivityAttributes.ContentState(
            status: status,
            progressPercent: status.progressValue,
            estimatedMinutes: estimatedMinutes,
            valetName: valetName ?? activity.content.state.valetName,
            lastUpdated: Date()
        )

        let content = ActivityContent(state: newState, staleDate: Date().addingTimeInterval(600))
        await activity.update(content)

        // End activity after car arrives (with delay for user to see)
        if status == .here {
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                Task {
                    await self.endValetActivity()
                }
            }
        }
    }

    func updateValetActivityFromPush(_ userInfo: [AnyHashable: Any]) {
        guard let statusString = userInfo["status"] as? String,
              let status = ValetActivityAttributes.ContentState.ValetLiveStatus(rawValue: statusString) else {
            return
        }

        let valetName = userInfo["valetName"] as? String
        let estimatedMinutes = userInfo["estimatedMinutes"] as? Int

        Task {
            await updateValetActivity(status: status, valetName: valetName, estimatedMinutes: estimatedMinutes)
        }
    }

    func endValetActivity() async {
        guard let activity = activeValetActivity else { return }

        let finalState = ValetActivityAttributes.ContentState(
            status: .here,
            progressPercent: 1.0,
            estimatedMinutes: 0,
            valetName: activity.content.state.valetName,
            lastUpdated: Date()
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(60))
        )

        self.activeValetActivity = nil
    }

    // MARK: - Arrival Countdown Activity

    func startArrivalActivity(memberId: String, memberName: String, eta: Int, guestCount: Int, specialRequests: String?) async throws {
        guard isLiveActivitySupported else { return }
        guard NotificationService.shared.preferences.enableArrivalLiveActivity else { return }

        await endArrivalActivity()

        let attributes = ArrivalActivityAttributes(
            memberId: memberId,
            memberName: memberName,
            guestCount: guestCount,
            specialRequests: specialRequests
        )

        let initialState = ArrivalActivityAttributes.ContentState(
            etaMinutes: eta,
            status: .notifying,
            confirmedAt: nil
        )

        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(Double(eta * 60) + 300))

        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )

        self.activeArrivalActivity = activity

        // Start countdown timer
        startArrivalCountdownTimer(initialEta: eta)
    }

    private func startArrivalCountdownTimer(initialEta: Int) {
        var remainingMinutes = initialEta

        updateTimers["arrival"]?.invalidate()
        updateTimers["arrival"] = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            remainingMinutes -= 1

            if remainingMinutes <= 0 {
                timer.invalidate()
                guard let strongSelf = self else { return }
                Task { @MainActor in
                    await strongSelf.updateArrivalActivity(eta: 0, status: .arrived)
                    // End after showing welcome message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                        Task {
                            await strongSelf.endArrivalActivity()
                        }
                    }
                }
            } else {
                guard let strongSelf = self else { return }
                let status: ArrivalActivityAttributes.ContentState.ArrivalLiveStatus = remainingMinutes <= 5 ? .almostThere : .confirmed
                Task { @MainActor in
                    await strongSelf.updateArrivalActivity(eta: remainingMinutes, status: status)
                }
            }
        }
    }

    func updateArrivalActivity(eta: Int, status: ArrivalActivityAttributes.ContentState.ArrivalLiveStatus) async {
        guard let activity = activeArrivalActivity else { return }

        let newState = ArrivalActivityAttributes.ContentState(
            etaMinutes: eta,
            status: status,
            confirmedAt: status == .confirmed ? Date() : activity.content.state.confirmedAt
        )

        let content = ActivityContent(state: newState, staleDate: Date().addingTimeInterval(120))
        await activity.update(content)
    }

    func confirmArrival() async {
        await updateArrivalActivity(eta: activeArrivalActivity?.content.state.etaMinutes ?? 0, status: .confirmed)
    }

    func endArrivalActivity() async {
        updateTimers["arrival"]?.invalidate()
        updateTimers["arrival"] = nil

        guard let activity = activeArrivalActivity else { return }

        let finalState = ArrivalActivityAttributes.ContentState(
            etaMinutes: 0,
            status: .arrived,
            confirmedAt: activity.content.state.confirmedAt
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        self.activeArrivalActivity = nil
    }

    // MARK: - Clubhouse Activity

    func startClubhouseActivity(memberId: String, memberName: String, tier: MembershipTier, locker: LockerAssignment?, upcomingEvent: ClubEvent?) async throws {
        guard isLiveActivitySupported else { return }
        guard NotificationService.shared.preferences.enableClubhouseLiveActivity else { return }

        await endClubhouseActivity()

        let attributes = ClubhouseActivityAttributes(
            memberId: memberId,
            memberName: memberName,
            membershipTier: tier.rawValue
        )

        let initialState = ClubhouseActivityAttributes.ContentState(
            nextEventTitle: upcomingEvent?.title,
            nextEventTime: upcomingEvent?.date,
            nextEventLocation: upcomingEvent?.location,
            lockerNumber: locker?.displayNumber,
            lockerFloor: locker?.floor,
            currentEventCount: 0, // Would be populated from EventManager
            isAtClubhouse: true,
            checkInTime: Date()
        )

        // Stale after 4 hours
        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(14400))

        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )

        self.activeClubhouseActivity = activity
    }

    func updateClubhouseActivity(locker: LockerAssignment?, upcomingEvent: ClubEvent?) async {
        guard let activity = activeClubhouseActivity else { return }

        let newState = ClubhouseActivityAttributes.ContentState(
            nextEventTitle: upcomingEvent?.title,
            nextEventTime: upcomingEvent?.date,
            nextEventLocation: upcomingEvent?.location,
            lockerNumber: locker?.displayNumber,
            lockerFloor: locker?.floor,
            currentEventCount: activity.content.state.currentEventCount,
            isAtClubhouse: true,
            checkInTime: activity.content.state.checkInTime
        )

        let content = ActivityContent(state: newState, staleDate: Date().addingTimeInterval(14400))
        await activity.update(content)
    }

    func endClubhouseActivity() async {
        guard let activity = activeClubhouseActivity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activeClubhouseActivity = nil
    }

    // MARK: - Event Countdown Activity

    func startEventActivity(event: ClubEvent) async throws {
        guard isLiveActivitySupported else { return }
        guard NotificationService.shared.preferences.enableEventLiveActivity else { return }

        // Don't start if event already started
        guard event.date > Date() else { return }

        // Check if we already have an activity for this event
        if activeEventActivities.contains(where: { $0.attributes.eventId == event.id.uuidString }) {
            return
        }

        let attributes = EventActivityAttributes(
            eventId: event.id.uuidString,
            eventTitle: event.title,
            location: event.location,
            category: event.category.rawValue,
            imageSystemName: event.imageSystemName
        )

        let minutesUntil = Int(event.date.timeIntervalSinceNow / 60)
        let initialState = EventActivityAttributes.ContentState(
            startTime: event.date,
            endTime: event.endDate,
            minutesUntilStart: max(0, minutesUntil),
            attendeeCount: event.totalSpots - event.spotsLeft,
            spotsLeft: event.spotsLeft,
            isStartingSoon: minutesUntil <= 30,
            hasStarted: false
        )

        let staleDate = event.endDate ?? event.date.addingTimeInterval(7200)
        let content = ActivityContent(state: initialState, staleDate: staleDate)

        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )

        activeEventActivities.append(activity)

        // Start countdown timer
        startEventCountdownTimer(for: event, activity: activity)
    }

    private func startEventCountdownTimer(for event: ClubEvent, activity: Activity<EventActivityAttributes>) {
        let timerId = "event_\(event.id.uuidString)"
        let eventId = event.id

        updateTimers[timerId]?.invalidate()
        updateTimers[timerId] = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            let minutesUntil = Int(event.date.timeIntervalSinceNow / 60)

            // End activity 2 hours after event ends (or starts if no end time)
            let eventEndTime = event.endDate ?? event.date.addingTimeInterval(7200)
            if Date() > eventEndTime.addingTimeInterval(7200) {
                timer.invalidate()
                guard let strongSelf = self else { return }
                Task { @MainActor in
                    await strongSelf.endEventActivity(eventId: eventId)
                }
            } else {
                guard let strongSelf = self else { return }
                Task { @MainActor in
                    await strongSelf.updateEventActivity(
                        activity: activity,
                        event: event,
                        minutesUntil: minutesUntil
                    )
                }
            }
        }
    }

    private func updateEventActivity(activity: Activity<EventActivityAttributes>, event: ClubEvent, minutesUntil: Int) async {
        let newState = EventActivityAttributes.ContentState(
            startTime: event.date,
            endTime: event.endDate,
            minutesUntilStart: max(0, minutesUntil),
            attendeeCount: event.totalSpots - event.spotsLeft,
            spotsLeft: event.spotsLeft,
            isStartingSoon: minutesUntil <= 30 && minutesUntil > 0,
            hasStarted: minutesUntil <= 0
        )

        let staleDate = event.endDate ?? event.date.addingTimeInterval(7200)
        await activity.update(ActivityContent(state: newState, staleDate: staleDate))
    }

    func endEventActivity(eventId: UUID) async {
        let timerId = "event_\(eventId.uuidString)"
        updateTimers[timerId]?.invalidate()
        updateTimers[timerId] = nil

        guard let index = activeEventActivities.firstIndex(where: { $0.attributes.eventId == eventId.uuidString }) else {
            return
        }

        let activity = activeEventActivities[index]
        await activity.end(nil, dismissalPolicy: .immediate)
        activeEventActivities.remove(at: index)
    }

    // MARK: - Reservation Activity

    func startReservationActivity(reservation: Reservation) async throws {
        guard isLiveActivitySupported else { return }
        guard NotificationService.shared.preferences.enableReservationLiveActivity else { return }

        let attributes = ReservationActivityAttributes(
            reservationId: reservation.id.uuidString,
            title: reservation.title,
            location: reservation.location,
            partySize: reservation.guests
        )

        let minutesUntil = Int(reservation.date.timeIntervalSinceNow / 60)
        let initialState = ReservationActivityAttributes.ContentState(
            scheduledTime: reservation.date,
            status: .upcoming,
            minutesUntilReady: max(0, minutesUntil),
            tableNumber: nil
        )

        let content = ActivityContent(state: initialState, staleDate: reservation.date.addingTimeInterval(3600))

        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: .token
        )

        activeReservationActivities.append(activity)

        // Monitor push token updates
        Task {
            for await token in activity.pushTokenUpdates {
                let tokenString = token.map { String(format: "%02x", $0) }.joined()
                await sendActivityPushTokenToServer(activityId: activity.id, token: tokenString, type: "reservation")
            }
        }
    }

    func updateReservationActivityFromPush(_ userInfo: [AnyHashable: Any]) {
        guard let reservationId = userInfo["reservationId"] as? String,
              let statusString = userInfo["status"] as? String,
              let status = ReservationActivityAttributes.ContentState.ReservationLiveStatus(rawValue: statusString) else {
            return
        }

        let tableNumber = userInfo["tableNumber"] as? String

        Task {
            await updateReservationActivity(reservationId: reservationId, status: status, tableNumber: tableNumber)
        }
    }

    func updateReservationActivity(reservationId: String, status: ReservationActivityAttributes.ContentState.ReservationLiveStatus, tableNumber: String?) async {
        guard let activity = activeReservationActivities.first(where: { $0.attributes.reservationId == reservationId }) else {
            return
        }

        let newState = ReservationActivityAttributes.ContentState(
            scheduledTime: activity.content.state.scheduledTime,
            status: status,
            minutesUntilReady: status == .ready ? 0 : activity.content.state.minutesUntilReady,
            tableNumber: tableNumber ?? activity.content.state.tableNumber
        )

        let content = ActivityContent(state: newState, staleDate: Date().addingTimeInterval(3600))
        await activity.update(content)

        // End after seated
        if status == .seated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                Task {
                    await self.endReservationActivity(reservationId: reservationId)
                }
            }
        }
    }

    func endReservationActivity(reservationId: String) async {
        guard let index = activeReservationActivities.firstIndex(where: { $0.attributes.reservationId == reservationId }) else {
            return
        }

        let activity = activeReservationActivities[index]
        await activity.end(nil, dismissalPolicy: .immediate)
        activeReservationActivities.remove(at: index)
    }

    // MARK: - Locker Live Activity

    func startLockerActivity(locker: LockerAssignment, memberName: String) async throws {
        guard isLiveActivitySupported else {
            print("Live Activities not supported")
            return
        }
        guard NotificationService.shared.preferences.enableLockerLiveActivity else { return }

        // End any existing locker activity
        await endLockerActivity()

        let attributes = LockerActivityAttributes(
            lockerId: locker.id.uuidString,
            lockerNumber: locker.displayNumber,
            floor: locker.floor,
            section: locker.section,
            memberId: "",
            memberName: memberName
        )

        let minutesUntilExpiry: Int?
        let status: LockerActivityAttributes.ContentState.LockerLiveStatus
        if let expiresAt = locker.expiresAt {
            let minutes = Int(expiresAt.timeIntervalSinceNow / 60)
            minutesUntilExpiry = max(0, minutes)
            status = minutes <= 120 ? .expiringSoon : .active
        } else {
            minutesUntilExpiry = nil
            status = .active
        }

        let initialState = LockerActivityAttributes.ContentState(
            accessCode: locker.accessCode,
            assignedTime: locker.assignedDate,
            expiresAt: locker.expiresAt,
            status: status,
            minutesUntilExpiry: minutesUntilExpiry,
            showCode: false
        )

        // Stale when locker expires or after 24 hours
        let staleDate = locker.expiresAt ?? Date().addingTimeInterval(86400)
        let content = ActivityContent(state: initialState, staleDate: staleDate)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            self.activeLockerActivity = activity
            print("Started locker Live Activity: \(activity.id)")

            // Start expiration countdown timer
            if locker.expiresAt != nil {
                startLockerExpirationTimer(locker: locker)
            }
        } catch {
            print("Failed to start locker activity: \(error)")
            throw error
        }
    }

    private func startLockerExpirationTimer(locker: LockerAssignment) {
        let timerId = "locker_\(locker.id.uuidString)"

        updateTimers[timerId]?.invalidate()
        updateTimers[timerId] = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            guard let expiresAt = locker.expiresAt else {
                timer.invalidate()
                return
            }

            let minutesUntil = Int(expiresAt.timeIntervalSinceNow / 60)

            if minutesUntil <= 0 {
                timer.invalidate()
                guard let strongSelf = self else { return }
                Task { @MainActor in
                    await strongSelf.updateLockerActivity(locker: locker, status: .expired, minutesUntilExpiry: 0)
                    // End activity after showing expired status
                    DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                        Task {
                            await strongSelf.endLockerActivity()
                        }
                    }
                }
            } else {
                let status: LockerActivityAttributes.ContentState.LockerLiveStatus = minutesUntil <= 120 ? .expiringSoon : .active
                guard let strongSelf = self else { return }
                Task { @MainActor in
                    await strongSelf.updateLockerActivity(locker: locker, status: status, minutesUntilExpiry: minutesUntil)
                }
            }
        }
    }

    func updateLockerActivity(locker: LockerAssignment, status: LockerActivityAttributes.ContentState.LockerLiveStatus? = nil, minutesUntilExpiry: Int? = nil, showCode: Bool? = nil) async {
        guard let activity = activeLockerActivity else { return }

        let currentState = activity.content.state
        let newMinutes = minutesUntilExpiry ?? currentState.minutesUntilExpiry
        let newStatus = status ?? currentState.status

        let newState = LockerActivityAttributes.ContentState(
            accessCode: locker.accessCode,
            assignedTime: currentState.assignedTime,
            expiresAt: locker.expiresAt,
            status: newStatus,
            minutesUntilExpiry: newMinutes,
            showCode: showCode ?? currentState.showCode
        )

        let staleDate = locker.expiresAt ?? Date().addingTimeInterval(86400)
        let content = ActivityContent(state: newState, staleDate: staleDate)
        await activity.update(content)
    }

    func endLockerActivity() async {
        let timerId = activeLockerActivity.map { "locker_\($0.attributes.lockerId)" }
        if let timerId = timerId {
            updateTimers[timerId]?.invalidate()
            updateTimers[timerId] = nil
        }

        guard let activity = activeLockerActivity else { return }

        await activity.end(nil, dismissalPolicy: .immediate)
        self.activeLockerActivity = nil
    }

    var hasActiveLockerActivity: Bool {
        activeLockerActivity != nil
    }

    // MARK: - Food Order Live Activity

    func startFoodOrderActivity(order: FoodOrder) async throws {
        guard isLiveActivitySupported else {
            print("Live Activities not supported")
            return
        }
        guard NotificationService.shared.preferences.enableFoodOrderLiveActivity else { return }

        // End any existing food order activity
        await endFoodOrderActivity()

        let attributes = FoodOrderActivityAttributes(
            orderId: order.id.uuidString,
            location: order.location.displayName,
            itemCount: order.totalItems
        )

        let workingItems: [FoodOrderActivityAttributes.ContentState.WorkingItemState] = order.currentlyWorking.map {
            FoodOrderActivityAttributes.ContentState.WorkingItemState(
                itemName: $0.itemName,
                staffName: $0.staffName,
                staffRole: $0.staffRole.rawValue
            )
        }

        let initialState = FoodOrderActivityAttributes.ContentState(
            status: order.status.rawValue,
            progressPercent: order.status.progressPercent,
            currentlyWorking: workingItems,
            estimatedMinutes: order.estimatedPrepTime,
            deliveredCount: order.items.filter { $0.isDelivered }.count,
            totalCount: order.totalItems
        )

        let content = ActivityContent(state: initialState, staleDate: Date().addingTimeInterval(3600))

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            self.activeFoodOrderActivity = activity
            print("Started food order Live Activity: \(activity.id)")
        } catch {
            print("Failed to start food order activity: \(error)")
            throw error
        }
    }

    func updateFoodOrderActivity(status: FoodOrder.OrderStatus, currentlyWorking: [WorkingItem], estimatedMinutes: Int) async {
        guard let activity = activeFoodOrderActivity else { return }

        let workingItems: [FoodOrderActivityAttributes.ContentState.WorkingItemState] = currentlyWorking.map {
            FoodOrderActivityAttributes.ContentState.WorkingItemState(
                itemName: $0.itemName,
                staffName: $0.staffName,
                staffRole: $0.staffRole.rawValue
            )
        }

        let newState = FoodOrderActivityAttributes.ContentState(
            status: status.rawValue,
            progressPercent: status.progressPercent,
            currentlyWorking: workingItems,
            estimatedMinutes: estimatedMinutes,
            deliveredCount: activity.content.state.deliveredCount,
            totalCount: activity.content.state.totalCount
        )

        let content = ActivityContent(state: newState, staleDate: Date().addingTimeInterval(3600))
        await activity.update(content)

        // End activity a bit after delivery
        if status == .delivered {
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                Task {
                    await self.endFoodOrderActivity()
                }
            }
        }
    }

    func endFoodOrderActivity() async {
        guard let activity = activeFoodOrderActivity else { return }

        let finalState = FoodOrderActivityAttributes.ContentState(
            status: "Delivered",
            progressPercent: 1.0,
            currentlyWorking: [],
            estimatedMinutes: 0,
            deliveredCount: activity.content.state.totalCount,
            totalCount: activity.content.state.totalCount
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(Date().addingTimeInterval(60))
        )

        self.activeFoodOrderActivity = nil
    }

    var hasActiveFoodOrderActivity: Bool {
        activeFoodOrderActivity != nil
    }

    // MARK: - Helper Methods

    private func sendActivityPushTokenToServer(activityId: String, token: String, type: String) async {
        // In production, send this token to your server for push-to-activity updates
        print("Activity push token - Type: \(type), Activity: \(activityId), Token: \(token.prefix(20))...")
    }

    /// End all activities (e.g., on logout)
    func endAllActivities() async {
        await endValetActivity()
        await endArrivalActivity()
        await endClubhouseActivity()
        await endLockerActivity()
        await endFoodOrderActivity()

        for activity in activeEventActivities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeEventActivities.removeAll()

        for activity in activeReservationActivities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activeReservationActivities.removeAll()

        // Clear all timers
        updateTimers.values.forEach { $0.invalidate() }
        updateTimers.removeAll()
    }

    // MARK: - Activity State Checks

    var hasActiveValetActivity: Bool {
        activeValetActivity != nil
    }

    var hasActiveArrivalActivity: Bool {
        activeArrivalActivity != nil
    }

    var hasActiveClubhouseActivity: Bool {
        activeClubhouseActivity != nil
    }

    func hasActiveEventActivity(for eventId: UUID) -> Bool {
        activeEventActivities.contains { $0.attributes.eventId == eventId.uuidString }
    }
}
