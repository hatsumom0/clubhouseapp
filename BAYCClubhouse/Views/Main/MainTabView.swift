import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "Home"
        case schedule = "Schedule"
        case membership = "Membership"
        case account = "Account"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .schedule: return "calendar"
            case .membership: return "creditcard.fill"
            case .account: return "person.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            TabContent(selectedTab: selectedTab)
                .ignoresSafeArea(edges: .bottom)

            // iOS 26 Liquid Glass floating tab bar
            FloatingTabBar(selectedTab: $selectedTab)
        }
    }
}

struct TabContent: View {
    let selectedTab: MainTabView.Tab

    var body: some View {
        switch selectedTab {
        case .home:
            HomeView()
        case .schedule:
            ScheduleView()
        case .membership:
            MembershipView()
        case .account:
            AccountView()
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    @Namespace private var animation

    var body: some View {
        // Real iOS 26 Liquid Glass: the container lets the bar and the
        // selected pill blend/morph as one glass surface.
        GlassEffectContainer {
            HStack(spacing: 6) {
                ForEach(MainTabView.Tab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        animation: animation
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .glassCard(cornerRadius: 28)
        }
        .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

struct TabButton: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? 17 : 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))

                if isSelected {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, isSelected ? 16 : 12)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    // Selected state: tinted interactive Liquid Glass pill
                    Capsule()
                        .fill(.clear)
                        .glassPill(
                            tint: Color(hex: "f39c12").opacity(0.6),
                            interactive: true
                        )
                        .matchedGeometryEffect(id: "TAB_BACKGROUND", in: animation)
                        .shadow(color: Color(hex: "f39c12").opacity(0.3), radius: 8, y: 2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(ChatManager())
}
