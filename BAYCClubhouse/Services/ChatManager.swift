import SwiftUI
import Combine

@MainActor
class ChatManager: ObservableObject {
    // Chat state
    @Published var isOpen = false
    @Published var isMinimized = false
    @Published var unreadCount = 0
    @Published var messages: [ChatMessage] = []
    @Published var isTyping = false

    // Inbox state
    @Published var inboxMessages: [InboxMessage] = []
    @Published var unreadInboxCount = 0
    @Published var showingInbox = false

    // Conversation history for context
    private var conversationHistory: [(role: String, content: String)] = []

    // MARK: - Conversation Context (for follow-up queries)

    struct ConversationContext {
        var currentEvent: ClubEvent?           // Last specific event discussed
        var currentEvents: [ClubEvent]?        // Last list of events shown
        var currentCategory: ClubEvent.EventCategory?  // Current category filter
        var lastQueryType: QueryType?          // What was the last query about
        var pendingFoodOrder: PendingFoodOrder? // Food order being assembled

        enum QueryType {
            case specificEvent
            case eventList
            case weather
            case reservation
            case general
            case foodOrder
            case spaceBooking
            case valet
        }

        struct PendingFoodOrder {
            var items: [(menuItem: MenuItem, quantity: Int)] = []
            var location: OrderLocation?
            var requestedTime: Date?
            var needsLocationConfirmation: Bool = false
            var needsTimeConfirmation: Bool = false
        }

        mutating func clear() {
            currentEvent = nil
            currentEvents = nil
            currentCategory = nil
            lastQueryType = nil
            pendingFoodOrder = nil
        }

        mutating func setEvent(_ event: ClubEvent) {
            currentEvent = event
            currentEvents = [event]
            currentCategory = event.category
            lastQueryType = .specificEvent
        }

        mutating func setEvents(_ events: [ClubEvent], category: ClubEvent.EventCategory? = nil) {
            currentEvents = events
            currentEvent = events.first
            currentCategory = category
            lastQueryType = .eventList
        }
    }

    private var context = ConversationContext()

    // MARK: - Message Types

    struct ChatMessage: Identifiable, Equatable {
        let id = UUID()
        let content: String
        let isFromUser: Bool
        let senderType: SenderType
        let timestamp: Date
        let eventInvite: EventInvite? // Optional single event invite
        let eventInvites: [EventInvite]? // Optional multiple event invites (for lists)

        enum SenderType {
            case user
            case ai
            case humanConcierge
        }

        init(content: String, isFromUser: Bool, senderType: SenderType, timestamp: Date, eventInvite: EventInvite? = nil, eventInvites: [EventInvite]? = nil) {
            self.content = content
            self.isFromUser = isFromUser
            self.senderType = senderType
            self.timestamp = timestamp
            self.eventInvite = eventInvite
            self.eventInvites = eventInvites
        }

        static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
            lhs.id == rhs.id
        }

        /// Returns true if this message has any event cards to display
        var hasEventCards: Bool {
            eventInvite != nil || (eventInvites != nil && !eventInvites!.isEmpty)
        }

