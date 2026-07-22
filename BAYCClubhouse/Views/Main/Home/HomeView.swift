import SwiftUI

// MARK: - Upcoming Item (Event or Reservation)

struct UpcomingItem: Identifiable {
    let id = UUID()
    let event: ClubEvent?
    let reservation: Reservation?
    let date: Date
}

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatManager: ChatManager

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

                ScrollView {
                    VStack(spacing: 24) {
                        // Welcome header
                        WelcomeHeader()

                        // AI Summary Card
                        AISummaryCard()

                        // Clubhouse Info Card
                        ClubhouseInfoCard()

                        // Upcoming Events Section
                        UpcomingEventsSection()

                        // Yuga News Section
                        YugaNewsSection()

                        // Featured Articles Section
                        FeaturedArticlesSection()

                        // Community Highlights
                        CommunityHighlightsSection()

                        // Member Perks Section
                        MemberPerksSection()

                        // Clubhouse Hours Section
                        ClubhouseHoursSection()

                        // Extra padding for tab bar
                        Color.clear
                            .frame(height: 140)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .globalToolbar(title: "CLUBHOUSE - MIAMI")
        }
    }
}

struct WelcomeHeader: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var weatherService = WeatherService.shared

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome back,")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Text(authViewModel.userNickname ?? "Ape #\(authViewModel.primaryNFTId ?? "????")")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Spacer()

            // Weather Widget
            if let weather = weatherService.currentWeather {
                WeatherWidget(weather: weather)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .task {
            await weatherService.fetchWeather()
        }
    }
}

// MARK: - Weather Widget

struct WeatherWidget: View {
    let weather: WeatherData

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: weather.sfSymbol)
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: weather.gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(weather.temperatureFahrenheit)°F")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Miami")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - AI Summary Card

struct AISummaryCard: View {
    @StateObject private var eventManager = EventManager.shared
    @StateObject private var weatherService = WeatherService.shared
    @StateObject private var orderService = FoodOrderService.shared
    @StateObject private var bookingService = SpaceBookingService.shared
    @EnvironmentObject var chatManager: ChatManager
    @State private var isExpanded = false
    @State private var showMySchedule = false
    @State private var showWeatherDetail = false
    @State private var showCurrentTab = false

    private var upcomingEvents: [ClubEvent] {
        eventManager.mySchedule.filter { $0.date > Date() }.sorted { $0.date < $1.date }
    }

    private var activeReservations: [Reservation] {
        eventManager.activeReservations.filter { $0.date > Date() }
    }

    private var hasOpenTab: Bool {
        orderService.currentOrder != nil && orderService.currentOrder?.status != .closed
    }

    private var hasActiveSpaceBooking: Bool {
        bookingService.currentBooking != nil && bookingService.currentBooking?.isActive == true
    }

    // Combined events and reservations sorted by date
    private var upcomingItems: [UpcomingItem] {
        var items: [UpcomingItem] = []

        for event in upcomingEvents {
            items.append(UpcomingItem(event: event, reservation: nil, date: event.date))
        }

        for reservation in activeReservations {
            items.append(UpcomingItem(event: nil, reservation: reservation, date: reservation.date))
        }

        return items.sorted { $0.date < $1.date }
    }

