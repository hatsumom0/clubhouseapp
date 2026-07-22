import Foundation
import SwiftUI

// MARK: - Space Booking Model

struct SpaceBooking: Codable, Identifiable {
    let id: UUID
    let spaceType: SpaceType
    let spaceName: String
    let spaceNumber: String
    let floor: String
    let date: Date
    let startTime: Date
    let endTime: Date
    let guestCount: Int
    var status: BookingStatus
    let specialRequests: String?
    let bookedAt: Date
    var totalCost: Double
    var tabTotal: Double  // Running tab for food/drinks

    init(
        id: UUID = UUID(),
        spaceType: SpaceType,
        spaceName: String,
        spaceNumber: String,
        floor: String,
        date: Date,
        startTime: Date,
        endTime: Date,
        guestCount: Int,
        status: BookingStatus = .confirmed,
        specialRequests: String? = nil,
        bookedAt: Date = Date(),
        totalCost: Double = 0,
        tabTotal: Double = 0
    ) {
        self.id = id
        self.spaceType = spaceType
        self.spaceName = spaceName
        self.spaceNumber = spaceNumber
        self.floor = floor
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.guestCount = guestCount
        self.status = status
        self.specialRequests = specialRequests
        self.bookedAt = bookedAt
        self.totalCost = totalCost
        self.tabTotal = tabTotal
    }

    // MARK: - Space Type

    enum SpaceType: String, Codable, CaseIterable {
        case cabana = "Cabana"
        case meetingRoom = "Meeting Room"

        var icon: String {
            switch self {
            case .cabana: return "sun.max.fill"
            case .meetingRoom: return "person.3.fill"
            }
        }

        var color: Color {
            switch self {
            case .cabana: return Color(hex: "f39c12")
            case .meetingRoom: return Color(hex: "3498db")
            }
        }

        var hourlyRate: Double {
            switch self {
            case .cabana: return 150
            case .meetingRoom: return 75
            }
        }

        var description: String {
            switch self {
            case .cabana: return "Poolside luxury with dedicated service"
            case .meetingRoom: return "Private space for meetings & events"
            }
        }
    }

    // MARK: - Booking Status

    enum BookingStatus: String, Codable {
        case pending = "Pending"
        case confirmed = "Confirmed"
        case active = "Active"
        case completed = "Completed"
        case cancelled = "Cancelled"

        var color: Color {
            switch self {
            case .pending: return .orange
            case .confirmed: return .blue
            case .active: return .green
            case .completed: return .gray
            case .cancelled: return .red
            }
        }

        var icon: String {
            switch self {
            case .pending: return "clock.fill"
            case .confirmed: return "checkmark.circle.fill"
            case .active: return "play.circle.fill"
            case .completed: return "checkmark.seal.fill"
            case .cancelled: return "xmark.circle.fill"
            }
        }
    }

    // MARK: - Computed Properties

    var displayName: String {
        "\(spaceName) \(spaceNumber)"
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

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    var durationHours: Double {
        endTime.timeIntervalSince(startTime) / 3600
    }

    var formattedDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        if minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(hours)h"
    }

    var baseCost: Double {
        spaceType.hourlyRate * durationHours
    }

    var formattedTotalCost: String {
        String(format: "$%.2f", totalCost > 0 ? totalCost : baseCost)
    }

    var formattedTabTotal: String {
        String(format: "$%.2f", tabTotal)
    }

    var isActive: Bool {
        status == .active || (status == .confirmed && Date() >= startTime && Date() <= endTime)
    }

    var isUpcoming: Bool {
        (status == .confirmed || status == .pending) && Date() < startTime
    }
}

// MARK: - Available Space

struct AvailableSpace: Identifiable {
    let id: UUID
    let spaceType: SpaceBooking.SpaceType
    let spaceName: String
    let spaceNumber: String
    let floor: String
    let amenities: [String]
    let maxGuests: Int
    let imageSystemName: String

