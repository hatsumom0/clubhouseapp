import SwiftUI

// MARK: - Current Tab Sheet

struct CurrentTabSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var orderService = FoodOrderService.shared
    @State private var showingPayment = false
    @State private var showingFoodOrder = false

    var order: FoodOrder? {
        orderService.currentOrder
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                if let order = order {
                    VStack(spacing: 0) {
                        // Order Status Banner (if submitted)
                        if order.status != .draft {
                            orderStatusBanner(order: order)
                        }

                        ScrollView {
                            VStack(spacing: 20) {
                                // Location
                                locationSection(order: order)

                                // Order Items
                                itemsSection(order: order)

                                // Working On Section (if preparing)
                                if order.status == .preparing && !order.currentlyWorking.isEmpty {
                                    workingSection(order: order)
                                }

                                // Summary
                                summarySection(order: order)

                                Spacer().frame(height: 120)
                            }
                            .padding(20)
                        }

                        // Bottom Actions
                        bottomActions(order: order)
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Your Tab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "f39c12"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPayment) {
                if let order = order {
                    PaymentSheet(
                        amount: order.subtotal,
                        itemDescription: "\(order.totalItems) item(s)",
                        onPay: { method, tip in
                            orderService.closeTab(paymentMethod: method, tipPercent: tip)
                            dismiss()
                        }
                    )
                }
            }
            .sheet(isPresented: $showingFoodOrder) {
                FoodOrderView()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Order Status Banner

    private func orderStatusBanner(order: FoodOrder) -> some View {
        HStack(spacing: 12) {
            Image(systemName: order.status.icon)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 2) {
                Text(order.status.rawValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                Text(order.status.description)
                    .font(.system(size: 12, design: .rounded))
                    .opacity(0.8)
            }

            Spacer()

            // Progress indicator
            OrderProgressBar(progress: order.status.progressPercent, status: order.status)
                .frame(width: 80)
        }
        .foregroundColor(.white)
        .padding(16)
        .background(order.status.color)
    }

    // MARK: - Location Section

    private func locationSection(order: FoodOrder) -> some View {
        HStack(spacing: 12) {
            Image(systemName: order.location.icon)
                .font(.system(size: 20))
                .foregroundColor(order.location.color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Delivery Location")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))

                Text(order.location.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
        )
    }

    // MARK: - Items Section

    private func itemsSection(order: FoodOrder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))

                Spacer()

                // Add More Items button (only when order allows adding)
                if order.canAddItems {
                    Button {
                        showingFoodOrder = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Add More")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "f39c12"))
                    }
                }
            }

            ForEach(order.items) { item in
                TabItemRow(item: item, canEdit: order.canAddItems) { newQuantity in
                    if newQuantity == 0 {
                        orderService.removeItem(item.id)
                    } else {
                        orderService.updateItemQuantity(item.id, quantity: newQuantity)
                    }
                }
            }
        }
    }

    // MARK: - Working Section

    private func workingSection(order: FoodOrder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Being Prepared")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.78))

            ForEach(order.currentlyWorking) { item in
                HStack(spacing: 12) {
                    Text(item.staffRole.emoji)
                        .font(.system(size: 24))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.staffName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("making \(item.itemName)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                    }

                    Spacer()

                    CookingIndicator()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Summary Section

    private func summarySection(order: FoodOrder) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                Spacer()
                Text(order.formattedSubtotal)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }

            Divider()
                .background(Color.white.opacity(0.2))

            HStack {
                Text("Total")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(order.formattedSubtotal)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "f39c12"))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Bottom Actions

    private func bottomActions(order: FoodOrder) -> some View {
        VStack(spacing: 12) {
            // Submit Order (if draft)
            if order.status == .draft && !order.items.isEmpty {
                Button {
                    orderService.submitOrder()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                        Text("Submit Order")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.green)
                    )
                }
            }

            // Close Tab (if delivered or can close)
            if order.status == .delivered || order.status != .draft {
                Button {
                    showingPayment = true
                } label: {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 16))
                        Text("Close Tab & Pay")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "f39c12"), Color(hex: "e67e22")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
            }
        }
        .padding(20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "takeoutbag.and.cup.and.straw")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.55))

            Text("No Open Tab")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Order some food or drinks to start a tab")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
        }
    }
}

// MARK: - Tab Item Row

struct TabItemRow: View {
    let item: OrderItem
    let canEdit: Bool
    let onQuantityChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Delivered indicator
            if item.isDelivered {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            } else {
                ZStack {
                    Circle()
                        .fill(item.menuItem.category.color.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: item.menuItem.imageSystemName)
                        .font(.system(size: 16))
                        .foregroundColor(item.menuItem.category.color)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.menuItem.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .strikethrough(item.isDelivered)

                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
            }

            Spacer()

            // Quantity (editable if canEdit and not yet delivered)
            if canEdit && !item.isDelivered {
                HStack(spacing: 6) {
                    Button {
                        onQuantityChange(item.quantity - 1)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.78))
                    }

                    Text("\(item.quantity)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 20)

                    Button {
                        onQuantityChange(item.quantity + 1)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "f39c12"))
                    }
                }
            } else {
                Text("x\(item.quantity)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
            }

            Text(item.formattedLineTotal)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.08))
        )
        .opacity(item.isDelivered ? 0.6 : 1.0)
    }
}

#Preview {
    CurrentTabSheet()
}
