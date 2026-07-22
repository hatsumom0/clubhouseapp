import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.dismiss) var dismiss

    private var brandGold: Color { Color(hex: "f39c12") }
    private var brandDark: Color { Color(hex: "1a1a2e") }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [brandDark, Color(hex: "16213e")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Authorization Status
                        AuthorizationSection()

                        // Push Notifications
                        PushNotificationSection()

                        // Live Activities
                        LiveActivitySection()

                        // Event Reminders
                        EventReminderSection()

                        // Quiet Hours
                        QuietHoursSection()

                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(brandGold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Authorization Section

struct AuthorizationSection: View {
    @EnvironmentObject var notificationService: NotificationService

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: notificationService.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                    .font(.title2)
                    .foregroundColor(notificationService.isAuthorized ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notification Status")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(notificationService.isAuthorized ? "Enabled" : "Disabled")
                        .font(.subheadline)
                        .foregroundColor(notificationService.isAuthorized ? .green : .orange)
                }

                Spacer()

                if !notificationService.isAuthorized {
                    Button("Enable") {
                        Task {
                            await notificationService.requestAuthorization()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(brandGold)
                    .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(notificationService.isAuthorized ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(notificationService.isAuthorized ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )

            if !notificationService.isAuthorized {
                Text("Enable notifications to receive event reminders, valet updates, and more.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Push Notification Section

struct PushNotificationSection: View {
    @EnvironmentObject var notificationService: NotificationService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotificationSectionHeader(title: "Push Notifications", icon: "bell.fill")

            VStack(spacing: 0) {
                NotificationToggleRow(
                    title: "Event Reminders",
                    subtitle: "Get notified before events",
                    icon: "calendar.badge.clock",
                    isOn: $notificationService.preferences.eventReminders
                )

                Divider().background(Color.white.opacity(0.1))

                NotificationToggleRow(
                    title: "Reservation Confirmations",
                    subtitle: "Booking and table updates",
                    icon: "checkmark.circle.fill",
                    isOn: $notificationService.preferences.reservationConfirmations
                )

                Divider().background(Color.white.opacity(0.1))

                NotificationToggleRow(
                    title: "Valet Updates",
                    subtitle: "Car status notifications",
                    icon: "car.fill",
                    isOn: $notificationService.preferences.valetUpdates
                )

                Divider().background(Color.white.opacity(0.1))

                NotificationToggleRow(
                    title: "Table Ready Alerts",
                    subtitle: "When your table is ready",
                    icon: "fork.knife",
                    isOn: $notificationService.preferences.tableReadyAlerts
                )

                Divider().background(Color.white.opacity(0.1))

                NotificationToggleRow(
                    title: "Locker Expiration",
                    subtitle: "Warning before locker expires",
                    icon: "lock.fill",
                    isOn: $notificationService.preferences.lockerExpirationWarnings
                )

                Divider().background(Color.white.opacity(0.1))

                NotificationToggleRow(
                    title: "Member Offers",
                    subtitle: "Exclusive deals and promotions",
                    icon: "gift.fill",
                    isOn: $notificationService.preferences.memberOffers
                )

                Divider().background(Color.white.opacity(0.1))

                NotificationToggleRow(
                    title: "Club Announcements",
                    subtitle: "Important club updates",
                    icon: "megaphone.fill",
                    isOn: $notificationService.preferences.clubAnnouncements
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .onChange(of: notificationService.preferences.eventReminders) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.reservationConfirmations) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.valetUpdates) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.tableReadyAlerts) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.lockerExpirationWarnings) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.memberOffers) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.clubAnnouncements) { _, _ in
            notificationService.savePreferences()
        }
    }
}

// MARK: - Live Activity Section

struct LiveActivitySection: View {
    @EnvironmentObject var notificationService: NotificationService
    @StateObject var liveActivityManager = LiveActivityManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotificationSectionHeader(title: "Live Activities", icon: "iphone.radiowaves.left.and.right")

            if !liveActivityManager.isLiveActivitySupported {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Live Activities are not available on this device")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.15))
                )
            } else {
                VStack(spacing: 0) {
                    NotificationToggleRow(
                        title: "Valet Tracking",
                        subtitle: "Track car retrieval progress",
                        icon: "car.fill",
                        isOn: $notificationService.preferences.enableValetLiveActivity
                    )

                    Divider().background(Color.white.opacity(0.1))

                    NotificationToggleRow(
                        title: "Arrival Countdown",
                        subtitle: "ETA countdown when arriving",
                        icon: "location.fill",
                        isOn: $notificationService.preferences.enableArrivalLiveActivity
                    )

                    Divider().background(Color.white.opacity(0.1))

                    NotificationToggleRow(
                        title: "Clubhouse Activity",
                        subtitle: "Quick access while at club",
                        icon: "building.2.fill",
                        isOn: $notificationService.preferences.enableClubhouseLiveActivity
                    )

                    Divider().background(Color.white.opacity(0.1))

                    NotificationToggleRow(
                        title: "Event Countdown",
                        subtitle: "Countdown to your events",
                        icon: "calendar",
                        isOn: $notificationService.preferences.enableEventLiveActivity
                    )

                    Divider().background(Color.white.opacity(0.1))

                    NotificationToggleRow(
                        title: "Reservation Updates",
                        subtitle: "Table ready notifications",
                        icon: "fork.knife",
                        isOn: $notificationService.preferences.enableReservationLiveActivity
                    )

                    Divider().background(Color.white.opacity(0.1))

                    NotificationToggleRow(
                        title: "Locker Access",
                        subtitle: "Quick access to locker info",
                        icon: "lock.fill",
                        isOn: $notificationService.preferences.enableLockerLiveActivity
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
        .onChange(of: notificationService.preferences.enableValetLiveActivity) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.enableArrivalLiveActivity) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.enableClubhouseLiveActivity) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.enableEventLiveActivity) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.enableReservationLiveActivity) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.enableLockerLiveActivity) { _, _ in
            notificationService.savePreferences()
        }
    }
}

