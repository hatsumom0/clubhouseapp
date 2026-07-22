import Foundation
import SwiftUI
import Combine

// MARK: - Food Order Service

@MainActor
class FoodOrderService: ObservableObject {
    static let shared = FoodOrderService()

    // MARK: - Published Properties

    @Published var currentOrder: FoodOrder?  // Open tab
    @Published var orderHistory: [FoodOrder] = []
    @Published var menuItems: [MenuItem] = MenuItem.sampleMenu
    @Published var isLoading: Bool = false

    // Progress simulation
    private var progressTimers: [Timer] = []
    private var workingTimer: Timer?

    // MARK: - Initialization

    private init() {
        loadPersistedOrder()
    }

    // MARK: - Tab Management

    /// Open a new tab at a location
    func openTab(location: OrderLocation, memberId: String = "") -> FoodOrder {
        // If there's already an open tab, return it
        if let existing = currentOrder, existing.isTabOpen {
            return existing
        }

        let order = FoodOrder(
            memberId: memberId,
            status: .draft,
            location: location
        )

        currentOrder = order
        savePersistedOrder()

        return order
    }

    /// Add item to current order
    func addItem(_ menuItem: MenuItem, quantity: Int = 1, notes: String? = nil) {
        guard var order = currentOrder, order.canAddItems else { return }

        // Check if item already exists, update quantity
        if let existingIndex = order.items.firstIndex(where: { $0.menuItem.id == menuItem.id && $0.notes == notes }) {
            order.items[existingIndex].quantity += quantity
        } else {
            let orderItem = OrderItem(
                menuItem: menuItem,
                quantity: quantity,
                notes: notes
            )
            order.items.append(orderItem)
        }

        // Track if we need to restart simulation (adding to already-submitted order)
        let needsSimulationRestart = order.status != .draft && order.status != .received

        // If adding items to an in-progress or delivered order, reset to received
        if order.status == .delivered || order.status == .preparing || order.status == .enRoute {
            // Cancel existing timers
            workingTimer?.invalidate()
            progressTimers.forEach { $0.invalidate() }
            progressTimers.removeAll()

            order.status = .received
            // Re-assign staff for all items (including new ones)
            assignStaffToOrder(&order)
        }

        currentOrder = order
        savePersistedOrder()

        // Restart progress simulation if we reset status
        if needsSimulationRestart {
            simulateOrderProgress()
        }
    }

    /// Update item quantity
    func updateItemQuantity(_ itemId: UUID, quantity: Int) {
        guard var order = currentOrder else { return }

        if let index = order.items.firstIndex(where: { $0.id == itemId }) {
            if quantity <= 0 {
                order.items.remove(at: index)
            } else {
                order.items[index].quantity = quantity
            }
            currentOrder = order
            savePersistedOrder()
        }
    }

    /// Remove item from order
    func removeItem(_ itemId: UUID) {
        guard var order = currentOrder else { return }

        order.items.removeAll { $0.id == itemId }
        currentOrder = order
        savePersistedOrder()
    }

    /// Submit order for preparation
    func submitOrder(requestedTime: Date? = nil) {
        guard var order = currentOrder, !order.items.isEmpty else { return }

        order.status = .received
        order.submittedAt = Date()

        // Assign staff based on items
        assignStaffToOrder(&order)

        currentOrder = order
        savePersistedOrder()

        // Start Live Activity
        Task {
            try? await LiveActivityManager.shared.startFoodOrderActivity(order: order)
        }

        // Send notification
        NotificationService.shared.sendLocalNotification(
            title: "Order Received",
            body: "Your order of \(order.totalItems) item(s) has been received.",
            categoryIdentifier: "FOOD_ORDER"
        )

        // Start progress simulation
        simulateOrderProgress()
    }

    /// Close tab and pay
    func closeTab(paymentMethod: PaymentMethod, tipPercent: Double = 18) {
        guard var order = currentOrder else { return }

        order.status = .closed
        order.completedAt = Date()
        order.isPaid = true

        // Calculate total with tip
        let tip = order.subtotal * (tipPercent / 100)
        let total = order.subtotal + tip

        // Add to history
        orderHistory.insert(order, at: 0)
        currentOrder = nil

        // Stop timers
        progressTimers.forEach { $0.invalidate() }
        progressTimers.removeAll()
        workingTimer?.invalidate()

        savePersistedOrder()

        // End Live Activity
        Task {
            await LiveActivityManager.shared.endFoodOrderActivity()
        }

        // Process payment
        processPayment(amount: total, method: paymentMethod)

        // If there's an active space booking, add to its tab
        if let booking = SpaceBookingService.shared.currentBooking {
            SpaceBookingService.shared.addToTab(booking.id, amount: total)
        }
    }

