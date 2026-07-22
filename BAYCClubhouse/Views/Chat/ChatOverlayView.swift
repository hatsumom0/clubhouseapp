import SwiftUI

struct ChatOverlayView: View {
    @EnvironmentObject var chatManager: ChatManager
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Minimized bubble
            if chatManager.isOpen && chatManager.isMinimized {
                MinimizedChatBubble()
                    .transition(.scale.combined(with: .opacity))
            }

            // Full chat window
            if chatManager.isOpen && !chatManager.isMinimized {
                FullChatView(messageText: $messageText, isInputFocused: _isInputFocused)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: chatManager.isOpen)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: chatManager.isMinimized)
        .sheet(isPresented: $chatManager.showingInbox) {
            InboxView()
        }
    }
}

// MARK: - Minimized Chat Bubble

struct MinimizedChatBubble: View {
    @EnvironmentObject var chatManager: ChatManager

    var body: some View {
        Button {
            chatManager.expandChat()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color(hex: "f39c12").opacity(0.5), radius: 10, y: 5)

                Image(systemName: "message.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)

                // Unread badge
                if chatManager.unreadCount > 0 {
                    Text("\(chatManager.unreadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(.red))
                        .offset(x: 20, y: -20)
                }
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100) // Above the tab bar
    }
}

// MARK: - Full Chat View

struct FullChatView: View {
    @EnvironmentObject var chatManager: ChatManager
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            ChatHeader()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatManager.messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }

                        if chatManager.isTyping {
                            TypingIndicator()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatManager.messages.count) { _, _ in
                    if let lastMessage = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Quick actions
            if chatManager.messages.count <= 2 {
                ChatQuickActions()
                    .padding(.bottom, 8)
            }

            // Input field
            ChatInputField(messageText: $messageText, isInputFocused: _isInputFocused)
        }
        .frame(maxWidth: .infinity, maxHeight: 500)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "1a1a2e"))
                .shadow(color: .black.opacity(0.4), radius: 20, y: -5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 12)
        .padding(.bottom, 100) // Above the tab bar
    }
}

struct ChatHeader: View {
    @EnvironmentObject var chatManager: ChatManager

    var body: some View {
        HStack(spacing: 12) {
            // Concierge avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("AI Concierge")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    // AI badge
                    Text("AI")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "f39c12"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: "f39c12").opacity(0.2))
                        )
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)

                    Text("Online")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Inbox button
            Button {
                chatManager.openInbox()
            } label: {
                ZStack {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.78))

                    if chatManager.unreadInboxCount > 0 {
                        Circle()
                            .fill(.red)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(chatManager.unreadInboxCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 10, y: -10)
                    }
                }
            }

            // Minimize button
            Button {
                chatManager.minimizeChat()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.78))
            }

            // Close button
            Button {
                chatManager.closeChat()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.78))
            }
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(Color(hex: "16213e"))
        )
    }
}

