import Foundation

// MARK: - Claude Service Error

enum ClaudeServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - Claude API Service

actor ClaudeService {
    static let shared = ClaudeService()

    // Replace with your actual API key in production
    // In production, this should come from environment variables or secure storage
    private var apiKey: String {
        // Check for environment variable or use placeholder
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "your-api-key-here"
    }

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-haiku-20240307" // Fast, cost-effective for chat

    private let baseSystemPrompt = """
        You are the AI concierge for the Bored Ape Yacht Club (BAYC) Miami Clubhouse, an exclusive members-only club for BAYC and MAYC NFT holders.

        Your role:
        - Provide exceptional, personalized service to club members
        - Help with reservations (lounge, dining, fitness, spa, cabanas, meeting rooms)
        - Take food and drink orders via natural language
        - Share information about upcoming events and amenities
        - Answer questions about the clubhouse and local weather
        - Be warm, professional, and slightly playful (matching the BAYC vibe)
        - Proactively suggest relevant actions based on context

        Clubhouse Details:
        - Location: Miami Beach, Florida (near South Beach)
        - Address: 1901 Collins Avenue, Miami Beach, FL 33139
        - Hours: Mon-Thu 10AM-11PM, Fri-Sat 10AM-2AM, Sun 11AM-10PM

        Amenities & Services:
        - Main Lounge: Comfortable seating, full bar, NFT displays
        - Rooftop Bar: Panoramic views, craft cocktails, DJ on weekends
        - Private Dining: Chef's table experiences, wine cellar access
        - Fitness Center: 24/7 access, personal trainers, Peloton bikes
        - Spa & Wellness: Massage, facials, sauna, cryotherapy
        - Pool Deck: Heated pool, cabanas (reservable), poolside service
        - Locker Rooms: Secure personal lockers with digital access codes
        - Valet Service: Complimentary for all members
        - NFT Gallery: Rotating exhibitions from top digital artists

        Dress Code:
        - Upscale casual (smart casual minimum)
        - No athletic wear in dining areas (gym/pool excluded)
        - Jackets suggested for private dining
        - Pool attire permitted only in pool/cabana areas

        Response Guidelines:
        - Keep responses concise (2-3 sentences when possible)
        - Use a friendly, upscale tone with light humor
        - Always end with a helpful follow-up question or suggestion
        - If discussing events, mention how to RSVP
        - If the user seems interested, suggest relevant next steps
        - Reference the user's current context when relevant (their schedule, locker, etc.)

        Food & Drink Ordering:
        - Members can order food/drinks for delivery to: Lounge, Poolside, Rooftop, their Cabana, or Meeting Room
        - Popular items: Clubhouse Burger ($24), Truffle Fries ($14), Cosmopolitan ($18), Old Fashioned ($20)
        - Categories: Appetizers, Mains, Sides, Cocktails, Wine, Beer, Spirits, Non-Alcoholic, Desserts
        - When member orders, confirm items and delivery location
        - If location unclear, ask: "Where would you like this delivered?"
        - Time modifiers: "now", "in X minutes", "at [time]" - default is ASAP

        Space Bookings:
        - Cabanas: Available when at clubhouse, poolside private areas
        - Meeting Rooms: Board Room, Executive Suite, etc.
        - Can deliver food/drinks to booked spaces

        Suggested Actions:
        - When discussing events: "Would you like me to add this to your schedule?"
        - When discussing dining: "Shall I make a reservation?"
        - When discussing activities: "Can I book this for you?"
        - When member mentions food/drinks: "I can have that sent right over. Where would you like it delivered?"
        - When user seems undecided: Offer 2-3 specific options

        Weather & Activity Guidelines:
        - Naturally incorporate weather into responses when relevant
        - For outdoor activities, proactively mention conditions
        - Recognize informal queries like "is it nice out?", "good day for the pool?"
        - Give practical advice: umbrella for rain, light clothes for heat

        Remember: Members are VIPs who own valuable NFTs. Treat them accordingly.
        """

    // MARK: - User Context for Personalization

    struct UserContext {
        var memberName: String?
        var memberTier: String? // "Black" or "Platinum"
        var upcomingEvents: [String]? // Event titles user has RSVP'd to
        var hasActiveLocker: Bool
        var lockerInfo: String? // e.g., "Locker A42 on Main Floor"
        var hasActiveValet: Bool
        var valetStatus: String? // e.g., "Car ready at entrance"
        var isAtClubhouse: Bool
        var hasOpenTab: Bool
        var foodOrderInfo: String? // e.g., "3 items - Preparing - Cabana 3"
        var hasActiveSpaceBooking: Bool
        var spaceBookingInfo: String? // e.g., "Poolside Cabana 3 - Cabana"

        static let empty = UserContext(hasActiveLocker: false, hasActiveValet: false, isAtClubhouse: false, hasOpenTab: false, hasActiveSpaceBooking: false)
    }

    private func buildSystemPrompt(withWeather weatherContext: String?, userContext: UserContext? = nil) -> String {
        var prompt = baseSystemPrompt

        // Add user-specific context
        if let context = userContext {
            prompt += "\n\n--- MEMBER CONTEXT (use this to personalize responses) ---"

            if let name = context.memberName {
                prompt += "\nMember: \(name)"
            }
            if let tier = context.memberTier {
                prompt += "\nMembership Tier: \(tier) (highest tier = Black, then Platinum)"
            }

            if context.isAtClubhouse {
                prompt += "\nStatus: CURRENTLY AT THE CLUBHOUSE"
            }

            if let events = context.upcomingEvents, !events.isEmpty {
                prompt += "\nUpcoming Events on Member's Schedule: \(events.joined(separator: ", "))"
            } else {
                prompt += "\nNo events on schedule yet - consider suggesting events!"
            }

            if context.hasActiveLocker, let locker = context.lockerInfo {
                prompt += "\nActive Locker: \(locker)"
            }

            if context.hasActiveValet, let valet = context.valetStatus {
                prompt += "\nValet Status: \(valet)"
            }

            if context.hasOpenTab, let orderInfo = context.foodOrderInfo {
                prompt += "\nActive Food/Drink Order: \(orderInfo)"
            }

            if context.hasActiveSpaceBooking, let booking = context.spaceBookingInfo {
                prompt += "\nActive Space Booking: \(booking)"
            }
        }

        // Add weather context
        if let weather = weatherContext {
            prompt += "\n\nCURRENT WEATHER AT CLUBHOUSE:\n\(weather)"
        }

        return prompt
    }

    // MARK: - Request/Response Models

    struct ClaudeRequest: Codable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]

        struct Message: Codable {
            let role: String
            let content: String
        }
    }

    struct ClaudeResponse: Codable {
        let content: [ContentBlock]
        let stop_reason: String?

        struct ContentBlock: Codable {
            let type: String
            let text: String?
        }
    }

    struct ClaudeAPIErrorResponse: Codable {
        let error: ErrorDetail

        struct ErrorDetail: Codable {
            let message: String
            let type: String
        }
    }

    // MARK: - Send Message

    func sendMessage(_ userMessage: String, conversationHistory: [(role: String, content: String)] = [], weatherContext: String? = nil, userContext: UserContext? = nil) async throws -> String {
        guard apiKey != "your-api-key-here" else {
            // Return simulated response if no API key
            return generateFallbackResponse(for: userMessage, weatherContext: weatherContext, userContext: userContext)
        }

        guard let url = URL(string: baseURL) else {
            throw ClaudeServiceError.invalidURL
        }

        // Build messages array with conversation history
        var messages: [ClaudeRequest.Message] = []
        for (role, content) in conversationHistory {
            messages.append(ClaudeRequest.Message(role: role, content: content))
        }
        messages.append(ClaudeRequest.Message(role: "user", content: userMessage))

        // Build system prompt with weather and user context
        let systemPrompt = buildSystemPrompt(withWeather: weatherContext, userContext: userContext)

        let request = ClaudeRequest(
            model: model,
            max_tokens: 300,
            system: systemPrompt,
            messages: messages
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            return claudeResponse.content.first?.text ?? "I apologize, but I couldn't process that request. How else can I help you?"
        } else {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(ClaudeAPIErrorResponse.self, from: data) {
                throw ClaudeServiceError.apiError(errorResponse.error.message)
            }
            throw ClaudeServiceError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Fallback Responses

    private func generateFallbackResponse(for message: String, weatherContext: String? = nil, userContext: UserContext? = nil) -> String {
        let lowercased = message.lowercased()

        // Greeting with personalization
        if lowercased.contains("hi") || lowercased.contains("hello") || lowercased.contains("hey") || lowercased == "yo" {
            return generateGreeting(userContext: userContext)
        }

        // Thanks
        if lowercased.contains("thank") || lowercased.contains("thanks") || lowercased.contains("appreciate") {
            return "You're welcome! Is there anything else I can help you with? I can assist with events, reservations, spa bookings, or anything else."
        }

        // Human concierge request
        if lowercased.contains("human") || lowercased.contains("person") || lowercased.contains("real") || lowercased.contains("manager") || lowercased.contains("speak to someone") {
            return "Of course! I'll connect you with one of our human concierge team members. They'll reach out shortly in your inbox. Is there anything specific I should let them know?"
        }

        // Weather queries
        let weatherIndicators = ["weather", "temperature", "forecast", "rain", "sunny", "cloudy", "storm",
                                 "umbrella", "jacket", "coat", "sweater", "what to wear", "should i bring",
                                 "cold", "hot", "warm", "humid", "nice out", "nice outside",
                                 "how's it out", "looking out", "outside like", "good day for"]
        let isWeatherQuery = weatherIndicators.contains { lowercased.contains($0) }

        let outdoorActivities = ["pool", "rooftop", "deck", "terrace", "outside", "outdoor", "yacht", "beach"]
        let activityQuestions = ["should i", "can i", "is it", "good for", "okay to"]
        let isOutdoorActivityQuery = outdoorActivities.contains { lowercased.contains($0) } &&
                                     activityQuestions.contains { lowercased.contains($0) }

        if isWeatherQuery || isOutdoorActivityQuery {
            return generateWeatherResponse(for: lowercased, weatherContext: weatherContext)
        }

        // Locker queries
        if lowercased.contains("locker") || lowercased.contains("my stuff") || lowercased.contains("belongings") {
            return handleLockerQuery(userContext: userContext)
        }

        // Valet queries
        if lowercased.contains("valet") || lowercased.contains("my car") || lowercased.contains("parking") || lowercased.contains("vehicle") {
            return handleValetQuery(userContext: userContext)
        }

        // Schedule/my events queries
        if lowercased.contains("my schedule") || lowercased.contains("my events") || lowercased.contains("what am i") || lowercased.contains("my plans") {
            return handleScheduleQuery(userContext: userContext)
        }

        // Reservations & bookings
        if lowercased.contains("reservation") || lowercased.contains("book") || lowercased.contains("table") {
            return "I'd be happy to help with a reservation! We have:\n\n• **Main Dining Room** - tonight at 7PM or 9PM\n• **Rooftop Bar** - tables available now\n• **Private Dining** - next availability tomorrow\n\nWhich would you prefer, or would you like a specific date?"
        }

        // Events
        if lowercased.contains("event") || lowercased.contains("what's happening") || lowercased.contains("what's going on") || lowercased.contains("anything going on") {
            return "We have some great events coming up! Would you like to see:\n\n• **This week's events**\n• **Exclusive member events**\n• **A specific type** (dining, fitness, social, art)?\n\nJust let me know and I'll show you the options!"
        }

        // Party/social
        if lowercased.contains("party") || lowercased.contains("mixer") || lowercased.contains("social") {
            return "Looking for some fun? Our **Member Mixer** happens every Saturday at 7PM - great for networking! We also have **Yacht Parties** monthly. Want me to add you to the guest list?"
        }

        // Hours
        if lowercased.contains("hours") || lowercased.contains("open") || lowercased.contains("close") || lowercased.contains("when") {
            return "**Clubhouse Hours:**\n• Mon-Thu: 10AM - 11PM\n• Fri-Sat: 10AM - 2AM\n• Sun: 11AM - 10PM\n\nOur **Fitness Center** is 24/7 with your membership card. Need anything else?"
        }

        // Fitness/gym
        if lowercased.contains("fitness") || lowercased.contains("gym") || lowercased.contains("workout") || lowercased.contains("exercise") || lowercased.contains("train") {
            return "Our **Fitness Center** is open 24/7 and includes:\n• Full weight room\n• Peloton bikes\n• Personal trainers (by appointment)\n• Post-workout smoothie bar\n\nWould you like to book a training session?"
        }

        // Spa
        if lowercased.contains("spa") || lowercased.contains("massage") || lowercased.contains("facial") || lowercased.contains("relax") || lowercased.contains("wellness") {
            return "Our **Spa & Wellness Center** offers:\n• Swedish & deep tissue massage\n• Signature facials\n• Cryotherapy\n• Sauna & steam room\n\nNext availability is tomorrow at 2PM. Shall I book something for you?"
        }

        // Pool
        if lowercased.contains("pool") || lowercased.contains("swim") || lowercased.contains("cabana") {
            let weatherNote = weatherContext != nil ? " Weather looks great for it today!" : ""
            return "Our **Pool Deck** is open 8AM to sunset.\(weatherNote)\n\n• Heated infinity pool\n• Private cabanas (reservable)\n• Poolside food & drink service\n\nWould you like me to reserve a cabana?"
        }

        // Food ordering intent
        let foodOrderIndicators = ["i'd like", "i want", "can i get", "send me", "order", "bring me", "get me", "have a"]
        let foodItems = ["burger", "fries", "salad", "steak", "sandwich", "wings", "nachos", "tacos", "pizza", "soup"]
        let drinkItems = ["cosmopolitan", "cosmo", "martini", "margarita", "old fashioned", "manhattan", "mojito", "beer", "wine", "champagne", "cocktail", "drink", "whiskey", "vodka", "rum", "tequila"]

        let hasFoodOrderIntent = foodOrderIndicators.contains { lowercased.contains($0) }
        let mentionsFood = foodItems.contains { lowercased.contains($0) }
        let mentionsDrink = drinkItems.contains { lowercased.contains($0) }

        if hasFoodOrderIntent && (mentionsFood || mentionsDrink) {
            return handleFoodOrderFallback(lowercased, userContext: userContext)
        }

        // Menu query
        if lowercased.contains("menu") || lowercased.contains("what do you have") || lowercased.contains("what's available") {
            return "**Our Menu Highlights:**\n\n🍔 **Mains:** Clubhouse Burger ($24), Grilled Salmon ($32), Truffle Pasta ($28)\n🥗 **Starters:** Truffle Fries ($14), Ahi Tuna Tartare ($22), Burrata ($18)\n🍸 **Cocktails:** Cosmopolitan ($18), Old Fashioned ($20), BAYC Sunset ($22)\n🍷 **Wine & More:** Full bar with premium spirits\n\nWould you like to place an order? Just tell me what you'd like!"

        }

        // Food/dining
        if lowercased.contains("food") || lowercased.contains("restaurant") || lowercased.contains("dining") || lowercased.contains("eat") || lowercased.contains("hungry") || lowercased.contains("lunch") || lowercased.contains("dinner") || lowercased.contains("breakfast") || lowercased.contains("brunch") {
            return "**Dining Options:**\n\n• **Main Restaurant** - Full menu, lunch & dinner\n• **Rooftop Bar** - Light bites & cocktails\n• **Pool Deck** - Casual fare\n• **Private Dining** - Chef's tasting menu (Thu-Sun)\n\nI can also take your order right now if you'd like food or drinks delivered. What sounds good?"
        }

        // Drinks/bar
        if lowercased.contains("drink") || lowercased.contains("bar") || lowercased.contains("cocktail") || lowercased.contains("wine") {
            return "Looking for drinks? We've got you covered:\n\n• **Main Bar** - Full spirits & cocktails\n• **Rooftop Bar** - Signature cocktails with a view\n• **Wine Cellar** - Private tastings available\n\nHead up anytime, or want me to reserve a table?"
        }

        // Dress code
        if lowercased.contains("dress code") || lowercased.contains("what to wear") || lowercased.contains("dress") && lowercased.contains("code") {
            return "**Dress Code:**\n\n• **General:** Upscale casual (smart casual minimum)\n• **Dining:** No athletic wear; jackets suggested for private dining\n• **Pool/Gym:** Athletic & swim attire welcome\n\nBasically - look sharp but be comfortable. Any specific area you're headed to?"
        }

        // Membership/tier
        if lowercased.contains("membership") || lowercased.contains("tier") || lowercased.contains("benefits") || lowercased.contains("perks") {
            let tierNote = userContext?.memberTier != nil ? "As a **\(userContext!.memberTier!)** member, you have access to all our premium amenities." : ""
            return "\(tierNote)\n\n**Membership Tiers:**\n• **Black (BAYC)** - Full access + exclusive events\n• **Platinum (MAYC)** - Full amenity access\n\nWant to know about specific benefits?"
        }

        // Location/directions
        if lowercased.contains("where") || lowercased.contains("address") || lowercased.contains("location") || lowercased.contains("direction") || lowercased.contains("find") {
            return "We're at **1901 Collins Avenue, Miami Beach, FL 33139** - right near South Beach!\n\n• Valet parking is complimentary\n• Uber/Lyft: drop-off at main entrance\n\nNeed help with anything else for your visit?"
        }

        // NFT/art/gallery
        if lowercased.contains("nft") || lowercased.contains("art") || lowercased.contains("gallery") || lowercased.contains("exhibit") {
            return "Our **NFT Gallery** features rotating exhibitions from top digital artists! Current show runs through the month.\n\nWe also have an **NFT Gallery Opening** event coming up with wine and hors d'oeuvres. Want me to add you to the list?"
        }

        // Help/what can you do
        if lowercased.contains("help") || lowercased.contains("what can you") || lowercased.contains("what do you") {
            return "I can help you with:\n\n• 📅 **Events** - Browse & RSVP\n• 🍽️ **Reservations** - Dining, spa, cabanas\n• 🏋️ **Amenities** - Gym, pool, spa info\n• 🚗 **Valet** - Request your car\n• 🔐 **Locker** - Check your locker info\n• ☀️ **Weather** - Current conditions\n\nWhat would you like to explore?"
        }

        // Catch-all with smart suggestions
        return generateContextualCatchAll(userContext: userContext)
    }

    private func generateGreeting(userContext: UserContext?) -> String {
        let name = userContext?.memberName ?? "there"
        let tier = userContext?.memberTier ?? ""
        let tierGreeting = tier == "Black" ? "Great to see our Black tier VIP! " : ""

        var greeting = "Hello\(name == "there" ? "" : ", \(name)")! \(tierGreeting)How can I make your clubhouse experience even better today?\n\n"

        // Add contextual suggestions
        if let context = userContext {
            if context.isAtClubhouse {
                greeting += "I see you're at the clubhouse! "
                if context.hasActiveLocker {
                    greeting += "Your locker is ready. "
                }
            }

            if let events = context.upcomingEvents, !events.isEmpty {
                greeting += "You have **\(events.first!)** coming up!"
            } else {
                greeting += "Would you like to see today's events or make a reservation?"
            }
        } else {
            greeting += "I can help with events, reservations, amenities, or anything else you need!"
        }

        return greeting
    }

    private func handleLockerQuery(userContext: UserContext?) -> String {
        if let context = userContext, context.hasActiveLocker, let locker = context.lockerInfo {
            return "Your locker is **\(locker)**. The access code is shown in your quick access panel. Need to extend your locker time or get a new one?"
        } else {
            return "Lockers are available in our locker rooms on the **Main Floor** and **Upper Floor**. Would you like me to assign you one? They include complimentary toiletries and towels!"
        }
    }

    private func handleValetQuery(userContext: UserContext?) -> String {
        if let context = userContext, context.hasActiveValet, let status = context.valetStatus {
            return "**Valet Update:** \(status)\n\nI'll keep you posted on any updates. Need anything else while you wait?"
        } else {
            return "Our **complimentary valet service** is available at the main entrance. Would you like me to request your car, or are you planning to arrive soon? I can let the valet know you're coming!"
        }
    }

    private func handleScheduleQuery(userContext: UserContext?) -> String {
        if let context = userContext, let events = context.upcomingEvents, !events.isEmpty {
            let eventList = events.prefix(3).map { "• \($0)" }.joined(separator: "\n")
            return "**Your Upcoming Events:**\n\n\(eventList)\n\nWould you like details on any of these, or want to browse more events?"
        } else {
            return "You don't have any events scheduled yet! We have some great options coming up - would you like me to show you:\n\n• This week's events\n• Exclusive member events\n• A specific category (dining, social, fitness)?"
        }
    }

    private func generateContextualCatchAll(userContext: UserContext?) -> String {
        var response = "I'm here to help! "

        if let context = userContext {
            if context.isAtClubhouse {
                response += "Since you're here, I can help with:\n\n• Dining reservations\n• Spa bookings\n• Pool cabana\n• Your locker\n\n"
            } else {
                response += "Planning your visit? I can help with:\n\n• Upcoming events\n• Reservations\n• Amenity info\n• Weather conditions\n\n"
            }
        } else {
            response += "I can assist with:\n\n• 📅 Events & RSVPs\n• 🍽️ Reservations\n• 🏋️ Amenities\n• ☀️ Weather & conditions\n\n"
        }

        response += "What sounds good?"
        return response
    }

    private func handleFoodOrderFallback(_ query: String, userContext: UserContext?) -> String {
        // Detect what was ordered
        var orderedItems: [String] = []

        // Food items mapping
        let foodMapping: [String: String] = [
            "burger": "Clubhouse Burger",
            "fries": "Truffle Fries",
            "truffle fries": "Truffle Fries",
            "salad": "Caesar Salad",
            "steak": "Filet Mignon",
            "salmon": "Grilled Salmon",
            "wings": "Crispy Wings",
            "nachos": "Loaded Nachos",
            "tacos": "Fish Tacos"
        ]

        // Drink items mapping
        let drinkMapping: [String: String] = [
            "cosmopolitan": "Cosmopolitan",
            "cosmo": "Cosmopolitan",
            "martini": "Classic Martini",
            "margarita": "Margarita",
            "old fashioned": "Old Fashioned",
            "manhattan": "Manhattan",
            "mojito": "Mojito",
            "champagne": "House Champagne",
            "beer": "Craft Beer",
            "wine": "House Wine"
        ]

        for (keyword, item) in foodMapping {
            if query.contains(keyword) {
                orderedItems.append(item)
            }
        }

        for (keyword, item) in drinkMapping {
            if query.contains(keyword) {
                orderedItems.append(item)
            }
        }

        if orderedItems.isEmpty {
            return "I'd be happy to take your order! What would you like? We have great burgers, fresh salads, craft cocktails, and more."
        }

        let itemList = orderedItems.joined(separator: " and ")

        // Check if user has an active space booking
        if let context = userContext, context.hasActiveSpaceBooking, let booking = context.spaceBookingInfo {
            return "Perfect! I'll send **\(itemList)** right over to your \(booking). Your order is being prepared! 🍽️"
        }

        // Check if user is at clubhouse
        if let context = userContext, context.isAtClubhouse {
            return "Great choice! I can send **\(itemList)** to you. Where would you like it delivered?\n\n• **Lounge**\n• **Poolside**\n• **Rooftop**\n\nJust let me know!"
        }

        // General response
        return "I've noted **\(itemList)**! Where at the clubhouse would you like this delivered?\n\n• **Lounge**\n• **Poolside**\n• **Rooftop**\n• **Your Cabana** (if booked)"
    }

    private func generateWeatherResponse(for query: String, weatherContext: String?) -> String {
        guard let weather = weatherContext, !weather.isEmpty else {
            return "I'm checking the weather conditions for you. Miami is typically warm and sunny, but let me get you the current conditions. Is there a specific day you're planning to visit?"
        }

        // Parse weather context for intelligent responses
        let weatherLower = weather.lowercased()
        let isRainy = weatherLower.contains("rain") || weatherLower.contains("shower") || weatherLower.contains("storm")
        let isCold = weatherLower.contains("cool") || weather.contains("65°") || weather.contains("60°")
        let isHot = weatherLower.contains("hot") || weather.contains("85°") || weather.contains("86°") || weather.contains("87°") || weather.contains("88°") || weather.contains("89°") || weather.contains("90°")
        let isPleasant = !isRainy && !isCold && !isHot
        let isGoodOutdoor = weatherLower.contains("excellent conditions") || weatherLower.contains("great for outdoor")

        // Extract just the current temp summary for concise responses
        let briefWeather: String
        if let tempRange = weather.range(of: #"\d+°F"#, options: .regularExpression) {
            briefWeather = "It's currently \(weather[tempRange]) and \(isRainy ? "rainy" : isHot ? "hot" : isCold ? "cool" : "pleasant")."
        } else {
            briefWeather = "Conditions are \(isRainy ? "rainy" : isHot ? "hot" : isCold ? "cool" : "pleasant") at the clubhouse."
        }

        // Informal "how's it out there" type queries
        if query.contains("nice out") || query.contains("nice outside") || query.contains("how's it") ||
           query.contains("how is it") || query.contains("looking out") || query.contains("what's it like") {
            if isRainy {
                return "\(briefWeather) A bit wet right now, but perfect for enjoying our indoor lounge or spa. The rain usually passes quickly in Miami!"
            } else if isHot {
                return "\(briefWeather) It's warm out there! The pool is calling, and our cabanas have great shade. Want me to reserve one?"
            } else if isPleasant {
                return "\(briefWeather) Beautiful day! The rooftop and pool deck are both excellent choices right now."
            } else {
                return "\(briefWeather) Might want a light layer for the evening, but overall lovely for the clubhouse."
            }
        }

        // "Good day for X" queries
        if query.contains("good day for") || query.contains("good time for") || query.contains("should i go") {
            if query.contains("pool") || query.contains("swim") {
                return isRainy ? "The pool deck might be a bit wet right now. Our spa is a great alternative!" :
                       isHot ? "Absolutely! \(briefWeather) Perfect pool weather. Shall I reserve a cabana?" :
                       "\(briefWeather) Good conditions for the pool! Water's always perfect temperature."
            } else if query.contains("rooftop") || query.contains("outside") || query.contains("outdoor") {
                return isGoodOutdoor ? "\(briefWeather) Excellent conditions for the rooftop! Would you like a table reserved?" :
                       isRainy ? "The rooftop might be affected by weather right now. Our indoor lounge has a great vibe!" :
                       "\(briefWeather) Should be nice out there. The rooftop bar is open!"
            }
        }

        // Clothing/preparation queries
        if query.contains("umbrella") || query.contains("rain") {
            return isRainy ?
                "Yes, I'd recommend an umbrella today! \(briefWeather) We also have complimentary umbrellas at the valet." :
                "You should be fine without one! \(briefWeather) But we keep umbrellas at the valet just in case."
        }

        if query.contains("jacket") || query.contains("coat") || query.contains("sweater") || query.contains("layer") {
            return isCold ?
                "A light layer would be smart! \(briefWeather) The rooftop can get breezy in the evening too." :
                "You probably won't need one outside. \(briefWeather) Though our indoor spaces are well air-conditioned!"
        }

        if query.contains("wear") || query.contains("dress") {
            if isHot {
                return "\(briefWeather) Light, breathable clothing is perfect. Don't forget sunglasses for the rooftop!"
            } else if isCold {
                return "\(briefWeather) A light jacket or cardigan would be nice, especially for evening."
            } else {
                return "\(briefWeather) Whatever you're comfortable in! Miami casual is always welcome at the clubhouse."
            }
        }

        // Activity-specific
        if query.contains("pool") || query.contains("swim") {
            return isRainy ?
                "The pool deck might not be ideal right now. May I suggest our spa instead?" :
                isHot ? "Perfect pool weather! \(briefWeather) Our cabanas offer great shade. Want me to reserve one?" :
                "Great day for the pool! \(briefWeather) Shall I reserve a cabana?"
        }

        if query.contains("rooftop") || query.contains("deck") || query.contains("terrace") {
            return isRainy ?
                "The rooftop might be affected by weather. Our indoor lounge is cozy though!" :
                "\(briefWeather) The rooftop is perfect right now. Would you like me to reserve a spot?"
        }

        // Time-specific queries
        if query.contains("weekend") || query.contains("saturday") || query.contains("sunday") {
            return "For the weekend at the clubhouse: \(weather.contains("WEEKEND") ? weather : briefWeather) Any events you're planning to attend?"
        }

        if query.contains("tomorrow") {
            return "For tomorrow: \(weather.contains("TOMORROW") ? weather : briefWeather) Would you like me to make any reservations?"
        }

        // General weather query
        return "\(briefWeather) \(isGoodOutdoor ? "Great conditions for enjoying all our amenities!" : "Is there anything specific you'd like to plan?")"
    }
}
