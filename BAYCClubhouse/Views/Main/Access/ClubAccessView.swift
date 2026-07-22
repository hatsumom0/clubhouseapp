import SwiftUI
import CoreImage.CIFilterBuiltins
import Combine

struct ClubAccessView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var accessService = ClubAccessService.shared

    @State private var selectedTab = 0
    @State private var showingValetSheet = false
    @State private var showingArrivalSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Status Banner
                        if accessService.isAtClubhouse {
                            AtClubhouseBanner(lastCheckIn: accessService.lastCheckIn)
                        }

                        // Quick Actions
                        QuickAccessActions(
                            showingArrivalSheet: $showingArrivalSheet,
                            showingValetSheet: $showingValetSheet,
                            arrivalStatus: accessService.arrivalStatus
                        )

                        // QR Code Entry Card
                        // Canonical member QR (same component the Show QR
                        // sheet presents), framed as the entry card.
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Entry QR Code")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)

                                    Text("Show at entrance for quick access")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(.white.opacity(0.78))
                                }
                                Spacer()
                            }

                            MemberQRView()
                        }
                        .padding(20)
                        .glassCard(cornerRadius: 24, tint: Color(hex: "f39c12").opacity(0.15))

                        // Locker Card
                        LockerAccessCard()

                        // Valet Status Card (if active)
                        if accessService.valetRequest != nil {
                            ValetStatusCard()
                        }

                        // Club Info
                        ClubAccessInfoCard()

                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Club Access")
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
            .sheet(isPresented: $showingValetSheet) {
                ValetRequestSheet()
            }
            .sheet(isPresented: $showingArrivalSheet) {
                ArrivalNotificationSheet()
            }
        }
    }
}

// MARK: - At Clubhouse Banner

struct AtClubhouseBanner: View {
    let lastCheckIn: Date?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("You're at the Clubhouse")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                if let checkIn = lastCheckIn {
                    Text("Checked in \(checkIn.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                }
            }

            Spacer()

            Text("WELCOME")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.green.opacity(0.2)))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Quick Access Actions

struct QuickAccessActions: View {
    @Binding var showingArrivalSheet: Bool
    @Binding var showingValetSheet: Bool
    let arrivalStatus: ArrivalStatus

    var body: some View {
        HStack(spacing: 12) {
            // I'm Arriving Button
            Button {
                showingArrivalSheet = true
            } label: {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: arrivalStatus.isArriving
                                        ? [Color.green, Color.green.opacity(0.7)]
                                        : [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)

                        Image(systemName: arrivalStatus.isArriving ? "checkmark" : "location.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    Text(arrivalStatus.isArriving ? "Arriving" : "I'm Arriving")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if case .confirmed(let eta) = arrivalStatus {
                        Text("\(eta) min")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(arrivalStatus.isArriving ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }

            // Valet Button
            Button {
                showingValetSheet = true
            } label: {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)

                        Image(systemName: "car.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    Text("Valet")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Request")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassCard(cornerRadius: 18)
            }
        }
    }
}

// MARK: - Locker Access Card

struct LockerAccessCard: View {
    @StateObject private var accessService = ClubAccessService.shared
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingCode = false
    @State private var isAssigning = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "3498db"))

                Text("Locker Access")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                if accessService.currentLocker != nil {
                    Text("ASSIGNED")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                }
            }

            if let locker = accessService.currentLocker {
                // Locker assigned view
                HStack(spacing: 20) {
                    // Locker number
                    VStack(spacing: 4) {
                        Text("LOCKER")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))

                        Text(locker.displayNumber)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(locker.floor)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .frame(width: 100)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "3498db").opacity(0.2))
                    )

                    // Access code
                    VStack(spacing: 4) {
                        Text("ACCESS CODE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))

                        if showingCode {
                            Text(locker.accessCode)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "f39c12"))
                        } else {
                            Text("••••")
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.55))
                        }

                        Button {
                            withAnimation { showingCode.toggle() }
                        } label: {
                            Text(showingCode ? "Hide" : "Show")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "3498db"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassCard(cornerRadius: 16)
                }

                // Actions
                HStack(spacing: 12) {
                    Button {
                        _ = accessService.regenerateLockerCode()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("New Code")
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    }

                    Spacer()

                    Button {
                        accessService.releaseLocker()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.open.fill")
                            Text("Release")
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.red.opacity(0.8))
                    }
                }
            } else {
                // No locker assigned
                VStack(spacing: 12) {
                    Text("No locker assigned")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))

                    Button {
                        isAssigning = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            _ = accessService.assignLocker(for: authViewModel.walletAddress ?? UUID().uuidString)
                            isAssigning = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isAssigning {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(isAssigning ? "Assigning..." : "Request Locker")
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "3498db"), Color(hex: "2980b9")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .disabled(isAssigning)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 24)
    }
}

