import SwiftUI

// MARK: - Order Tracker Card

struct OrderTrackerCard: View {
    @ObservedObject var orderService: FoodOrderService
    @State private var showingTab = false
    @State private var animateProgress = false

    var order: FoodOrder? {
        orderService.currentOrder
    }

    var body: some View {
        if let order = order, order.status != .draft && order.status != .closed {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                        .font(.system(size: 20))
                        .foregroundColor(order.status.color)

                    Text("Your Order")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    Text(order.formattedSubtotal)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "f39c12"))
                }

                // Progress Bar
                OrderProgressBar(progress: order.status.progressPercent, status: order.status)
                    .animation(.spring(response: 0.6), value: order.status)

                // Status Text
                HStack {
                    Image(systemName: order.status.icon)
                        .font(.system(size: 14))
                    Text(order.status.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(order.status.color)

                // Working Items
                if order.status == .preparing && !order.currentlyWorking.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(order.currentlyWorking) { item in
                            WorkingItemRow(item: item)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                }

                // En Route Info
                if order.status == .enRoute {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 16))

                        if let server = order.assignedStaff.first(where: { $0.staffRole == .server }) {
                            Text("\(server.staffName) is bringing your order")
                                .font(.system(size: 13, design: .rounded))
                        } else {
                            Text("Your order is on the way")
                                .font(.system(size: 13, design: .rounded))
                        }
                    }
                    .foregroundColor(.white.opacity(0.7))
                }

                // Delivered Message
                if order.status == .delivered {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 16))
                        Text("Enjoy your order!")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.green)
                }

                // ETA
                if order.status != .delivered {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                        Text("Est. \(order.estimatedPrepTime) min")
                            .font(.system(size: 12, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.72))
                }

                // View Tab Button
                Button {
                    showingTab = true
                } label: {
                    Text("View Tab")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "f39c12"))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(order.status.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(order.status.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .sheet(isPresented: $showingTab) {
                CurrentTabSheet()
            }
        }
    }
}

// MARK: - Order Progress Bar

struct OrderProgressBar: View {
    let progress: Double
    let status: FoodOrder.OrderStatus

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 12)

                // Progress fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [status.color.opacity(0.8), status.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 12)

                // Progress markers
                HStack(spacing: 0) {
                    ForEach(0..<4) { index in
                        let markerProgress = Double(index + 1) * 0.25
                        Circle()
                            .fill(progress >= markerProgress ? status.color : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Working Item Row

struct WorkingItemRow: View {
    let item: WorkingItem

    var body: some View {
        HStack(spacing: 10) {
            Text(item.staffRole.emoji)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.staffName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("working on: \(item.itemName)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
            }

            Spacer()

            // Animated cooking indicator
            CookingIndicator()
        }
    }
}

// MARK: - Cooking Indicator

struct CookingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(hex: "f39c12"))
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Space Booking Card

struct SpaceBookingCard: View {
    let booking: SpaceBooking
    @State private var showingPayment = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: booking.spaceType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(booking.spaceType.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(booking.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(booking.floor)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                }

                Spacer()

                // Status badge
                Text(booking.status.rawValue)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(booking.status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(booking.status.color.opacity(0.2))
                    )
            }

            // Time info
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DATE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))

                    Text(booking.formattedDate)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TIME")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))

                    Text(booking.formattedTimeRange)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("GUESTS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))

                    Text("\(booking.guestCount)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            // Tab total if any
            if booking.tabTotal > 0 {
                HStack {
                    Text("Tab Total")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))

                    Spacer()

                    Text(booking.formattedTabTotal)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "f39c12"))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )
            }

            // Check Out Button (for active bookings)
            if booking.isActive {
                Button {
                    showingPayment = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14))
                        Text("Check Out")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(booking.spaceType.color)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(booking.spaceType.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(booking.spaceType.color.opacity(0.3), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingPayment) {
            PaymentSheet(
                amount: booking.baseCost + booking.tabTotal,
                itemDescription: booking.displayName,
                onPay: { method, tip in
                    SpaceBookingService.shared.checkOut(booking.id, paymentMethod: method, tipPercent: tip)
                }
            )
        }
    }
}

// MARK: - Compact Order Tracker (for Quick Access Pill)