    private var summaryText: String {
        var lines: [String] = []

        // Events & reservations summary
        let eventCount = upcomingEvents.count
        let reservationCount = activeReservations.count
        let totalCount = eventCount + reservationCount

        if totalCount > 0 {
            if let nextItem = upcomingItems.first {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE 'at' h:mm a"

                var countText = ""
                if eventCount > 0 && reservationCount > 0 {
                    countText = "\(eventCount) event\(eventCount == 1 ? "" : "s") and \(reservationCount) reservation\(reservationCount == 1 ? "" : "s")"
                } else if eventCount > 0 {
                    countText = "\(eventCount) upcoming event\(eventCount == 1 ? "" : "s")"
                } else {
                    countText = "\(reservationCount) reservation\(reservationCount == 1 ? "" : "s")"
                }

                let itemTitle = nextItem.event?.title ?? nextItem.reservation?.title ?? "Activity"
                let itemDate = formatter.string(from: nextItem.date)
                lines.append("You have \(countText). Next: \(itemTitle) on \(itemDate).")
            }
        } else {
            lines.append("No upcoming events or reservations. Check out what's happening at the clubhouse!")
        }

        // Weather summary
        if let weather = weatherService.currentWeather {
            if weather.temperature >= 80 {
                lines.append("It's a warm \(weather.temperatureFahrenheit)°F in Miami - perfect for the rooftop lounge.")
            } else if weather.icon.contains("10") || weather.icon.contains("09") {
                lines.append("Rain expected today (\(weather.temperatureFahrenheit)°F) - great day for indoor activities.")
            } else {
                lines.append("Beautiful \(weather.temperatureFahrenheit)°F weather in Miami today.")
            }
        }

        // Messages summary
        let unreadCount = chatManager.unreadCount
        if unreadCount > 0 {
            lines.append("You have \(unreadCount) unread message\(unreadCount == 1 ? "" : "s").")
        }

        // Open tab summary
        if hasOpenTab, let order = orderService.currentOrder {
            let itemCount = order.items.count
            let total = order.items.reduce(0) { $0 + ($1.menuItem.price * Double($1.quantity)) }
            lines.append("You have an open tab with \(itemCount) item\(itemCount == 1 ? "" : "s") ($\(String(format: "%.2f", total))).")
        }

        // Active space booking summary
        if hasActiveSpaceBooking, let booking = bookingService.currentBooking {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let endTimeStr = timeFormatter.string(from: booking.endTime)
            lines.append("Your \(booking.spaceName) is booked until \(endTimeStr).")
        }

        return lines.joined(separator: " ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Concierge Summary")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Your personalized daily briefing")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.72))
                }
            }

            // Summary content
            Text(summaryText)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
                .lineLimit(isExpanded ? nil : 3)

            // Expanded content
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.white.opacity(0.2))

                    // Quick actions
                    HStack(spacing: 12) {
                        SummaryQuickAction(icon: "calendar", title: "View Events", color: Color(hex: "f39c12")) {
                            showMySchedule = true
                        }
                        SummaryQuickAction(icon: "message.fill", title: "Open Chat", color: Color(hex: "3498db")) {
                            chatManager.toggleChat()
                        }
                        SummaryQuickAction(icon: "cloud.sun.fill", title: "Weather", color: Color(hex: "27ae60")) {
                            showWeatherDetail = true
                        }
                    }

                    // Active Tab & Space Bookings
                    if hasOpenTab || hasActiveSpaceBooking {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ACTIVE NOW")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.72))
                                .tracking(1)

                            // Open Tab Row
                            if hasOpenTab, let order = orderService.currentOrder {
                                Button {
                                    showCurrentTab = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "menucard.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "f39c12"))
                                            .frame(width: 28, height: 28)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color(hex: "f39c12").opacity(0.2))
                                            )

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Open Tab")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)

                                            let itemCount = order.items.count
                                            let total = order.items.reduce(0) { $0 + ($1.menuItem.price * Double($1.quantity)) }
                                            Text("\(itemCount) item\(itemCount == 1 ? "" : "s") • $\(String(format: "%.2f", total))")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundColor(.white.opacity(0.72))
                                        }

                                        Spacer()

                                        Text(order.status.rawValue.uppercased())
                                            .font(.system(size: 8, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(hex: "f39c12"))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color(hex: "f39c12").opacity(0.2)))

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.55))
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            // Active Space Booking Row
                            if hasActiveSpaceBooking, let booking = bookingService.currentBooking {
                                HStack(spacing: 10) {
                                    Image(systemName: booking.spaceType == .cabana ? "beach.umbrella.fill" : "person.3.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "8b5cf6"))
                                        .frame(width: 28, height: 28)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hex: "8b5cf6").opacity(0.2))
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(booking.spaceName)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)

                                        let timeFormatter = DateFormatter()
                                        let _ = timeFormatter.dateFormat = "h:mm a"
                                        Text("Until \(timeFormatter.string(from: booking.endTime))")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(.white.opacity(0.72))
                                    }

                                    Spacer()

                                    Text("ACTIVE")
                                        .font(.system(size: 8, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "27ae60"))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color(hex: "27ae60").opacity(0.2)))
                                }
                            }
                        }
                    }

                    // Upcoming events AND reservations preview
                    if !upcomingItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEXT UP")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.72))
                                .tracking(1)

                            ForEach(upcomingItems.prefix(3), id: \.id) { item in
                                if let event = item.event {
                                    NavigationLink {
                                        EventDetailView(event: event)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: event.imageSystemName)
                                                .font(.system(size: 14))
                                                .foregroundColor(event.category.color)
                                                .frame(width: 28, height: 28)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(event.category.color.opacity(0.2))
                                                )

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(event.title)
                                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)

                                                Text(formatEventDate(event.date))
                                                    .font(.system(size: 11, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.72))
                                            }

                                            Spacer()

                                            Text("EVENT")
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                .foregroundColor(event.category.color)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(event.category.color.opacity(0.2)))

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.55))
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                } else if let reservation = item.reservation {
                                    NavigationLink {
                                        ReservationDetailView(reservation: reservation)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: reservation.category.icon)
                                                .font(.system(size: 14))
                                                .foregroundColor(reservation.category.color)
                                                .frame(width: 28, height: 28)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(reservation.category.color.opacity(0.2))
                                                )

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(reservation.title)
                                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)

                                                Text("\(reservation.formattedDate) • \(reservation.formattedTime)")
                                                    .font(.system(size: 11, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.72))
                                            }

                                            Spacer()

                                            Text("RESERVATION")
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                .foregroundColor(reservation.category.color)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(reservation.category.color.opacity(0.2)))

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.55))
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1e1e3f"), Color(hex: "2d2d5a")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "8b5cf6").opacity(0.5), Color(hex: "6366f1").opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: Color(hex: "8b5cf6").opacity(0.2), radius: 15, y: 5)
        .sheet(isPresented: $showMySchedule) {
            MyScheduleView()
        }
        .sheet(isPresented: $showWeatherDetail) {
            WeatherDetailView()
        }
        .sheet(isPresented: $showCurrentTab) {
            if orderService.currentOrder != nil {
                CurrentTabSheet()
            }
        }
    }

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - My Schedule View

