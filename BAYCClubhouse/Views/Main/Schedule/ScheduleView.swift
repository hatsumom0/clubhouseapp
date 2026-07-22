import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var chatManager: ChatManager
    @State private var selectedDate = Date()
    @State private var showingAddReservation = false
    @State private var showQuickAccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(hex: "1a1a2e"),
                        Color(hex: "16213e"),
                        Color(hex: "0f3460")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 24) {
                        // Calendar Header
                        CalendarHeaderView(selectedDate: $selectedDate)

                        // My Reservations Section
                        MyReservationsSection()

                        // Upcoming Events I'm Attending
                        MyEventsSection()

                        // Quick Book Section
                        QuickBookSection(showingAddReservation: $showingAddReservation)

                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .scrollIndicators(.visible)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarTitleView(title: "MY SCHEDULE")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        QuickAccessPillButton(showQuickAccess: $showQuickAccess)

                        ChatToolbarButton()

                        Button {
                            showingAddReservation = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: "f39c12"))
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddReservation) {
                AddReservationView()
            }
            .sheet(isPresented: $showQuickAccess) {
                QuickAccessSheet()
            }
        }
    }
}

// MARK: - Calendar Header

struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    @StateObject private var eventManager = EventManager.shared
    @State private var isExpanded = false
    @State private var displayedMonth: Date = Date()
    @State private var dragOffset: CGFloat = 0

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 16) {
            // Month/Year with navigation
            HStack {
                Button {
                    navigatePrevious()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(monthYearString)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(isExpanded ? "Month View" : "Week View")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }

                Spacer()

                Button {
                    navigateNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.78))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }

            // Week days header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid - Week or Month view
            if isExpanded {
                // Month view
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(monthDates, id: \.self) { date in
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvent: hasEvent(on: date),
                            isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                        ) {
                            selectedDate = date
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Week view
                HStack(spacing: 0) {
                    ForEach(currentWeekDates, id: \.self) { date in
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasEvent: hasEvent(on: date),
                            isCurrentMonth: true
                        ) {
                            selectedDate = date
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 4)
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if value.translation.height > 50 && !isExpanded {
                            // Drag down - expand to month
                            isExpanded = true
                        } else if value.translation.height < -50 && isExpanded {
                            // Drag up - collapse to week
                            isExpanded = false
                        }
                        dragOffset = 0
                    }
                }
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var currentWeekDates: [Date] {
        let weekday = calendar.component(.weekday, from: displayedMonth)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: displayedMonth)!

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }

    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }

        var dates: [Date] = []
        var currentDate = monthFirstWeek.start

        while currentDate < monthLastWeek.end {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return dates
    }

    private func hasEvent(on date: Date) -> Bool {
        // Check EventManager for events on this date
        return eventManager.events.contains { event in
            calendar.isDate(event.date, inSameDayAs: date)
        }
    }

    private func navigatePrevious() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isExpanded {
                // Previous month
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } else {
                // Previous week
                displayedMonth = calendar.date(byAdding: .weekOfYear, value: -1, to: displayedMonth) ?? displayedMonth
            }
        }
    }

    private func navigateNext() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isExpanded {
                // Next month
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } else {
                // Next week
                displayedMonth = calendar.date(byAdding: .weekOfYear, value: 1, to: displayedMonth) ?? displayedMonth
            }
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvent: Bool
    var isCurrentMonth: Bool = true
    let onTap: () -> Void

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                    } else if isToday {
                        Circle()
                            .stroke(Color(hex: "f39c12"), lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }

                    Text(dayNumber)
                        .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular, design: .rounded))
                        .foregroundColor(
                            isSelected ? .white :
                            isCurrentMonth ? .white.opacity(0.8) : .white.opacity(0.3)
                        )
                }

                // Event indicator dot
                Circle()
                    .fill(hasEvent && isCurrentMonth ? Color(hex: "f39c12") : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - My Reservations Section

struct MyReservationsSection: View {
    @StateObject private var eventManager = EventManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Reservations")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                if eventManager.activeReservations.count > 3 {
                    Text("View All")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "f39c12"))
                }
            }

            if eventManager.activeReservations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.55))

                    Text("No active reservations")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))

                    Text("Book a lounge, spa treatment, or dining experience!")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .glassCard(cornerRadius: 18)
            } else {
                VStack(spacing: 12) {
                    ForEach(eventManager.activeReservations.prefix(4)) { reservation in
                        NavigationLink {
                            ReservationDetailView(reservation: reservation)
                        } label: {
                            ReservationCard(reservation: reservation)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

struct ReservationCard: View {
    let reservation: Reservation

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                reservation.category.color.opacity(0.3),
                                reservation.category.color.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: reservation.icon)
                    .font(.system(size: 20))
                    .foregroundColor(reservation.category.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reservation.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("\(reservation.formattedDate) • \(reservation.formattedTime)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text("\(reservation.guests)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.72))

                    Text(reservation.status.rawValue)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(reservation.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(reservation.status.color.opacity(0.2))
                        )
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }
}

// MARK: - Reservation Detail View

struct ReservationDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var chatManager: ChatManager
    @StateObject private var eventManager = EventManager.shared
    let reservation: Reservation
    @State private var showingCancelAlert = false
    @State private var isCancelled = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f3460")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    ReservationHeaderCard(reservation: reservation, isCancelled: isCancelled)

                    // Details section
                    ReservationDetailsSection(reservation: reservation)

                    // Concierge button
                    Button {
                        chatManager.openChat()
                        chatManager.sendMessage("I have a question about my \(reservation.title) reservation on \(reservation.formattedDate)")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 18))

                            Text("Message Concierge")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }

                    // Cancel button
                    if !isCancelled && reservation.status != .cancelled {
                        Button {
                            showingCancelAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))

                                Text("Cancel Reservation")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .glassCard(cornerRadius: 18)
                        }
                    }

                    Spacer()
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("RESERVATION")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("Cancel Reservation", isPresented: $showingCancelAlert) {
            Button("Keep Reservation", role: .cancel) {}
            Button("Cancel", role: .destructive) {
                withAnimation {
                    isCancelled = true
                    eventManager.cancelReservation(reservation.id)
                }
            }
        } message: {
            Text("Are you sure you want to cancel your \(reservation.title) reservation? This action cannot be undone.")
        }
    }
}

