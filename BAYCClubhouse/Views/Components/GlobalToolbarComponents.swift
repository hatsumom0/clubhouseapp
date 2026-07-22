import SwiftUI

// MARK: - Global Toolbar Modifier

/// A view modifier that adds the quick access pill and chat button to any page's toolbar
struct GlobalToolbarModifier: ViewModifier {
    @EnvironmentObject var chatManager: ChatManager
    @StateObject private var accessService = ClubAccessService.shared
    @StateObject private var orderService = FoodOrderService.shared
    @StateObject private var bookingService = SpaceBookingService.shared
    @State private var showQuickAccess = false

    let title: String

    private var hasActiveOrder: Bool {
        if let order = orderService.currentOrder {
            return order.status != .draft && order.status != .closed
        }
        return false
    }

    private var showPill: Bool {
        accessService.isAtClubhouse ||
        accessService.currentLocker != nil ||
        accessService.valetRequest != nil ||
        hasActiveOrder ||
        (bookingService.currentBooking != nil && bookingService.currentBooking!.isActive)
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Quick Access Pill (shows when checked in, has active locker/valet, or active order)
                        if showPill {
                            Button {
                                showQuickAccess = true
                            } label: {
                                if hasActiveOrder, let order = orderService.currentOrder {
                                    CompactOrderTracker(order: order)
                                } else {
                                    HStack(spacing: 6) {
                                        Image(systemName: "key.fill")
                                            .font(.system(size: 14))
                                        if accessService.currentLocker != nil {
                                            Text(accessService.currentLocker!.displayNumber)
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                }
                            }
                        }

                        // Message button
                        Button {
                            chatManager.toggleChat()
                        } label: {
                            ZStack {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "f39c12"))

                                if chatManager.unreadCount > 0 {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 12, height: 12)
                                        .offset(x: 10, y: -10)
                                }
                            }
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showQuickAccess) {
                QuickAccessSheet()
            }
    }
}

extension View {
    /// Apply the global toolbar with quick access pill and chat button
    func globalToolbar(title: String) -> some View {
        modifier(GlobalToolbarModifier(title: title))
    }
}

// MARK: - Reusable Toolbar Components

/// Quick Access Pill Button - shows when at clubhouse, has locker, valet, or active order
struct QuickAccessPillButton: View {
    @StateObject private var accessService = ClubAccessService.shared
    @StateObject private var orderService = FoodOrderService.shared
    @StateObject private var bookingService = SpaceBookingService.shared
    @Binding var showQuickAccess: Bool

    var isVisible: Bool {
        accessService.isAtClubhouse ||
        accessService.currentLocker != nil ||
        accessService.valetRequest != nil ||
        (orderService.currentOrder != nil && orderService.currentOrder?.status != .draft && orderService.currentOrder?.status != .closed) ||
        (bookingService.currentBooking != nil && bookingService.currentBooking!.isActive)
    }

    var body: some View {
        if isVisible {
            Button {
                showQuickAccess = true
            } label: {
                HStack(spacing: 6) {
                    // Show order status indicator if there's an active order
                    if let order = orderService.currentOrder,
                       order.status != .draft && order.status != .closed {
                        CompactOrderTracker(order: order)
                    } else {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14))
                        if accessService.currentLocker != nil {
                            Text(accessService.currentLocker!.displayNumber)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, orderService.currentOrder != nil && orderService.currentOrder?.status != .draft ? 0 : 10)
                .padding(.vertical, orderService.currentOrder != nil && orderService.currentOrder?.status != .draft ? 0 : 6)
                .background(
                    Group {
                        if orderService.currentOrder == nil || orderService.currentOrder?.status == .draft || orderService.currentOrder?.status == .closed {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                )
            }
        }
    }
}

/// Chat Button with unread badge
struct ChatToolbarButton: View {
    @EnvironmentObject var chatManager: ChatManager

    var body: some View {
        Button {
            chatManager.toggleChat()
        } label: {
            ZStack {
                Image(systemName: "message.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "f39c12"))

                if chatManager.unreadCount > 0 {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                        .offset(x: 10, y: -10)
                }
            }
        }
    }
}

/// Toolbar Title View
struct ToolbarTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .tracking(2)
            .foregroundColor(.white)
    }
}

// MARK: - Quick Access Sheet

struct QuickAccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var accessService = ClubAccessService.shared
    @StateObject private var passKitService = PassKitService.shared
    @StateObject private var orderService = FoodOrderService.shared
    @StateObject private var bookingService = SpaceBookingService.shared
    @State private var showingCode = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Check-in status
                        if accessService.isAtClubhouse {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Checked In")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)

                                    if let checkIn = accessService.lastCheckIn {
                                        Text("Since \(checkIn.formatted(date: .omitted, time: .shortened))")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }

                                Spacer()
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.green.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }

                        // Active Order Tracker
                        OrderTrackerCard(orderService: orderService)

                        // Active Space Booking
                        if let booking = bookingService.currentBooking, booking.isActive {
                            SpaceBookingCard(booking: booking)
                        }

                        // Locker Card
                        if let locker = accessService.currentLocker {
                            LockerQuickAccessCard(locker: locker, showingCode: $showingCode)
                        }

                        // Valet Tracker Card
                        ValetTrackerCard(clubAccess: accessService)

                        // NFC Membership Card Shortcut
                        if passKitService.isPassAddedLocally() {
                            NFCMembershipShortcutCard()
                        }

                        // Tip about NFC
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                            Text("Tap your phone at the locker or door for instant access")
                                .font(.system(size: 12, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Quick Access")
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Locker Quick Access Card

struct LockerQuickAccessCard: View {
    let locker: LockerAssignment
    @Binding var showingCode: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "3498db"))

                Text("Your Locker")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()
            }

            HStack(spacing: 24) {
                // Locker number
                VStack(spacing: 4) {
                    Text(locker.displayNumber)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(locker.floor)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 100)

                // Access code
                VStack(spacing: 4) {
                    Text("CODE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))

                    Button {
                        withAnimation { showingCode.toggle() }
                    } label: {
                        Text(showingCode ? locker.accessCode : "••••")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(showingCode ? Color(hex: "f39c12") : .white.opacity(0.3))
                    }

                    Text(showingCode ? "Tap to hide" : "Tap to reveal")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "3498db").opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "3498db").opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Valet Quick Access Card

struct ValetQuickAccessCard: View {
    let valet: ValetRequest

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "car.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "f39c12"))

                Text("Valet")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text(valet.status.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(valet.status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(valet.status.color.opacity(0.2)))
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(valet.vehicleInfo.displayName)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white)

                    Text("Ticket: \(valet.ticketNumber)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "f39c12"))
                }

                Spacer()

                if valet.status == .ready {
                    Image(systemName: "key.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "f39c12").opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "f39c12").opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - NFC Membership Shortcut Card

struct NFCMembershipShortcutCard: View {
    @StateObject private var accessService = ClubAccessService.shared

    var body: some View {
        Button {
            // This would ideally open Apple Wallet directly
            // For now, we show a message
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "wave.3.right")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("NFC Membership Card")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Tap to open Apple Wallet")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))

                    if let locker = accessService.currentLocker {
                        Text("Includes locker \(locker.displayNumber) access")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(Color(hex: "3498db"))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
        }
    }
}