    /// Cancel current order
    func cancelOrder() {
        progressTimers.forEach { $0.invalidate() }
        progressTimers.removeAll()
        workingTimer?.invalidate()
        currentOrder = nil
        savePersistedOrder()

        Task {
            await LiveActivityManager.shared.endFoodOrderActivity()
        }
    }

    // MARK: - Staff Assignment

    private func assignStaffToOrder(_ order: inout FoodOrder) {
        var staff: [StaffAssignment] = []

        // Count food and drink items
        let foodItems = order.items.filter { item in
            [.appetizers, .mains, .sides, .desserts].contains(item.menuItem.category)
        }

        let drinkItems = order.items.filter { item in
            [.cocktails, .wine, .beer, .spirits, .nonAlcoholic].contains(item.menuItem.category)
        }

        // Assign chefs based on number of food items
        // 1-2 items = 1 chef, 3-4 items = 2 chefs, 5+ items = 3 chefs
        if !foodItems.isEmpty {
            var usedChefNames: Set<String> = []
            let chefCount = min(3, max(1, (foodItems.count + 1) / 2))
            for _ in 0..<chefCount {
                var chef = StaffAssignment.randomChef()
                // Ensure unique chef names
                while usedChefNames.contains(chef.staffName) {
                    chef = StaffAssignment.randomChef()
                }
                usedChefNames.insert(chef.staffName)
                staff.append(chef)
            }
        }

        // Assign bartenders based on number of drink items
        // 1-3 drinks = 1 bartender, 4+ drinks = 2 bartenders
        if !drinkItems.isEmpty {
            var usedBartenderNames: Set<String> = []
            let bartenderCount = drinkItems.count >= 4 ? 2 : 1
            for _ in 0..<bartenderCount {
                var bartender = StaffAssignment.randomBartender()
                // Ensure unique bartender names
                while usedBartenderNames.contains(bartender.staffName) {
                    bartender = StaffAssignment.randomBartender()
                }
                usedBartenderNames.insert(bartender.staffName)
                staff.append(bartender)
            }
        }

        // Always assign a server for delivery
        staff.append(StaffAssignment.randomServer())

        order.assignedStaff = staff
    }

    // MARK: - Progress Simulation