        /// Returns all event invites (combines single and multiple)
        var allEventInvites: [EventInvite] {
            if let invites = eventInvites, !invites.isEmpty {
                return invites
            } else if let invite = eventInvite {
                return [invite]
            }
            return []
        }
    }

    struct EventInvite: Identifiable, Equatable {
        let id = UUID()
        let eventId: UUID
        let eventTitle: String
        let eventDate: Date
        let eventLocation: String
        let eventCategory: ClubEvent.EventCategory
        let spotsLeft: Int
        let requiresTokenProof: Bool
        let requiredTier: MembershipTier?
        // Organizer/Staff info
        let organizerName: String?
        let organizerRole: String?
        let staffSummary: String? // e.g., "with Lucia Santos" or "Trainer: Mike Torres"

        static func == (lhs: EventInvite, rhs: EventInvite) -> Bool {
            lhs.id == rhs.id
        }

        static func from(event: ClubEvent) -> EventInvite {
            // Build staff summary from event details
            var staffSummary: String? = nil
            if let staff = event.details?.staff, !staff.isEmpty {
                // Get the primary staff member based on category
                let primaryStaff: EventStaffMember?
                switch event.category {
                case .spa:
                    primaryStaff = staff.first { $0.role == .massageTherapist || $0.role == .esthetician || $0.role == .spaDirector }
                case .fitness:
                    primaryStaff = staff.first { $0.role == .personalTrainer || $0.role == .fitnessInstructor }
                case .wellness:
                    primaryStaff = staff.first { $0.role == .yogaInstructor || $0.role == .wellnessCoach }
                case .dining:
                    primaryStaff = staff.first { $0.role == .chef || $0.role == .sommelier }
                case .party:
                    primaryStaff = staff.first { $0.role == .dj }
                default:
                    primaryStaff = staff.first
                }

                if let primary = primaryStaff {
                    staffSummary = "with \(primary.name)"
                    // Add specialty if available
                    if let specialties = primary.specialties, !specialties.isEmpty {
                        staffSummary! += " • \(specialties.first!)"
                    }
                }
            }

            return EventInvite(
                eventId: event.id,
                eventTitle: event.title,
                eventDate: event.date,
                eventLocation: event.location,
                eventCategory: event.category,
                spotsLeft: event.spotsLeft,
                requiresTokenProof: event.requiresTokenProof,
                requiredTier: event.requiredMembershipTier,
                organizerName: event.organizer.name,
                organizerRole: event.organizer.role,
                staffSummary: staffSummary
            )
        }
    }

    struct InboxMessage: Identifiable {
        let id = UUID()
        let senderName: String
        let senderRole: String
        let senderAvatar: String
        let content: String
        let timestamp: Date
        var isRead: Bool
        let eventInvite: EventInvite? // Optional event invite attachment

        // Thread of replies
        var replies: [InboxReply] = []

        init(senderName: String, senderRole: String, senderAvatar: String, content: String, timestamp: Date, isRead: Bool, eventInvite: EventInvite? = nil, replies: [InboxReply] = []) {
            self.senderName = senderName
            self.senderRole = senderRole
            self.senderAvatar = senderAvatar
            self.content = content
            self.timestamp = timestamp
            self.isRead = isRead
            self.eventInvite = eventInvite
            self.replies = replies
        }
    }

    struct InboxReply: Identifiable {
        let id = UUID()
        let content: String
        let isFromUser: Bool
        let timestamp: Date
    }

    // MARK: - Event Group Chat

    struct EventGroupChat: Identifiable {
        let id: UUID
        let eventId: UUID
        let eventTitle: String
        let eventDate: Date
        let eventCategory: ClubEvent.EventCategory
        var participants: [GroupChatParticipant]
        var messages: [GroupChatMessage]
        var unreadCount: Int

        struct GroupChatParticipant: Identifiable {
            let id = UUID()
            let name: String
            let avatarSystemName: String
            let tokenId: String?
            let isOrganizer: Bool
        }

        struct GroupChatMessage: Identifiable {
            let id = UUID()
            let senderId: UUID
            let senderName: String
            let content: String
            let timestamp: Date
            let isFromCurrentUser: Bool
        }

        var lastMessage: GroupChatMessage? {
            messages.last
        }

        var formattedEventDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: eventDate)
        }
    }

    // Event group chats
    @Published var eventGroupChats: [EventGroupChat] = []

    // MARK: - Initialization

    init() {
        setupWelcomeMessages()
        setupMockInboxMessages()
        setupMockEventGroupChats()
    }

    private func setupWelcomeMessages() {
        messages.append(ChatMessage(
            content: "Welcome to BAYC Miami Clubhouse! I'm your AI-powered concierge. How can I assist you today?",
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        ))
    }

    private func setupMockInboxMessages() {
        // Simulate messages from human relationship managers
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!

        // Create event invite from the gallery event
        let galleryEvent = ClubEvent.sampleEvents.first { $0.title.contains("Gallery") }
        let galleryInvite = galleryEvent.map { EventInvite.from(event: $0) }

        inboxMessages = [
            InboxMessage(
                senderName: "Sarah Chen",
                senderRole: "Relationship Manager",
                senderAvatar: "person.crop.circle.fill",
                content: "Hi! Just wanted to personally welcome you to the club. I'm your dedicated relationship manager - feel free to reach out anytime you need anything special arranged.",
                timestamp: twoDaysAgo,
                isRead: true,
                replies: [
                    InboxReply(content: "Thank you Sarah! Looking forward to visiting soon.", isFromUser: true, timestamp: yesterday)
                ]
            ),
            InboxMessage(
                senderName: "Marcus Williams",
                senderRole: "Events Coordinator",
                senderAvatar: "person.crop.circle.fill",
                content: "Exclusive invite: We're hosting a private NFT gallery opening next Friday. Only 30 spots available. Would you like me to reserve yours?",
                timestamp: yesterday,
                isRead: false,
                eventInvite: galleryInvite
            )
        ]

        unreadInboxCount = inboxMessages.filter { !$0.isRead }.count
    }

    private func setupMockEventGroupChats() {
        // Create mock group chats for events user is attending
        let yachtEvent = ClubEvent.sampleEvents.first { $0.title.contains("Yacht") }

        if let yacht = yachtEvent {
            let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
            let twoHoursAgo = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!

            eventGroupChats = [
                EventGroupChat(
                    id: UUID(),
                    eventId: yacht.id,
                    eventTitle: yacht.title,
                    eventDate: yacht.date,
                    eventCategory: yacht.category,
                    participants: [
                        .init(name: "Marcus Williams", avatarSystemName: "person.crop.circle.fill", tokenId: nil, isOrganizer: true),
                        .init(name: "CryptoWhale", avatarSystemName: "person.crop.circle.fill", tokenId: "1234", isOrganizer: false),
                        .init(name: "DiamondHands", avatarSystemName: "person.crop.circle.fill", tokenId: "5678", isOrganizer: false),
                        .init(name: "ApeLord", avatarSystemName: "person.crop.circle.fill", tokenId: "9012", isOrganizer: false),
                        .init(name: "You", avatarSystemName: "person.crop.circle.fill", tokenId: "7246", isOrganizer: false)
                    ],
                    messages: [
                        .init(senderId: UUID(), senderName: "Marcus Williams", content: "Welcome to the Yacht Party group chat! 🛥️ Feel free to introduce yourselves and share what you're most excited about.", timestamp: twoHoursAgo, isFromCurrentUser: false),
                        .init(senderId: UUID(), senderName: "CryptoWhale", content: "Hey everyone! Can't wait for this. Anyone know if we're docking at Star Island?", timestamp: twoHoursAgo.addingTimeInterval(1800), isFromCurrentUser: false),
                        .init(senderId: UUID(), senderName: "Marcus Williams", content: "Great question! Yes, we'll have a brief stop at Star Island for photos. The sunset views from there are incredible.", timestamp: oneHourAgo, isFromCurrentUser: false),
                        .init(senderId: UUID(), senderName: "DiamondHands", content: "This is going to be epic! 🎉", timestamp: oneHourAgo.addingTimeInterval(600), isFromCurrentUser: false)
                    ],
                    unreadCount: 2
                )
            ]
        }
    }

    // MARK: - Event Group Chat Functions

    func createGroupChat(for event: ClubEvent) {
        // Check if group chat already exists
        guard !eventGroupChats.contains(where: { $0.eventId == event.id }) else { return }

        let newGroupChat = EventGroupChat(
            id: UUID(),
            eventId: event.id,
            eventTitle: event.title,
            eventDate: event.date,
            eventCategory: event.category,
            participants: [
                .init(name: event.organizer.name, avatarSystemName: event.organizer.avatarSystemName, tokenId: nil, isOrganizer: true),
                .init(name: "You", avatarSystemName: "person.crop.circle.fill", tokenId: "7246", isOrganizer: false)
            ],
            messages: [
                .init(
                    senderId: UUID(),
                    senderName: event.organizer.name,
                    content: "Welcome to the \(event.title) group chat! Feel free to ask any questions or connect with fellow attendees.",
                    timestamp: Date(),
                    isFromCurrentUser: false
                )
            ],
            unreadCount: 1
        )

        eventGroupChats.append(newGroupChat)
    }

    func sendGroupMessage(to chatId: UUID, content: String) {
        guard let index = eventGroupChats.firstIndex(where: { $0.id == chatId }) else { return }

        let newMessage = EventGroupChat.GroupChatMessage(
            senderId: UUID(),
            senderName: "You",
            content: content,
            timestamp: Date(),
            isFromCurrentUser: true
        )

        eventGroupChats[index].messages.append(newMessage)
    }

    func markGroupChatAsRead(_ chatId: UUID) {
        guard let index = eventGroupChats.firstIndex(where: { $0.id == chatId }) else { return }
        eventGroupChats[index].unreadCount = 0
    }

    var totalGroupChatUnread: Int {
        eventGroupChats.reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Chat Functions

    func openChat() {
        isOpen = true
        isMinimized = false
        unreadCount = 0
    }

    /// Opens the chat with context about a specific event and automatically provides info
    func openChatWithEventContext(_ event: ClubEvent) {
        // Open the chat
        isOpen = true
        isMinimized = false
        unreadCount = 0

        // Set the event in context
        context.setEvent(event)

        // Show typing indicator briefly
        isTyping = true

        // Generate a response about the event after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            self.isTyping = false

            // Create an informative message about the event
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE, MMMM d 'at' h:mm a"
            let dateStr = dateFormatter.string(from: event.date)

            var messageContent = "Here's what you need to know about **\(event.title)**:\n\n"
            messageContent += "📅 **When:** \(dateStr)\n"
            messageContent += "📍 **Where:** \(event.location)\n"

            if event.spotsLeft > 0 {
                messageContent += "🎟️ **Availability:** \(event.spotsLeft) spots remaining\n"
            } else {
                messageContent += "🎟️ **Status:** Fully booked\n"
            }

            if let tier = event.requiredMembershipTier {
                messageContent += "👑 **Access:** \(tier.displayName) members\n"
            }

            messageContent += "\n\(event.description)\n\n"
            messageContent += "Would you like to add this to your schedule, or do you have any questions?"

            let aiMessage = ChatMessage(
                content: messageContent,
                isFromUser: false,
                senderType: .ai,
                timestamp: Date(),
                eventInvite: EventInvite.from(event: event)
            )
            self.messages.append(aiMessage)
        }
    }

    func closeChat() {
        isOpen = false
        isMinimized = false
    }

    func minimizeChat() {
        isMinimized = true
    }

    func expandChat() {
        isMinimized = false
        unreadCount = 0
    }

    func toggleChat() {
        if isOpen {
            if isMinimized {
                expandChat()
            } else {
                minimizeChat()
            }
        } else {
            openChat()
        }
    }

    func sendMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Add user message
        let userMessage = ChatMessage(
            content: content,
            isFromUser: true,
            senderType: .user,
            timestamp: Date()
        )
        messages.append(userMessage)

        // Add to conversation history for context
        conversationHistory.append((role: "user", content: content))

        // Check if user wants human help
        let lowercased = content.lowercased()
        if lowercased.contains("human") || lowercased.contains("real person") || lowercased.contains("manager") || lowercased.contains("speak to someone") {
            handleHumanRequest()
            return
        }

        // PRIORITY 1: Check for food order queries
        if let foodOrderResponse = handleFoodOrderQuery(content) {
            isTyping = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.isTyping = false
                self?.messages.append(foodOrderResponse)
                self?.conversationHistory.append((role: "assistant", content: foodOrderResponse.content))
                if self?.isMinimized == true {
                    self?.unreadCount += 1
                }
            }
            return
        }

        // PRIORITY 1.5: Check for space booking queries (cabana/meeting room)
        if let spaceBookingResponse = handleSpaceBookingQuery(content) {
            isTyping = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.isTyping = false
                self?.messages.append(spaceBookingResponse)
                self?.conversationHistory.append((role: "assistant", content: spaceBookingResponse.content))
                if self?.isMinimized == true {
                    self?.unreadCount += 1
                }
            }
            return
        }

        // PRIORITY 1.6: Check for valet queries
        if let valetResponse = handleValetQuery(content) {
            isTyping = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.isTyping = false
                self?.messages.append(valetResponse)
                self?.conversationHistory.append((role: "assistant", content: valetResponse.content))
                if self?.isMinimized == true {
                    self?.unreadCount += 1
                }
            }
            return
        }

        // PRIORITY 1.7: Check for check-in/arrival queries
        if let checkInResponse = handleCheckInQuery(content) {
            isTyping = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.isTyping = false
                self?.messages.append(checkInResponse)
                self?.conversationHistory.append((role: "assistant", content: checkInResponse.content))
                if self?.isMinimized == true {
                    self?.unreadCount += 1
                }
            }
            return
        }

        // PRIORITY 1.8: Check for event booking queries with staff (spa, fitness, yoga, dining)
        if let eventBookingResponse = handleUnifiedEventBookingQuery(content) {
            isTyping = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.isTyping = false
                self?.messages.append(eventBookingResponse)
                self?.conversationHistory.append((role: "assistant", content: eventBookingResponse.content))
                if self?.isMinimized == true {
                    self?.unreadCount += 1
                }
            }
            return
        }

        // PRIORITY 2: Check for contextual follow-up queries (using current context)
        if let contextualResponse = handleContextualFollowUp(content) {
            isTyping = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.isTyping = false
                self?.messages.append(contextualResponse)
                self?.conversationHistory.append((role: "assistant", content: contextualResponse.content))
                if self?.isMinimized == true {
                    self?.unreadCount += 1
                }
            }
            return
        }

        // PRIORITY 3: Check for new event queries (this will update context)
        if let eventResponse = handleEventQuery(content) {
            isTyping = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isTyping = false
                self?.messages.append(eventResponse)
                self?.conversationHistory.append((role: "assistant", content: eventResponse.content))
                if self?.isMinimized == true {
                    self?.unreadCount += 1
                }
            }
            return
        }

        // PRIORITY 3: Get AI response for general queries
        isTyping = true

        // Always provide weather context - Claude will intelligently use it when relevant
        let weatherContext = buildComprehensiveWeatherContext(for: content)

        // Build user context for personalized responses
        let userContext = buildUserContext()

        Task {
            do {
                let response = try await ClaudeService.shared.sendMessage(
                    content,
                    conversationHistory: conversationHistory,
                    weatherContext: weatherContext,
                    userContext: userContext
                )
                await MainActor.run {
                    self.isTyping = false
                    self.addAIResponse(response)
                }
            } catch {
                await MainActor.run {
                    self.isTyping = false
                    self.addAIResponse("I apologize, but I'm having trouble processing that request. Would you like me to connect you with a human concierge?")
                }
            }
        }
    }

    // MARK: - User Context Builder

    /// Builds context about the current user's state for personalized AI responses
    private func buildUserContext() -> ClaudeService.UserContext {
        let clubAccess = ClubAccessService.shared
        let eventManager = EventManager.shared
        let orderService = FoodOrderService.shared
        let bookingService = SpaceBookingService.shared

        // Get user's scheduled events
        let upcomingEventTitles = eventManager.mySchedule.prefix(5).map { $0.title }

        // Build locker info if active
        var lockerInfo: String?
        if let locker = clubAccess.currentLocker {
            lockerInfo = "Locker \(locker.displayNumber) on \(locker.floor)"
        }

        // Build valet status if active
        var valetStatus: String?
        if let valet = clubAccess.valetRequest {
            valetStatus = "\(valet.vehicleInfo.displayName) - \(valet.status.rawValue)"
        }

        // Build food order info if active
        var foodOrderInfo: String?
        if let order = orderService.currentOrder {
            let itemCount = order.totalItems
            let status = order.status.rawValue
            foodOrderInfo = "\(itemCount) item(s) - \(status) - \(order.location.displayName)"
        }

        // Build space booking info if active
        var spaceBookingInfo: String?
        if let booking = bookingService.currentBooking, booking.isActive {
            spaceBookingInfo = "\(booking.displayName) - \(booking.spaceType.rawValue)"
        }

        return ClaudeService.UserContext(
            memberName: nil, // Would come from AuthViewModel in full implementation
            memberTier: nil, // Would come from AuthViewModel
            upcomingEvents: upcomingEventTitles.isEmpty ? nil : Array(upcomingEventTitles),
            hasActiveLocker: clubAccess.currentLocker != nil,
            lockerInfo: lockerInfo,
            hasActiveValet: clubAccess.valetRequest != nil,
            valetStatus: valetStatus,
            isAtClubhouse: clubAccess.isAtClubhouse,
            hasOpenTab: orderService.hasOpenTab,
            foodOrderInfo: foodOrderInfo,
            hasActiveSpaceBooking: bookingService.currentBooking?.isActive ?? false,
            spaceBookingInfo: spaceBookingInfo
        )
    }

    // MARK: - Contextual Follow-Up Handling

    private func handleContextualFollowUp(_ content: String) -> ChatMessage? {
        let lowercased = content.lowercased()

        // Check if this is a context-switching trigger ("how about X events")
        if isContextSwitchTrigger(lowercased) {
            return nil // Let handleEventQuery handle the new context
        }

        // PRIORITY: Handle numbered references ("the first one", "number 2", etc.)
        if let numberedResponse = handleNumberedReference(lowercased) {
            return numberedResponse
        }

        // Handle pronoun references ("that one", "this one", "it")
        if let pronounResponse = handlePronounReference(lowercased) {
            return pronounResponse
        }

        // Handle "my events" / "my schedule" queries
        if isMyScheduleQuery(lowercased) {
            return handleMyScheduleQuery()
        }

        // Handle locker queries
        if isLockerQuery(lowercased) {
            return handleLockerQuery()
        }

        // Handle valet queries
        if isValetQuery(lowercased) {
            return handleValetQuery()
        }

        // Handle amenity/service queries
        if let amenityResponse = handleAmenityQuery(lowercased) {
            return amenityResponse
        }

        // Need existing context to handle follow-ups
        guard context.currentEvent != nil || context.currentEvents != nil else {
            return nil
        }

        // Check for follow-up questions about the current event/context

        // "What's the weather" / "Weather for that event" - answer about context event
        if isWeatherFollowUp(lowercased) {
            return handleWeatherFollowUp(lowercased)
        }

        // "How many spots" / "Are there slots" / "Is it full" - answer about current event
        if isSpotsFollowUp(lowercased) {
            return handleSpotsFollowUp()
        }

        // "When is it" / "What time" - answer about current event
        if isTimeFollowUp(lowercased) {
            return handleTimeFollowUp()
        }

        // "Where is it" / "Location" - answer about current event
        if isLocationFollowUp(lowercased) {
            return handleLocationFollowUp()
        }

        // "Tell me more" / "More details" / "More info" - give details about current event
        if isMoreInfoFollowUp(lowercased) {
            return handleMoreInfoFollowUp()
        }

        // "RSVP" / "Sign me up" / "Add me" - RSVP to current event
        if isRSVPFollowUp(lowercased) {
            return handleRSVPFollowUp()
        }

        // "Show me more" / "What else" / "Other events" - show more from current category
        if isShowMoreFollowUp(lowercased) {
            return handleShowMoreFollowUp()
        }

        // "Who is my trainer" / "Who's leading" - answer about staff
        if isStaffQuery(lowercased) {
            if let response = handleStaffQuery() {
                return response
            }
        }

        // "Will there be food" / "What's on the menu" - answer about food/beverage
        if isFoodQuery(lowercased) {
            if let response = handleFoodQuery() {
                return response
            }
        }

        // "What artwork" / "Which artists" - answer about gallery exhibitions
        if isArtworkQuery(lowercased) {
            if let response = handleArtworkQuery() {
                return response
            }
        }

        // "What should I wear" / "Dress code" - answer about attire
        if isDressCodeQuery(lowercased) {
            if let response = handleDressCodeQuery() {
                return response
            }
        }

        // "What's included" - answer about event inclusions
        if isIncludedQuery(lowercased) {
            if let response = handleIncludedQuery() {
                return response
            }
        }

        return nil
    }

    // MARK: - Smart Context Detection

    /// Handles numbered references like "the first one", "number 2", "the third event"
    private func handleNumberedReference(_ query: String) -> ChatMessage? {
        guard let events = context.currentEvents, !events.isEmpty else { return nil }

        // Patterns for numbered references
        let numberPatterns: [(pattern: String, index: Int)] = [
            ("first", 0), ("1st", 0), ("number 1", 0), ("number one", 0), ("#1", 0),
            ("second", 1), ("2nd", 1), ("number 2", 1), ("number two", 1), ("#2", 1),
            ("third", 2), ("3rd", 2), ("number 3", 2), ("number three", 2), ("#3", 2),
            ("fourth", 3), ("4th", 3), ("number 4", 3), ("number four", 3), ("#4", 3),
            ("fifth", 4), ("5th", 4), ("number 5", 4), ("number five", 4), ("#5", 4),
            ("last", events.count - 1), ("final", events.count - 1)
        ]

        for (pattern, index) in numberPatterns {
            if query.contains(pattern) && index < events.count {
                let selectedEvent = events[index]
                context.setEvent(selectedEvent)

                // Check what action the user wants
                if isRSVPFollowUp(query) {
                    EventManager.shared.addToSchedule(selectedEvent)
                    return ChatMessage(
                        content: "Done! I've added **\(selectedEvent.title)** to your schedule.",
                        isFromUser: false,
                        senderType: .ai,
                        timestamp: Date(),
                        eventInvite: EventInvite.from(event: selectedEvent)
                    )
                }

                // Default: show event details
                let responseText = "Here are the details for **\(selectedEvent.title)**:"
                return ChatMessage(
                    content: responseText,
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvite: EventInvite.from(event: selectedEvent)
                )
            }
        }

        return nil
    }

    /// Handles pronoun references like "that one", "this event", "it"
    private func handlePronounReference(_ query: String) -> ChatMessage? {
        // Only handle if we have a clear single event in context
        guard let event = context.currentEvent else { return nil }

        // Check for pronoun + action patterns
        let pronounPatterns = ["that one", "this one", "that event", "this event", "it"]
        let hasPronouns = pronounPatterns.contains { query.contains($0) }

        guard hasPronouns else { return nil }

        // Check what action they want with "that one"
        if isRSVPFollowUp(query) {
            EventManager.shared.addToSchedule(event)
            return ChatMessage(
                content: "You're all set! I've added **\(event.title)** to your schedule.",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date(),
                eventInvite: EventInvite.from(event: event)
            )
        }

        // If they just say "that one" or "tell me about that one", show details
        if query.contains("tell me") || query.contains("about") || query.contains("details") || query.contains("more") {
            return handleMoreInfoFollowUp()
        }

        return nil
    }

    /// Check if query is about user's own schedule
    private func isMyScheduleQuery(_ query: String) -> Bool {
        let scheduleWords = ["my events", "my schedule", "what i'm attending", "what am i going to",
                            "my upcoming", "what did i rsvp", "events i'm going", "my rsvp"]
        return scheduleWords.contains { query.contains($0) }
    }

    /// Handle queries about user's scheduled events
    private func handleMyScheduleQuery() -> ChatMessage? {
        let myEvents = EventManager.shared.mySchedule

        if myEvents.isEmpty {
            return ChatMessage(
                content: "You don't have any events on your schedule yet! Would you like me to show you what's coming up?",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
        }

        context.setEvents(myEvents, category: nil)
        let invites = myEvents.map { EventInvite.from(event: $0) }

        return ChatMessage(
            content: "Here are the **\(myEvents.count) events** on your schedule:",
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    /// Provides time-of-day-aware suggestions
    func getTimeOfDaySuggestion() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<10:
            return "Good morning! Would you like to see today's yoga or fitness classes?"
        case 10..<14:
            return "Looking for a lunch reservation or mid-day spa treatment?"
        case 14..<17:
            return "The pool and spa are lovely this time of day. Can I help you book something?"
        case 17..<21:
            return "Planning for the evening? We have dinner reservations and social events available."
        case 21..<24, 0..<5:
            return "Our late-night lounge is open. Want to see what's happening?"
        default:
            return "How can I help you today?"
        }
    }

    /// Detects if user is asking about events happening soon
    private func isSoonQuery(_ query: String) -> Bool {
        let soonWords = ["happening soon", "starting soon", "about to start", "in the next hour",
                        "right now", "happening now", "currently", "ongoing"]
        return soonWords.contains { query.contains($0) }
    }

    /// Handle queries about events happening soon/now
    private func handleSoonEventsQuery() -> ChatMessage? {
        let now = Date()
        let twoHoursFromNow = now.addingTimeInterval(7200)

        // Find events starting within the next 2 hours
        let soonEvents = ClubEvent.sampleEvents.filter { event in
            event.date > now && event.date <= twoHoursFromNow
        }.sorted { $0.date < $1.date }

        // Find events currently ongoing
        let ongoingEvents = ClubEvent.sampleEvents.filter { event in
            guard let endDate = event.endDate else { return false }
            return event.date <= now && endDate > now
        }

        let allRelevantEvents = ongoingEvents + soonEvents

        if allRelevantEvents.isEmpty {
            return ChatMessage(
                content: "Nothing is happening in the next couple hours, but the clubhouse amenities are always available! Would you like to see today's full schedule?",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
        }

        context.setEvents(allRelevantEvents, category: nil)
        let invites = allRelevantEvents.map { EventInvite.from(event: $0) }

        var message = ""
        if !ongoingEvents.isEmpty {
            message = "Here's what's **happening now** or **starting soon**:"
        } else {
            message = "Here's what's **starting within the next 2 hours**:"
        }

        return ChatMessage(
            content: message,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    // MARK: - Service Query Handlers

    // MARK: - Food Order Handling

    private func handleFoodOrderQuery(_ content: String) -> ChatMessage? {
        let lowercased = content.lowercased()

        // Check for food order status query
        if isFoodOrderStatusQuery(lowercased) {
            return handleFoodOrderStatusQuery()
        }

        // Check for menu query
        if isMenuQuery(lowercased) {
            return handleMenuQuery()
        }

        // Check for food order intent
        if let orderResponse = detectAndProcessFoodOrder(lowercased) {
            return orderResponse
        }

        // Check for location confirmation (follow-up to pending order)
        if let pendingOrder = context.pendingFoodOrder, pendingOrder.needsLocationConfirmation {
            if let locationResponse = handleLocationConfirmation(lowercased) {
                return locationResponse
            }
        }

        return nil
    }

    private func isFoodOrderStatusQuery(_ query: String) -> Bool {
        let statusIndicators = ["my order", "order status", "where's my food", "where's my drink",
                                "how's my order", "order coming", "is my order ready", "my tab", "check my tab"]
        return statusIndicators.contains { query.contains($0) }
    }

    private func handleFoodOrderStatusQuery() -> ChatMessage {
        let orderService = FoodOrderService.shared

        if let order = orderService.currentOrder {
            let statusEmoji: String
            switch order.status {
            case .draft: statusEmoji = "📝"
            case .received: statusEmoji = "✅"
            case .preparing: statusEmoji = "👨‍🍳"
            case .enRoute: statusEmoji = "🚶"
            case .delivered: statusEmoji = "🎉"
            case .closed: statusEmoji = "💳"
            }

            var content = """
            **Your Order** \(statusEmoji)

            **Status:** \(order.status.rawValue)
            **Location:** \(order.location.displayName)
            **Items:** \(order.totalItems) item(s) - \(order.formattedSubtotal)
            """

            if !order.currentlyWorking.isEmpty {
                content += "\n\n**Currently Preparing:**"
                for item in order.currentlyWorking {
                    content += "\n• \(item.staffRole.emoji) \(item.staffName) working on \(item.itemName)"
                }
            }

            if order.status != .delivered && order.status != .closed {
                content += "\n\nEstimated time: ~\(order.estimatedPrepTime) minutes"
            }

            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        } else {
            let content = """
            You don't have an active order right now.

            Would you like to order something? Just tell me what you'd like! For example:
            • "I'd like a burger and fries"
            • "Can I get a cosmopolitan?"
            • "Send a bottle of champagne to my cabana"
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }
    }

    private func isMenuQuery(_ query: String) -> Bool {
        let menuIndicators = ["menu", "what do you have", "what's available", "what can i order",
                              "what food", "what drinks", "show me the menu", "see the menu"]
        return menuIndicators.contains { query.contains($0) }
    }

    private func handleMenuQuery() -> ChatMessage {
        let content = """
        **Clubhouse Menu** 🍽️

        **🥗 Starters**
        • Truffle Fries - $14
        • Ahi Tuna Tartare - $22
        • Burrata Caprese - $18

        **🍔 Mains**
        • Clubhouse Burger - $24
        • Grilled Salmon - $32
        • Truffle Pasta - $28
        • Filet Mignon - $48

        **🍸 Cocktails**
        • Cosmopolitan - $18
        • Old Fashioned - $20
        • BAYC Sunset - $22
        • Margarita - $18

        **🍷 Wine & Champagne**
        • House wines from $14/glass
        • Premium champagne available

        Just tell me what you'd like and where to send it!
        """
        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    private func detectAndProcessFoodOrder(_ query: String) -> ChatMessage? {
        let orderService = FoodOrderService.shared

        // Order intent keywords
        let orderIntents = ["i'd like", "i would like", "can i get", "can i have", "i want",
                           "send me", "bring me", "get me", "order", "i'll have", "i'll take"]
        let hasOrderIntent = orderIntents.contains { query.contains($0) }

        if !hasOrderIntent {
            return nil
        }

        // Try to find menu items in the query
        var foundItems: [(MenuItem, Int)] = []

        // Check each menu item
        for menuItem in MenuItem.sampleMenu {
            let itemNameLower = menuItem.name.lowercased()
            let words = itemNameLower.split(separator: " ").map { String($0) }

            // Check if the query contains the full item name or key words
            if query.contains(itemNameLower) {
                foundItems.append((menuItem, 1))
            } else {
                // Check for partial matches (e.g., "burger" matches "Clubhouse Burger")
                for word in words where word.count > 3 {
                    if query.contains(word) && !["with", "and", "the"].contains(word) {
                        foundItems.append((menuItem, 1))
                        break
                    }
                }
            }
        }

        // Also check common aliases
        let aliases: [String: String] = [
            "cosmo": "Cosmopolitan",
            "old fashion": "Old Fashioned",
            "fries": "Truffle Fries",
            "champagne": "Veuve Clicquot",
            "beer": "Craft IPA",
            "wine": "Cabernet Sauvignon",
            "burger": "Clubhouse Burger",
            "steak": "Filet Mignon",
            "salmon": "Grilled Salmon",
            "pasta": "Truffle Pasta"
        ]

        for (alias, itemName) in aliases {
            if query.contains(alias) {
                if let menuItem = MenuItem.findByName(itemName), !foundItems.contains(where: { $0.0.id == menuItem.id }) {
                    foundItems.append((menuItem, 1))
                }
            }
        }

        if foundItems.isEmpty {
            return nil
        }

        // Detect location from query
        var location: OrderLocation?
        if query.contains("cabana") {
            if let bookingLocation = SpaceBookingService.shared.currentBookingAsOrderLocation,
               case .cabana = bookingLocation {
                location = bookingLocation
            } else {
                location = .cabana(id: UUID(), name: "Cabana")
            }
        } else if query.contains("meeting room") || query.contains("conference") || query.contains("board room") {
            if let bookingLocation = SpaceBookingService.shared.currentBookingAsOrderLocation,
               case .meetingRoom = bookingLocation {
                location = bookingLocation
            } else {
                location = .meetingRoom(id: UUID(), name: "Meeting Room")
            }
        } else if query.contains("lounge") {
            location = .lounge
        } else if query.contains("pool") || query.contains("poolside") {
            location = .poolside
        } else if query.contains("rooftop") || query.contains("roof") {
            location = .rooftop
        }

        // Build order summary
        let itemNames = foundItems.map { $0.0.name }.joined(separator: ", ")
        var totalPrice: Double = 0
        for (item, qty) in foundItems {
            totalPrice += item.price * Double(qty)
        }

        if let location = location {
            // Place the order directly
            _ = orderService.openTab(location: location)
            for (item, qty) in foundItems {
                orderService.addItem(item, quantity: qty)
            }
            orderService.submitOrder()

            context.lastQueryType = .foodOrder

            let content = """
            **Order Placed!** ✅

            **Items:** \(itemNames)
            **Total:** $\(String(format: "%.2f", totalPrice))
            **Delivering to:** \(location.displayName)

            Your order is being prepared now! I'll update you on the progress. 🍽️
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        } else {
            // Need to ask for location
            context.pendingFoodOrder = ConversationContext.PendingFoodOrder(
                items: foundItems,
                location: nil,
                needsLocationConfirmation: true
            )
            context.lastQueryType = .foodOrder

            // Check for active booking to suggest
            var locationSuggestion = ""
            if let bookingLocation = SpaceBookingService.shared.currentBookingAsOrderLocation {
                locationSuggestion = "\n• **\(bookingLocation.displayName)** (your current booking)"
            }

            let content = """
            **Great choice!** 🎉

            **\(itemNames)** - $\(String(format: "%.2f", totalPrice))

            Where would you like this delivered?\(locationSuggestion)
            • **Lounge**
            • **Poolside**
            • **Rooftop**

            Just let me know!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }
    }

    private func handleLocationConfirmation(_ query: String) -> ChatMessage? {
        guard let pendingOrder = context.pendingFoodOrder else { return nil }

        let orderService = FoodOrderService.shared
        var location: OrderLocation?

        // Detect location from response
        if query.contains("lounge") {
            location = .lounge
        } else if query.contains("pool") || query.contains("poolside") {
            location = .poolside
        } else if query.contains("rooftop") || query.contains("roof") {
            location = .rooftop
        } else if query.contains("cabana") {
            if let bookingLocation = SpaceBookingService.shared.currentBookingAsOrderLocation,
               case .cabana = bookingLocation {
                location = bookingLocation
            } else {
                location = .poolside // Default if no cabana booking
            }
        } else if query.contains("meeting") || query.contains("conference") || query.contains("board") {
            if let bookingLocation = SpaceBookingService.shared.currentBookingAsOrderLocation,
               case .meetingRoom = bookingLocation {
                location = bookingLocation
            }
        } else if query.contains("my booking") || query.contains("my space") || query.contains("current booking") {
            location = SpaceBookingService.shared.currentBookingAsOrderLocation
        }

        guard let finalLocation = location else {
            return nil // Didn't understand location, let it fall through to AI
        }

        // Place the order
        _ = orderService.openTab(location: finalLocation)
        for (item, qty) in pendingOrder.items {
            orderService.addItem(item, quantity: qty)
        }
        orderService.submitOrder()

        // Clear pending order
        context.pendingFoodOrder = nil

        let itemNames = pendingOrder.items.map { $0.menuItem.name }.joined(separator: ", ")
        var totalPrice: Double = 0
        for (item, qty) in pendingOrder.items {
            totalPrice += item.price * Double(qty)
        }

        let content = """
        **Order Placed!** ✅

        **Items:** \(itemNames)
        **Total:** $\(String(format: "%.2f", totalPrice))
        **Delivering to:** \(finalLocation.displayName)

        Your order is on its way! I'll keep you posted on the progress. 🍽️
        """
        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    // MARK: - Space Booking Handling

    private func handleSpaceBookingQuery(_ content: String) -> ChatMessage? {
        let lowercased = content.lowercased()

        // Check for checkout/end booking query
        if isSpaceCheckoutQuery(lowercased) {
            return handleSpaceCheckoutQuery()
        }

        // Check for booking status query
        if isSpaceBookingStatusQuery(lowercased) {
            return handleSpaceBookingStatusQuery()
        }

        // Check for cabana booking intent
        if isCabanaBookingQuery(lowercased) {
            return handleCabanaBookingQuery()
        }

        // Check for meeting room booking intent
        if isMeetingRoomBookingQuery(lowercased) {
            return handleMeetingRoomBookingQuery()
        }

        return nil
    }

    private func isSpaceCheckoutQuery(_ query: String) -> Bool {
        let checkoutIndicators = ["end my cabana", "end my booking", "check out of cabana", "checkout cabana",
                                   "finish my cabana", "done with cabana", "leave my cabana", "close my cabana",
                                   "end my meeting room", "check out of meeting", "checkout meeting", "done with meeting room",
                                   "end booking", "check out", "check me out"]
        return checkoutIndicators.contains { query.contains($0) }
    }

    private func isSpaceBookingStatusQuery(_ query: String) -> Bool {
        let statusIndicators = ["my cabana", "my booking", "my meeting room", "booking status", "where's my cabana"]
        return statusIndicators.contains { query.contains($0) } && !isSpaceCheckoutQuery(query)
    }

    private func isCabanaBookingQuery(_ query: String) -> Bool {
        // Direct booking intent phrases
        let bookingIndicators = ["book a cabana", "book cabana", "reserve a cabana", "reserve cabana",
                                 "get a cabana", "want a cabana", "need a cabana", "cabana available",
                                 "available cabana", "show me cabanas", "what cabanas", "rent a cabana",
                                 "rent cabana", "cabana for"]
        if bookingIndicators.contains(where: { query.contains($0) }) {
            return true
        }

        // "Can I" / "Could I" / "I'd like" patterns with cabana
        if query.contains("cabana") {
            let intentPhrases = ["can i", "could i", "i'd like", "i would like", "i want to",
                                "may i", "let me", "help me", "looking for", "interested in"]
            if intentPhrases.contains(where: { query.contains($0) }) {
                return true
            }
        }

        return false
    }

    private func isMeetingRoomBookingQuery(_ query: String) -> Bool {
        let bookingIndicators = ["book a meeting room", "book meeting room", "reserve a meeting room", "reserve meeting",
                                 "get a meeting room", "need a meeting room", "conference room", "book conference",
                                 "board room", "available meeting rooms", "show me meeting rooms", "what meeting rooms"]
        return bookingIndicators.contains { query.contains($0) }
    }

    private func handleSpaceCheckoutQuery() -> ChatMessage {
        let bookingService = SpaceBookingService.shared

        if let booking = bookingService.currentBooking, booking.isActive {
            // Calculate total
            let totalCost = booking.baseCost + booking.tabTotal
            let formattedTotal = String(format: "$%.2f", totalCost)

            let content = """
            **Ready to check out of \(booking.displayName)?** 🏖️

            **Summary:**
            • Space: \(booking.displayName)
            • Duration: \(booking.formattedDuration)
            • Space Cost: \(String(format: "$%.2f", booking.baseCost))
            \(booking.tabTotal > 0 ? "• Tab Total: \(booking.formattedTabTotal)\n" : "")• **Total: \(formattedTotal)**

            To complete checkout, please tap the **Check Out** button on your booking card in the Membership tab, or I can connect you with a concierge to process your payment.
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        } else {
            let content = """
            You don't have an active space booking to check out of.

            Would you like to book a cabana or meeting room? Just ask!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }
    }

    private func handleSpaceBookingStatusQuery() -> ChatMessage {
        let bookingService = SpaceBookingService.shared

        if let booking = bookingService.currentBooking {
            let statusEmoji = booking.isActive ? "✅" : "📅"
            let timeInfo = booking.isActive ? "Currently active" : "Starts at \(booking.formattedTimeRange)"

            let content = """
            **Your Booking** \(statusEmoji)

            **Space:** \(booking.displayName)
            **Type:** \(booking.spaceType.rawValue)
            **Location:** \(booking.floor)
            **Date:** \(booking.formattedDate)
            **Time:** \(timeInfo)
            **Guests:** \(booking.guestCount)
            \(booking.tabTotal > 0 ? "\n**Current Tab:** \(booking.formattedTabTotal)" : "")

            Need anything delivered to your space? Just let me know what you'd like!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        } else if !bookingService.upcomingBookings.isEmpty {
            let upcoming = bookingService.upcomingBookings.first!
            let content = """
            You don't have an active booking right now, but you have an upcoming reservation:

            **\(upcoming.displayName)** on \(upcoming.formattedDate) at \(upcoming.formattedTimeRange)

            Would you like to book something for now?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        } else {
            let content = """
            You don't have any active or upcoming space bookings.

            Would you like me to show you available cabanas or meeting rooms?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }
    }

    private func handleCabanaBookingQuery() -> ChatMessage {
        let bookingService = SpaceBookingService.shared
        let clubAccess = ClubAccessService.shared

        // Check if user is at clubhouse (cabanas require being at clubhouse)
        if !clubAccess.isAtClubhouse {
            let content = """
            **Cabana Reservations** ☀️

            Cabanas can be booked when you're at the clubhouse. I can see you're not currently checked in.

            Would you like to book a meeting room instead, or I can help you plan a visit?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Check if already has a booking
        if let existingBooking = bookingService.currentBooking, existingBooking.spaceType == .cabana {
            let content = """
            You already have an active cabana booked:

            **\(existingBooking.displayName)** until \(existingBooking.formattedTimeRange)

            Would you like to extend your booking or order something to your cabana?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Show available cabanas
        let cabanas = AvailableSpace.sampleCabanas
        var content = """
        **Available Cabanas** ☀️

        Here are the cabanas available right now:

        """

        for (index, cabana) in cabanas.enumerated() {
            content += """
            **\(index + 1). \(cabana.displayName)** - \(cabana.floor)
            • Max guests: \(cabana.maxGuests)
            • Amenities: \(cabana.amenities.prefix(3).joined(separator: ", "))
            • Rate: $\(Int(SpaceBooking.SpaceType.cabana.hourlyRate))/hour

            """
        }

        content += """
        To book, just say something like "Book cabana 1 for 2 hours" or head to the **Membership tab** to complete your reservation!
        """

        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    private func handleMeetingRoomBookingQuery() -> ChatMessage {
        let bookingService = SpaceBookingService.shared

        // Check if already has a meeting room booking
        if let existingBooking = bookingService.currentBooking, existingBooking.spaceType == .meetingRoom {
            let content = """
            You already have an active meeting room booked:

            **\(existingBooking.displayName)** until \(existingBooking.formattedTimeRange)

            Would you like to extend your booking or order refreshments?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Show available meeting rooms
        let rooms = AvailableSpace.sampleMeetingRooms
        var content = """
        **Available Meeting Rooms** 🏢

        Here are the meeting rooms available:

        """

        for (index, room) in rooms.enumerated() {
            content += """
            **\(index + 1). \(room.displayName)** - \(room.floor)
            • Capacity: \(room.maxGuests) people
            • Amenities: \(room.amenities.prefix(3).joined(separator: ", "))
            • Rate: $\(Int(SpaceBooking.SpaceType.meetingRoom.hourlyRate))/hour

            """
        }

        content += """
        To book, just say "Book meeting room 1 for 2 hours" or go to the **Membership tab** to complete your reservation!
        """

        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    // MARK: - Valet Handling

    private func handleValetQuery(_ content: String) -> ChatMessage? {
        let lowercased = content.lowercased()

        // Check for valet status query
        if isValetStatusQuery(lowercased) {
            return handleValetStatusQuery()
        }

        // Check for car retrieval request
        if isCarRetrievalQuery(lowercased) {
            return handleCarRetrievalQuery(lowercased)
        }

        // Check for valet parking request (park my car)
        if isValetParkingQuery(lowercased) {
            return handleValetParkingQuery(lowercased)
        }

        // Check for general valet help
        if isGeneralValetQuery(lowercased) {
            return handleGeneralValetQuery()
        }

        return nil
    }

    private func isValetStatusQuery(_ query: String) -> Bool {
        let statusIndicators = ["my car", "where is my car", "car status", "valet status", "my valet",
                                "where did you park", "is my car ready", "check on my car"]
        return statusIndicators.contains { query.contains($0) } && !isCarRetrievalQuery(query)
    }

    private func isCarRetrievalQuery(_ query: String) -> Bool {
        let retrievalIndicators = ["get my car", "bring my car", "retrieve my car", "need my car",
                                   "pull my car", "fetch my car", "i'm leaving", "ready to leave",
                                   "bring the car", "car to", "car at main", "car at vip"]
        return retrievalIndicators.contains { query.contains($0) }
    }

    private func isValetParkingQuery(_ query: String) -> Bool {
        let parkingIndicators = ["park my car", "valet my car", "take my car", "need valet",
                                 "request valet", "call valet", "valet service", "drop my car",
                                 "drop off my car", "drop my car off", "leave my car", "park my",
                                 "can i park", "parking my", "i'm parking", "here to park"]
        return parkingIndicators.contains { query.contains($0) }
    }

    // MARK: - Vehicle Info Parsing

    private func parseVehicleInfo(from query: String) -> VehicleInfo? {
        let lowercased = query.lowercased()

        // Common car colors
        let colors = ["black", "white", "grey", "gray", "silver", "red", "blue", "green", "yellow",
                      "orange", "brown", "beige", "gold", "purple", "pink", "midnight", "matte"]

        // Common car makes
        let makes: [String: String] = [
            "bmw": "BMW", "mercedes": "Mercedes-Benz", "benz": "Mercedes-Benz", "audi": "Audi",
            "tesla": "Tesla", "porsche": "Porsche", "ferrari": "Ferrari", "lamborghini": "Lamborghini",
            "maserati": "Maserati", "bentley": "Bentley", "rolls": "Rolls-Royce", "royce": "Rolls-Royce",
            "lexus": "Lexus", "toyota": "Toyota", "honda": "Honda", "ford": "Ford", "chevy": "Chevrolet",
            "chevrolet": "Chevrolet", "jeep": "Jeep", "range rover": "Range Rover", "land rover": "Land Rover",
            "cadillac": "Cadillac", "lincoln": "Lincoln", "infiniti": "Infiniti", "acura": "Acura",
            "volvo": "Volvo", "jaguar": "Jaguar", "aston": "Aston Martin", "mclaren": "McLaren",
            "bugatti": "Bugatti", "maybach": "Maybach", "genesis": "Genesis", "lucid": "Lucid",
            "rivian": "Rivian"
        ]

        // Common model patterns
        let modelPatterns: [String: [String]] = [
            "BMW": ["m3", "m4", "m5", "m8", "x3", "x5", "x6", "x7", "i4", "i7", "i8", "3 series", "5 series", "7 series"],
            "Mercedes-Benz": ["amg", "s class", "e class", "c class", "g wagon", "g class", "gle", "gls", "sl", "gt"],
            "Tesla": ["model s", "model 3", "model x", "model y", "cybertruck", "roadster"],
            "Porsche": ["911", "cayenne", "panamera", "taycan", "macan", "boxster", "cayman"],
            "Audi": ["a4", "a6", "a8", "q5", "q7", "q8", "r8", "rs", "e-tron", "etron"],
            "Range Rover": ["sport", "velar", "evoque", "defender"]
        ]

        // Extract color
        var detectedColor: String?
        for color in colors {
            if lowercased.contains(color) {
                detectedColor = color.capitalized
                if color == "gray" { detectedColor = "Grey" }
                break
            }
        }

        // Extract make
        var detectedMake: String?
        for (key, value) in makes {
            if lowercased.contains(key) {
                detectedMake = value
                break
            }
        }

        // Extract model (if we found a make)
        var detectedModel: String?
        if let make = detectedMake, let patterns = modelPatterns[make] {
            for pattern in patterns {
                if lowercased.contains(pattern) {
                    detectedModel = pattern.uppercased()
                    if pattern.contains("model") { detectedModel = pattern.capitalized }
                    if pattern.contains("class") || pattern.contains("wagon") || pattern.contains("series") {
                        detectedModel = pattern.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
                    }
                    break
                }
            }
        }

        // Only return vehicle info if we detected at least make OR color
        if detectedMake != nil || detectedColor != nil {
            return VehicleInfo(
                make: detectedMake ?? "Unknown",
                model: detectedModel ?? (detectedMake != nil ? "" : "Car"),
                color: detectedColor ?? "Unknown",
                licensePlate: "" // Will be filled by valet
            )
        }

        return nil
    }

    private func isGeneralValetQuery(_ query: String) -> Bool {
        return query.contains("valet")
    }

    private func handleValetStatusQuery() -> ChatMessage {
        let clubAccess = ClubAccessService.shared

        if let valet = clubAccess.valetRequest {
            var content = """
            **Your Valet Request** 🚗

            **Vehicle:** \(valet.vehicleInfo.displayName)
            **Ticket:** \(valet.ticketNumber)
            **Status:** \(valet.statusDisplayText)
            """

            if let valetName = valet.assignedValet {
                content += "\n**Valet:** \(valetName)"
            }

            if let parkedLocation = valet.parkedLocation, valet.requestType == .arrival {
                content += "\n**Parked at:** \(parkedLocation)"
            }

            if let deliveryLocation = valet.deliveryLocation, valet.requestType == .departure {
                content += "\n**Delivering to:** \(deliveryLocation.rawValue)"
            }

            if valet.status == .carParked {
                content += "\n\nYour car is safely parked! Say **\"get my car\"** when you're ready to leave."
            } else if valet.status == .carReady {
                content += "\n\n✨ Your car is waiting for you!"
            }

            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        let content = """
        You don't have an active valet request. Would you like me to:

        1. **Park your car** - I'll have a valet come get your keys
        2. **Help with something else** - Just ask!

        Say "park my car" to get started!
        """
        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    private func handleCarRetrievalQuery(_ query: String) -> ChatMessage {
        let clubAccess = ClubAccessService.shared

        guard let valet = clubAccess.valetRequest else {
            let content = """
            I don't see a parked car on your account. Would you like to use valet service?

            Just say "park my car" when you arrive!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        if valet.requestType == .departure && valet.status != .carReady && valet.status != .completed {
            let content = """
            **Your car is already on its way!** 🚗

            **Status:** \(valet.statusDisplayText)
            """
            + (valet.assignedValet != nil ? "\n**Valet:** \(valet.assignedValet!)" : "")
            + (valet.deliveryLocation != nil ? "\n**Delivery:** \(valet.deliveryLocation!.rawValue)" : "")
            + "\n\nI'll let you know when it's ready!"

            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Parse delivery location from query
        var deliveryLocation: ValetRequest.DeliveryLocation = .mainEntrance

        if query.contains("vip") {
            deliveryLocation = .vipEntrance
        } else if query.contains("pool") {
            deliveryLocation = .poolsideDrop
        } else if query.contains("circle") || query.contains("valet circle") {
            deliveryLocation = .valetCircle
        }

        // Request car retrieval
        _ = clubAccess.requestCarRetrieval(deliveryLocation: deliveryLocation)

        let content = """
        **Car Retrieval Requested!** 🚗

        I've asked the valet to bring your **\(valet.vehicleInfo.displayName)** to the **\(deliveryLocation.rawValue)**.

        **Ticket:** \(valet.ticketNumber)

        You can track the progress in the **Membership** tab or Quick Access. I'll notify you when your car is ready!
        """
        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    private func handleValetParkingQuery(_ query: String) -> ChatMessage {
        let clubAccess = ClubAccessService.shared

        if let existingValet = clubAccess.valetRequest {
            if existingValet.requestType == .arrival && existingValet.status != .carParked {
                let content = """
                **Valet is already handling your car!** 🚗

                **Status:** \(existingValet.statusDisplayText)
                **Ticket:** \(existingValet.ticketNumber)
                """
                + (existingValet.assignedValet != nil ? "\n**Valet:** \(existingValet.assignedValet!)" : "")

                return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
            }
        }

        // Try to parse vehicle info from the query
        if let parsedVehicle = parseVehicleInfo(from: query) {
            // We detected vehicle info in the query
            let vehicleInfo = VehicleInfo(
                make: parsedVehicle.make,
                model: parsedVehicle.model,
                color: parsedVehicle.color,
                licensePlate: "" // Will be filled by valet
            )

            let request = clubAccess.requestValet(vehicleInfo: vehicleInfo)

            var vehicleDesc = ""
            if parsedVehicle.color != "Unknown" && parsedVehicle.make != "Unknown" {
                vehicleDesc = "\(parsedVehicle.color) \(parsedVehicle.make)"
                if !parsedVehicle.model.isEmpty {
                    vehicleDesc += " \(parsedVehicle.model)"
                }
            } else if parsedVehicle.make != "Unknown" {
                vehicleDesc = parsedVehicle.make
                if !parsedVehicle.model.isEmpty {
                    vehicleDesc += " \(parsedVehicle.model)"
                }
            } else {
                vehicleDesc = "\(parsedVehicle.color) vehicle"
            }

            let content = """
            **Valet Request Submitted!** 🚗

            I've got your **\(vehicleDesc)** noted for valet service.

            **Vehicle:** \(request.vehicleInfo.displayName)
            **Ticket:** \(request.ticketNumber)

            A valet will be with you shortly to take your keys. You can track the progress in the **Membership** tab.

            *Tip: When you're ready to leave, just say "get my car" and I'll have it brought to you!*
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // No vehicle info detected - ask for details or use generic
        let content = """
        **Valet Service** 🚗

        I'd be happy to park your car! To help our valet find your vehicle:

        **Tell me about your car:**
        For example: "It's a grey BMW" or "Black Tesla Model S"

        Or just say **"park my car now"** and we'll identify it when the valet arrives.

        What would you like to do?
        """
        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    private func handleValetParkingWithFallback() -> ChatMessage {
        let clubAccess = ClubAccessService.shared

        // Create a generic vehicle for immediate parking without vehicle details
        let genericVehicle = VehicleInfo(
            make: "Member's",
            model: "Vehicle",
            color: "",
            licensePlate: ""
        )

        let request = clubAccess.requestValet(vehicleInfo: genericVehicle)

        let content = """
        **Valet Request Submitted!** 🚗

        **Ticket:** \(request.ticketNumber)

        A valet will be with you shortly. They'll note your vehicle details when they take your keys.

        You can track the progress in the **Membership** tab.

        *Tip: When you're ready to leave, just say "get my car" and I'll have it brought to you!*
        """
        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    private func handleGeneralValetQuery() -> ChatMessage {
        let clubAccess = ClubAccessService.shared

        if clubAccess.valetRequest != nil {
            return handleValetStatusQuery()
        }

        let content = """
        **Valet Service** 🚗

        I can help you with:

        • **Park your car** - "Park my car"
        • **Get your car** - "Bring my car to the main entrance"
        • **Check status** - "Where is my car?"

        Delivery locations available:
        • Main Entrance
        • VIP Entrance
        • Poolside Drop-off
        • Valet Circle

        What would you like to do?
        """
        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    // MARK: - Check-In Handling

    private func handleCheckInQuery(_ content: String) -> ChatMessage? {
        let lowercased = content.lowercased()

        // Check for arrival ETA queries
        if let etaResponse = handleArrivalETAQuery(lowercased) {
            return etaResponse
        }

        // Check for check-in request
        if isCheckInRequest(lowercased) {
            return handleCheckInRequest()
        }

        return nil
    }

    private func isCheckInRequest(_ query: String) -> Bool {
        let checkInIndicators = ["check me in", "check in", "i'm here", "im here", "i am here",
                                  "just arrived", "at the club", "at the clubhouse", "i've arrived",
                                  "ive arrived", "checking in"]
        return checkInIndicators.contains { query.contains($0) }
    }

    private func handleArrivalETAQuery(_ query: String) -> ChatMessage? {
        // Parse "I'll be there in X" patterns
        let etaPatterns = [
            (pattern: "be there in (\\d+)", unit: "minutes"),
            (pattern: "there in (\\d+)", unit: "minutes"),
            (pattern: "arriving in (\\d+)", unit: "minutes"),
            (pattern: "eta (\\d+)", unit: "minutes"),
            (pattern: "(\\d+) minutes? away", unit: "minutes"),
            (pattern: "(\\d+) mins? away", unit: "minutes"),
            (pattern: "on my way", unit: "default")
        ]

        for pattern in etaPatterns {
            if pattern.unit == "default" && query.contains("on my way") {
                // Default 15 minutes ETA
                return notifyArrival(eta: 15)
            }

            if let regex = try? NSRegularExpression(pattern: pattern.pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: query, options: [], range: NSRange(query.startIndex..., in: query)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: query),
               let minutes = Int(query[range]) {
                return notifyArrival(eta: minutes)
            }
        }

        return nil
    }

    private func notifyArrival(eta: Int) -> ChatMessage {
        let clubAccess = ClubAccessService.shared
        clubAccess.notifyArriving(eta: eta, guests: 0, specialRequests: nil, memberName: "Member")

        let content = """
        **Arrival Notification Sent!** 🚗

        I've let the club know you'll be here in **\(eta) minutes**.

        • Your arrival has been confirmed
        • Staff will be ready to greet you
        • Valet service will be on standby

        Safe travels! I'll be here if you need anything.
        """
        return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
    }

    private func handleCheckInRequest() -> ChatMessage {
        let clubAccess = ClubAccessService.shared

        if clubAccess.isAtClubhouse {
            // Already at clubhouse, confirm check-in
            clubAccess.checkIn()

            let content = """
            **You're Checked In!** ✅

            Welcome to the clubhouse! Here's what's available:

            • **Locker** - Say "get me a locker" if you need one
            • **Valet** - Say "park my car" for valet service
            • **Food & Drinks** - Say "order food" to start a tab
            • **Spa** - Say "book a massage" for treatments
            • **Events** - Say "what's happening today" for events

            Enjoy your visit!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        } else {
            // Not at clubhouse yet
            let content = """
            **Almost There!** 📍

            I don't detect you at the clubhouse yet. When you arrive:
            • You'll be automatically checked in via GPS
            • Or scan your QR code at the entrance

            **Heading over now?** Just say "I'll be there in 10 minutes" and I'll notify the staff!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }
    }

    // MARK: - Unified Event Booking with Staff

    /// All known staff members with their info for booking queries
    private struct StaffInfo {
        let name: String
        let role: String
        let category: ClubEvent.EventCategory
        let gender: String // "female", "male", "unknown"
        let specialties: [String]
    }

    private var allStaffMembers: [StaffInfo] {
        [
            // Spa - Massage Therapists
            StaffInfo(name: "Lucia Santos", role: "Massage Therapist", category: .spa, gender: "female", specialties: ["Hot stone", "Deep tissue", "Swedish"]),
            StaffInfo(name: "Andrei Volkov", role: "Massage Therapist", category: .spa, gender: "male", specialties: ["Deep tissue", "Sports massage"]),
            StaffInfo(name: "Marcus Chen", role: "Massage Therapist", category: .spa, gender: "male", specialties: ["Sports recovery", "CBD massage"]),
            // Spa - Estheticians
            StaffInfo(name: "Sophie Chen", role: "Esthetician", category: .spa, gender: "female", specialties: ["Anti-aging facials", "Glass skin"]),
            StaffInfo(name: "Elena Martinez", role: "Spa Director", category: .spa, gender: "female", specialties: ["Salt therapy", "Holistic health"]),
            // Fitness - Trainers
            StaffInfo(name: "Mike Torres", role: "Personal Trainer", category: .fitness, gender: "male", specialties: ["HIIT", "Strength training", "Weight loss"]),
            StaffInfo(name: "Jessica Williams", role: "Personal Trainer", category: .fitness, gender: "female", specialties: ["Functional fitness", "Flexibility", "Dance fitness"]),
            // Wellness - Yoga
            StaffInfo(name: "Maya Johnson", role: "Yoga Instructor", category: .wellness, gender: "female", specialties: ["Vinyasa flow", "Restorative yoga", "Breathwork"]),
            // Wellness - Other
            StaffInfo(name: "Dr. James Park", role: "Wellness Physician", category: .spa, gender: "male", specialties: ["Athletic recovery", "CBD therapy"]),
            // Dining - Chefs
            StaffInfo(name: "Chef Antonio Rossi", role: "Executive Chef", category: .dining, gender: "male", specialties: ["Italian cuisine", "Wine pairings"]),
            StaffInfo(name: "Chef Michael Laurent", role: "Chef", category: .dining, gender: "male", specialties: ["Seafood", "Mediterranean"]),
            StaffInfo(name: "Victoria Wells", role: "Sommelier", category: .dining, gender: "female", specialties: ["California wines", "Food pairing"])
        ]
    }

    private func handleUnifiedEventBookingQuery(_ content: String) -> ChatMessage? {
        let lowercased = content.lowercased()

        // 1. Check for staff preference queries ("female trainer", "male therapist")
        if let preferenceResponse = handleStaffPreferenceQuery(lowercased) {
            return preferenceResponse
        }

        // 2. Check for availability queries ("who's available tomorrow", "any openings this week")
        if let availabilityResponse = handleStaffAvailabilityQuery(lowercased) {
            return availabilityResponse
        }

        // 3. Check for booking with specific staff name (any category)
        if let staffBookingResponse = handleBookingWithSpecificStaff(lowercased) {
            return staffBookingResponse
        }

        // 4. Check for category-specific booking queries
        if let categoryBookingResponse = handleCategoryBookingQuery(lowercased) {
            return categoryBookingResponse
        }

        // 5. Check for my schedule/appointments queries
        if isMyScheduleQuery(lowercased) {
            return handleMyScheduleQuery()
        }

        return nil
    }

    // MARK: Staff Preference Queries

    private func handleStaffPreferenceQuery(_ query: String) -> ChatMessage? {
        // Detect gender preference
        let wantsFemale = query.contains("female") || query.contains("woman") || query.contains("lady")
        let wantsMale = query.contains("male") || query.contains("man") || query.contains("guy")

        guard wantsFemale || wantsMale else { return nil }

        let preferredGender = wantsFemale ? "female" : "male"

        // Detect what type of staff they want
        var targetCategory: ClubEvent.EventCategory? = nil
        var targetRole: String? = nil

        if query.contains("trainer") || query.contains("training") || query.contains("workout") || query.contains("gym") {
            targetCategory = .fitness
            targetRole = "trainer"
        } else if query.contains("therapist") || query.contains("massage") {
            targetCategory = .spa
            targetRole = "massage therapist"
        } else if query.contains("yoga") || query.contains("instructor") {
            targetCategory = .wellness
            targetRole = "yoga instructor"
        } else if query.contains("esthetician") || query.contains("facial") {
            targetCategory = .spa
            targetRole = "esthetician"
        }

        // Find matching staff
        let matchingStaff = allStaffMembers.filter { staff in
            staff.gender == preferredGender &&
            (targetCategory == nil || staff.category == targetCategory)
        }

        if matchingStaff.isEmpty {
            let content = """
            I couldn't find any \(preferredGender) \(targetRole ?? "staff") available right now.

            Would you like me to show all available \(targetRole ?? "staff") instead?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Find events with matching staff
        var allMatchingEvents: [ClubEvent] = []
        for staff in matchingStaff {
            let events = ClubEvent.sampleEvents.filter { event in
                event.date > Date() &&
                event.spotsLeft > 0 &&
                (event.details?.staff?.contains { $0.name == staff.name } ?? false)
            }
            allMatchingEvents.append(contentsOf: events)
        }

        // Remove duplicates by ID and sort by date
        var seenIds = Set<UUID>()
        let uniqueEvents = allMatchingEvents.filter { event in
            if seenIds.contains(event.id) { return false }
            seenIds.insert(event.id)
            return true
        }.sorted { $0.date < $1.date }

        if uniqueEvents.isEmpty {
            let content = """
            **\(preferredGender.capitalized) \(targetRole ?? "Staff") Available** 👤

            I found these \(preferredGender) \(targetRole ?? "staff members"):
            \(matchingStaff.map { "• **\($0.name)** - \($0.role)" }.joined(separator: "\n"))

            Unfortunately, they don't have any open sessions right now. Would you like me to:
            1. Add you to a waitlist
            2. Check a different date
            3. Show all available sessions

            Just let me know!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        let eventsToShow = Array(uniqueEvents.prefix(4))
        let invites = eventsToShow.map { EventInvite.from(event: $0) }

        let staffNames = matchingStaff.prefix(3).map { $0.name }.joined(separator: ", ")
        let content = """
        **\(preferredGender.capitalized) \(targetRole?.capitalized ?? "Staff") Available** 👤

        Here are sessions with \(staffNames):
        """

        return ChatMessage(
            content: content,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    // MARK: Staff Availability Queries

    private func handleStaffAvailabilityQuery(_ query: String) -> ChatMessage? {
        // Check for availability patterns
        let availabilityPatterns = ["who's available", "who is available", "who's open", "who is open",
                                     "any openings", "available sessions", "open slots", "availability",
                                     "when can i", "what's available", "what is available"]

        guard availabilityPatterns.contains(where: { query.contains($0) }) else { return nil }

        // Detect time frame
        let isTomorrow = query.contains("tomorrow")
        let isThisWeek = query.contains("this week") || query.contains("week")
        let isToday = query.contains("today") || query.contains("now")

        // Detect category
        var targetCategory: ClubEvent.EventCategory? = nil
        if query.contains("massage") || query.contains("spa") || query.contains("therapist") || query.contains("facial") {
            targetCategory = .spa
        } else if query.contains("training") || query.contains("trainer") || query.contains("gym") || query.contains("workout") || query.contains("fitness") {
            targetCategory = .fitness
        } else if query.contains("yoga") || query.contains("wellness") || query.contains("meditation") {
            targetCategory = .wellness
        }

        // Get matching events
        var events = ClubEvent.sampleEvents.filter { $0.date > Date() && $0.spotsLeft > 0 }

        if let category = targetCategory {
            events = events.filter { $0.category == category }
        } else {
            // Default to spa, fitness, wellness if no category specified
            events = events.filter { [.spa, .fitness, .wellness].contains($0.category) }
        }

        // Filter by time
        let calendar = Calendar.current
        if isToday {
            events = events.filter { calendar.isDateInToday($0.date) }
        } else if isTomorrow {
            events = events.filter { calendar.isDateInTomorrow($0.date) }
        } else if isThisWeek {
            let weekFromNow = calendar.date(byAdding: .day, value: 7, to: Date())!
            events = events.filter { $0.date <= weekFromNow }
        }

        events = events.sorted { $0.date < $1.date }

        if events.isEmpty {
            var timeFrame = "right now"
            if isTomorrow { timeFrame = "tomorrow" }
            if isThisWeek { timeFrame = "this week" }

            let categoryName = targetCategory?.rawValue.lowercased() ?? "sessions"

            let content = """
            **No \(categoryName) available \(timeFrame)** 📅

            Would you like me to:
            1. Check a different time
            2. Show all upcoming availability
            3. Add you to the waitlist

            Just let me know!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        let eventsToShow = Array(events.prefix(4))
        let invites = eventsToShow.map { EventInvite.from(event: $0) }

        var timeFrame = ""
        if isToday { timeFrame = "today" }
        else if isTomorrow { timeFrame = "tomorrow" }
        else if isThisWeek { timeFrame = "this week" }
        else { timeFrame = "coming up" }

        let categoryName = targetCategory?.rawValue ?? "Sessions"

        let content = """
        **\(categoryName) Available \(timeFrame.capitalized)** 📅

        Here's what's open:
        """

        return ChatMessage(
            content: content,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    // MARK: Booking with Specific Staff

    private func handleBookingWithSpecificStaff(_ query: String) -> ChatMessage? {
        // Look for staff names in the query
        for staff in allStaffMembers {
            let firstName = staff.name.split(separator: " ").first?.lowercased() ?? ""
            let fullNameLower = staff.name.lowercased()

            if query.contains(firstName) || query.contains(fullNameLower) {
                return handleBookingWithStaffMember(staff)
            }
        }
        return nil
    }

    private func handleBookingWithStaffMember(_ staff: StaffInfo) -> ChatMessage {
        // Find events with this staff member
        let events = ClubEvent.sampleEvents.filter { event in
            event.date > Date() &&
            event.spotsLeft > 0 &&
            (event.details?.staff?.contains { $0.name == staff.name } ?? false)
        }.sorted { $0.date < $1.date }

        if events.isEmpty {
            let content = """
            **\(staff.name)** doesn't have any open slots right now.

            **Their specialties:** \(staff.specialties.joined(separator: ", "))

            Would you like me to:
            1. Add you to \(staff.name.split(separator: " ").first ?? "their")'s waitlist
            2. Show other \(staff.role.lowercased())s available
            3. Check a different date

            Just let me know!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        let eventsToShow = Array(events.prefix(4))
        let invites = eventsToShow.map { EventInvite.from(event: $0) }

        let content = """
        **\(staff.name)'s Available Sessions** ✨

        **Role:** \(staff.role)
        **Specialties:** \(staff.specialties.joined(separator: ", "))

        Tap a session to book:
        """

        return ChatMessage(
            content: content,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    // MARK: Category Booking Queries

    private func handleCategoryBookingQuery(_ query: String) -> ChatMessage? {
        // Spa bookings
        if isSpaBookingQuery(query) {
            return handleGeneralSpaBookingQuery(query)
        }

        // Fitness bookings
        if isFitnessBookingQuery(query) {
            return handleFitnessBookingQuery(query)
        }

        // Yoga/Wellness bookings
        if isWellnessBookingQuery(query) {
            return handleWellnessBookingQuery(query)
        }

        return nil
    }

    private func isFitnessBookingQuery(_ query: String) -> Bool {
        let indicators = ["book a training", "book training", "personal training", "book a workout",
                         "schedule training", "want a trainer", "need a trainer", "book gym",
                         "fitness session", "book a session with a trainer", "hiit class", "book hiit"]
        return indicators.contains { query.contains($0) }
    }

    private func handleFitnessBookingQuery(_ query: String) -> ChatMessage {
        let fitnessEvents = ClubEvent.events(forCategory: .fitness)
            .filter { $0.date > Date() && $0.spotsLeft > 0 }
            .sorted { $0.date < $1.date }

        if fitnessEvents.isEmpty {
            return ChatMessage(
                content: "Our fitness sessions are fully booked at the moment. Would you like me to add you to the waitlist?",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
        }

        let eventsToShow = Array(fitnessEvents.prefix(4))
        let invites = eventsToShow.map { EventInvite.from(event: $0) }

        let content = """
        **Fitness Sessions Available** 🏋️

        Here are the available training sessions:

        Tap a card to book, or say "book with [trainer name]" for a specific trainer!
        """

        return ChatMessage(
            content: content,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    private func isWellnessBookingQuery(_ query: String) -> Bool {
        let indicators = ["book yoga", "book a yoga", "yoga class", "yoga session", "schedule yoga",
                         "meditation class", "book meditation", "wellness session", "mindfulness"]
        return indicators.contains { query.contains($0) }
    }

    private func handleWellnessBookingQuery(_ query: String) -> ChatMessage {
        let wellnessEvents = ClubEvent.events(forCategory: .wellness)
            .filter { $0.date > Date() && $0.spotsLeft > 0 }
            .sorted { $0.date < $1.date }

        if wellnessEvents.isEmpty {
            return ChatMessage(
                content: "Our wellness sessions are fully booked at the moment. Would you like me to add you to the waitlist?",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
        }

        let eventsToShow = Array(wellnessEvents.prefix(4))
        let invites = eventsToShow.map { EventInvite.from(event: $0) }

        let content = """
        **Wellness Sessions Available** 🧘

        Here are the available yoga and wellness sessions:

        Tap a card to book, or say "book with [instructor name]" for a specific instructor!
        """

        return ChatMessage(
            content: content,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    // MARK: - Spa & Wellness Booking (Legacy support)

    private func handleSpaBookingQuery(_ content: String) -> ChatMessage? {
        let lowercased = content.lowercased()

        // Check for booking with specific therapist
        if let therapistBooking = handleTherapistBookingQuery(lowercased) {
            return therapistBooking
        }

        // Check for general spa booking queries
        if isSpaBookingQuery(lowercased) {
            return handleGeneralSpaBookingQuery(lowercased)
        }

        // Check for my schedule/appointments queries
        if isMyScheduleQuery(lowercased) {
            return handleMyScheduleQuery()
        }

        return nil
    }

    private func isSpaBookingQuery(_ query: String) -> Bool {
        let bookingIndicators = ["book a massage", "book massage", "book a facial", "book facial",
                                  "book a treatment", "book treatment", "schedule a massage",
                                  "schedule massage", "get a massage", "want a massage",
                                  "need a massage", "book spa", "spa appointment",
                                  "book a spa", "can i get a massage", "can i book a massage"]
        return bookingIndicators.contains { query.contains($0) }
    }

    private func handleTherapistBookingQuery(_ query: String) -> ChatMessage? {
        // Look for patterns like "book with Lucia" or "massage with Andrei"
        let therapistNames = ["lucia", "andrei", "marcus", "sophie", "elena", "maya", "mike", "jessica"]

        for name in therapistNames {
            if query.contains(name) || query.contains("with \(name)") {
                return handleBookingWithTherapist(name.capitalized)
            }
        }

        return nil
    }

    private func handleBookingWithTherapist(_ therapistName: String) -> ChatMessage {
        // Find spa events with this therapist
        let spaEvents = ClubEvent.events(forCategory: .spa)
            .filter { event in
                event.details?.staff?.contains { $0.name.lowercased().contains(therapistName.lowercased()) } ?? false
            }
            .filter { $0.date > Date() && $0.spotsLeft > 0 }

        if spaEvents.isEmpty {
            // Therapist not available, show general availability
            let content = """
            **\(therapistName)** doesn't have any open slots right now.

            Would you like me to:
            1. Show you other therapists' availability
            2. Add you to \(therapistName)'s waitlist
            3. Check a different date

            Just let me know!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Show available slots with this therapist
        let eventsToShow = Array(spaEvents.prefix(3))
        let invites = eventsToShow.map { EventInvite.from(event: $0) }

        var content = """
        **\(therapistName)'s Available Sessions** 💆

        Here are the upcoming times with \(therapistName):
        """

        for event in eventsToShow {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
            content += "\n• \(event.title) - \(formatter.string(from: event.date))"
        }

        content += "\n\nTap an event card below to book, or say \"book the first one\"!"

        return ChatMessage(
            content: content,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    private func handleGeneralSpaBookingQuery(_ query: String) -> ChatMessage {
        // Check what type of treatment they want
        var treatmentType = "massage"
        if query.contains("facial") {
            treatmentType = "facial"
        } else if query.contains("couples") {
            treatmentType = "couples"
        } else if query.contains("hot stone") {
            treatmentType = "hot stone"
        } else if query.contains("cbd") || query.contains("recovery") {
            treatmentType = "cbd recovery"
        }

        // Find matching spa events
        let spaEvents = ClubEvent.events(forCategory: .spa)
            .filter { $0.date > Date() && $0.spotsLeft > 0 }
            .filter { event in
                event.title.lowercased().contains(treatmentType) ||
                event.description.lowercased().contains(treatmentType)
            }
            .sorted { $0.date < $1.date }

        if spaEvents.isEmpty {
            // No matching treatments, show all spa options
            let allSpa = ClubEvent.events(forCategory: .spa)
                .filter { $0.date > Date() && $0.spotsLeft > 0 }
                .sorted { $0.date < $1.date }

            if allSpa.isEmpty {
                return ChatMessage(
                    content: "Our spa is fully booked at the moment. Would you like me to add you to the waitlist?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }

            let invites = Array(allSpa.prefix(4)).map { EventInvite.from(event: $0) }
            return ChatMessage(
                content: "I don't have \(treatmentType) treatments available right now, but here are our other spa options:",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date(),
                eventInvites: invites
            )
        }

        // Show available treatments
        let eventsToShow = Array(spaEvents.prefix(4))
        let invites = eventsToShow.map { EventInvite.from(event: $0) }

        // Get therapist info for the first event
        var therapistInfo = ""
        if let firstEvent = eventsToShow.first,
           let staff = firstEvent.details?.staff,
           let therapist = staff.first(where: { $0.role == .massageTherapist || $0.role == .esthetician }) {
            therapistInfo = "\n\n**Your therapist:** \(therapist.name)"
            if let specialties = therapist.specialties, !specialties.isEmpty {
                therapistInfo += " - Specializes in \(specialties.prefix(2).joined(separator: ", "))"
            }
        }

        let content = """
        **Spa Appointments Available** 💆‍♀️

        Here are the \(treatmentType) treatments available:\(therapistInfo)

        Tap a card to book, or say "book with [therapist name]" for a specific therapist!
        """

        return ChatMessage(
            content: content,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    private func handleMyScheduleQuery() -> ChatMessage {
        let eventManager = EventManager.shared
        let myEvents = eventManager.mySchedule.filter { $0.date > Date() }
        let reservations = eventManager.activeReservations

        if myEvents.isEmpty && reservations.isEmpty {
            let content = """
            **Your Schedule** 📅

            You don't have any upcoming events or reservations.

            Would you like me to help you:
            • Book a **spa treatment**
            • Reserve a **cabana**
            • Sign up for an **event**

            Just ask!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        var content = "**Your Upcoming Schedule** 📅\n"

        // Show events
        if !myEvents.isEmpty {
            content += "\n**Events:**\n"
            for event in myEvents.prefix(5) {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
                content += "• \(event.title) - \(formatter.string(from: event.date))\n"

                // Add therapist/trainer info
                if let staff = event.details?.staff?.first {
                    content += "  👤 \(staff.name) (\(staff.role.rawValue))\n"
                }
            }
        }

        // Show reservations
        if !reservations.isEmpty {
            content += "\n**Reservations:**\n"
            for reservation in reservations.prefix(5) {
                content += "• \(reservation.title) - \(reservation.formattedDate) at \(reservation.formattedTime)\n"
            }
        }

        content += "\nSay \"cancel [event name]\" to cancel, or \"tell me about [event]\" for details."

        let invites = Array(myEvents.prefix(3)).map { EventInvite.from(event: $0) }

        return ChatMessage(
            content: content,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites.isEmpty ? nil : invites
        )
    }

    // MARK: - Locker Queries

    private func isLockerQuery(_ query: String) -> Bool {
        return query.contains("locker") || query.contains("my stuff") || query.contains("my belongings") ||
               query.contains("locker code") || query.contains("locker number")
    }

    private func handleLockerQuery() -> ChatMessage {
        let clubAccess = ClubAccessService.shared

        if let locker = clubAccess.currentLocker {
            let expiryText: String
            if let expires = locker.expiresAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                expiryText = "Expires at \(formatter.string(from: expires))"
            } else {
                expiryText = "No expiration set"
            }

            let content = """
            **Your Locker:** \(locker.displayNumber)
            📍 **Location:** \(locker.floor), Section \(locker.section)
            🔐 **Code:** \(locker.accessCode)
            ⏰ **\(expiryText)**

            Need to extend your locker time or release it?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        } else {
            let content = """
            You don't have an active locker right now.

            **Locker Rooms Available:**
            • Main Floor - Section A & B
            • Upper Floor - Section A & B

            Would you like me to assign you a locker? They're complimentary and include toiletries and fresh towels!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }
    }

    private func isValetQuery(_ query: String) -> Bool {
        return query.contains("valet") || query.contains("my car") || query.contains("parking") ||
               query.contains("get my car") || query.contains("car ready") || query.contains("vehicle")
    }

    private func handleValetQuery() -> ChatMessage {
        let clubAccess = ClubAccessService.shared

        if let valet = clubAccess.valetRequest {
            let content = """
            **Valet Status:** \(valet.status.rawValue)
            🚗 **Vehicle:** \(valet.vehicleInfo.displayName)
            🎫 **Ticket:** \(valet.ticketNumber)
            \(valet.assignedValet != nil ? "👤 **Valet:** \(valet.assignedValet!)" : "")

            I'll notify you as soon as your car is ready at the entrance!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        } else {
            let content = """
            **Valet Service** is complimentary for all members! 🚗

            **Options:**
            • **Request your car** - I'll have it brought to the entrance
            • **Notify arrival** - Let us know you're on your way

            Would you like me to request your car or notify the valet of your arrival?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }
    }

    private func handleAmenityQuery(_ query: String) -> ChatMessage? {
        // Fitness/Gym
        if query.contains("fitness") || query.contains("gym") || query.contains("workout") || query.contains("train") {
            let content = """
            **Fitness Center** 🏋️

            • **Hours:** 24/7 with your membership card
            • **Equipment:** Full weight room, cardio machines, Peloton bikes
            • **Services:** Personal training (by appointment)
            • **Post-Workout:** Smoothie bar & recovery lounge

            Would you like to book a personal training session?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Spa
        if query.contains("spa") || query.contains("massage") || query.contains("facial") || query.contains("wellness") || query.contains("relax") {
            let content = """
            **Spa & Wellness** 💆

            • **Massages:** Swedish, deep tissue, hot stone
            • **Facials:** Signature treatments & anti-aging
            • **Recovery:** Cryotherapy, compression therapy
            • **Relaxation:** Sauna, steam room, quiet lounge

            Next availability is tomorrow at 2PM. Shall I book a treatment?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Pool
        if query.contains("pool") || query.contains("swim") || query.contains("cabana") {
            let weather = WeatherService.shared.currentWeather
            let weatherNote = weather != nil ? " Current temp: \(Int(weather!.temperature))°F - \(weather!.temperature >= 75 ? "perfect pool weather!" : "still nice with our heated pool!")" : ""

            let content = """
            **Pool Deck** 🏊

            • **Hours:** 8AM - Sunset daily
            • **Features:** Heated infinity pool, panoramic views
            • **Cabanas:** Private cabanas with bottle service
            • **Service:** Full poolside food & drink menu
            \(weatherNote)

            Would you like to reserve a cabana?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Rooftop
        if query.contains("rooftop") || query.contains("roof") {
            let content = """
            **Rooftop Bar** 🌴

            • **Hours:** 4PM - Close (DJ on weekends)
            • **Views:** Panoramic Miami Beach skyline
            • **Menu:** Craft cocktails, wine, light bites
            • **Vibe:** Lounge seating, fire pits, sunset views

            Tables are available - would you like me to reserve one?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Hours
        if query.contains("hours") || query.contains("open") || query.contains("close") {
            let content = """
            **Clubhouse Hours** 🕐

            • **Mon-Thu:** 10AM - 11PM
            • **Fri-Sat:** 10AM - 2AM
            • **Sunday:** 11AM - 10PM

            **Special Hours:**
            • Fitness Center: 24/7
            • Pool Deck: 8AM - Sunset
            • Spa: 9AM - 9PM

            We're currently open! Anything I can help you with?
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Dress code
        if query.contains("dress code") || (query.contains("what") && query.contains("wear")) {
            let content = """
            **Dress Code** 👔

            • **General:** Upscale casual (smart casual minimum)
            • **Main Dining:** No athletic wear; jackets suggested for private dining
            • **Rooftop Bar:** Miami chic - look sharp!
            • **Pool/Gym:** Athletic & swim attire welcome in those areas

            Basically - look good, feel good. We want you comfortable but polished!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        // Location/Address
        if query.contains("address") || query.contains("location") || query.contains("where") || query.contains("direction") {
            let content = """
            **Location** 📍

            **BAYC Miami Clubhouse**
            1901 Collins Avenue
            Miami Beach, FL 33139

            • Near South Beach, 5 min from Lincoln Road
            • Complimentary valet at main entrance
            • Uber/Lyft drop-off available

            Planning your visit? I can notify valet you're on your way!
            """
            return ChatMessage(content: content, isFromUser: false, senderType: .ai, timestamp: Date())
        }

        return nil
    }

    // MARK: - Context Detection Helpers

    private func isContextSwitchTrigger(_ query: String) -> Bool {
        // Phrases that indicate switching to a new event context
        let switchPhrases = [
            "how about", "what about", "show me", "switch to",
            "let's see", "tell me about", "looking for"
        ]

        let categoryWords = ["spa", "fitness", "dining", "wellness", "social", "party", "exclusive", "vip"]

        for phrase in switchPhrases {
            if query.contains(phrase) {
                for category in categoryWords {
                    if query.contains(category) {
                        return true
                    }
                }
                // Also check for "events" keyword
                if query.contains("event") {
                    return true
                }
            }
        }

        return false
    }

    private func isWeatherFollowUp(_ query: String) -> Bool {
        let weatherWords = ["weather", "rain", "umbrella", "temperature", "hot", "cold", "outside"]
        return weatherWords.contains { query.contains($0) }
    }

    private func isSpotsFollowUp(_ query: String) -> Bool {
        let spotsWords = ["spot", "slot", "space", "room", "full", "available", "capacity", "sold out", "left"]
        return spotsWords.contains { query.contains($0) }
    }

    private func isTimeFollowUp(_ query: String) -> Bool {
        let timeWords = ["when", "what time", "time", "start", "begin", "schedule"]
        return timeWords.contains { query.contains($0) }
    }

    private func isLocationFollowUp(_ query: String) -> Bool {
        let locationWords = ["where", "location", "place", "venue", "floor", "room"]
        return locationWords.contains { query.contains($0) }
    }

    private func isMoreInfoFollowUp(_ query: String) -> Bool {
        let infoWords = ["more", "detail", "info", "about", "describe", "explain"]
        return infoWords.contains { query.contains($0) } && !query.contains("event")
    }

    private func isRSVPFollowUp(_ query: String) -> Bool {
        let rsvpWords = ["rsvp", "sign me up", "add me", "book", "reserve", "join", "attend", "going", "i'm in", "im in", "count me in"]
        return rsvpWords.contains { query.contains($0) }
    }

    private func isShowMoreFollowUp(_ query: String) -> Bool {
        let showMoreWords = ["show more", "what else", "other", "another", "more events", "next one", "any others"]
        return showMoreWords.contains { query.contains($0) }
    }

    // MARK: - Detailed Event Query Detection

    private func isStaffQuery(_ query: String) -> Bool {
        let staffWords = ["who is", "who's", "trainer", "instructor", "teacher", "masseuse", "massage therapist",
                          "esthetician", "chef", "sommelier", "dj", "bartender", "mixologist", "host",
                          "leading", "teaching", "running", "conducting", "my therapist", "my trainer"]
        return staffWords.contains { query.contains($0) }
    }

    private func isFoodQuery(_ query: String) -> Bool {
        let foodWords = ["food", "eat", "meal", "menu", "dining", "appetizer", "snack", "drink", "beverage",
                         "open bar", "wine", "cocktail", "champagne", "refreshment", "catering",
                         "will there be food", "is food included", "what's to eat", "what to eat"]
        return foodWords.contains { query.contains($0) }
    }

    private func isArtworkQuery(_ query: String) -> Bool {
        let artWords = ["artwork", "art", "artist", "painting", "sculpture", "exhibit", "exhibition",
                        "piece", "collection", "gallery", "who's showing", "featured artist",
                        "what art", "which artist", "what will be shown"]
        return artWords.contains { query.contains($0) }
    }

    private func isDressCodeQuery(_ query: String) -> Bool {
        let dressWords = ["wear", "dress code", "dress", "outfit", "attire", "clothing", "what to wear",
                          "should i wear", "dress up", "casual", "formal", "bring"]
        return dressWords.contains { query.contains($0) }
    }

    private func isIncludedQuery(_ query: String) -> Bool {
        let includedWords = ["included", "include", "what's included", "comes with", "get with",
                             "part of", "provided", "complimentary", "free"]
        return includedWords.contains { query.contains($0) }
    }

    // MARK: - Context Follow-Up Handlers

    private func handleWeatherFollowUp(_ query: String) -> ChatMessage? {
        guard let event = context.currentEvent else { return nil }

        let forecast = WeatherService.shared.forecast
        let eventDateForecast = forecast.first { Calendar.current.isDate($0.date, inSameDayAs: event.date) }

        var weatherInfo: String
        if let dayForecast = eventDateForecast {
            let isRainy = dayForecast.icon.contains("09") || dayForecast.icon.contains("10") || dayForecast.icon.contains("11")
            weatherInfo = "For **\(event.title)** on \(formatEventDateWithTime(event.date)):\n\n"
            weatherInfo += "\(dayForecast.description), High \(dayForecast.high)°F, Low \(dayForecast.low)°F"

            if isRainy {
                weatherInfo += "\n\nI'd recommend bringing an umbrella just in case!"
            } else if dayForecast.high > 85 {
                weatherInfo += "\n\nIt'll be warm - dress light and stay hydrated!"
            } else {
                weatherInfo += "\n\nLooks like great weather for the event!"
            }
        } else {
            weatherInfo = "The forecast for **\(event.title)** isn't available yet (it's more than 5 days out), but I'll have it closer to the date!"
        }

        return ChatMessage(
            content: weatherInfo,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    private func handleSpotsFollowUp() -> ChatMessage? {
        guard let event = context.currentEvent else { return nil }

        let spotsMessage: String
        if event.spotsLeft == 0 {
            spotsMessage = "**\(event.title)** is currently full! Would you like me to add you to the waitlist?"
        } else if event.spotsLeft <= 5 {
            spotsMessage = "There are only **\(event.spotsLeft) spots left** for \(event.title)! I'd recommend RSVPing soon."
        } else {
            spotsMessage = "There are **\(event.spotsLeft) spots available** for \(event.title). Would you like me to reserve one for you?"
        }

        return ChatMessage(
            content: spotsMessage,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    private func handleTimeFollowUp() -> ChatMessage? {
        guard let event = context.currentEvent else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d 'at' h:mm a"
        let timeString = formatter.string(from: event.date)

        let message = "**\(event.title)** is scheduled for **\(timeString)**."

        return ChatMessage(
            content: message,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    private func handleLocationFollowUp() -> ChatMessage? {
        guard let event = context.currentEvent else { return nil }

        var message = "**\(event.title)** will be held at **\(event.location)**"

        if let detail = event.locationDetail {
            message += " (\(detail))"
        }

        message += ". Need directions when you arrive? Just ask!"

        return ChatMessage(
            content: message,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    private func handleMoreInfoFollowUp() -> ChatMessage? {
        guard let event = context.currentEvent else { return nil }

        var message = "Here's more about **\(event.title)**:\n\n"
        message += event.description
        message += "\n\n**When:** \(formatEventDateWithTime(event.date))"
        message += "\n**Where:** \(event.location)"
        message += "\n**Spots left:** \(event.spotsLeft)"

        if event.requiresTokenProof {
            message += "\n**Note:** This event requires TokenProof verification."
        }

        // Return with event card for easy RSVP
        return ChatMessage(
            content: message,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvite: EventInvite.from(event: event)
        )
    }

    private func handleRSVPFollowUp() -> ChatMessage? {
        guard let event = context.currentEvent else { return nil }

        // Actually add to schedule
        EventManager.shared.addToSchedule(event)

        return ChatMessage(
            content: "You're all set! I've added **\(event.title)** to your schedule. See you there!",
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvite: EventInvite.from(event: event)
        )
    }

    private func handleShowMoreFollowUp() -> ChatMessage? {
        // If we have a category context, show more from that category
        if let category = context.currentCategory {
            let allCategoryEvents = ClubEvent.events(forCategory: category)
                .filter { $0.date > Date() }
                .sorted { $0.date < $1.date }

            // Get events not yet shown (or all if none shown)
            let shownEventIds = Set(context.currentEvents?.map { $0.id } ?? [])
            let remainingEvents = allCategoryEvents.filter { !shownEventIds.contains($0.id) }

            if !remainingEvents.isEmpty {
                let eventsToShow = Array(remainingEvents.prefix(3))
                let invites = eventsToShow.map { EventInvite.from(event: $0) }

                // Update context with new events
                context.setEvents(eventsToShow, category: category)

                return ChatMessage(
                    content: "Here are more **\(category.rawValue)** events:",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            } else {
                return ChatMessage(
                    content: "That's all the \(category.rawValue.lowercased()) events we have coming up! Would you like to see a different category?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
        }

        return nil
    }

    // MARK: - Detailed Event Query Handlers

    private func handleStaffQuery() -> ChatMessage? {
        guard let event = context.currentEvent, let details = event.details, let staff = details.staff, !staff.isEmpty else {
            return nil
        }

        var message = "Here's who'll be taking care of you at **\(event.title)**:\n\n"

        for member in staff {
            message += "**\(member.name)** - \(member.role.rawValue)\n"
            if let bio = member.bio {
                message += "\(bio)\n"
            }
            if let specialties = member.specialties, !specialties.isEmpty {
                message += "Specialties: \(specialties.joined(separator: ", "))\n"
            }
            if let certs = member.certifications, !certs.isEmpty {
                message += "Credentials: \(certs.joined(separator: ", "))\n"
            }
            message += "\n"
        }

        return ChatMessage(
            content: message.trimmingCharacters(in: .whitespacesAndNewlines),
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    private func handleFoodQuery() -> ChatMessage? {
        guard let event = context.currentEvent, let details = event.details, let food = details.foodAndBeverage else {
            if let event = context.currentEvent {
                return ChatMessage(
                    content: "I don't have specific food details for **\(event.title)**, but I'd be happy to ask the events team for you. Would you like me to connect you with them?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
            return nil
        }

        var message = "Here's what's on the menu for **\(event.title)**:\n\n"

        if let description = food.description {
            message += "\(description)\n\n"
        }

        if let highlights = food.menuHighlights, !highlights.isEmpty {
            message += "**Menu Highlights:**\n"
            for item in highlights {
                message += "• \(item)\n"
            }
            message += "\n"
        }

        if let beverages = food.beverages, !beverages.isEmpty {
            message += "**Beverages:**\n"
            for drink in beverages {
                message += "• \(drink)\n"
            }
            if food.isOpenBar {
                message += "*(Open bar included!)*\n"
            }
            message += "\n"
        }

        if let dietary = food.dietaryOptions, !dietary.isEmpty {
            message += "**Dietary Options:** \(dietary.joined(separator: ", "))\n"
        }

        if food.isIncluded {
            message += "\n*All food and beverages are included with your reservation.*"
        }

        return ChatMessage(
            content: message.trimmingCharacters(in: .whitespacesAndNewlines),
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    private func handleArtworkQuery() -> ChatMessage? {
        guard let event = context.currentEvent, let details = event.details, let artwork = details.artwork else {
            if let event = context.currentEvent {
                return ChatMessage(
                    content: "I don't have specific artwork details for **\(event.title)**. Would you like me to connect you with our art curator for more information?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
            return nil
        }

        var message = ""

        if let exhibitionName = artwork.exhibitionName {
            message += "**\(exhibitionName)**\n\n"
        }

        if let curatorNotes = artwork.curatorNotes {
            message += "\(curatorNotes)\n\n"
        }

        if let artists = artwork.artists, !artists.isEmpty {
            message += "**Featured Artists:**\n"
            for artist in artists {
                message += "• **\(artist.name)**"
                if let handle = artist.socialHandle {
                    message += " (\(handle))"
                }
                message += "\n"
                if let bio = artist.bio {
                    message += "  \(bio)\n"
                }
            }
            message += "\n"
        }

        if let featured = artwork.featuredPieces, !featured.isEmpty {
            message += "**Featured Pieces:**\n"
            for piece in featured {
                message += "• *\(piece.title)* by \(piece.artist) (\(piece.medium))\n"
                if let description = piece.description {
                    message += "  \(description)\n"
                }
                if let value = piece.estimatedValue {
                    message += "  Estimated value: \(value)\n"
                }
            }
            message += "\n"
        }

        if let count = artwork.artworkCount {
            message += "**Total pieces on display:** \(count)\n"
        }

        if let mediums = artwork.mediums, !mediums.isEmpty {
            message += "**Mediums:** \(mediums.joined(separator: ", "))"
        }

        return ChatMessage(
            content: message.trimmingCharacters(in: .whitespacesAndNewlines),
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    private func handleDressCodeQuery() -> ChatMessage? {
        guard let event = context.currentEvent, let details = event.details else {
            return nil
        }

        var message = "For **\(event.title)**:\n\n"

        if let dressCode = details.dressCode {
            message += "**Dress Code:** \(dressCode)\n\n"
        }

        if let whatToBring = details.whatToBring, !whatToBring.isEmpty {
            message += "**What to Bring:**\n"
            for item in whatToBring {
                message += "• \(item)\n"
            }
        }

        if let notes = details.specialNotes {
            message += "\n**Note:** \(notes)"
        }

        if message == "For **\(event.title)**:\n\n" {
            return ChatMessage(
                content: "I don't have specific dress code info for **\(event.title)**, but I'd recommend smart casual for most clubhouse events. Want me to check with the events team?",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
        }

        return ChatMessage(
            content: message.trimmingCharacters(in: .whitespacesAndNewlines),
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    private func handleIncludedQuery() -> ChatMessage? {
        guard let event = context.currentEvent, let details = event.details else {
            return nil
        }

        var message = "Here's what's included with **\(event.title)**:\n\n"

        if let included = details.includedItems, !included.isEmpty {
            for item in included {
                message += "• \(item)\n"
            }
        }

        if let food = details.foodAndBeverage, food.isIncluded {
            if let foodDesc = food.description {
                message += "• \(foodDesc)\n"
            }
            if food.isOpenBar {
                message += "• Premium open bar\n"
            }
        }

        if message == "Here's what's included with **\(event.title)**:\n\n" {
            return ChatMessage(
                content: "I don't have a detailed inclusions list for **\(event.title)**. Would you like me to get that information from the events team?",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
        }

        return ChatMessage(
            content: message.trimmingCharacters(in: .whitespacesAndNewlines),
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
    }

    // MARK: - Weather Context Helper

    /// Builds comprehensive weather context for Claude to use intelligently.
    /// Always provides current conditions so Claude can naturally incorporate weather
    /// into responses about activities, recommendations, what to wear, etc.
    private func buildComprehensiveWeatherContext(for query: String) -> String {
        let lowercased = query.lowercased()
        var context = WeatherService.shared.getWeatherSummary()

        // Determine if this is likely a weather-focused query for additional context
        let weatherFocusedIndicators = [
            // Direct weather words
            "weather", "temperature", "forecast", "rain", "sunny", "cloudy", "storm",
            // Clothing/preparation
            "umbrella", "jacket", "coat", "sweater", "dress", "wear", "bring",
            // Outdoor activities
            "outside", "outdoor", "pool", "rooftop", "deck", "terrace", "patio", "beach",
            // Comfort questions
            "hot", "cold", "warm", "humid", "nice out", "nice outside", "good day",
            // Informal queries
            "how's it", "what's it like", "looking out", "step out"
        ]

        let isWeatherFocused = weatherFocusedIndicators.contains { lowercased.contains($0) }

        // Add extended forecast for weather-focused queries or time-specific queries
        if isWeatherFocused || lowercased.contains("week") || lowercased.contains("few days") {
            let forecast = WeatherService.shared.forecast
            if !forecast.isEmpty && !context.contains("Upcoming forecast") {
                context += "\n\n3-DAY OUTLOOK:"
                for day in forecast.prefix(3) {
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "EEEE"
                    let isRainy = day.icon.contains("09") || day.icon.contains("10") || day.icon.contains("11")
                    context += "\n• \(dayFormatter.string(from: day.date)): \(day.description), \(day.high)°F/\(day.low)°F"
                    if isRainy {
                        context += " (rain likely)"
                    }
                }
            }
        }

        // Add weekend forecast for weekend queries
        if lowercased.contains("weekend") || lowercased.contains("saturday") || lowercased.contains("sunday") {
            let forecast = WeatherService.shared.forecast
            let weekendForecast = forecast.filter { forecast in
                let weekday = Calendar.current.component(.weekday, from: forecast.date)
                return weekday == 1 || weekday == 7 // Sunday or Saturday
            }

            if !weekendForecast.isEmpty {
                context += "\n\nWEEKEND FORECAST:"
                for day in weekendForecast.prefix(2) {
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "EEEE"
                    let isRainy = day.icon.contains("09") || day.icon.contains("10") || day.icon.contains("11")
                    context += "\n• \(dayFormatter.string(from: day.date)): \(day.description), High \(day.high)°F, Low \(day.low)°F"
                    if isRainy {
                        context += " (rain expected)"
                    }
                }
            }
        }

        // Add tomorrow's forecast
        if lowercased.contains("tomorrow") {
            let forecast = WeatherService.shared.forecast
            if let tomorrow = forecast.first(where: { Calendar.current.isDateInTomorrow($0.date) }) {
                let isRainy = tomorrow.icon.contains("09") || tomorrow.icon.contains("10") || tomorrow.icon.contains("11")
                context += "\n\nTOMORROW: \(tomorrow.description), High \(tomorrow.high)°F, Low \(tomorrow.low)°F"
                if isRainy {
                    context += " (rain expected)"
                }
            }
        }

        // Add event-specific weather if asking about an event
        let eventKeywords = ["yacht", "party", "mixer", "gallery", "yoga", "event", "dinner", "brunch", "spa", "fitness", "massage"]
        for keyword in eventKeywords {
            if lowercased.contains(keyword) {
                if let event = ClubEvent.sampleEvents.first(where: { $0.title.lowercased().contains(keyword) }) {
                    let forecast = WeatherService.shared.forecast
                    if let eventDayForecast = forecast.first(where: { Calendar.current.isDate($0.date, inSameDayAs: event.date) }) {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "EEEE, MMM d"
                        let isRainy = eventDayForecast.icon.contains("09") || eventDayForecast.icon.contains("10") || eventDayForecast.icon.contains("11")
                        context += "\n\nFORECAST FOR \(event.title.uppercased()) (\(dateFormatter.string(from: event.date))): \(eventDayForecast.description), High \(eventDayForecast.high)°F, Low \(eventDayForecast.low)°F"
                        if isRainy {
                            context += " (rain expected)"
                        }
                    }
                }
                break
            }
        }

        // Add practical guidance hints for Claude
        if let weather = WeatherService.shared.currentWeather {
            context += "\n\nQUICK REFERENCE:"
            // Rain check
            if weather.icon.contains("09") || weather.icon.contains("10") || weather.icon.contains("11") {
                context += "\n• RAIN: Yes, umbrella recommended"
            } else {
                context += "\n• RAIN: No rain expected"
            }
            // Temperature comfort
            if weather.temperature >= 85 {
                context += "\n• COMFORT: Hot - light clothing, stay hydrated, pool/indoor recommended"
            } else if weather.temperature >= 75 {
                context += "\n• COMFORT: Pleasant - great for outdoor activities"
            } else if weather.temperature >= 65 {
                context += "\n• COMFORT: Mild - light layer may be nice for evening"
            } else {
                context += "\n• COMFORT: Cool - jacket recommended"
            }
            // Outdoor suitability
            let isGoodForOutdoor = !weather.icon.contains("09") && !weather.icon.contains("10") && !weather.icon.contains("11") && weather.temperature >= 65 && weather.temperature <= 90
            context += "\n• OUTDOOR ACTIVITIES: \(isGoodForOutdoor ? "Excellent conditions" : "Consider indoor alternatives")"
        }

        return context
    }

    // MARK: - Event Query Handling

    private func handleEventQuery(_ content: String) -> ChatMessage? {
        let lowercased = content.lowercased()

        // PRIORITY 0: Check for "happening soon/now" queries
        if isSoonQuery(lowercased) {
            return handleSoonEventsQuery()
        }

        // Detect if user wants ALL events of a type (not just the next one)
        _ = lowercased.contains("all ") || lowercased.contains("show me") ||
            lowercased.contains("list") || lowercased.contains("what are")

        // Detect time-based queries
        let isNextWeekQuery = lowercased.contains("next week")
        let isThisWeekQuery = lowercased.contains("this week") && !isNextWeekQuery
        let isTomorrowQuery = lowercased.contains("tomorrow")
        let isTodayQuery = lowercased.contains("today") || lowercased.contains("tonight")
        let isWeekendQuery = lowercased.contains("weekend") || lowercased.contains("saturday") || lowercased.contains("sunday")

        // PRIORITY 1: Category-specific queries - show event CARDS
        if let category = ClubEvent.detectCategory(from: lowercased) {
            let categoryEvents = ClubEvent.events(forCategory: category)
                .filter { $0.date > Date() }
                .sorted { $0.date < $1.date }

            if !categoryEvents.isEmpty {
                // Update context for follow-up queries
                context.setEvents(categoryEvents, category: category)

                // Show event cards (up to 4 for usability)
                let eventsToShow = Array(categoryEvents.prefix(4))
                let invites = eventsToShow.map { EventInvite.from(event: $0) }
                let remainingCount = categoryEvents.count - eventsToShow.count

                var message = "Here are the upcoming **\(category.rawValue)** events:"
                if remainingCount > 0 {
                    message += " (\(remainingCount) more available - say 'show more')"
                }

                return ChatMessage(
                    content: message,
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            } else {
                context.currentCategory = category
                return ChatMessage(
                    content: "We don't have any \(category.rawValue.lowercased()) events scheduled at the moment, but I can notify you when new ones are added. Would you like me to set that up?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
        }

        // PRIORITY 2: Time-based queries - show event CARDS
        if isNextWeekQuery {
            let nextWeekEvents = getEventsForNextWeek()
            if !nextWeekEvents.isEmpty {
                context.setEvents(nextWeekEvents, category: nil)
                let eventsToShow = Array(nextWeekEvents.prefix(4))
                let invites = eventsToShow.map { EventInvite.from(event: $0) }

                return ChatMessage(
                    content: "Here's everything happening **next week**:",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            } else {
                return ChatMessage(
                    content: "No events scheduled for next week yet. Check back soon or ask about this week's events!",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
        }

        if isThisWeekQuery {
            let weekEvents = ClubEvent.thisWeekEvents
            if !weekEvents.isEmpty {
                context.setEvents(weekEvents, category: nil)
                let eventsToShow = Array(weekEvents.prefix(4))
                let invites = eventsToShow.map { EventInvite.from(event: $0) }
                let remainingCount = weekEvents.count - eventsToShow.count

                var message = "Here's everything happening **this week**:"
                if remainingCount > 0 {
                    message += " (\(remainingCount) more - say 'show more')"
                }

                return ChatMessage(
                    content: message,
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            } else {
                return ChatMessage(
                    content: "No events scheduled for the rest of this week. Would you like to see what's coming up next week?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
        }

        if isWeekendQuery {
            let weekendEvents = getWeekendEvents()
            if !weekendEvents.isEmpty {
                context.setEvents(weekendEvents, category: nil)
                let invites = weekendEvents.map { EventInvite.from(event: $0) }

                return ChatMessage(
                    content: "Here's what's happening this **weekend**:",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            } else {
                return ChatMessage(
                    content: "Nothing scheduled for this weekend yet. The clubhouse is always open though! Want to book a spa treatment or reserve a table?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
        }

        if isTodayQuery {
            let todayEvents = ClubEvent.todayEvents
            if !todayEvents.isEmpty {
                context.setEvents(todayEvents, category: nil)
                let invites = todayEvents.map { EventInvite.from(event: $0) }

                return ChatMessage(
                    content: "Here's what's happening **today**:",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            } else {
                return ChatMessage(
                    content: "No events scheduled for today, but the clubhouse is open! Would you like to see what's coming up this week, or perhaps book a spa treatment?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
        }

        if isTomorrowQuery {
            let tomorrowEvents = getEventsTomorrow()
            if !tomorrowEvents.isEmpty {
                context.setEvents(tomorrowEvents, category: nil)
                let invites = tomorrowEvents.map { EventInvite.from(event: $0) }

                return ChatMessage(
                    content: "Here's what's happening **tomorrow**:",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            } else {
                return ChatMessage(
                    content: "Nothing scheduled for tomorrow. Would you like to see this week's events?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
        }

        // PRIORITY 3: "Upcoming events" / "all events" - show event CARDS
        if lowercased.contains("upcoming event") || lowercased.contains("all event") ||
           lowercased.contains("show me event") || lowercased.contains("list event") ||
           lowercased.contains("what event") {
            let upcomingEvents = ClubEvent.upcomingEvents
            if !upcomingEvents.isEmpty {
                context.setEvents(upcomingEvents, category: nil)
                let eventsToShow = Array(upcomingEvents.prefix(5))
                let invites = eventsToShow.map { EventInvite.from(event: $0) }
                let remainingCount = upcomingEvents.count - eventsToShow.count

                var message = "Here are the **upcoming events** at the clubhouse:"
                if remainingCount > 0 {
                    message += " (\(remainingCount) more - say 'show more')"
                }

                return ChatMessage(
                    content: message,
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            }
        }

        // PRIORITY 4: Specific event name queries - show single event card
        let eventKeywords = [
            ("yacht", "Yacht"),
            ("gallery", "Gallery"),
            ("mixer", "Mixer"),
            ("yoga", "Yoga"),
            ("wine", "Wine"),
            ("apefest", "ApeFest"),
            ("massage", "Massage"),
            ("meditation", "Meditation"),
            ("training", "Training"),
            ("hiit", "HIIT"),
            ("pilates", "Pilates"),
            ("facial", "Facial")
        ]

        for (keyword, eventName) in eventKeywords {
            if lowercased.contains(keyword) {
                if let event = ClubEvent.sampleEvents.first(where: {
                    $0.title.lowercased().contains(eventName.lowercased()) && $0.date > Date()
                }) {
                    // Update context for follow-up queries
                    context.setEvent(event)

                    let eventInvite = EventInvite.from(event: event)
                    let responseText = generateEventResponse(for: event)
                    return ChatMessage(
                        content: responseText,
                        isFromUser: false,
                        senderType: .ai,
                        timestamp: Date(),
                        eventInvite: eventInvite
                    )
                }
            }
        }

        // PRIORITY 5: Exclusive/VIP event queries - show event CARDS
        if lowercased.contains("exclusive") || lowercased.contains("vip") || lowercased.contains("black tier") || lowercased.contains("members only") {
            let exclusiveEvents = ClubEvent.sampleEvents
                .filter { $0.isExclusiveEvent && $0.date > Date() }
                .sorted { $0.date < $1.date }

            if !exclusiveEvents.isEmpty {
                context.setEvents(exclusiveEvents, category: .exclusive)
                let invites = exclusiveEvents.map { EventInvite.from(event: $0) }

                return ChatMessage(
                    content: "Here are the **exclusive VIP events** (TokenProof required):",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            }
        }

        // PRIORITY 6: General "event" or "what's happening" query - show next few events
        if lowercased.contains("event") || lowercased.contains("what's happening") || lowercased.contains("what is happening") {
            let upcomingEvents = ClubEvent.upcomingEvents
            if !upcomingEvents.isEmpty {
                context.setEvents(upcomingEvents, category: nil)
                let eventsToShow = Array(upcomingEvents.prefix(3))
                let invites = eventsToShow.map { EventInvite.from(event: $0) }
                let totalCount = upcomingEvents.count

                return ChatMessage(
                    content: "Here's what's coming up! We have **\(totalCount) total events** - tap any card for details or say 'show more'.",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            }
        }

        // PRIORITY 7: Concierge services query
        if lowercased.contains("service") || lowercased.contains("concierge") || lowercased.contains("help me") {
            context.clear() // Clear context for service queries
            return ChatMessage(
                content: "I can help you with a variety of services:\n\n• **Events** - 'show me events' or 'spa events'\n• **Follow-ups** - Ask about weather, spots left, or RSVP after I show an event\n• **Weather** - Current conditions and forecasts\n• **Human Concierge** - Connect with your relationship manager\n\nJust let me know what you need!",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
        }

        // PRIORITY 8: Dining/reservation queries - show event CARDS
        if lowercased.contains("dining") || lowercased.contains("restaurant") || lowercased.contains("table") || lowercased.contains("reservation") {
            let diningEvents = ClubEvent.sampleEvents.filter { $0.category == .dining && $0.date > Date() }.sorted { $0.date < $1.date }
            if !diningEvents.isEmpty {
                context.setEvents(diningEvents, category: .dining)
                let invites = diningEvents.map { EventInvite.from(event: $0) }

                return ChatMessage(
                    content: "Here are our **dining experiences**:",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date(),
                    eventInvites: invites
                )
            } else {
                return ChatMessage(
                    content: "I'd be happy to help you with a dining reservation! Our private dining room offers an intimate experience for members. Would you like me to connect you with our reservations team?",
                    isFromUser: false,
                    senderType: .ai,
                    timestamp: Date()
                )
            }
        }

        // PRIORITY 9: Recommendation queries - smart time-of-day suggestions
        if lowercased.contains("recommend") || lowercased.contains("suggestion") || lowercased.contains("what should i do") ||
           lowercased.contains("suggest") || lowercased.contains("ideas") || lowercased.contains("what do you think") {
            return handleRecommendationQuery()
        }

        // Weather queries will be handled by ClaudeService with proper context
        // Return nil to fall through to ClaudeService
        return nil
    }

    /// Provides smart recommendations based on time of day and available events
    private func handleRecommendationQuery() -> ChatMessage? {
        let hour = Calendar.current.component(.hour, from: Date())
        let upcomingEvents = ClubEvent.upcomingEvents

        // Determine which categories to prioritize based on time of day
        var priorityCategories: [ClubEvent.EventCategory] = []
        var greeting = ""

        switch hour {
        case 5..<10:
            priorityCategories = [.wellness, .fitness, .spa]
            greeting = "Good morning! Here are some great ways to start your day"
        case 10..<14:
            priorityCategories = [.spa, .wellness, .dining]
            greeting = "Perfect time for some self-care or a nice lunch"
        case 14..<17:
            priorityCategories = [.spa, .fitness, .wellness]
            greeting = "The afternoon is ideal for relaxation or a workout"
        case 17..<21:
            priorityCategories = [.dining, .social, .exclusive]
            greeting = "Evening is here! Here are some wonderful ways to spend it"
        default:
            priorityCategories = [.party, .social, .exclusive]
            greeting = "Looking for something special tonight?"
        }

        // Get events from priority categories
        var recommendedEvents: [ClubEvent] = []
        for category in priorityCategories {
            let categoryEvents = upcomingEvents.filter { $0.category == category }
            recommendedEvents.append(contentsOf: categoryEvents.prefix(2))
        }

        // If not enough priority events, add other upcoming events
        if recommendedEvents.count < 3 {
            let recommendedIds = Set(recommendedEvents.map { $0.id })
            let otherEvents = upcomingEvents.filter { !recommendedIds.contains($0.id) }
            recommendedEvents.append(contentsOf: otherEvents.prefix(3 - recommendedEvents.count))
        }

        // Remove duplicates and limit to 4
        var seen = Set<UUID>()
        recommendedEvents = recommendedEvents.filter { seen.insert($0.id).inserted }
        recommendedEvents = Array(recommendedEvents.prefix(4))

        if recommendedEvents.isEmpty {
            return ChatMessage(
                content: "\(greeting), but I don't see any events matching that timeframe. The clubhouse amenities are always open though! Would you like to book a spa treatment or make a dining reservation?",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
        }

        context.setEvents(recommendedEvents, category: nil)
        let invites = recommendedEvents.map { EventInvite.from(event: $0) }

        return ChatMessage(
            content: "\(greeting):",
            isFromUser: false,
            senderType: .ai,
            timestamp: Date(),
            eventInvites: invites
        )
    }

    // MARK: - Event Query Helpers

    private func getEventsForNextWeek() -> [ClubEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: today),
              let nextWeekEnd = calendar.date(byAdding: .day, value: 7, to: nextWeekStart) else {
            return []
        }

        return ClubEvent.sampleEvents
            .filter { $0.date >= nextWeekStart && $0.date < nextWeekEnd }
            .sorted { $0.date < $1.date }
    }

    private func getWeekendEvents() -> [ClubEvent] {
        let calendar = Calendar.current
        let today = Date()

        // Find this weekend (or next if past Friday)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 7 // Saturday
        guard let saturday = calendar.date(from: components) else { return [] }

        let friday = calendar.date(byAdding: .day, value: -1, to: saturday)!
        let sunday = calendar.date(byAdding: .day, value: 1, to: saturday)!
        let mondayMorning = calendar.date(byAdding: .day, value: 2, to: saturday)!

        // If we're past Sunday, get next weekend
        let weekendStart = today > sunday ? calendar.date(byAdding: .day, value: 7, to: friday)! : friday
        let weekendEnd = today > sunday ? calendar.date(byAdding: .day, value: 7, to: mondayMorning)! : mondayMorning

        return ClubEvent.sampleEvents
            .filter { $0.date >= weekendStart && $0.date < weekendEnd }
            .sorted { $0.date < $1.date }
    }

    private func getEventsTomorrow() -> [ClubEvent] {
        let calendar = Calendar.current
        return ClubEvent.sampleEvents.filter {
            calendar.isDateInTomorrow($0.date)
        }.sorted { $0.date < $1.date }
    }

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func formatEventDateWithTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        }
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func generateEventResponse(for event: ClubEvent) -> String {
        var response = "Great choice! Here are the details for the \(event.title)."

        if event.requiresTokenProof {
            response += " This is an exclusive event that requires TokenProof verification."
        }

        if event.spotsLeft <= 5 {
            response += " Only \(event.spotsLeft) spots left - I'd recommend RSVPing soon!"
        }

        return response
    }

    // MARK: - Event Invite Functions

    func sendEventInvite(for event: ClubEvent, from senderType: ChatMessage.SenderType = .ai) {
        let eventInvite = EventInvite.from(event: event)
        let content = senderType == .ai
            ? "I found an event you might be interested in! Here are the details:"
            : "I've reserved a spot for you at this exclusive event. Here's your invitation:"

        let message = ChatMessage(
            content: content,
            isFromUser: false,
            senderType: senderType,
            timestamp: Date(),
            eventInvite: eventInvite
        )
        messages.append(message)
        conversationHistory.append((role: "assistant", content: content))

        if isMinimized {
            unreadCount += 1
        }
    }

    func addEventToSchedule(eventId: UUID) {
        EventManager.shared.addToSchedule(ClubEvent.sampleEvents.first { $0.id == eventId }!)
    }

    private func addAIResponse(_ response: String) {
        let aiMessage = ChatMessage(
            content: response,
            isFromUser: false,
            senderType: .ai,
            timestamp: Date()
        )
        messages.append(aiMessage)

        // Add to conversation history
        conversationHistory.append((role: "assistant", content: response))

        // Keep conversation history manageable (last 10 exchanges)
        if conversationHistory.count > 20 {
            conversationHistory.removeFirst(2)
        }

        // If minimized, increment unread count
        if isMinimized {
            unreadCount += 1
        }
    }

    private func handleHumanRequest() {
        isTyping = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isTyping = false

            let aiMessage = ChatMessage(
                content: "Absolutely! I'm connecting you with Sarah Chen, your dedicated relationship manager. She'll reach out to you in your inbox shortly. In the meantime, is there anything else I can help with?",
                isFromUser: false,
                senderType: .ai,
                timestamp: Date()
            )
            self?.messages.append(aiMessage)

            // Simulate human reaching out after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.simulateHumanMessage()
            }
        }
    }

    private func simulateHumanMessage() {
        // Add notification for new inbox message
        let newMessage = InboxMessage(
            senderName: "Sarah Chen",
            senderRole: "Relationship Manager",
            senderAvatar: "person.crop.circle.fill",
            content: "Hi there! I heard you wanted to speak with someone. How can I help you today?",
            timestamp: Date(),
            isRead: false
        )
        inboxMessages.insert(newMessage, at: 0)
        unreadInboxCount += 1

        // Also add notification in chat
        let notificationMessage = ChatMessage(
            content: "Sarah Chen has sent you a message. Check your inbox!",
            isFromUser: false,
            senderType: .humanConcierge,
            timestamp: Date()
        )
        messages.append(notificationMessage)

        if isMinimized {
            unreadCount += 1
        }
    }

    // MARK: - Inbox Functions

    func openInbox() {
        showingInbox = true
    }

    func closeInbox() {
        showingInbox = false
    }

    func markInboxMessageAsRead(_ messageId: UUID) {
        if let index = inboxMessages.firstIndex(where: { $0.id == messageId }) {
            if !inboxMessages[index].isRead {
                inboxMessages[index].isRead = true
                unreadInboxCount = max(0, unreadInboxCount - 1)
            }
        }
    }

    func replyToInboxMessage(_ messageId: UUID, content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if let index = inboxMessages.firstIndex(where: { $0.id == messageId }) {
            let reply = InboxReply(
                content: content,
                isFromUser: true,
                timestamp: Date()
            )
            inboxMessages[index].replies.append(reply)

            // Simulate human response after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.simulateHumanReply(to: messageId)
            }
        }
    }

    private func simulateHumanReply(to messageId: UUID) {
        if let index = inboxMessages.firstIndex(where: { $0.id == messageId }) {
            let reply = InboxReply(
                content: "Thanks for getting back to me! I'll take care of that right away. Is there anything else you need?",
                isFromUser: false,
                timestamp: Date()
            )
            inboxMessages[index].replies.append(reply)
        }
    }
}