struct CompactOrderTracker: View {
    let order: FoodOrder

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: order.status.icon)
                .font(.system(size: 12))
                .foregroundColor(order.status.color)

            Text(order.totalItems > 0 ? "\(order.totalItems)" : "")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Mini progress dots
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(order.status.progressPercent >= Double(index + 1) * 0.25 ?
                              order.status.color : Color.white.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(order.status.color.opacity(0.3))
        )
    }
}

// MARK: - Valet Tracker Card

struct ValetTrackerCard: View {
    @ObservedObject var clubAccess: ClubAccessService
    @State private var showingDetail = false
    @State private var showingRetrievalSheet = false

    var request: ValetRequest? {
        clubAccess.valetRequest
    }

    var body: some View {
        if let request = request, request.status != .completed && request.status != .cancelled {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "car.fill")
                        .font(.system(size: 20))
                        .foregroundColor(request.status.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.requestType == .arrival ? "Parking Your Car" : "Retrieving Your Car")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(request.vehicleInfo.displayName)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                    }

                    Spacer()

                    // Ticket number
                    Text(request.ticketNumber)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "f39c12"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "f39c12").opacity(0.2))
                        )
                }

                // Progress Bar
                ValetProgressBar(progress: request.status.progressPercent, status: request.status)
                    .animation(.spring(response: 0.6), value: request.status)

                // Status Text
                HStack {
                    Image(systemName: request.status.icon)
                        .font(.system(size: 14))
                    Text(request.statusDisplayText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(request.status.color)

                // Valet Info (when assigned)
                if let valetName = request.assignedValet {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 36, height: 36)

                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(valetName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)

                            Text(valetStatusDescription(request))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.78))
                        }

                        Spacer()

                        // Animated indicator
                        if request.status != .carParked && request.status != .carReady {
                            ValetActivityIndicator()
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                }

                // Parked Location (for arrival)
                if request.requestType == .arrival && request.status == .carParked,
                   let parkedLocation = request.parkedLocation {
                    HStack(spacing: 8) {
                        Image(systemName: "parkingsign.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)

                        Text("Parked at: \(parkedLocation)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }

                // Delivery Location (for departure)
                if request.requestType == .departure,
                   let location = request.deliveryLocation,
                   (request.status == .bringingCar || request.status == .carReady) {
                    HStack(spacing: 8) {
                        Image(systemName: location.icon)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "f39c12"))

                        Text("Delivering to: \(location.rawValue)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "f39c12").opacity(0.1))
                    )
                }

                // Action Buttons
                HStack(spacing: 12) {
                    // Request Retrieval (if parked)
                    if request.requestType == .arrival && request.status == .carParked {
                        Button {
                            showingRetrievalSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "car.side.fill")
                                    .font(.system(size: 14))
                                Text("Get My Car")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "f39c12"))
                            )
                        }
                    }

                    // View Details
                    Button {
                        showingDetail = true
                    } label: {
                        Text("Details")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "f39c12"))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(request.status.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(request.status.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .sheet(isPresented: $showingDetail) {
                ValetDetailSheet(request: request)
            }
            .sheet(isPresented: $showingRetrievalSheet) {
                CarRetrievalSheet()
            }
        }
    }

    private func valetStatusDescription(_ request: ValetRequest) -> String {
        switch request.status {
        case .valetAssigned:
            return request.requestType == .arrival ? "Taking your car" : "Going to get your car"
        case .drivingToPark:
            return "Driving to parking"
        case .valetOnTheWay:
            return "Walking to your car"
        case .bringingCar:
            return "Driving to \(request.deliveryLocation?.rawValue ?? "entrance")"
        case .carParked:
            return "Your car is parked"
        case .carReady:
            return "Waiting at \(request.deliveryLocation?.rawValue ?? "entrance")"
        default:
            return "Processing request"
        }
    }
}

// MARK: - Valet Progress Bar