struct ReservationHeaderCard: View {
    let reservation: Reservation
    let isCancelled: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [reservation.category.color.opacity(0.3), reservation.category.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: reservation.icon)
                    .font(.system(size: 36))
                    .foregroundColor(reservation.category.color)
            }

            Text(reservation.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Status badge
            HStack(spacing: 6) {
                Circle()
                    .fill(isCancelled ? Color.red : reservation.status.color)
                    .frame(width: 8, height: 8)

                Text(isCancelled ? "Cancelled" : reservation.status.rawValue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isCancelled ? .red : reservation.status.color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill((isCancelled ? Color.red : reservation.status.color).opacity(0.2))
            )

            // Date and time
            VStack(spacing: 4) {
                Text(reservation.formattedDate)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(reservation.formattedTime)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 24)
    }
}

struct ReservationDetailsSection: View {
    let reservation: Reservation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DETAILS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .tracking(1)

            VStack(spacing: 16) {
                // Location
                HStack(spacing: 14) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "f39c12"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(reservation.location)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        if let detail = reservation.locationDetail {
                            Text(detail)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.white.opacity(0.78))
                        }
                    }

                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Guests
                HStack(spacing: 14) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "3498db"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Guests")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("\(reservation.guests) \(reservation.guests == 1 ? "person" : "people")")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.78))
                    }

                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(reservation.description)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(4)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
        }
    }
}

// MARK: - My Events Section

struct MyEventsSection: View {
    @StateObject private var eventManager = EventManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Events I'm Attending")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if eventManager.mySchedule.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.55))

                    Text("No upcoming events")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))

                    Text("Browse events on the Home tab or ask the concierge to RSVP!")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .glassCard(cornerRadius: 18)
            } else {
                VStack(spacing: 12) {
                    ForEach(eventManager.mySchedule) { event in
                        NavigationLink {
                            EventDetailView(event: event)
                        } label: {
                            AttendingEventCard(event: event)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

struct AttendingEventCard: View {
    let event: ClubEvent

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: event.date).uppercased()
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: event.date)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        return formatter.string(from: event.date)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Date badge
            VStack(spacing: 2) {
                Text(monthString)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(event.category.color)

                Text(dayString)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(formattedDate)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                        Text(event.location)
                            .font(.system(size: 11, design: .rounded))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(event.totalSpots - event.spotsLeft) going")
                            .font(.system(size: 11, design: .rounded))
                    }
                }
                .foregroundColor(.white.opacity(0.72))
            }

            Spacer()

            // RSVP badge
            Text(event.rsvpStatus.displayText.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(event.rsvpStatus.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(event.rsvpStatus.color.opacity(0.2))
                )
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }
}

// MARK: - Quick Book Section

struct QuickBookSection: View {
    @Binding var showingAddReservation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Book")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickBookCard(icon: "sofa.fill", title: "Lounge", onTap: { showingAddReservation = true })
                QuickBookCard(icon: "fork.knife", title: "Dining", onTap: { showingAddReservation = true })
                QuickBookCard(icon: "dumbbell.fill", title: "Fitness", onTap: { showingAddReservation = true })
                QuickBookCard(icon: "sparkles", title: "Spa", onTap: { showingAddReservation = true })
            }
        }
    }
}

struct QuickBookCard: View {
    let icon: String
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: "f39c12"))

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .glassCard(cornerRadius: 18)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Reservation View

struct AddReservationView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1a1a2e")
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("New Reservation")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Coming Soon")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))

                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "f39c12"))
                }
            }
        }
    }
}

#Preview {
    ScheduleView()
        .environmentObject(ChatManager())
}