// MARK: - Event Reminder Section

struct EventReminderSection: View {
    @EnvironmentObject var notificationService: NotificationService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotificationSectionHeader(title: "Event Reminder Timing", icon: "clock.fill")

            VStack(spacing: 0) {
                ForEach(NotificationPreferences.ReminderTiming.allCases) { timing in
                    ReminderTimingRow(
                        timing: timing,
                        isSelected: notificationService.preferences.eventReminderTiming.contains(timing),
                        onToggle: {
                            toggleTiming(timing)
                        }
                    )

                    if timing != NotificationPreferences.ReminderTiming.allCases.last {
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )

            Text("Select when you want to be reminded about upcoming events.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 4)
        }
    }

    private func toggleTiming(_ timing: NotificationPreferences.ReminderTiming) {
        if notificationService.preferences.eventReminderTiming.contains(timing) {
            notificationService.preferences.eventReminderTiming.removeAll { $0 == timing }
        } else {
            notificationService.preferences.eventReminderTiming.append(timing)
        }
        notificationService.savePreferences()
    }
}

// MARK: - Quiet Hours Section

struct QuietHoursSection: View {
    @EnvironmentObject var notificationService: NotificationService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotificationSectionHeader(title: "Quiet Hours", icon: "moon.fill")

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Quiet Hours")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                        Text("Silence notifications during set times")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Toggle("", isOn: $notificationService.preferences.quietHoursEnabled)
                        .tint(Color(hex: "f39c12"))
                }
                .padding(16)

                if notificationService.preferences.quietHoursEnabled {
                    Divider().background(Color.white.opacity(0.1))

                    HStack {
                        Text("Start")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $notificationService.preferences.quietHoursStart,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().background(Color.white.opacity(0.1))

                    HStack {
                        Text("End")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        DatePicker(
                            "",
                            selection: $notificationService.preferences.quietHoursEnd,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .onChange(of: notificationService.preferences.quietHoursEnabled) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.quietHoursStart) { _, _ in
            notificationService.savePreferences()
        }
        .onChange(of: notificationService.preferences.quietHoursEnd) { _, _ in
            notificationService.savePreferences()
        }
    }
}

// MARK: - Helper Views

struct NotificationSectionHeader: View {
    let title: String
    let icon: String

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(brandGold)
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(brandGold)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(brandGold)
        }
        .padding(16)
    }
}

struct ReminderTimingRow: View {
    let timing: NotificationPreferences.ReminderTiming
    let isSelected: Bool
    let onToggle: () -> Void

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text(timing.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? brandGold : .white.opacity(0.3))
            }
            .padding(16)
        }
    }
}

#Preview {
    NotificationSettingsView()
        .environmentObject(NotificationService.shared)
}