struct ValetProgressBar: View {
    let progress: Double
    let status: ValetRequest.ValetStatus

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 12)

                // Progress fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [status.color.opacity(0.8), status.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 12)

                // Progress markers
                HStack(spacing: 0) {
                    ForEach(0..<4) { index in
                        let markerProgress = Double(index + 1) * 0.25
                        Circle()
                            .fill(progress >= markerProgress ? status.color : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Valet Activity Indicator

struct ValetActivityIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Car Retrieval Sheet

struct CarRetrievalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var clubAccess = ClubAccessService.shared
    @State private var selectedLocation: ValetRequest.DeliveryLocation = .mainEntrance

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "car.side.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(hex: "f39c12"))

                        Text("Where should we bring your car?")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)

                    // Location Options
                    VStack(spacing: 12) {
                        ForEach(ValetRequest.DeliveryLocation.allCases, id: \.self) { location in
                            DeliveryLocationRow(
                                location: location,
                                isSelected: selectedLocation == location
                            ) {
                                selectedLocation = location
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Request Button
                    Button {
                        _ = clubAccess.requestCarRetrieval(deliveryLocation: selectedLocation)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 16))
                            Text("Request My Car")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "f39c12"))
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Get Your Car")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "f39c12"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct DeliveryLocationRow: View {
    let location: ValetRequest.DeliveryLocation
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                Image(systemName: location.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color(hex: "f39c12") : .white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color(hex: "f39c12").opacity(0.2) : Color.white.opacity(0.05))
                    )

                Text(location.rawValue)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "f39c12"))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color(hex: "f39c12").opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color(hex: "f39c12").opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Valet Detail Sheet

struct ValetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: ValetRequest

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Vehicle Card
                        VStack(spacing: 16) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: "f39c12"))

                            Text(request.vehicleInfo.displayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            if let plate = request.vehicleInfo.licensePlate {
                                Text(plate)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.78))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.vertical, 30)

                        // Info Grid
                        VStack(spacing: 12) {
                            DetailRow(label: "Ticket", value: request.ticketNumber)
                            DetailRow(label: "Status", value: request.statusDisplayText)
                            if let valet = request.assignedValet {
                                DetailRow(label: "Valet", value: valet)
                            }
                            if let parked = request.parkedLocation {
                                DetailRow(label: "Parked At", value: parked)
                            }
                            if let delivery = request.deliveryLocation {
                                DetailRow(label: "Delivery", value: delivery.rawValue)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )

                        // Progress Timeline
                        ValetProgressTimeline(request: request)
                    }
                    .padding()
                }
            }
            .navigationTitle("Valet Details")
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
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.78))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

struct ValetProgressTimeline: View {
    let request: ValetRequest

    var steps: [(status: ValetRequest.ValetStatus, label: String)] {
        if request.requestType == .arrival {
            return [
                (.requestReceived, "Request Received"),
                (.valetAssigned, "Valet Assigned"),
                (.drivingToPark, "Driving to Park"),
                (.carParked, "Car Parked")
            ]
        } else {
            return [
                (.retrievalRequested, "Request Received"),
                (.valetAssigned, "Valet Assigned"),
                (.valetOnTheWay, "On the Way"),
                (.carReady, "Car Ready")
            ]
        }
    }

    var currentIndex: Int {
        steps.firstIndex(where: { $0.status == request.status }) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PROGRESS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .tracking(1)
                .padding(.bottom, 16)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 14) {
                    // Step indicator
                    ZStack {
                        Circle()
                            .fill(index <= currentIndex ? step.status.color : Color.white.opacity(0.1))
                            .frame(width: 24, height: 24)

                        if index < currentIndex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else if index == currentIndex {
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(step.label)
                        .font(.system(size: 14, weight: index == currentIndex ? .semibold : .regular, design: .rounded))
                        .foregroundColor(index <= currentIndex ? .white : .white.opacity(0.4))

                    Spacer()

                    if index == currentIndex && request.assignedValet != nil {
                        Text(request.assignedValet!)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.blue)
                    }
                }

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentIndex ? step.status.color : Color.white.opacity(0.1))
                        .frame(width: 2, height: 30)
                        .padding(.leading, 11)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Compact Valet Tracker (for Quick Access Pill)

struct CompactValetTracker: View {
    let request: ValetRequest

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: request.status.icon)
                .font(.system(size: 12))
                .foregroundColor(request.status.color)

            Text(request.ticketNumber)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            // Mini progress dots
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(request.status.progressPercent >= Double(index + 1) * 0.25 ?
                              request.status.color : Color.white.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(request.status.color.opacity(0.3))
        )
    }
}

#Preview {
    ZStack {
        Color(hex: "1a1a2e")
            .ignoresSafeArea()

        VStack(spacing: 20) {
            OrderTrackerCard(orderService: FoodOrderService.shared)
            ValetTrackerCard(clubAccess: ClubAccessService.shared)
        }
        .padding()
    }
}
