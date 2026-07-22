import SwiftUI
import UserNotifications

@main
struct BAYCClubhouseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var chatManager = ChatManager()
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var liveActivityManager = LiveActivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(chatManager)
                .environmentObject(notificationService)
                .environmentObject(liveActivityManager)
                .task {
                    // Request notification authorization on launch
                    _ = await notificationService.requestAuthorization()
                }
        }
    }
}

// MARK: - App Delegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationService.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            NotificationService.shared.handleRemoteNotification(userInfo, completion: completionHandler)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatManager: ChatManager
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Main content
            Group {
                if showSplash {
                    SplashView(showSplash: $showSplash)
                } else if !authViewModel.isAuthenticated {
                    LoginView()
                } else if !authViewModel.hasCompletedOnboarding {
                    ProfileSetupView()
                } else {
                    MainTabView()
                }
            }

            // Chat overlay (appears on top when authenticated)
            if authViewModel.isAuthenticated && authViewModel.hasCompletedOnboarding {
                ChatOverlayView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
    }
}