    var displayName: String {
        "\(spaceName) \(spaceNumber)"
    }
}

// MARK: - Time Slot

struct TimeSlot: Identifiable, Hashable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let isAvailable: Bool

    init(id: UUID = UUID(), startTime: Date, endTime: Date, isAvailable: Bool = true) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.isAvailable = isAvailable
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }

    var formattedRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

// MARK: - Sample Available Spaces

extension AvailableSpace {
    static let sampleCabanas: [AvailableSpace] = [
        AvailableSpace(
            id: UUID(),
            spaceType: .cabana,
            spaceName: "Poolside Cabana",
            spaceNumber: "1",
            floor: "Pool Level",
            amenities: ["Day bed", "Mini fridge", "Fan", "Dedicated server"],
            maxGuests: 6,
            imageSystemName: "sun.max.fill"
        ),
        AvailableSpace(
            id: UUID(),
            spaceType: .cabana,
            spaceName: "Poolside Cabana",
            spaceNumber: "2",
            floor: "Pool Level",
            amenities: ["Day bed", "Mini fridge", "Fan", "Dedicated server"],
            maxGuests: 6,
            imageSystemName: "sun.max.fill"
        ),
        AvailableSpace(
            id: UUID(),
            spaceType: .cabana,
            spaceName: "VIP Cabana",
            spaceNumber: "3",
            floor: "Pool Level",
            amenities: ["King day bed", "Full bar", "TV", "Private bathroom", "Dedicated server"],
            maxGuests: 10,
            imageSystemName: "star.fill"
        ),
        AvailableSpace(
            id: UUID(),
            spaceType: .cabana,
            spaceName: "Rooftop Cabana",
            spaceNumber: "1",
            floor: "Rooftop",
            amenities: ["Ocean view", "Day bed", "Champagne service", "Dedicated server"],
            maxGuests: 8,
            imageSystemName: "cloud.sun.fill"
        )
    ]

    static let sampleMeetingRooms: [AvailableSpace] = [
        AvailableSpace(
            id: UUID(),
            spaceType: .meetingRoom,
            spaceName: "Board Room",
            spaceNumber: "A",
            floor: "3rd Floor",
            amenities: ["Conference table (12)", "Video conferencing", "Whiteboard", "Coffee service"],
            maxGuests: 12,
            imageSystemName: "person.3.fill"
        ),
        AvailableSpace(
            id: UUID(),
            spaceType: .meetingRoom,
            spaceName: "Board Room",
            spaceNumber: "B",
            floor: "3rd Floor",
            amenities: ["Conference table (8)", "Video conferencing", "Whiteboard", "Coffee service"],
            maxGuests: 8,
            imageSystemName: "person.3.fill"
        ),
        AvailableSpace(
            id: UUID(),
            spaceType: .meetingRoom,
            spaceName: "Executive Suite",
            spaceNumber: "1",
            floor: "4th Floor",
            amenities: ["Premium furnishings", "Ocean view", "Full AV", "Private bar", "Catering available"],
            maxGuests: 20,
            imageSystemName: "star.fill"
        ),
        AvailableSpace(
            id: UUID(),
            spaceType: .meetingRoom,
            spaceName: "Huddle Room",
            spaceNumber: "1",
            floor: "2nd Floor",
            amenities: ["4-person table", "TV display", "Whiteboard"],
            maxGuests: 4,
            imageSystemName: "person.2.fill"
        ),
        AvailableSpace(
            id: UUID(),
            spaceType: .meetingRoom,
            spaceName: "Huddle Room",
            spaceNumber: "2",
            floor: "2nd Floor",
            amenities: ["4-person table", "TV display", "Whiteboard"],
            maxGuests: 4,
            imageSystemName: "person.2.fill"
        )
    ]

    static var allSpaces: [AvailableSpace] {
        sampleCabanas + sampleMeetingRooms
    }
}