struct ChatMessageBubble: View {
    let message: ChatManager.ChatMessage
    @EnvironmentObject var chatManager: ChatManager

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
            } else {
                // Avatar for non-user messages
                senderAvatar
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 8) {
                // Sender label for human messages
                if message.senderType == .humanConcierge {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text("Human Concierge")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "8b5cf6"))
                }

                Text(message.content)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(message.isFromUser ? .white : .white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(bubbleBackground)
                    )
                    .overlay(
                        message.senderType == .humanConcierge
                            ? RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "8b5cf6").opacity(0.5), lineWidth: 1)
                            : nil
                    )

                // Event invite cards (single or multiple)
                if let invites = message.eventInvites, !invites.isEmpty {
                    // Multiple event cards - scrollable horizontal list
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(invites) { invite in
                                ChatEventInviteCard(eventInvite: invite)
                            }
                        }
                    }
                    .frame(maxWidth: 320)
                } else if let eventInvite = message.eventInvite {
                    // Single event card
                    ChatEventInviteCard(eventInvite: eventInvite)
                }

                Text(timeString)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private var senderAvatar: some View {
        ZStack {
            Circle()
                .fill(avatarBackground)
                .frame(width: 28, height: 28)

            Image(systemName: avatarIcon)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
    }

    private var avatarBackground: LinearGradient {
        switch message.senderType {
        case .ai:
            return LinearGradient(
                colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .humanConcierge:
            return LinearGradient(
                colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .user:
            return LinearGradient(
                colors: [Color(hex: "2d2d44"), Color(hex: "2d2d44")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var avatarIcon: String {
        switch message.senderType {
        case .ai:
            return "sparkles"
        case .humanConcierge:
            return "person.fill"
        case .user:
            return "person.fill"
        }
    }

    private var bubbleBackground: LinearGradient {
        if message.isFromUser {
            return LinearGradient(
                colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if message.senderType == .humanConcierge {
            return LinearGradient(
                colors: [Color(hex: "3d3d5c"), Color(hex: "3d3d5c")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "2d2d44"), Color(hex: "2d2d44")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

// MARK: - Chat Event Invite Card

struct ChatEventInviteCard: View {
    let eventInvite: ChatManager.EventInvite
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isRSVPing = false
    @State private var hasRSVPd = false

    private var userTier: MembershipTier {
        authViewModel.membershipTier
    }

    private var canAccess: Bool {
        guard let requiredTier = eventInvite.requiredTier else { return true }
        switch requiredTier {
        case .black:
            return userTier == .black
        case .platinum:
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with category
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: eventInvite.eventCategory.icon)
                        .font(.system(size: 12))
                    Text(eventInvite.eventCategory.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                }
                .foregroundColor(eventInvite.eventCategory.color)

                Spacer()

                if eventInvite.requiresTokenProof {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                        Text("TokenProof")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "8b5cf6"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: "8b5cf6").opacity(0.2))
                    )
                }
            }

            // Event title
            Text(eventInvite.eventTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Date and location
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(formattedDate)
                        .font(.system(size: 12, design: .rounded))
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 12))
                    Text(eventInvite.eventLocation)
                        .font(.system(size: 12, design: .rounded))
                }
            }
            .foregroundColor(.white.opacity(0.7))

            // Staff/Organizer info
            if let staffSummary = eventInvite.staffSummary {
                HStack(spacing: 4) {
                    Image(systemName: staffIcon)
                        .font(.system(size: 10))
                    Text(staffSummary)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color(hex: "f39c12"))
            } else if let organizerName = eventInvite.organizerName {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 10))
                    Text("by \(organizerName)")
                        .font(.system(size: 11, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.78))
            }

            // Spots left
            if eventInvite.spotsLeft > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text("\(eventInvite.spotsLeft) spots left")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(eventInvite.spotsLeft <= 5 ? .red : .green)
            }

            // Tier requirement warning
            if let tier = eventInvite.requiredTier, !canAccess {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("\(tier.displayName) tier required")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundColor(.red.opacity(0.8))
            }

            // RSVP Button
            Button {
                rsvpToEvent()
            } label: {
                HStack(spacing: 8) {
                    if isRSVPing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: hasRSVPd ? "checkmark.circle.fill" : canAccess ? "calendar.badge.plus" : "lock.fill")
                            .font(.system(size: 14))
                        Text(hasRSVPd ? "Added to Schedule!" : canAccess ? "Add to My Schedule" : "Locked")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            hasRSVPd
                                ? LinearGradient(colors: [Color(hex: "2ecc71"), Color(hex: "27ae60")], startPoint: .leading, endPoint: .trailing)
                                : canAccess
                                    ? LinearGradient(colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                )
            }
            .disabled(!canAccess || isRSVPing || hasRSVPd)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "2d2d44"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [eventInvite.eventCategory.color.opacity(0.5), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .frame(maxWidth: 280)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: eventInvite.eventDate)
    }

    private var staffIcon: String {
        switch eventInvite.eventCategory {
        case .spa:
            return "hand.raised.fingers.spread.fill"
        case .fitness:
            return "dumbbell.fill"
        case .wellness:
            return "figure.yoga"
        case .dining:
            return "fork.knife"
        case .party:
            return "music.note"
        default:
            return "person.fill"
        }
    }

    private func rsvpToEvent() {
        isRSVPing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            EventManager.shared.rsvp(to: eventInvite.eventId, status: .going)
            isRSVPing = false
            hasRSVPd = true

            // Send confirmation message
            let confirmMessage = ChatManager.ChatMessage(
                content: "You're all set! I've added \(eventInvite.eventTitle) to your schedule. See you there!",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
            chatManager.messages.append(confirmMessage)
        }
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotCount == index ? 1.2 : 0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "2d2d44"))
            )

            Spacer()
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}

struct ChatInputField: View {
    @EnvironmentObject var chatManager: ChatManager
    @Binding var messageText: String
    @FocusState var isInputFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField("", text: $messageText, prompt: Text("Type a message...").foregroundColor(.white.opacity(0.65)))
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "2d2d44"))
                )
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        messageText.isEmpty
                            ? Color.white.opacity(0.3)
                            : Color(hex: "f39c12")
                    )
            }
            .disabled(messageText.isEmpty)
        }
        .padding(12)
        .background(Color(hex: "16213e"))
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        chatManager.sendMessage(messageText)
        messageText = ""
    }
}