struct MyScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var eventManager = EventManager.shared

    private var upcomingEvents: [ClubEvent] {
        eventManager.mySchedule.filter { $0.date > Date() }.sorted { $0.date < $1.date }
    }

    private var activeReservations: [Reservation] {
        eventManager.activeReservations
    }

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
                        // Header stats
                        HStack(spacing: 16) {
                            ScheduleStatCard(
                                icon: "calendar.badge.checkmark",
                                value: "\(upcomingEvents.count)",
                                label: "Events",
                                color: Color(hex: "f39c12")
                            )
                            ScheduleStatCard(
                                icon: "bookmark.fill",
                                value: "\(activeReservations.count)",
                                label: "Reservations",
                                color: Color(hex: "8b5cf6")
                            )
                        }
                        .padding(.top, 8)

                        // Events Section
                        if !upcomingEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(title: "Upcoming Events", icon: "calendar")

                                ForEach(upcomingEvents) { event in
                                    NavigationLink {
                                        EventDetailView(event: event)
                                    } label: {
                                        ScheduleEventCard(event: event)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }

                        // Reservations Section
                        if !activeReservations.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(title: "Reservations", icon: "bookmark.fill")

                                ForEach(activeReservations) { reservation in
                                    NavigationLink {
                                        ReservationDetailView(reservation: reservation)
                                    } label: {
                                        ScheduleReservationCard(reservation: reservation)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }

                        // Empty State
                        if upcomingEvents.isEmpty && activeReservations.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.55))

                                Text("No Upcoming Events")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))

                                Text("Browse events and make reservations to see them here")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.72))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 60)
                        }

                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("My Schedule")
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

struct ScheduleStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: 18)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "f39c12"))

            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .tracking(1)
        }
    }
}

struct ScheduleEventCard: View {
    let event: ClubEvent

    private var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(event.date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if Calendar.current.isDateInTomorrow(event.date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        }
        return formatter.string(from: event.date)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Event icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [event.category.color.opacity(0.3), event.category.color.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                Image(systemName: event.imageSystemName)
                    .font(.system(size: 22))
                    .foregroundColor(event.category.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if event.isExclusiveEvent {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "f39c12"))
                    }
                }

