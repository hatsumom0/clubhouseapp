import Foundation
import SwiftUI

// MARK: - Food Order Model

struct FoodOrder: Codable, Identifiable {
    let id: UUID
    let memberId: String
    var items: [OrderItem]
    var status: OrderStatus
    let location: OrderLocation
    let requestedTime: Date?  // nil = ASAP
    var assignedStaff: [StaffAssignment]
    var currentlyWorking: [WorkingItem]
    let createdAt: Date
    var submittedAt: Date?
    var completedAt: Date?
    var isPaid: Bool

    init(
        id: UUID = UUID(),
        memberId: String,
        items: [OrderItem] = [],
        status: OrderStatus = .draft,
        location: OrderLocation,
        requestedTime: Date? = nil,
        assignedStaff: [StaffAssignment] = [],
        currentlyWorking: [WorkingItem] = [],
        createdAt: Date = Date(),
        submittedAt: Date? = nil,
        completedAt: Date? = nil,
        isPaid: Bool = false
    ) {
        self.id = id
        self.memberId = memberId
        self.items = items
        self.status = status
        self.location = location
        self.requestedTime = requestedTime
        self.assignedStaff = assignedStaff
        self.currentlyWorking = currentlyWorking
        self.createdAt = createdAt
        self.submittedAt = submittedAt
        self.completedAt = completedAt
        self.isPaid = isPaid
    }

    // MARK: - Order Status

    enum OrderStatus: String, Codable {
        case draft = "Draft"           // Tab open but not submitted
        case received = "Order Received"
        case preparing = "Working On It"
        case enRoute = "On the Way"
        case delivered = "Delivered"
        case closed = "Closed"

        var progressPercent: Double {
            switch self {
            case .draft: return 0.0
            case .received: return 0.25
            case .preparing: return 0.5
            case .enRoute: return 0.75
            case .delivered, .closed: return 1.0
            }
        }

        var color: Color {
            switch self {
            case .draft: return .gray
            case .received: return .blue
            case .preparing: return .orange
            case .enRoute: return .purple
            case .delivered: return .green
            case .closed: return .gray
            }
        }

        var icon: String {
            switch self {
            case .draft: return "pencil.circle.fill"
            case .received: return "checkmark.circle.fill"
            case .preparing: return "flame.fill"
            case .enRoute: return "figure.walk"
            case .delivered: return "hand.thumbsup.fill"
            case .closed: return "checkmark.seal.fill"
            }
        }

        var description: String {
            switch self {
            case .draft: return "Add items to your order"
            case .received: return "Your order has been received"
            case .preparing: return "Your order is being prepared"
            case .enRoute: return "Your order is on the way"
            case .delivered: return "Enjoy your order!"
            case .closed: return "Order complete"
            }
        }
    }

    // MARK: - Computed Properties

    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    var subtotal: Double {
        items.reduce(0) { $0 + ($1.menuItem.price * Double($1.quantity)) }
    }

    var formattedSubtotal: String {
        String(format: "$%.2f", subtotal)
    }

    var deliveredCount: Int {
        items.filter { $0.isDelivered }.reduce(0) { $0 + $1.quantity }
    }

    var estimatedPrepTime: Int {
        items.map { $0.menuItem.prepTime }.max() ?? 10
    }

    var isTabOpen: Bool {
        status == .draft || (status != .closed && !isPaid)
    }

    var canAddItems: Bool {
        status != .closed
    }
}

// MARK: - Order Location

enum OrderLocation: Codable, Hashable {
    case lounge
    case meetingRoom(id: UUID, name: String)
    case cabana(id: UUID, name: String)
    case poolside
    case rooftop

    var displayName: String {
        switch self {
        case .lounge: return "Main Lounge"
        case .meetingRoom(_, let name): return name
        case .cabana(_, let name): return name
        case .poolside: return "Poolside"
        case .rooftop: return "Rooftop Bar"
        }
    }

    var icon: String {
        switch self {
        case .lounge: return "sofa.fill"
        case .meetingRoom: return "person.3.fill"
        case .cabana: return "sun.max.fill"
        case .poolside: return "figure.pool.swim"
        case .rooftop: return "building.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .lounge: return Color(hex: "9b59b6")
        case .meetingRoom: return Color(hex: "3498db")
        case .cabana: return Color(hex: "f39c12")
        case .poolside: return Color(hex: "1abc9c")
        case .rooftop: return Color(hex: "e74c3c")
        }
    }

