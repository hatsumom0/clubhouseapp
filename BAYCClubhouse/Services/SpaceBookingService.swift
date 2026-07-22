import Foundation
import SwiftUI
import Combine

// MARK: - Space Booking Service

@MainActor
class SpaceBookingService: ObservableObject {
    static let shared = SpaceBookingService()

    // MARK: - Published Properties

    @Published var currentBooking: SpaceBooking?
    @Published var upcomingBookings: [SpaceBooking] = []
    @Published var pastBookings: [SpaceBooking] = []
    @Published var availableCabanas: [AvailableSpace] = AvailableSpace.sampleCabanas
    @Published var availableMeetingRooms: [AvailableSpace] = AvailableSpace.sampleMeetingRooms
    @Published var isLoading: Bool = false

    // MARK: - Initialization

    private init() {
        loadPersistedBookings()
    }

    // MARK: - Booking Functions

    /// Book a space (cabana or meeting room)
    func bookSpace(
        space: AvailableSpace,
        date: Date,
        startTime: Date,
        endTime: Date,
        guestCount: Int,
        specialRequests: String? = nil
    ) -> SpaceBooking {
        let booking = SpaceBooking(
            spaceType: space.spaceType,
            spaceName: space.spaceName,
            spaceNumber: space.spaceNumber,
            floor: space.floor,
            date: date,
            startTime: startTime,
            endTime: endTime,
            guestCount: guestCount,
            status: .confirmed,
            specialRequests: specialRequests,
            totalCost: space.spaceType.hourlyRate * (endTime.timeIntervalSince(startTime) / 3600)
        )

        // Set as current if it's today and within the time window
        if Calendar.current.isDateInToday(date) {
            currentBooking = booking
        } else {
            upcomingBookings.append(booking)
            upcomingBookings.sort { $0.startTime < $1.startTime }
        }

        savePersistedBookings()

        // Schedule notification reminder
        NotificationService.shared.scheduleSpaceBookingReminder(booking: booking)

        return booking
    }

    /// Activate a booking (when member checks in)
    func activateBooking(_ bookingId: UUID) {
        if var booking = currentBooking, booking.id == bookingId {
            booking.status = .active
            currentBooking = booking
            savePersistedBookings()
        } else if let index = upcomingBookings.firstIndex(where: { $0.id == bookingId }) {
            var booking = upcomingBookings.remove(at: index)
            booking.status = .active
            currentBooking = booking
            savePersistedBookings()
        }
    }

    /// Cancel a booking
    func cancelBooking(_ bookingId: UUID) {
        if currentBooking?.id == bookingId {
            if var booking = currentBooking {
                booking.status = .cancelled
                pastBookings.insert(booking, at: 0)
            }
            currentBooking = nil
        } else if let index = upcomingBookings.firstIndex(where: { $0.id == bookingId }) {
            var booking = upcomingBookings.remove(at: index)
            booking.status = .cancelled
            pastBookings.insert(booking, at: 0)
        }

        savePersistedBookings()

        // Cancel notification
        NotificationService.shared.cancelSpaceBookingReminder(bookingId: bookingId)
    }

    /// Complete/checkout a booking
    func checkOut(_ bookingId: UUID, paymentMethod: PaymentMethod, tipPercent: Double = 0) {
        guard var booking = currentBooking, booking.id == bookingId else { return }

        booking.status = .completed

        // Calculate final cost with any tab charges
        let tip = (booking.baseCost + booking.tabTotal) * (tipPercent / 100)
        booking.totalCost = booking.baseCost + booking.tabTotal + tip

        pastBookings.insert(booking, at: 0)
        currentBooking = nil

        savePersistedBookings()

        // Process payment (simulated)
        processPayment(amount: booking.totalCost, method: paymentMethod)
    }

    /// Add charges to current booking's tab
    func addToTab(_ bookingId: UUID, amount: Double) {
        guard var booking = currentBooking, booking.id == bookingId else { return }
        booking.tabTotal += amount
        currentBooking = booking
        savePersistedBookings()
    }

    // MARK: - Availability Functions