                Text(formattedDate)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))

                HStack(spacing: 8) {
                    Label(event.location, systemImage: "mappin")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))

                    if event.rsvpStatus == .going {
                        Text("GOING")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.2)))
                    }
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

struct ScheduleReservationCard: View {
    let reservation: Reservation

    var body: some View {
        HStack(spacing: 14) {
            // Reservation icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [reservation.category.color.opacity(0.3), reservation.category.color.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                Image(systemName: reservation.category.icon)
                    .font(.system(size: 22))
                    .foregroundColor(reservation.category.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(reservation.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(reservation.formattedDate) • \(reservation.formattedTime)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))

                HStack(spacing: 8) {
                    Label(reservation.location, systemImage: "mappin")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))

                    Text(reservation.status.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(reservation.status.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(reservation.status.color.opacity(0.2)))

                    if reservation.guests > 1 {
                        Label("\(reservation.guests)", systemImage: "person.2.fill")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))
                    }
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

// MARK: - Weather Detail View

struct WeatherDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weatherService = WeatherService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic weather background
                weatherBackground

                ScrollView {
                    VStack(spacing: 24) {
                        // Current Weather Hero
                        if let weather = weatherService.currentWeather {
                            CurrentWeatherHero(weather: weather)
                        }

                        // Weather Details Grid
                        if let weather = weatherService.currentWeather {
                            WeatherDetailsGrid(weather: weather)
                        }

                        // 5-Day Forecast
                        if !weatherService.forecast.isEmpty {
                            ForecastSection(forecast: weatherService.forecast)
                        }

                        // Weather-Based Suggestions
                        WeatherSuggestionsSection()

                        // Last Updated
                        if let lastUpdated = weatherService.lastUpdated {
                            Text("Last updated: \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.white.opacity(0.65))
                                .padding(.top, 8)
                        }

                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Weather")
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
        .task {
            await weatherService.fetchWeather()
        }
    }

    @ViewBuilder
    private var weatherBackground: some View {
        if let weather = weatherService.currentWeather {
            LinearGradient(
                colors: weatherGradientColors(for: weather),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(
                ZStack {
                    // Animated weather particles
                    if weather.icon.contains("10") || weather.icon.contains("09") {
                        RainOverlay()
                    } else if weather.icon.contains("01") {
                        SunOverlay()
                    }
                }
            )
        } else {
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func weatherGradientColors(for weather: WeatherData) -> [Color] {
        switch weather.icon {
        case "01d": // Clear day
            return [Color(hex: "74b9ff"), Color(hex: "0984e3"), Color(hex: "2d3436")]
        case "01n": // Clear night
            return [Color(hex: "0c0c1e"), Color(hex: "1a1a2e"), Color(hex: "2d3436")]
        case "02d", "03d", "04d": // Cloudy day
            return [Color(hex: "636e72"), Color(hex: "2d3436"), Color(hex: "1a1a2e")]
        case "02n", "03n", "04n": // Cloudy night
            return [Color(hex: "1a1a2e"), Color(hex: "2d3436"), Color(hex: "0c0c1e")]
        case "09d", "09n", "10d", "10n": // Rain
            return [Color(hex: "2d3436"), Color(hex: "636e72"), Color(hex: "1a1a2e")]
        case "11d", "11n": // Thunderstorm
            return [Color(hex: "1a1a2e"), Color(hex: "2d3436"), Color(hex: "0c0c1e")]
        default:
            return [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")]
        }
    }
}

struct CurrentWeatherHero: View {
    let weather: WeatherData

    var body: some View {
        VStack(spacing: 8) {
            // Weather Icon
            Image(systemName: weather.sfSymbol)
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: weather.gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: weather.gradientColors.first?.opacity(0.5) ?? .clear, radius: 20)

            // Temperature
            Text("\(weather.temperatureFahrenheit)°")
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .foregroundColor(.white)

            // Description
            Text(weather.briefDescription)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            // Feels like
            if weather.feelsLikeFahrenheit != weather.temperatureFahrenheit {
                Text("Feels like \(weather.feelsLikeFahrenheit)°")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
            }

            // Location
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                Text(weather.cityName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.72))
            .padding(.top, 4)
        }
        .padding(.vertical, 30)
    }
}

struct WeatherDetailsGrid: View {
    let weather: WeatherData

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            WeatherDetailTile(
                icon: "thermometer.medium",
                title: "Feels Like",
                value: "\(weather.feelsLikeFahrenheit)°F",
                color: Color(hex: "e74c3c")
            )

            WeatherDetailTile(
                icon: "humidity.fill",
                title: "Humidity",
                value: "\(weather.humidity)%",
                color: Color(hex: "3498db")
            )

            WeatherDetailTile(
                icon: "wind",
                title: "Wind",
                value: "\(weather.windSpeedMph) mph",
                color: Color(hex: "1abc9c")
            )

            WeatherDetailTile(
                icon: "sun.max.fill",
                title: "UV Index",
                value: "Moderate",
                color: Color(hex: "f39c12")
            )
        }
    }
}

struct WeatherDetailTile: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
            }

            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}

