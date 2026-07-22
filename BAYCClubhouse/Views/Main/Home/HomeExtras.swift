import SwiftUI

// The 4-block Home. Everything that used to stack nine sections deep now
// lives where it belongs: events → Schedule, news/articles/community →
// ClubFeedView, perks → Membership benefits, info + hours → ClubInfoSheet
// behind the status chip.

// MARK: - Status chip row (open-until + club feed entry)

struct ClubStatusRow: View {
    @State private var showInfo = false
    @State private var showFeed = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                showInfo = true
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(ClubHours.isOpenNow ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(ClubHours.statusText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassPill(interactive: true)
            }

            Spacer()

            Button {
                showFeed = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 12))
                    Text("Club Feed")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassPill(interactive: true)
            }
        }
        .sheet(isPresented: $showInfo) { ClubInfoSheet() }
        .sheet(isPresented: $showFeed) { ClubFeedView() }
    }
}

/// Static clubhouse hours (Mon–Thu 10–23, Fri–Sat 10–02, Sun 11–22).
enum ClubHours {
    static var isOpenNow: Bool { statusText.hasPrefix("Open") }

    static var statusText: String {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now) // 1 = Sunday
        let hour = cal.component(.hour, from: now)

        // Friday/Saturday close at 2 AM the following day
        let isLateNight = hour < 2 && (weekday == 7 || weekday == 1)
        if isLateNight { return "Open until 2 AM" }

        let openHour = weekday == 1 ? 11 : 10
        let closeText: String
        switch weekday {
        case 1: closeText = "10 PM"
        case 6, 7: closeText = "2 AM"
        default: closeText = "11 PM"
        }

        if hour < openHour {
            return "Opens \(openHour == 11 ? "11 AM" : "10 AM")"
        }
        if weekday == 1 && hour >= 22 { return "Closed · Opens 10 AM" }
        if (2...5).contains(weekday) && hour >= 23 { return "Closed · Opens 10 AM" }
        return "Open until \(closeText)"
    }
}

// MARK: - Up Next (single next commitment)

struct UpNextCard: View {
    @StateObject private var eventManager = EventManager.shared
    @State private var showDetail = false

    private var nextEvent: ClubEvent? {
        eventManager.mySchedule
            .filter { $0.date > Date() }
            .min(by: { $0.date < $1.date })
    }

    private var nextReservation: Reservation? {
        eventManager.activeReservations
            .filter { $0.date > Date() && $0.status != .cancelled }
            .min(by: { $0.date < $1.date })
    }

    /// Whichever comes first — event or reservation.
    private var showsReservation: Bool {
        guard let r = nextReservation else { return false }
        guard let e = nextEvent else { return true }
        return r.date < e.date
    }

    var body: some View {
        if nextEvent != nil || nextReservation != nil {
            Button {
                showDetail = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "f39c12").opacity(0.2))
                            .frame(width: 48, height: 48)

                        Image(systemName: showsReservation
                            ? (nextReservation?.icon ?? "calendar")
                            : "calendar.badge.clock")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "f39c12"))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Up next")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.65))

                        Text(showsReservation
                            ? (nextReservation?.title ?? "")
                            : (nextEvent?.title ?? ""))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(upNextSubtitle)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.72))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(16)
                .glassCard(cornerRadius: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showDetail) {
                if showsReservation, let reservation = nextReservation {
                    ReservationDetailView(reservation: reservation)
                } else if let event = nextEvent {
                    EventDetailView(event: event)
                }
            }
        }
    }

    private var upNextSubtitle: String {
        let date = showsReservation ? nextReservation?.date : nextEvent?.date
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        var text = formatter.string(from: date)
        if showsReservation, let status = nextReservation?.status {
            text += " • \(status.rawValue)"
        }
        return text
    }
}

// MARK: - Tonight at the club (one featured CTA)

struct TonightCard: View {
    @StateObject private var eventManager = EventManager.shared
    @State private var showDetail = false

    private var featured: ClubEvent? {
        eventManager.events
            .filter { $0.date > Date() }
            .min(by: { $0.date < $1.date })
    }

    private var isTonight: Bool {
        guard let event = featured else { return false }
        return Calendar.current.isDateInToday(event.date)
    }

    var body: some View {
        if let event = featured {
            Button {
                showDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isTonight ? "TONIGHT AT THE CLUB" : "COMING UP AT THE CLUB")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(Color(hex: "f39c12"))

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text("\(event.date.formatted(date: .abbreviated, time: .shortened)) • \(event.spotsLeft) spots left")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.72))
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(hex: "f39c12"))
                    }
                }
                .padding(16)
                .glassCard(
                    cornerRadius: 20,
                    tint: Color(hex: "f39c12").opacity(0.22),
                    interactive: true
                )
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showDetail) {
                EventDetailView(event: event)
            }
        }
    }
}

// MARK: - Club info sheet (info card + hours, off the status chip)

struct ClubInfoSheet: View {
    @Environment(\.dismiss) var dismiss

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
                        ClubhouseInfoCard()
                        ClubhouseHoursSection()
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("THE CLUBHOUSE")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "f39c12"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Club feed (news + articles + community, off Home)

struct ClubFeedView: View {
    @Environment(\.dismiss) var dismiss

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
                        YugaNewsSection()
                        FeaturedArticlesSection()
                        CommunityHighlightsSection()
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CLUB FEED")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "f39c12"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