// MARK: - Quick Actions in Chat

struct ChatQuickActions: View {
    @EnvironmentObject var chatManager: ChatManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Event quick actions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Upcoming events shortcut
                    QuickActionButton(
                        icon: "calendar.badge.clock",
                        text: "Next Event",
                        color: Color(hex: "f39c12")
                    ) {
                        chatManager.sendMessage("What's the next upcoming event?")
                    }

                    // Browse all events
                    QuickActionButton(
                        icon: "ticket.fill",
                        text: "All Events",
                        color: Color(hex: "e74c3c")
                    ) {
                        chatManager.sendMessage("Show me all upcoming events")
                    }

                    // Exclusive events
                    QuickActionButton(
                        icon: "crown.fill",
                        text: "Exclusive",
                        color: Color(hex: "8b5cf6")
                    ) {
                        chatManager.sendMessage("What exclusive events are coming up?")
                    }

                    // Book a table
                    QuickActionButton(
                        icon: "fork.knife",
                        text: "Dining",
                        color: Color(hex: "2ecc71")
                    ) {
                        chatManager.sendMessage("I'd like to make a dining reservation")
                    }

                    // Concierge services
                    QuickActionButton(
                        icon: "sparkles",
                        text: "Services",
                        color: Color(hex: "3498db")
                    ) {
                        chatManager.sendMessage("What concierge services are available?")
                    }
                }
                .padding(.horizontal, 16)
            }

            // Event shortcuts (specific events)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ClubEvent.sampleEvents.prefix(4)) { event in
                        EventQuickChip(event: event) {
                            chatManager.sendMessage("Tell me about \(event.title)")
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let text: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color.opacity(0.3))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
        }
    }
}

struct EventQuickChip: View {
    let event: ClubEvent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: event.category.icon)
                    .font(.system(size: 11))
                    .foregroundColor(event.category.color)

                Text(event.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - Inbox View

struct InboxView: View {
    @EnvironmentObject var chatManager: ChatManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

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

                VStack(spacing: 0) {
                    // Tab selector
                    HStack(spacing: 0) {
                        InboxTabButton(
                            title: "Messages",
                            count: chatManager.unreadInboxCount,
                            isSelected: selectedTab == 0
                        ) {
                            withAnimation(.spring(response: 0.3)) { selectedTab = 0 }
                        }

                        InboxTabButton(
                            title: "Event Chats",
                            count: chatManager.totalGroupChatUnread,
                            isSelected: selectedTab == 1
                        ) {
                            withAnimation(.spring(response: 0.3)) { selectedTab = 1 }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Content
                    TabView(selection: $selectedTab) {
                        // Direct Messages Tab
                        DirectMessagesTab()
                            .tag(0)

                        // Event Group Chats Tab
                        EventGroupChatsTab()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("INBOX")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .topBarLeading) {
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

struct InboxTabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))

                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "f39c12"))
                            )
                    }
                }

                Rectangle()
                    .fill(isSelected ? Color(hex: "f39c12") : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct DirectMessagesTab: View {
    @EnvironmentObject var chatManager: ChatManager

    var body: some View {
        if chatManager.inboxMessages.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.55))

                Text("No Messages")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))

                Text("Messages from your relationship manager will appear here")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatManager.inboxMessages) { message in
                        NavigationLink {
                            InboxThreadView(message: message)
                        } label: {
                            InboxMessageRow(message: message)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
            }
        }
    }
}

struct EventGroupChatsTab: View {
    @EnvironmentObject var chatManager: ChatManager

    var body: some View {
        if chatManager.eventGroupChats.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.55))

                Text("No Event Chats")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))

                Text("When you RSVP to events, you'll be able to chat with other attendees here")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chatManager.eventGroupChats) { chat in
                        NavigationLink {
                            EventGroupChatView(chat: chat)
                        } label: {
                            EventGroupChatRow(chat: chat)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
            }
        }
    }
}

struct EventGroupChatRow: View {
    let chat: ChatManager.EventGroupChat