// MARK: - Valet Status Card

struct ValetStatusCard: View {
    @StateObject private var accessService = ClubAccessService.shared

    var body: some View {
        if let request = accessService.valetRequest {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "car.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "f39c12"))

                    Text("Valet Status")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    // Status badge
                    HStack(spacing: 4) {
                        Image(systemName: request.status.icon)
                            .font(.system(size: 12))
                        Text(request.status.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(request.status.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(request.status.color.opacity(0.2)))
                }

                // Vehicle info
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "f39c12").opacity(0.2))
                            .frame(width: 60, height: 60)

                        Image(systemName: "car.side.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "f39c12"))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.vehicleInfo.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Ticket: \(request.ticketNumber)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.78))

                        if let valet = request.assignedValet {
                            Text("Valet: \(valet)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.72))
                        }
                    }

                    Spacer()
                }

                // Progress indicator for in-progress states
                if request.status == .inProgress || request.status == .confirmed {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(index <= progressIndex(for: request.status) ? Color(hex: "f39c12") : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }

                        Spacer()

                        if request.status == .inProgress {
                            Text("Bringing your car...")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.78))
                        }
                    }
                }

                // Ready state celebration
                if request.status == .ready {
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)

                        Text("Your car is ready at the entrance!")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.15))
                    )
                }

                // Cancel button
                if request.status != .ready && request.status != .completed {
                    Button {
                        accessService.cancelValetRequest()
                    } label: {
                        Text("Cancel Request")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(hex: "f39c12").opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private func progressIndex(for status: ValetRequest.ValetStatus) -> Int {
        switch status {
        case .confirmed: return 0
        case .inProgress: return 1
        case .ready: return 2
        default: return -1
        }
    }
}

// MARK: - Club Access Info Card

struct ClubAccessInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Access Information")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                AccessInfoRow(icon: "door.left.hand.open", title: "Main Entrance", detail: "QR code or Apple Wallet")
                AccessInfoRow(icon: "figure.pool.swim", title: "Pool Area", detail: "Membership verified at desk")
                AccessInfoRow(icon: "car.fill", title: "Parking", detail: "Valet available 24/7")
                AccessInfoRow(icon: "clock.fill", title: "Hours", detail: "6:00 AM - 2:00 AM daily")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 24)
    }
}

struct AccessInfoRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "f39c12"))
                .frame(width: 24)

            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            Text(detail)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
        }
    }
}

// MARK: - Arrival Notification Sheet

struct ArrivalNotificationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accessService = ClubAccessService.shared

    @State private var eta: Double = 15
    @State private var guestCount: Int = 0
    @State private var specialRequests: String = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            Image(systemName: "location.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }

                        Text("I'm Arriving")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Let the club know you're on your way")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))

                        // ETA Slider
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Estimated Arrival")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                Text("\(Int(eta)) minutes")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "f39c12"))
                            }

                            Slider(value: $eta, in: 5...60, step: 5)
                                .tint(Color(hex: "f39c12"))
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 16)

                        // Guest Count
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Guests with you")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)

                            HStack(spacing: 16) {
                                Button {
                                    if guestCount > 0 { guestCount -= 1 }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(guestCount == 0 ? .white.opacity(0.3) : Color(hex: "f39c12"))
                                }
                                .disabled(guestCount == 0)

                                Text("\(guestCount)")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 60)

                                Button {
                                    if guestCount < 10 { guestCount += 1 }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(hex: "f39c12"))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 16)

                        // Special Requests
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Special Requests (optional)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)

                            TextField("e.g., Champagne ready, table by window...", text: $specialRequests, axis: .vertical)
                                .font(.system(size: 14, design: .rounded))
                                .padding(12)
                                .glassCard(cornerRadius: 12)
                                .lineLimit(3...5)
                        }

                        // Submit Button
                        Button {
                            isSubmitting = true
                            accessService.notifyArriving(
                                eta: Int(eta),
                                guests: guestCount,
                                specialRequests: specialRequests.isEmpty ? nil : specialRequests
                            )
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bell.fill")
                                }
                                Text(isSubmitting ? "Notifying Club..." : "Notify Club")
                            }
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                        .disabled(isSubmitting)

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Valet Request Sheet

