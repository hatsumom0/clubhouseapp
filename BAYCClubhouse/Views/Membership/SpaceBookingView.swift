import SwiftUI

// MARK: - Space Booking View

struct SpaceBookingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var bookingService = SpaceBookingService.shared
    @StateObject private var accessService = ClubAccessService.shared

    @State private var selectedType: SpaceBooking.SpaceType = .meetingRoom
    @State private var selectedDate: Date = Date()
    @State private var selectedStartTime: Date = Date()
    @State private var selectedEndTime: Date = Date().addingTimeInterval(3600)
    @State private var selectedSpace: AvailableSpace?
    @State private var guestCount: Int = 2
    @State private var specialRequests: String = ""
    @State private var showingConfirmation = false
    @State private var confirmedBooking: SpaceBooking?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Space Type Selector
                        spaceTypeSelector

                        // Cabana notice (only when not at clubhouse)
                        if selectedType == .cabana && !accessService.isAtClubhouse {
                            cabanaNotice
                        }

                        // Date Selection
                        dateSection

                        // Time Selection
                        timeSection

                        // Available Spaces
                        spacesSection

                        // Guest Count
                        guestSection

                        // Special Requests
                        requestsSection

                        // Price Summary
                        if selectedSpace != nil {
                            priceSummary
                        }

                        // Book Button
                        bookButton

                        Spacer().frame(height: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Book a Space")
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
            .sheet(isPresented: $showingConfirmation) {
                if let booking = confirmedBooking {
                    BookingConfirmationView(booking: booking) {
                        showingConfirmation = false
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Space Type Selector

    private var spaceTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Space Type")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 12) {
                ForEach(SpaceBooking.SpaceType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedType = type
                            selectedSpace = nil
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18))

                            Text(type.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(selectedType == type ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selectedType == type ? type.color.opacity(0.8) : .white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selectedType == type ? type.color : .clear, lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Cabana Notice

    private var cabanaNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "f39c12"))

            Text("Cabana bookings are available when you're at the clubhouse. You can browse availability now.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "f39c12").opacity(0.15))
        )
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            DatePicker(
                "",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(selectedType.color)
            .colorScheme(.dark)
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))

                    DatePicker("", selection: $selectedStartTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(selectedType.color)
                        .colorScheme(.dark)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("End")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))

                    DatePicker("", selection: $selectedEndTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(selectedType.color)
                        .colorScheme(.dark)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.1))
                )
            }

            // Duration display
            let duration = selectedEndTime.timeIntervalSince(selectedStartTime) / 3600
            if duration > 0 {
                Text("\(String(format: "%.1f", duration)) hours")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(selectedType.color)
            }
        }
    }

    // MARK: - Spaces Section

    private var spacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Spaces")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            let spaces = selectedType == .cabana ?
                AvailableSpace.sampleCabanas : AvailableSpace.sampleMeetingRooms

            ForEach(spaces) { space in
                SpaceOptionCard(
                    space: space,
                    isSelected: selectedSpace?.id == space.id,
                    onSelect: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedSpace = space
                        }
                    }
                )
            }
        }
    }

    // MARK: - Guest Section

    private var guestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Number of Guests")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            HStack {
                Button {
                    if guestCount > 1 { guestCount -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(guestCount > 1 ? selectedType.color : .gray)
                }

                Text("\(guestCount)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 60)

                Button {
                    let max = selectedSpace?.maxGuests ?? 20
                    if guestCount < max { guestCount += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(selectedType.color)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white.opacity(0.1))
            )

            if let space = selectedSpace {
                Text("Max: \(space.maxGuests) guests")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Requests Section

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Special Requests (Optional)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            TextField("E.g., Extra towels, champagne on ice...", text: $specialRequests, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white)
                .padding(16)
                .frame(minHeight: 80, alignment: .top)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.1))
                )
                .lineLimit(3...6)
        }
    }

    // MARK: - Price Summary

    private var priceSummary: some View {
        VStack(spacing: 12) {
            let duration = selectedEndTime.timeIntervalSince(selectedStartTime) / 3600
            let total = selectedType.hourlyRate * duration

            HStack {
                Text("Hourly Rate")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("$\(String(format: "%.0f", selectedType.hourlyRate))/hr")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }

            HStack {
                Text("Duration")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(String(format: "%.1f", duration)) hours")
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
                Text("$\(String(format: "%.2f", total))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(selectedType.color)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Book Button

    private var bookButton: some View {
        Button {
            bookSpace()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                Text("Confirm Booking")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        selectedSpace != nil ?
                        LinearGradient(colors: [selectedType.color, selectedType.color.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing) :
                        LinearGradient(colors: [.gray, .gray.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
            )
        }
        .disabled(selectedSpace == nil)
    }

    // MARK: - Actions

    private func bookSpace() {
        guard let space = selectedSpace else { return }

        let booking = bookingService.bookSpace(
            space: space,
            date: selectedDate,
            startTime: selectedStartTime,
            endTime: selectedEndTime,
            guestCount: guestCount,
            specialRequests: specialRequests.isEmpty ? nil : specialRequests
        )

        confirmedBooking = booking
        showingConfirmation = true
    }
}

// MARK: - Space Option Card

struct SpaceOptionCard: View {
    let space: AvailableSpace
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(space.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text(space.floor)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(space.spaceType.color)
                    }
                }

                // Amenities
                FlowLayout(spacing: 6) {
                    ForEach(space.amenities, id: \.self) { amenity in
                        Text(amenity)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.1))
                            )
                    }
                }

                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("Up to \(space.maxGuests) guests")
                        .font(.system(size: 12, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? space.spaceType.color.opacity(0.2) : .white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? space.spaceType.color : .clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

// MARK: - Booking Confirmation View

struct BookingConfirmationView: View {
    let booking: SpaceBooking
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "1a1a2e")
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Success icon
                ZStack {
                    Circle()
                        .fill(booking.spaceType.color.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(booking.spaceType.color)
                }

                VStack(spacing: 8) {
                    Text("Booking Confirmed!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(booking.displayName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(booking.spaceType.color)
                }

                // Details
                VStack(spacing: 16) {
                    ConfirmationRow(icon: "calendar", label: "Date", value: booking.formattedDate)
                    ConfirmationRow(icon: "clock", label: "Time", value: booking.formattedTimeRange)
                    ConfirmationRow(icon: "mappin", label: "Location", value: booking.floor)
                    ConfirmationRow(icon: "person.2", label: "Guests", value: "\(booking.guestCount)")
                    ConfirmationRow(icon: "dollarsign.circle", label: "Total", value: booking.formattedTotalCost)
                }
                .padding(20)
                .glassCard(cornerRadius: 20)
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(booking.spaceType.color)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

struct ConfirmationRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    SpaceBookingView()
}