    var body: some View {
        HStack(spacing: 14) {
            // Event icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [chat.eventCategory.color.opacity(0.3), chat.eventCategory.color.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: chat.eventCategory.icon)
                    .font(.system(size: 20))
                    .foregroundColor(chat.eventCategory.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.eventTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "f39c12"))
                            )
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text("\(chat.participants.count) members")
                        .font(.system(size: 12, design: .rounded))
                    Text("•")
                    Text(chat.formattedEventDate)
                        .font(.system(size: 12, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.72))

                if let lastMessage = chat.lastMessage {
                    Text("\(lastMessage.senderName): \(lastMessage.content)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            chat.unreadCount > 0
                                ? Color(hex: "f39c12").opacity(0.3)
                                : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct EventGroupChatView: View {
    @EnvironmentObject var chatManager: ChatManager
    @Environment(\.dismiss) var dismiss
    let chat: ChatManager.EventGroupChat
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

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

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Event info header
                            EventGroupChatHeader(chat: chat)

                            ForEach(chat.messages) { message in
                                GroupChatMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: chat.messages.count) { _, _ in
                        if let lastMessage = chat.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                HStack(spacing: 12) {
                    TextField("Message the group...", text: $messageText)
                        .padding(12)
                        .glassCard(cornerRadius: 20)
                        .foregroundColor(.white)
                        .focused($isInputFocused)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.isEmpty ? .white.opacity(0.3) : Color(hex: "f39c12"))
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(chat.eventTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("\(chat.participants.count) members")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            chatManager.markGroupChatAsRead(chat.id)
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        chatManager.sendGroupMessage(to: chat.id, content: messageText)
        messageText = ""
    }
}

struct EventGroupChatHeader: View {
    let chat: ChatManager.EventGroupChat

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(chat.eventCategory.color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: chat.eventCategory.icon)
                    .font(.system(size: 28))
                    .foregroundColor(chat.eventCategory.color)
            }

            Text(chat.eventTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(chat.formattedEventDate)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.78))

            // Participants
            HStack(spacing: -8) {
                ForEach(chat.participants.prefix(5)) { participant in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "f39c12").opacity(0.5), Color(hex: "e74c3c").opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(participant.name.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "1a1a2e"), lineWidth: 2)
                        )
                }

                if chat.participants.count > 5 {
                    Circle()
                        .fill(Color(hex: "636e72"))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("+\(chat.participants.count - 5)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "1a1a2e"), lineWidth: 2)
                        )
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.top, 8)
        }
        .padding(.bottom, 8)
    }
}

struct GroupChatMessageBubble: View {
    let message: ChatManager.EventGroupChat.GroupChatMessage

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.isFromCurrentUser {
                Spacer()
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "f39c12").opacity(0.5), Color(hex: "e74c3c").opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.senderName.prefix(1)))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.senderName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                }

                Text(message.content)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(message.isFromCurrentUser
                                  ? Color(hex: "f39c12").opacity(0.3)
                                  : Color.white.opacity(0.1))
                    )

                Text(timeString)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            if message.isFromCurrentUser {
                // No avatar for current user
            } else {
                Spacer()
            }
        }
    }
}

struct InboxMessageRow: View {
    let message: ChatManager.InboxMessage

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: message.senderAvatar)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.senderName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if !message.isRead {
                        Circle()
                            .fill(Color(hex: "f39c12"))
                            .frame(width: 8, height: 8)
                    }

                    // Event invite badge
                    if message.eventInvite != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 8))
                            Text("Event")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "f39c12"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(hex: "f39c12").opacity(0.2))
                        )
                    }

                    Spacer()

                    Text(timeAgoString(from: message.timestamp))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }

                Text(message.senderRole)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color(hex: "8b5cf6"))

                Text(message.content)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            message.isRead
                                ? Color.white.opacity(0.1)
                                : Color(hex: "f39c12").opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Inbox Thread View

struct InboxThreadView: View {
    @EnvironmentObject var chatManager: ChatManager
    let message: ChatManager.InboxMessage
    @State private var replyText = ""

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

            VStack(spacing: 0) {
                // Messages
                ScrollView {
                    VStack(spacing: 16) {
                        // Sender info header
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)

                                Image(systemName: message.senderAvatar)
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                            }

                            Text(message.senderName)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)

