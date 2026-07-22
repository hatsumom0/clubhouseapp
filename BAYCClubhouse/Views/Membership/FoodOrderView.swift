import SwiftUI

// MARK: - Food Order View

struct FoodOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var orderService = FoodOrderService.shared
    @StateObject private var bookingService = SpaceBookingService.shared
    @StateObject private var accessService = ClubAccessService.shared

    @State private var selectedCategory: MenuItem.MenuCategory?
    @State private var selectedLocation: OrderLocation = .lounge
    @State private var searchText = ""
    @State private var showingTab = false

    // Local cart for multi-item selection before adding to order
    @State private var pendingItems: [UUID: Int] = [:]  // menuItemId: quantity

    var filteredItems: [MenuItem] {
        var items = orderService.menuItems

        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return items
    }

    var pendingItemCount: Int {
        pendingItems.values.reduce(0, +)
    }

    var pendingSubtotal: Double {
        pendingItems.reduce(0) { total, item in
            guard let menuItem = orderService.menuItems.first(where: { $0.id == item.key }) else { return total }
            return total + (menuItem.price * Double(item.value))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Location Selector
                    locationSelector
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Search Bar
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    // Category Pills
                    categoryScroller
                        .padding(.top, 16)

                    // Menu Items
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems) { item in
                                MenuItemCard(
                                    item: item,
                                    quantity: pendingItems[item.id] ?? 0
                                ) { newQuantity in
                                    updatePendingItem(item: item, quantity: newQuantity)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 140)  // Extra padding for bottom buttons
                    }
                }

                // Floating Bottom Buttons
                VStack {
                    Spacer()
                    bottomButtonStack
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
            }
            .navigationTitle("Order Food & Drinks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingTab) {
                CurrentTabSheet()
            }
            .onAppear {
                setupInitialLocation()
            }
        }
    }

    // MARK: - Location Selector

    private var locationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deliver to")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.72))

            Menu {
                ForEach(orderService.getAvailableLocations(), id: \.displayName) { location in
                    Button {
                        selectedLocation = location
                    } label: {
                        Label(location.displayName, systemImage: location.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedLocation.icon)
                        .font(.system(size: 16))
                        .foregroundColor(selectedLocation.color)

                    Text(selectedLocation.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.72))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.65))

            TextField("Search menu...", text: $searchText)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.1))
        )
    }

    // MARK: - Category Scroller

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All category
                CategoryPill(
                    title: "All",
                    icon: "square.grid.2x2.fill",
                    color: Color(hex: "f39c12"),
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedCategory = nil
                    }
                }

                ForEach(MenuItem.MenuCategory.allCases, id: \.self) { category in
                    CategoryPill(
                        title: category.rawValue,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Bottom Button Stack

    private var bottomButtonStack: some View {
        VStack(spacing: 12) {
            // Add to Order Button (when items are pending)
            if pendingItemCount > 0 {
                Button {
                    addPendingItemsToOrder()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add to Order")
                                .font(.system(size: 16, weight: .bold, design: .rounded))

                            Text("\(pendingItemCount) item\(pendingItemCount == 1 ? "" : "s")")
                                .font(.system(size: 13, design: .rounded))
                                .opacity(0.8)
                        }

                        Spacer()

                        Text(String(format: "$%.2f", pendingSubtotal))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green)
                    )
                    .shadow(color: Color.green.opacity(0.4), radius: 12, y: 6)
                }
            }

            // View Tab Button (when there's an active order)
            if let order = orderService.currentOrder, !order.items.isEmpty {
                Button {
                    showingTab = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Tab")
                                .font(.system(size: 16, weight: .bold, design: .rounded))

                            Text("\(order.totalItems) items")
                                .font(.system(size: 13, design: .rounded))
                                .opacity(0.8)
                        }

                        Spacer()

                        Text(order.formattedSubtotal)
                            .font(.system(size: 18, weight: .bold, design: .rounded))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "f39c12"), Color(hex: "e67e22")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: Color(hex: "f39c12").opacity(0.4), radius: 12, y: 6)
                }
            }
        }
    }

    // MARK: - Actions

    private func setupInitialLocation() {
        // Auto-select cabana/meeting room if active
        if let bookingLocation = bookingService.currentBookingAsOrderLocation {
            selectedLocation = bookingLocation
        }
    }

    private func updatePendingItem(item: MenuItem, quantity: Int) {
        if quantity <= 0 {
            pendingItems.removeValue(forKey: item.id)
        } else {
            pendingItems[item.id] = quantity
        }

        // Light haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    private func addPendingItemsToOrder() {
        // Open tab if not already open
        if orderService.currentOrder == nil {
            _ = orderService.openTab(location: selectedLocation)
        }

        // Add all pending items to the order
        for (menuItemId, quantity) in pendingItems {
            if let menuItem = orderService.menuItems.first(where: { $0.id == menuItemId }) {
                orderService.addItem(menuItem, quantity: quantity)
            }
        }

        // Clear pending items
        pendingItems.removeAll()

        // Medium haptic feedback for confirmation
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Show the tab
        showingTab = true
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - Menu Item Card

struct MenuItemCard: View {
    let item: MenuItem
    let quantity: Int
    let onQuantityChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Item icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.category.color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: item.imageSystemName)
                    .font(.system(size: 24))
                    .foregroundColor(item.category.color)
            }

            // Item info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(item.description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(item.formattedPrice)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "f39c12"))

                    if item.category.requiresAgeVerification {
                        Text("21+")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                }
            }

            Spacer()

            // Quantity controls
            if quantity > 0 {
                HStack(spacing: 8) {
                    Button {
                        onQuantityChange(quantity - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "f39c12"))
                    }

                    Text("\(quantity)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 24)

                    Button {
                        onQuantityChange(quantity + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "f39c12"))
                    }
                }
            } else {
                Button {
                    onQuantityChange(1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "f39c12"))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(quantity > 0 ? Color(hex: "f39c12").opacity(0.15) : .white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(quantity > 0 ? Color(hex: "f39c12").opacity(0.5) : .clear, lineWidth: 1)
                )
        )
    }
}

#Preview {
    FoodOrderView()
}