struct ForecastSection: View {
    let forecast: [WeatherForecast]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("5-DAY FORECAST")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .tracking(1)

            VStack(spacing: 0) {
                ForEach(Array(forecast.enumerated()), id: \.element.id) { index, day in
                    HStack {
                        Text(index == 0 ? "Today" : day.dayName)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 60, alignment: .leading)

                        Spacer()

                        Image(systemName: day.sfSymbol)
                            .font(.system(size: 20))
                            .foregroundColor(iconColor(for: day.icon))
                            .frame(width: 30)

                        Spacer()

                        HStack(spacing: 12) {
                            Text("\(day.low)°")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.white.opacity(0.72))
                                .frame(width: 35, alignment: .trailing)

                            // Temperature bar
                            GeometryReader { geometry in
                                let range = 30.0 // Assume 30 degree range
                                let minTemp = Double(day.low - 60) / range
                                let maxTemp = Double(day.high - 60) / range

                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: "3498db"), Color(hex: "f39c12")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(maxTemp - minTemp))
                                        .offset(x: geometry.size.width * CGFloat(minTemp))
                                }
                            }
                            .frame(width: 80, height: 4)

                            Text("\(day.high)°")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 35, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 14)

                    if index < forecast.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.1))
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
        }
    }

    private func iconColor(for icon: String) -> Color {
        switch icon {
        case "01d": return Color(hex: "f39c12")
        case "01n": return Color(hex: "f1c40f")
        case "02d", "03d", "04d": return Color(hex: "74b9ff")
        case "09d", "09n", "10d", "10n": return Color(hex: "3498db")
        case "11d", "11n": return Color(hex: "9b59b6")
        default: return .white.opacity(0.7)
        }
    }
}

struct WeatherSuggestionsSection: View {
    @StateObject private var weatherService = WeatherService.shared

    private var suggestions: [(icon: String, title: String, color: Color)] {
        guard let weather = weatherService.currentWeather else { return [] }

        var result: [(String, String, Color)] = []

        if weather.icon.contains("01") || weather.icon.contains("02") {
            result.append(("sun.max.fill", "Perfect for Rooftop Lounge", Color(hex: "f39c12")))
            if weather.temperature >= 75 {
                result.append(("figure.pool.swim", "Great Pool Weather", Color(hex: "3498db")))
            }
        }

        if weather.icon.contains("10") || weather.icon.contains("09") {
            result.append(("umbrella.fill", "Bring an Umbrella", Color(hex: "9b59b6")))
            result.append(("house.fill", "Indoor Events Recommended", Color(hex: "1abc9c")))
        }

        if weather.temperature >= 85 {
            result.append(("drop.fill", "Stay Hydrated", Color(hex: "3498db")))
        }

        if weather.windSpeedMph >= 15 {
            result.append(("wind", "Windy Conditions", Color(hex: "74b9ff")))
        }

        if result.isEmpty {
            result.append(("sparkles", "Great Day for the Clubhouse", Color(hex: "f39c12")))
        }

        return result
    }

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("TODAY'S TIPS")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .tracking(1)