    // For Codable
    enum CodingKeys: String, CodingKey {
        case type, id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "lounge": self = .lounge
        case "meetingRoom":
            let id = try container.decode(UUID.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            self = .meetingRoom(id: id, name: name)
        case "cabana":
            let id = try container.decode(UUID.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            self = .cabana(id: id, name: name)
        case "poolside": self = .poolside
        case "rooftop": self = .rooftop
        default: self = .lounge
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .lounge:
            try container.encode("lounge", forKey: .type)
        case .meetingRoom(let id, let name):
            try container.encode("meetingRoom", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
        case .cabana(let id, let name):
            try container.encode("cabana", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
        case .poolside:
            try container.encode("poolside", forKey: .type)
        case .rooftop:
            try container.encode("rooftop", forKey: .type)
        }
    }
}

// MARK: - Order Item

struct OrderItem: Codable, Identifiable {
    let id: UUID
    let menuItem: MenuItem
    var quantity: Int
    var isDelivered: Bool
    var notes: String?
    let addedAt: Date

    init(
        id: UUID = UUID(),
        menuItem: MenuItem,
        quantity: Int = 1,
        isDelivered: Bool = false,
        notes: String? = nil,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.menuItem = menuItem
        self.quantity = quantity
        self.isDelivered = isDelivered
        self.notes = notes
        self.addedAt = addedAt
    }

    var lineTotal: Double {
        menuItem.price * Double(quantity)
    }

    var formattedLineTotal: String {
        String(format: "$%.2f", lineTotal)
    }
}

// MARK: - Staff Assignment

struct StaffAssignment: Codable, Identifiable {
    let id: UUID
    let staffName: String
    let staffRole: StaffRole
    let assignedAt: Date

    init(id: UUID = UUID(), staffName: String, staffRole: StaffRole, assignedAt: Date = Date()) {
        self.id = id
        self.staffName = staffName
        self.staffRole = staffRole
        self.assignedAt = assignedAt
    }

    enum StaffRole: String, Codable {
        case chef = "Chef"
        case bartender = "Bartender"
        case server = "Server"

        var icon: String {
            switch self {
            case .chef: return "flame.fill"
            case .bartender: return "wineglass"
            case .server: return "figure.walk"
            }
        }

        var emoji: String {
            switch self {
            case .chef: return "👨‍🍳"
            case .bartender: return "🍸"
            case .server: return "🏃"
            }
        }
    }
}

// MARK: - Working Item (What's being made right now)

struct WorkingItem: Codable, Identifiable, Hashable {
    let id: UUID
    let itemName: String
    let staffName: String
    let staffRole: StaffAssignment.StaffRole
    let startedAt: Date

    init(id: UUID = UUID(), itemName: String, staffName: String, staffRole: StaffAssignment.StaffRole, startedAt: Date = Date()) {
        self.id = id
        self.itemName = itemName
        self.staffName = staffName
        self.staffRole = staffRole
        self.startedAt = startedAt
    }

    var displayText: String {
        "\(staffRole.emoji) \(staffName) working on: \(itemName)"
    }

    var shortDisplayText: String {
        "\(staffName): \(itemName)"
    }
}

// MARK: - Payment Method

enum PaymentMethod: String, CaseIterable {
    case applePay = "Apple Pay"
    case billToMembership = "Bill to Membership"
    case glyphWallet = "Glyph Wallet"

    var icon: String {
        switch self {
        case .applePay: return "apple.logo"
        case .billToMembership: return "creditcard.fill"
        case .glyphWallet: return "wallet.pass.fill"
        }
    }

    var description: String {
        switch self {
        case .applePay: return "Pay instantly with Apple Pay"
        case .billToMembership: return "Charge to your membership account"
        case .glyphWallet: return "Pay with connected crypto wallet"
        }
    }
}

// MARK: - Sample Staff Names

extension StaffAssignment {
    static let sampleChefs = ["Marco", "Isabella", "Chen Wei", "Roberto", "Sofia"]
    static let sampleBartenders = ["Sarah", "James", "Miguel", "Nina", "Alex"]
    static let sampleServers = ["Emma", "Lucas", "Olivia", "Carlos", "Mia"]

    static func randomChef() -> StaffAssignment {
        StaffAssignment(staffName: sampleChefs.randomElement()!, staffRole: .chef)
    }

    static func randomBartender() -> StaffAssignment {
        StaffAssignment(staffName: sampleBartenders.randomElement()!, staffRole: .bartender)
    }

    static func randomServer() -> StaffAssignment {
        StaffAssignment(staffName: sampleServers.randomElement()!, staffRole: .server)
    }
}