    func simulateOrderProgress() {
        guard let order = currentOrder, order.status == .received else { return }

        // Cancel any existing progress timers
        progressTimers.forEach { $0.invalidate() }
        progressTimers.removeAll()
        workingTimer?.invalidate()

        // Start "working on" updates
        startWorkingSimulation()

        // Progress to preparing after 3 seconds
        let preparingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.updateStatus(to: .preparing)
            }
        }
        progressTimers.append(preparingTimer)

        // Progress to en route after 8 seconds
        let enRouteTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.updateStatus(to: .enRoute)
            }
        }
        progressTimers.append(enRouteTimer)

        // Progress to delivered after 12 seconds
        let deliveredTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.updateStatus(to: .delivered)
                strongSelf.markAllItemsDelivered()
            }
        }
        progressTimers.append(deliveredTimer)
    }

    private func startWorkingSimulation() {
        workingTimer?.invalidate()

        // Update what's being worked on every 2 seconds
        workingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                self.updateWorkingItems()
            }
        }
    }

    private func updateWorkingItems() {
        guard var order = currentOrder, !order.items.isEmpty else {
            workingTimer?.invalidate()
            return
        }

        // Only update working items during preparing status
        // But don't invalidate timer - keep it running for when status changes
        guard order.status == .preparing else {
            // Stop timer only if order is delivered or closed
            if order.status == .delivered || order.status == .closed {
                workingTimer?.invalidate()
            }
            return
        }

        // Get undelivered items
        let undeliveredItems = order.items.filter { !$0.isDelivered }
        guard !undeliveredItems.isEmpty else {
            order.currentlyWorking = []
            currentOrder = order
            return
        }

        var working: [WorkingItem] = []

        // Get all chefs and bartenders assigned
        let chefs = order.assignedStaff.filter { $0.staffRole == .chef }
        let bartenders = order.assignedStaff.filter { $0.staffRole == .bartender }

        // Get food and drink items that need to be prepared
        let foodItems = undeliveredItems.filter {
            [.appetizers, .mains, .sides, .desserts].contains($0.menuItem.category)
        }
        let drinkItems = undeliveredItems.filter {
            [.cocktails, .wine, .beer, .spirits, .nonAlcoholic].contains($0.menuItem.category)
        }

        // Assign food items to chefs (distribute items among available chefs)
        if !chefs.isEmpty && !foodItems.isEmpty {
            // Shuffle food items to vary which items are shown
            let shuffledFoodItems = foodItems.shuffled()
            for (index, item) in shuffledFoodItems.enumerated() {
                // Rotate through available chefs
                let chef = chefs[index % chefs.count]
                working.append(WorkingItem(
                    itemName: item.menuItem.name,
                    staffName: chef.staffName,
                    staffRole: .chef
                ))
            }
        }

        // Assign drink items to bartenders (distribute items among available bartenders)
        if !bartenders.isEmpty && !drinkItems.isEmpty {
            // Shuffle drink items to vary which items are shown
            let shuffledDrinkItems = drinkItems.shuffled()
            for (index, item) in shuffledDrinkItems.enumerated() {
                // Rotate through available bartenders
                let bartender = bartenders[index % bartenders.count]
                working.append(WorkingItem(
                    itemName: item.menuItem.name,
                    staffName: bartender.staffName,
                    staffRole: .bartender
                ))
            }
        }

        order.currentlyWorking = working
        currentOrder = order

        // Update Live Activity
        Task {
            await LiveActivityManager.shared.updateFoodOrderActivity(
                status: order.status,
                currentlyWorking: working,
                estimatedMinutes: order.estimatedPrepTime
            )
        }
    }

    private func updateStatus(to status: FoodOrder.OrderStatus) {
        guard var order = currentOrder else { return }

        order.status = status
        currentOrder = order
        savePersistedOrder()

        // Clear working items when en route or delivered
        if status == .enRoute || status == .delivered {
            order.currentlyWorking = []
            currentOrder = order
            workingTimer?.invalidate()
        }

        // Update Live Activity
        Task {
            await LiveActivityManager.shared.updateFoodOrderActivity(
                status: status,
                currentlyWorking: order.currentlyWorking,
                estimatedMinutes: status == .delivered ? 0 : order.estimatedPrepTime
            )
        }

        // Send notification
        let body: String
        switch status {
        case .preparing:
            body = "Your order is being prepared."
        case .enRoute:
            body = "Your order is on the way!"
        case .delivered:
            body = "Your order has been delivered. Enjoy!"
        default:
            return
        }

        NotificationService.shared.sendLocalNotification(
            title: status.rawValue,
            body: body,
            categoryIdentifier: "FOOD_ORDER"
        )
    }

    private func markAllItemsDelivered() {
        guard var order = currentOrder else { return }

        for i in order.items.indices {
            order.items[i].isDelivered = true
        }

        currentOrder = order
        savePersistedOrder()
    }

    // MARK: - Payment

    private func processPayment(amount: Double, method: PaymentMethod) {
        // In production, integrate with payment processor
        print("Processing \(method.rawValue) payment of $\(String(format: "%.2f", amount))")

        NotificationService.shared.sendLocalNotification(
            title: "Payment Confirmed",
            body: "Your tab of $\(String(format: "%.2f", amount)) was paid via \(method.rawValue).",
            categoryIdentifier: "PAYMENT"
        )
    }

    // MARK: - Menu Functions

    func getMenuByCategory() -> [MenuItem.MenuCategory: [MenuItem]] {
        Dictionary(grouping: menuItems, by: { $0.category })
    }

    func searchMenu(_ query: String) -> [MenuItem] {
        MenuItem.search(query)
    }

    func findMenuItem(byName name: String) -> MenuItem? {
        MenuItem.findByName(name)
    }

    // MARK: - Persistence

    private func savePersistedOrder() {
        if let order = currentOrder,
           let data = try? JSONEncoder().encode(order) {
            UserDefaults.standard.set(data, forKey: "currentFoodOrder")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentFoodOrder")
        }

        if let data = try? JSONEncoder().encode(Array(orderHistory.prefix(20))) {
            UserDefaults.standard.set(data, forKey: "foodOrderHistory")
        }
    }

    private func loadPersistedOrder() {
        if let data = UserDefaults.standard.data(forKey: "currentFoodOrder"),
           let order = try? JSONDecoder().decode(FoodOrder.self, from: data) {
            // Only restore if tab is still open
            if order.isTabOpen {
                currentOrder = order
            }
        }

        if let data = UserDefaults.standard.data(forKey: "foodOrderHistory"),
           let orders = try? JSONDecoder().decode([FoodOrder].self, from: data) {
            orderHistory = orders
        }
    }

    // MARK: - Helper Functions

    var hasOpenTab: Bool {
        currentOrder?.isTabOpen ?? false
    }

    var currentOrderLocation: OrderLocation? {
        currentOrder?.location
    }

    /// Get appropriate order locations based on context
    func getAvailableLocations() -> [OrderLocation] {
        var locations: [OrderLocation] = [.lounge, .poolside, .rooftop]

        // Add current space booking if exists
        if let bookingLocation = SpaceBookingService.shared.currentBookingAsOrderLocation {
            locations.insert(bookingLocation, at: 0)
        }

        return locations
    }
}