                VStack(spacing: 10) {
                    ForEach(suggestions.indices, id: \.self) { index in
                        let suggestion = suggestions[index]
                        HStack(spacing: 12) {
                            Image(systemName: suggestion.icon)
                                .font(.system(size: 18))
                                .foregroundColor(suggestion.color)
                                .frame(width: 36, height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(suggestion.color.opacity(0.2))
                                )

                            Text(suggestion.title)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(12)
                        .glassCard(cornerRadius: 14)
                    }
                }
            }
        }
    }
}

// MARK: - Weather Overlays

struct RainOverlay: View {
    @State private var animate = false

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<20, id: \.self) { index in
                RainDrop()
                    .offset(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: animate ? geometry.size.height + 50 : -50
                    )
                    .animation(
                        .linear(duration: Double.random(in: 0.5...1.5))
                        .repeatForever(autoreverses: false)
                        .delay(Double.random(in: 0...1)),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

struct RainDrop: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.3))
            .frame(width: 2, height: 10)
    }
}

struct SunOverlay: View {
    @State private var rotate = false

    var body: some View {
        VStack {
            HStack {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "f39c12").opacity(0.3), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)

                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(Color(hex: "f39c12").opacity(0.2))
                            .frame(width: 3, height: 40)
                            .offset(y: -70)
                            .rotationEffect(.degrees(Double(index) * 45))
                    }
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: rotate)
                }
                .offset(x: 50, y: -50)
            }
            Spacer()
        }
        .onAppear { rotate = true }
    }
}

struct SummaryQuickAction: View {
    let icon: String
    let title: String
    let color: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ClubhouseInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 180)

                VStack {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.55))

                    Text("Clubhouse Image")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.72))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("BAYC Miami Clubhouse")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(Color(hex: "f39c12"))

                    Text("Miami, Florida")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text("Your exclusive members-only space in the heart of Miami. Access premium amenities, networking events, and the ultimate Ape experience.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .lineSpacing(4)
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .glassCard(cornerRadius: 28)
        .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
    }
}

struct UpcomingEventsSection: View {
    @StateObject private var eventManager = EventManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Events")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text("See All")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "f39c12"))
            }

            VStack(spacing: 12) {
                ForEach(eventManager.events.prefix(4)) { event in
                    NavigationLink {
                        EventDetailView(event: event)
                    } label: {
                        EventCard(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct EventCard: View {
    let event: ClubEvent

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        return formatter.string(from: event.date)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [event.category.color.opacity(0.3), event.category.color.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: event.imageSystemName)
                    .font(.system(size: 20))
                    .foregroundColor(event.category.color)

                // Exclusive badge
                if event.isExclusiveEvent {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "f39c12"))
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(Color(hex: "1a1a2e"))
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 50, height: 50)
                    .offset(x: 5, y: -5)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if event.requiresTokenProof {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "8b5cf6"))
                    }
                }

                Text(formattedDate)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))

                HStack(spacing: 8) {
                    if event.spotsLeft > 0 {
                        Text("\(event.spotsLeft) spots left")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(event.spotsLeft < 10 ? Color(hex: "e74c3c") : Color.green)
                    } else {
                        Text("Waitlist")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.purple)
                    }

                    if let tier = event.requiredMembershipTier {
                        Text(tier.displayName)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(tier.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(tier.accentColor.opacity(0.2))
                            )
                    }

                    if event.rsvpStatus == .going {
                        Text("GOING")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.2))
                            )
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(14)
        .glassCard(
            cornerRadius: 18,
            tint: event.isExclusiveEvent
                ? Color(hex: "f39c12").opacity(0.25)
                : ClubhouseGlass.cardTint
        )
    }
}

// MARK: - Yuga News Section (from @BoredApeYachtClub)

struct YugaNewsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(Color(hex: "f39c12"))

                Text("Yuga News")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 4) {
                    Text("@BoredApeYC")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }

            VStack(spacing: 12) {
                NewsCard(
                    headline: "ApeFest 2025 Dates Announced",
                    preview: "Get ready for the biggest BAYC event of the year. Early bird tickets available for members...",
                    timeAgo: "2h ago",
                    hasImage: true
                )

                NewsCard(
                    headline: "New Otherside Update: Voyagers Quest",
                    preview: "The latest chapter in the Otherside saga is here. Holders can now explore new territories...",
                    timeAgo: "5h ago",
                    hasImage: true
                )

                NewsCard(
                    headline: "BAYC x Adidas Drop Coming Soon",
                    preview: "Our collaboration with Adidas continues with an exclusive member-only collection...",
                    timeAgo: "1d ago",
                    hasImage: false
                )

                NewsCard(
                    headline: "Miami Clubhouse Grand Opening Recap",
                    preview: "Thank you to everyone who joined us for the grand opening! Check out the highlights...",
                    timeAgo: "2d ago",
                    hasImage: true
                )
            }
        }
    }
}