struct ValetRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var accessService = ClubAccessService.shared

    @State private var vehicleMake: String = ""
    @State private var vehicleModel: String = ""
    @State private var vehicleColor: String = ""
    @State private var licensePlate: String = ""
    @State private var specialRequests: String = ""
    @State private var isSubmitting = false
    @State private var requestType: ValetRequestType = .arrival

    enum ValetRequestType {
        case arrival, departure
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            Image(systemName: "car.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }

                        Text("Valet Service")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        // Request type picker
                        Picker("Request Type", selection: $requestType) {
                            Text("Drop Off").tag(ValetRequestType.arrival)
                            Text("Pick Up").tag(ValetRequestType.departure)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)

                        if requestType == .arrival {
                            // Vehicle details form
                            VStack(spacing: 16) {
                                ValetFormField(title: "Make", placeholder: "e.g., Tesla, BMW, Mercedes", text: $vehicleMake)
                                ValetFormField(title: "Model", placeholder: "e.g., Model S, M5, S-Class", text: $vehicleModel)
                                ValetFormField(title: "Color", placeholder: "e.g., Black, White, Silver", text: $vehicleColor)
                                ValetFormField(title: "License Plate (optional)", placeholder: "ABC-1234", text: $licensePlate)
                            }

                            // Special requests
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Special Requests")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)

                                TextField("e.g., Keep AC running, charging needed...", text: $specialRequests, axis: .vertical)
                                    .font(.system(size: 14, design: .rounded))
                                    .padding(12)
                                    .glassCard(cornerRadius: 12)
                                    .lineLimit(2...4)
                            }
                        } else {
                            // Pick up - show current ticket if available
                            if let request = accessService.valetRequest {
                                VStack(spacing: 16) {
                                    Text("Your vehicle")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.78))

                                    Text(request.vehicleInfo.displayName)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)

                                    Text("Ticket: \(request.ticketNumber)")
                                        .font(.system(size: 16, design: .monospaced))
                                        .foregroundColor(Color(hex: "f39c12"))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .glassCard(cornerRadius: 16)
                            } else {
                                Text("No vehicle currently parked with valet")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.78))
                                    .padding(24)
                            }
                        }

                        // Submit Button
                        Button {
                            submitRequest()
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: requestType == .arrival ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                }
                                Text(isSubmitting ? "Requesting..." : (requestType == .arrival ? "Request Valet" : "Bring My Car"))
                            }
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                        .disabled(isSubmitting || (requestType == .arrival && (vehicleMake.isEmpty || vehicleModel.isEmpty || vehicleColor.isEmpty)))
                        .opacity((requestType == .arrival && (vehicleMake.isEmpty || vehicleModel.isEmpty || vehicleColor.isEmpty)) ? 0.5 : 1)

                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func submitRequest() {
        isSubmitting = true

        if requestType == .arrival {
            let vehicleInfo = VehicleInfo(
                make: vehicleMake,
                model: vehicleModel,
                color: vehicleColor,
                licensePlate: licensePlate.isEmpty ? nil : licensePlate
            )
            _ = accessService.requestValet(
                vehicleInfo: vehicleInfo,
                specialRequests: specialRequests.isEmpty ? nil : specialRequests
            )
        } else {
            _ = accessService.requestCarRetrieval()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

struct ValetFormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)

            TextField(placeholder, text: $text)
                .font(.system(size: 15, design: .rounded))
                .padding(12)
                .glassCard(cornerRadius: 12)
        }
    }
}

// MARK: - Preview

#Preview {
    ClubAccessView()
        .environmentObject(AuthViewModel())
}