    /// Get available time slots for a space type on a given date
    func getAvailability(for spaceType: SpaceBooking.SpaceType, on date: Date) -> [TimeSlot] {
        var slots: [TimeSlot] = []
        let calendar = Calendar.current

        // Generate time slots from 8 AM to 10 PM
        guard let startOfDay = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date),
              let endOfDay = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: date) else {
            return slots
        }

        var currentSlotStart = startOfDay
        // Using 1 hour slots via calendar.date(byAdding: .hour, ...)

        while currentSlotStart < endOfDay {
            guard let slotEnd = calendar.date(byAdding: .hour, value: 1, to: currentSlotStart) else { break }

            // Check if slot is in the past
            let isPast = currentSlotStart < Date()

            // Simulate some booked slots (random for demo)
            let isBooked = Int.random(in: 1...10) <= 2  // 20% chance booked

            let slot = TimeSlot(
                startTime: currentSlotStart,
                endTime: slotEnd,
                isAvailable: !isPast && !isBooked
            )
            slots.append(slot)

            currentSlotStart = slotEnd
        }

        return slots
    }

    /// Get available spaces of a type
    func getAvailableSpaces(type: SpaceBooking.SpaceType, date: Date, startTime: Date, endTime: Date) -> [AvailableSpace] {
        switch type {
        case .cabana:
            // Filter out any cabanas that are already booked (simplified)
            return availableCabanas
        case .meetingRoom:
            return availableMeetingRooms
        }
    }

    // MARK: - Payment (Simulated)

    private func processPayment(amount: Double, method: PaymentMethod) {
        // In production, this would integrate with payment processors
        print("Processing \(method.rawValue) payment of $\(String(format: "%.2f", amount))")

        // Send confirmation notification
        NotificationService.shared.sendLocalNotification(
            title: "Payment Confirmed",
            body: "Your payment of $\(String(format: "%.2f", amount)) via \(method.rawValue) was successful.",
            categoryIdentifier: "PAYMENT"
        )
    }

    // MARK: - Persistence

    private func savePersistedBookings() {
        if let booking = currentBooking,
           let data = try? JSONEncoder().encode(booking) {
            UserDefaults.standard.set(data, forKey: "currentSpaceBooking")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentSpaceBooking")
        }

        if let data = try? JSONEncoder().encode(upcomingBookings) {
            UserDefaults.standard.set(data, forKey: "upcomingSpaceBookings")
        }

        if let data = try? JSONEncoder().encode(Array(pastBookings.prefix(10))) {
            UserDefaults.standard.set(data, forKey: "pastSpaceBookings")
        }
    }

    private func loadPersistedBookings() {
        if let data = UserDefaults.standard.data(forKey: "currentSpaceBooking"),
           let booking = try? JSONDecoder().decode(SpaceBooking.self, from: data) {
            // Only restore if not expired
            if booking.endTime > Date() && booking.status != .completed && booking.status != .cancelled {
                currentBooking = booking
            }
        }

        if let data = UserDefaults.standard.data(forKey: "upcomingSpaceBookings"),
           let bookings = try? JSONDecoder().decode([SpaceBooking].self, from: data) {
            upcomingBookings = bookings.filter { $0.startTime > Date() }
        }

        if let data = UserDefaults.standard.data(forKey: "pastSpaceBookings"),
           let bookings = try? JSONDecoder().decode([SpaceBooking].self, from: data) {
            pastBookings = bookings
        }
    }

    // MARK: - Helper Functions

    /// Check if member has an active booking they can order food to
    var hasActiveBookingForFoodDelivery: Bool {
        guard let booking = currentBooking else { return false }
        return booking.isActive && (booking.spaceType == .cabana || booking.spaceType == .meetingRoom)
    }

    /// Get order location for current booking
    var currentBookingAsOrderLocation: OrderLocation? {
        guard let booking = currentBooking, booking.isActive else { return nil }
        switch booking.spaceType {
        case .cabana:
            return .cabana(id: booking.id, name: booking.displayName)
        case .meetingRoom:
            return .meetingRoom(id: booking.id, name: booking.displayName)
        }
    }
}