struct NewsCard: View {
    let headline: String
    let preview: String
    let timeAgo: String
    let hasImage: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(preview)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(2)

                Text(timeAgo)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            if hasImage {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.55))
                    )
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }
}

// MARK: - Featured Articles Section

struct FeaturedArticlesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Featured Articles")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Text("View All")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "f39c12"))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ArticleCard(title: "The Future of NFT Communities", category: "Web3", readTime: "5 min read", imageIcon: "globe.americas.fill")
                    ArticleCard(title: "Miami's Hottest New Member Spots", category: "Lifestyle", readTime: "3 min read", imageIcon: "sun.max.fill")
                    ArticleCard(title: "Building Wealth in the Metaverse", category: "Finance", readTime: "7 min read", imageIcon: "chart.line.uptrend.xyaxis")
                    ArticleCard(title: "Inside the Otherside: A Guide", category: "Gaming", readTime: "10 min read", imageIcon: "gamecontroller.fill")
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

struct ArticleCard: View {
    let title: String
    let category: String
    let readTime: String
    let imageIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 120)

                Image(systemName: imageIcon)
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.55))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(category.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "f39c12"))
                    .tracking(1)

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .frame(width: 180, alignment: .leading)

                Text(readTime)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 20)
    }
}

// MARK: - Community Highlights

struct CommunityHighlightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community Highlights")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                CommunityCard(
                    username: "CryptoWhale",
                    action: "just checked in at the Rooftop Bar",
                    timeAgo: "5 min ago",
                    likes: 24
                )

                CommunityCard(
                    username: "NFTCollector",
                    action: "shared a photo from Member Mixer",
                    timeAgo: "1 hour ago",
                    likes: 89
                )

                CommunityCard(
                    username: "BoredInMiami",
                    action: "booked a private lounge for 8 guests",
                    timeAgo: "2 hours ago",
                    likes: 12
                )
            }
        }
    }
}

struct CommunityCard: View {
    let username: String
    let action: String
    let timeAgo: String
    let likes: Int

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "f39c12").opacity(0.5), Color(hex: "e74c3c").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.7))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(username)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(action)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .lineLimit(1)

                HStack(spacing: 12) {
                    Text(timeAgo)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))

                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                        Text("\(likes)")
                            .font(.system(size: 12, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.65))
                }
            }

            Spacer()
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
    }
}

struct MemberPerksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Member Perks")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PerkCard(icon: "cup.and.saucer.fill", title: "Cafe Access")
                PerkCard(icon: "dumbbell.fill", title: "Fitness Center")
                PerkCard(icon: "sofa.fill", title: "Lounge Areas")
                PerkCard(icon: "network", title: "Networking")
                PerkCard(icon: "car.fill", title: "Valet Parking")
                PerkCard(icon: "gift.fill", title: "Merch Drops")
            }
        }
    }
}

struct PerkCard: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "f39c12"))

            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard(cornerRadius: 18)
    }
}

struct ClubhouseHoursSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clubhouse Hours")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                HoursRow(day: "Monday - Thursday", hours: "10:00 AM - 11:00 PM")
                HoursRow(day: "Friday - Saturday", hours: "10:00 AM - 2:00 AM")
                HoursRow(day: "Sunday", hours: "11:00 AM - 10:00 PM")
            }
            .padding(16)
            .glassCard(cornerRadius: 20)

            HStack(spacing: 10) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)

                Text("Currently Open")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.green)

                Text("• Closes at 11:00 PM")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
    }
}

struct HoursRow: View {
    let day: String
    let hours: String

    var body: some View {
        HStack {
            Text(day)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(hours)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(ChatManager())
}