                            Text(message.senderRole)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(Color(hex: "8b5cf6"))
                        }
                        .padding(.top, 16)

                        // Original message
                        InboxThreadBubble(
                            content: message.content,
                            isFromUser: false,
                            timestamp: message.timestamp
                        )

                        // Event invite card (if present)
                        if let eventInvite = message.eventInvite {
                            InboxEventInviteCard(eventInvite: eventInvite)
                                .padding(.horizontal, 20)
                        }

                        // Replies
                        ForEach(message.replies) { reply in
                            InboxThreadBubble(
                                content: reply.content,
                                isFromUser: reply.isFromUser,
                                timestamp: reply.timestamp
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                // Reply input
                HStack(spacing: 12) {
                    TextField("", text: $replyText, prompt: Text("Reply...").foregroundColor(.white.opacity(0.65)))
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "2d2d44"))
                        )

                    Button {
                        if !replyText.isEmpty {
                            chatManager.replyToInboxMessage(message.id, content: replyText)
                            replyText = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(
                                replyText.isEmpty
                                    ? Color.white.opacity(0.3)
                                    : Color(hex: "f39c12")
                            )
                    }
                    .disabled(replyText.isEmpty)
                }
                .padding(12)
                .background(Color(hex: "16213e"))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("CONVERSATION")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            chatManager.markInboxMessageAsRead(message.id)
        }
    }
}

struct InboxThreadBubble: View {
    let content: String
    let isFromUser: Bool
    let timestamp: Date

    var body: some View {
        HStack {
            if isFromUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                Text(content)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                isFromUser
                                    ? LinearGradient(
                                        colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color(hex: "3d3d5c"), Color(hex: "3d3d5c")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                    )

                Text(timeString)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            if !isFromUser {
                Spacer(minLength: 60)
            }
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Inbox Event Invite Card

struct InboxEventInviteCard: View {
    let eventInvite: ChatManager.EventInvite
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isRSVPing = false
    @State private var hasRSVPd = false

    private var userTier: MembershipTier {
        authViewModel.membershipTier
    }

    private var canAccess: Bool {
        guard let requiredTier = eventInvite.requiredTier else { return true }
        switch requiredTier {
        case .black:
            return userTier == .black
        case .platinum:
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(eventInvite.eventCategory.color.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: eventInvite.eventCategory.icon)
                            .font(.system(size: 16))
                            .foregroundColor(eventInvite.eventCategory.color)
                    }

                    Text(eventInvite.eventCategory.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(eventInvite.eventCategory.color)
                }

                Spacer()

                if eventInvite.requiresTokenProof {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                        Text("Exclusive")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "8b5cf6"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(hex: "8b5cf6").opacity(0.2))
                    )
                }
            }

            // Event title
            Text(eventInvite.eventTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Event details
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "f39c12"))
                        .frame(width: 20)
                    Text(formattedDate)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "e74c3c"))
                        .frame(width: 20)
                    Text(eventInvite.eventLocation)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(eventInvite.spotsLeft <= 5 ? .red : .green)
                        .frame(width: 20)
                    Text("\(eventInvite.spotsLeft) spots remaining")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(eventInvite.spotsLeft <= 5 ? .red : .green)
                }
            }

            // Tier requirement
            if let tier = eventInvite.requiredTier {
                HStack(spacing: 6) {
                    Image(systemName: canAccess ? tier.badgeIcon : "lock.fill")
                        .font(.system(size: 12))
                    Text(canAccess ? "\(tier.displayName) Member Access" : "\(tier.displayName) Tier Required")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(canAccess ? tier.accentColor : .red.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(canAccess ? tier.accentColor.opacity(0.15) : Color.red.opacity(0.1))
                )
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    rsvpToEvent()
                } label: {
                    HStack(spacing: 8) {
                        if isRSVPing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: hasRSVPd ? "checkmark.circle.fill" : canAccess ? "plus.circle.fill" : "lock.fill")
                                .font(.system(size: 16))
                            Text(hasRSVPd ? "Added!" : canAccess ? "Add to Schedule" : "Locked")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                hasRSVPd
                                    ? LinearGradient(colors: [Color(hex: "2ecc71"), Color(hex: "27ae60")], startPoint: .leading, endPoint: .trailing)
                                    : canAccess
                                        ? LinearGradient(colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
                .disabled(!canAccess || isRSVPing || hasRSVPd)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "2d2d44"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [eventInvite.eventCategory.color.opacity(0.4), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: eventInvite.eventCategory.color.opacity(0.2), radius: 15, y: 8)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return formatter.string(from: eventInvite.eventDate)
    }

    private func rsvpToEvent() {
        isRSVPing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            EventManager.shared.rsvp(to: eventInvite.eventId, status: .going)
            isRSVPing = false
            hasRSVPd = true
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "1a1a2e").ignoresSafeArea()
        ChatOverlayView()
    }
    .environmentObject(ChatManager())
}
