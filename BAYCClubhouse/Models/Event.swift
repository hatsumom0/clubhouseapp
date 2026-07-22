import SwiftUI

// MARK: - Event Model

struct ClubEvent: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let date: Date
    let endDate: Date?
    let location: String
    let locationDetail: String?
    let organizer: EventOrganizer
    let attendees: [EventAttendee]
    let totalSpots: Int
    var spotsLeft: Int
    let imageSystemName: String
    let category: EventCategory
    var rsvpStatus: RSVPStatus

    // Membership & TokenProof
    let requiredMembershipTier: MembershipTier? // nil = open to all members
    let requiresTokenProof: Bool // Whether TokenProof verification is needed

    // Rich metadata for AI concierge queries
    let details: EventDetails?

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        date: Date,
        endDate: Date?,
        location: String,
        locationDetail: String?,
        organizer: EventOrganizer,
        attendees: [EventAttendee],
        totalSpots: Int,
        spotsLeft: Int,
        imageSystemName: String,
        category: EventCategory,
        rsvpStatus: RSVPStatus,
        requiredMembershipTier: MembershipTier? = nil,
        requiresTokenProof: Bool = false,
        details: EventDetails? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.date = date
        self.endDate = endDate
        self.location = location
        self.locationDetail = locationDetail
        self.organizer = organizer
        self.attendees = attendees
        self.totalSpots = totalSpots
        self.spotsLeft = spotsLeft
        self.imageSystemName = imageSystemName
        self.category = category
        self.rsvpStatus = rsvpStatus
        self.requiredMembershipTier = requiredMembershipTier
        self.requiresTokenProof = requiresTokenProof
        self.details = details
    }

    var isExclusiveEvent: Bool {
        requiredMembershipTier != nil || requiresTokenProof
    }

    var tierBadgeText: String? {
        guard let tier = requiredMembershipTier else { return nil }
        return "\(tier.displayName) Members Only"
    }

    enum EventCategory: String, CaseIterable {
        case social = "Social"
        case dining = "Dining"
        case wellness = "Wellness"
        case spa = "Spa"
        case fitness = "Fitness"
        case exclusive = "Exclusive"
        case party = "Party"

        var color: Color {
            switch self {
            case .social: return Color(hex: "f39c12")
            case .dining: return Color(hex: "e74c3c")
            case .wellness: return Color(hex: "2ecc71")
            case .spa: return Color(hex: "1abc9c")
            case .fitness: return Color(hex: "e67e22")
            case .exclusive: return Color(hex: "9b59b6")
            case .party: return Color(hex: "3498db")
            }
        }

        var icon: String {
            switch self {
            case .social: return "person.3.fill"
            case .dining: return "fork.knife"
            case .wellness: return "leaf.fill"
            case .spa: return "sparkles"
            case .fitness: return "dumbbell.fill"
            case .exclusive: return "star.fill"
            case .party: return "party.popper.fill"
            }
        }

        var keywords: [String] {
            switch self {
            case .social: return ["social", "mixer", "networking", "meet", "mingle"]
            case .dining: return ["dining", "dinner", "lunch", "food", "restaurant", "eat", "wine", "chef"]
            case .wellness: return ["wellness", "yoga", "meditation", "health", "mindfulness"]
            case .spa: return ["spa", "massage", "facial", "treatment", "relax", "pamper", "sauna", "steam"]
            case .fitness: return ["fitness", "gym", "workout", "training", "exercise", "class"]
            case .exclusive: return ["exclusive", "vip", "special", "private", "limited"]
            case .party: return ["party", "dj", "dance", "music", "celebration", "yacht"]
            }
        }
    }

    enum RSVPStatus: String {
        case notResponded = "not_responded"
        case going = "going"
        case maybe = "maybe"
        case declined = "declined"
        case waitlist = "waitlist"
        case pendingVerification = "pending_verification"

        var displayText: String {
            switch self {
            case .notResponded: return "RSVP"
            case .going: return "Going"
            case .maybe: return "Maybe"
            case .declined: return "Not Going"
            case .waitlist: return "Waitlist"
            case .pendingVerification: return "Verify"
            }
        }

        var color: Color {
            switch self {
            case .notResponded: return Color(hex: "f39c12")
            case .going: return .green
            case .maybe: return .orange
            case .declined: return .red
            case .waitlist: return .purple
            case .pendingVerification: return Color(hex: "8b5cf6")
            }
        }
    }
}

struct EventOrganizer {
    let name: String
    let role: String
    let avatarSystemName: String
}

struct EventAttendee: Identifiable {
    let id = UUID()
    let name: String
    let avatarSystemName: String
    let tokenId: String?
}

// MARK: - Rich Event Details

struct EventDetails {
    // Staff members (instructors, trainers, chefs, etc.)
    let staff: [EventStaffMember]?

    // Food & Beverage
    let foodAndBeverage: FoodAndBeverageInfo?

    // Artwork/Artists (for gallery events)
    let artwork: ArtworkInfo?

    // What's included
    let includedItems: [String]?

    // What to bring/wear
    let whatToBring: [String]?
    let dressCode: String?

    // Special notes
    let specialNotes: String?

    // Music/Entertainment
    let entertainment: EntertainmentInfo?

    init(
        staff: [EventStaffMember]? = nil,
        foodAndBeverage: FoodAndBeverageInfo? = nil,
        artwork: ArtworkInfo? = nil,
        includedItems: [String]? = nil,
        whatToBring: [String]? = nil,
        dressCode: String? = nil,
        specialNotes: String? = nil,
        entertainment: EntertainmentInfo? = nil
    ) {
        self.staff = staff
        self.foodAndBeverage = foodAndBeverage
        self.artwork = artwork
        self.includedItems = includedItems
        self.whatToBring = whatToBring
        self.dressCode = dressCode
        self.specialNotes = specialNotes
        self.entertainment = entertainment
    }
}

struct EventStaffMember: Identifiable {
    let id = UUID()
    let name: String
    let role: StaffRole
    let bio: String?
    let certifications: [String]?
    let specialties: [String]?

    enum StaffRole: String {
        case yogaInstructor = "Yoga Instructor"
        case personalTrainer = "Personal Trainer"
        case fitnessInstructor = "Fitness Instructor"
        case massageTherapist = "Massage Therapist"
        case esthetician = "Esthetician"
        case spaDirector = "Spa Director"
        case chef = "Executive Chef"
        case sommelier = "Sommelier"
        case bartender = "Mixologist"
        case dj = "DJ"
        case artCurator = "Art Curator"
        case host = "Event Host"
        case concierge = "Concierge"
        case wellnessCoach = "Wellness Coach"

        var icon: String {
            switch self {
            case .yogaInstructor: return "figure.yoga"
            case .personalTrainer, .fitnessInstructor: return "dumbbell.fill"
            case .massageTherapist, .spaDirector: return "hand.raised.fingers.spread.fill"
            case .esthetician: return "face.smiling.inverse"
            case .chef: return "fork.knife"
            case .sommelier: return "wineglass.fill"
            case .bartender: return "wineglass"
            case .dj: return "music.mic"
            case .artCurator: return "photo.artframe"
            case .host, .concierge: return "person.crop.circle.fill"
            case .wellnessCoach: return "heart.fill"
            }
        }
    }
}

struct FoodAndBeverageInfo {
    let description: String?
    let menuHighlights: [String]?
    let dietaryOptions: [String]? // Vegan, GF, etc.
    let beverages: [String]?
    let isOpenBar: Bool
    let isIncluded: Bool

    init(
        description: String? = nil,
        menuHighlights: [String]? = nil,
        dietaryOptions: [String]? = nil,
        beverages: [String]? = nil,
        isOpenBar: Bool = false,
        isIncluded: Bool = true
    ) {
        self.description = description
        self.menuHighlights = menuHighlights
        self.dietaryOptions = dietaryOptions
        self.beverages = beverages
        self.isOpenBar = isOpenBar
        self.isIncluded = isIncluded
    }
}

struct ArtworkInfo {
    let exhibitionName: String?
    let artists: [ArtistInfo]?
    let artworkCount: Int?
    let mediums: [String]? // Digital, sculpture, etc.
    let featuredPieces: [FeaturedArtwork]?
    let curatorNotes: String?

    init(
        exhibitionName: String? = nil,
        artists: [ArtistInfo]? = nil,
        artworkCount: Int? = nil,
        mediums: [String]? = nil,
        featuredPieces: [FeaturedArtwork]? = nil,
        curatorNotes: String? = nil
    ) {
        self.exhibitionName = exhibitionName
        self.artists = artists
        self.artworkCount = artworkCount
        self.mediums = mediums
        self.featuredPieces = featuredPieces
        self.curatorNotes = curatorNotes
    }
}

struct ArtistInfo: Identifiable {
    let id = UUID()
    let name: String
    let bio: String?
    let notableWorks: [String]?
    let socialHandle: String?
}

struct FeaturedArtwork: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let medium: String
    let description: String?
    let estimatedValue: String?
}

struct EntertainmentInfo {
    let type: String // DJ, Live Band, etc.
    let performer: String?
    let genre: String?
    let setTimes: String?
}

// MARK: - Sample Events Data

extension ClubEvent {
    static let sampleEvents: [ClubEvent] = [
        ClubEvent(
            title: "Member Mixer",
            description: "Join fellow BAYC members for an evening of networking, cocktails, and good vibes. Connect with other ape holders and make new friends in the community.",
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!.addingTimeInterval(19 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!.addingTimeInterval(23 * 3600),
            location: "Main Lounge",
            locationDetail: "2nd Floor, BAYC Miami Clubhouse",
            organizer: EventOrganizer(name: "Sarah Chen", role: "Events Coordinator", avatarSystemName: "person.crop.circle.fill"),
            attendees: [
                EventAttendee(name: "ApeLord", avatarSystemName: "person.crop.circle.fill", tokenId: "1234"),
                EventAttendee(name: "CryptoApe", avatarSystemName: "person.crop.circle.fill", tokenId: "5678"),
                EventAttendee(name: "DiamondHands", avatarSystemName: "person.crop.circle.fill", tokenId: "9012"),
                EventAttendee(name: "NFTWhale", avatarSystemName: "person.crop.circle.fill", tokenId: "3456"),
                EventAttendee(name: "BoredApe", avatarSystemName: "person.crop.circle.fill", tokenId: "7890"),
            ],
            totalSpots: 50,
            spotsLeft: 12,
            imageSystemName: "person.3.fill",
            category: .social,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Sarah Chen", role: .host, bio: "Sarah has 8 years of experience in event coordination and loves connecting people.", certifications: nil, specialties: ["Networking events", "VIP experiences"]),
                    EventStaffMember(name: "Carlos Rodriguez", role: .bartender, bio: "Award-winning mixologist specializing in craft cocktails.", certifications: ["Certified Mixologist"], specialties: ["Craft cocktails", "Molecular mixology"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "Gourmet appetizers and craft cocktails throughout the evening",
                    menuHighlights: ["Truffle arancini", "Wagyu sliders", "Tuna tartare", "Artisanal cheese board"],
                    dietaryOptions: ["Vegetarian options available", "Gluten-free upon request"],
                    beverages: ["Signature BAYC cocktail", "Premium spirits", "Craft beer selection", "Fine wines"],
                    isOpenBar: true,
                    isIncluded: true
                ),
                includedItems: ["Open bar", "Gourmet appetizers", "Networking opportunities", "Live DJ"],
                dressCode: "Smart casual"
            )
        ),
        ClubEvent(
            title: "Yacht Party",
            description: "Set sail on an exclusive yacht experience with stunning views of Miami Beach. Premium open bar, gourmet dining, and DJ entertainment all night long. BAYC holders only.",
            date: Calendar.current.date(byAdding: .day, value: 17, to: Date())!.addingTimeInterval(16 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 17, to: Date())!.addingTimeInterval(23 * 3600),
            location: "Miami Marina",
            locationDetail: "Dock 7, 400 Alton Road",
            organizer: EventOrganizer(name: "Marcus Williams", role: "Events Director", avatarSystemName: "person.crop.circle.fill"),
            attendees: [
                EventAttendee(name: "YachtClub", avatarSystemName: "person.crop.circle.fill", tokenId: "1111"),
                EventAttendee(name: "SeasideApe", avatarSystemName: "person.crop.circle.fill", tokenId: "2222"),
                EventAttendee(name: "WaveRider", avatarSystemName: "person.crop.circle.fill", tokenId: "3333"),
            ],
            totalSpots: 120,
            spotsLeft: 45,
            imageSystemName: "sailboat.fill",
            category: .party,
            rsvpStatus: .going,
            requiredMembershipTier: .black,
            requiresTokenProof: true,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "DJ Crypto", role: .dj, bio: "Miami's hottest DJ known for high-energy sets at exclusive venues.", certifications: nil, specialties: ["House", "Electronic", "Hip-hop remixes"]),
                    EventStaffMember(name: "Chef Michael Laurent", role: .chef, bio: "Michelin-starred chef specializing in Mediterranean seafood cuisine.", certifications: ["Michelin Star", "Culinary Institute of America"], specialties: ["Seafood", "Mediterranean", "French cuisine"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "Five-course gourmet dinner featuring fresh seafood and premium cuts",
                    menuHighlights: ["Fresh oysters", "Lobster tail", "Wagyu ribeye", "Champagne toast"],
                    dietaryOptions: ["Vegetarian", "Pescatarian", "Vegan upon request"],
                    beverages: ["Dom Pérignon champagne", "Premium cocktails", "Top-shelf spirits"],
                    isOpenBar: true,
                    isIncluded: true
                ),
                includedItems: ["7-hour yacht charter", "Gourmet dinner", "Premium open bar", "Live DJ", "Sunset photo opportunity at Star Island"],
                whatToBring: ["Sunscreen", "Sunglasses", "Light jacket for evening", "Camera"],
                dressCode: "Miami chic - elegant but comfortable",
                entertainment: EntertainmentInfo(type: "DJ", performer: "DJ Crypto", genre: "House & Electronic", setTimes: "6PM - 11PM")
            )
        ),
        ClubEvent(
            title: "NFT Gallery Opening",
            description: "Exclusive preview of our new digital art gallery featuring works from renowned NFT artists. Wine and hors d'oeuvres provided. Black tier members get priority access.",
            date: Calendar.current.date(byAdding: .day, value: 10, to: Date())!.addingTimeInterval(18 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!.addingTimeInterval(21 * 3600),
            location: "Gallery Space",
            locationDetail: "3rd Floor, West Wing",
            organizer: EventOrganizer(name: "Alex Rivera", role: "Art Curator", avatarSystemName: "person.crop.circle.fill"),
            attendees: [
                EventAttendee(name: "ArtCollector", avatarSystemName: "person.crop.circle.fill", tokenId: "4444"),
                EventAttendee(name: "DigitalPicasso", avatarSystemName: "person.crop.circle.fill", tokenId: "5555"),
            ],
            totalSpots: 30,
            spotsLeft: 5,
            imageSystemName: "photo.artframe",
            category: .exclusive,
            rsvpStatus: .notResponded,
            requiredMembershipTier: .black,
            requiresTokenProof: true,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Alex Rivera", role: .artCurator, bio: "Former Sotheby's digital art specialist with deep expertise in NFT valuations.", certifications: ["Christie's Art Business Certificate"], specialties: ["NFT art", "Digital collectibles", "Contemporary art"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "Curated wine selection paired with artisanal hors d'oeuvres",
                    menuHighlights: ["Caviar blinis", "Foie gras crostini", "Truffle bruschetta", "Artisan cheeses"],
                    dietaryOptions: ["Vegetarian available"],
                    beverages: ["Curated wine selection", "Champagne", "Artisan cocktails"],
                    isOpenBar: false,
                    isIncluded: true
                ),
                artwork: ArtworkInfo(
                    exhibitionName: "Digital Horizons: The Future of Art",
                    artists: [
                        ArtistInfo(name: "XCOPY", bio: "Pioneering crypto artist known for dark, surreal animations", notableWorks: ["Right-click and Save As guy", "Death Dip"], socialHandle: "@xcaborx"),
                        ArtistInfo(name: "Beeple", bio: "Digital artist whose 'Everydays' sold for $69M at Christie's", notableWorks: ["Everydays: The First 5000 Days"], socialHandle: "@bikiwinkel"),
                        ArtistInfo(name: "Fewocious", bio: "Young prodigy blending traditional techniques with digital innovation", notableWorks: ["The EverLasting Beautiful"], socialHandle: "@fewocious"),
                        ArtistInfo(name: "Pak", bio: "Anonymous artist exploring digital scarcity and perception", notableWorks: ["The Merge", "Censored"], socialHandle: "@muikiverse")
                    ],
                    artworkCount: 24,
                    mediums: ["Generative art", "3D sculptures", "Animated pieces", "AI-assisted works"],
                    featuredPieces: [
                        FeaturedArtwork(title: "Ape Genesis", artist: "XCOPY", medium: "Animated GIF", description: "A haunting tribute to the BAYC origins", estimatedValue: "45 ETH"),
                        FeaturedArtwork(title: "Miami Sunset #001", artist: "Beeple", medium: "Digital render", description: "Exclusive commission for BAYC Miami", estimatedValue: "120 ETH"),
                        FeaturedArtwork(title: "Club Culture", artist: "Fewocious", medium: "Mixed digital", description: "Exploring community in the digital age", estimatedValue: "28 ETH")
                    ],
                    curatorNotes: "This exhibition explores the intersection of traditional art valuation and digital scarcity, featuring works from artists who have redefined what art ownership means in the Web3 era."
                ),
                includedItems: ["Guided tour with curator", "Wine & hors d'oeuvres", "Exhibition catalog", "Meet-and-greet with artists"],
                dressCode: "Cocktail attire"
            )
        ),
        ClubEvent(
            title: "Sunset Yoga Session",
            description: "Relax and rejuvenate with a sunset yoga session on the rooftop deck. All skill levels welcome. Mats and refreshments provided.",
            date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!.addingTimeInterval(17 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!.addingTimeInterval(18.5 * 3600),
            location: "Rooftop Deck",
            locationDetail: "5th Floor",
            organizer: EventOrganizer(name: "Maya Johnson", role: "Wellness Director", avatarSystemName: "person.crop.circle.fill"),
            attendees: [
                EventAttendee(name: "ZenApe", avatarSystemName: "person.crop.circle.fill", tokenId: "6666"),
            ],
            totalSpots: 20,
            spotsLeft: 8,
            imageSystemName: "figure.yoga",
            category: .wellness,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Maya Johnson", role: .yogaInstructor, bio: "E-RYT 500 certified instructor with 15 years experience. Maya trained in India and specializes in Vinyasa and restorative yoga.", certifications: ["E-RYT 500", "Yoga Alliance Certified", "Meditation Teacher Training"], specialties: ["Vinyasa flow", "Restorative yoga", "Breathwork", "Sunset sessions"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "Post-session refreshments",
                    menuHighlights: ["Fresh coconut water", "Fruit skewers", "Energy bites"],
                    dietaryOptions: ["Vegan", "Gluten-free"],
                    beverages: ["Coconut water", "Herbal tea", "Infused water"],
                    isOpenBar: false,
                    isIncluded: true
                ),
                includedItems: ["Premium yoga mat", "Towel", "Post-session refreshments", "Essential oil aromatherapy"],
                whatToBring: ["Comfortable workout clothes", "Water bottle", "Sunscreen (we're on the roof!)"],
                dressCode: "Athletic wear",
                specialNotes: "Beginners are absolutely welcome! Maya offers modifications for all poses."
            )
        ),
        ClubEvent(
            title: "Wine Tasting Dinner",
            description: "An exquisite five-course dinner paired with premium wines from Napa Valley. Limited seating for an intimate experience.",
            date: Calendar.current.date(byAdding: .day, value: 5, to: Date())!.addingTimeInterval(19 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!.addingTimeInterval(22 * 3600),
            location: "Private Dining Room",
            locationDetail: "1st Floor, East Wing",
            organizer: EventOrganizer(name: "Chef Antonio", role: "Executive Chef", avatarSystemName: "person.crop.circle.fill"),
            attendees: [
                EventAttendee(name: "WineConnoisseur", avatarSystemName: "person.crop.circle.fill", tokenId: "7777"),
                EventAttendee(name: "FoodieApe", avatarSystemName: "person.crop.circle.fill", tokenId: "8888"),
                EventAttendee(name: "GourmetGorilla", avatarSystemName: "person.crop.circle.fill", tokenId: "9999"),
            ],
            totalSpots: 16,
            spotsLeft: 3,
            imageSystemName: "wineglass.fill",
            category: .dining,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Chef Antonio Rossi", role: .chef, bio: "Two Michelin star chef from Florence, Italy. Trained under Massimo Bottura and brings 20 years of culinary excellence.", certifications: ["Michelin 2-Star", "James Beard Nominee"], specialties: ["Italian cuisine", "Farm-to-table", "Wine pairings"]),
                    EventStaffMember(name: "Victoria Wells", role: .sommelier, bio: "Master Sommelier with extensive Napa Valley expertise. Former head sommelier at The French Laundry.", certifications: ["Master Sommelier", "WSET Diploma"], specialties: ["California wines", "Napa Valley", "Food pairing"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "Five-course tasting menu with premium Napa Valley wine pairings",
                    menuHighlights: [
                        "Amuse-bouche: White truffle foam with parmigiano crisp",
                        "Course 1: Hokkaido scallop crudo with yuzu and caviar",
                        "Course 2: Handmade pappardelle with wild boar ragù",
                        "Course 3: Pan-seared branzino with Meyer lemon beurre blanc",
                        "Course 4: 45-day dry-aged ribeye with bone marrow",
                        "Course 5: Chocolate soufflé with raspberry coulis"
                    ],
                    dietaryOptions: ["Vegetarian alternative menu available", "Allergies accommodated with 48hr notice"],
                    beverages: [
                        "2019 Opus One - Bordeaux blend",
                        "2020 Screaming Eagle - Cabernet Sauvignon",
                        "2018 Kistler - Chardonnay",
                        "2017 Harlan Estate - Red blend",
                        "NV Schramsberg - Blanc de Blancs"
                    ],
                    isOpenBar: false,
                    isIncluded: true
                ),
                includedItems: ["5-course tasting menu", "5 premium wine pairings", "Meet the chef experience", "Take-home wine notes"],
                dressCode: "Business elegant"
            )
        ),
        ClubEvent(
            title: "ApeFest Pre-Party",
            description: "Get hyped for ApeFest with an exclusive pre-party at the clubhouse. DJ sets, open bar, and surprise guest appearances. BAYC holders only - TokenProof required.",
            date: Calendar.current.date(byAdding: .day, value: 21, to: Date())!.addingTimeInterval(20 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 22, to: Date())!.addingTimeInterval(2 * 3600),
            location: "Main Floor",
            locationDetail: "Entire Clubhouse",
            organizer: EventOrganizer(name: "Yuga Labs Events", role: "Official Partner", avatarSystemName: "person.crop.circle.fill"),
            attendees: [
                EventAttendee(name: "PartyApe", avatarSystemName: "person.crop.circle.fill", tokenId: "0001"),
            ],
            totalSpots: 200,
            spotsLeft: 150,
            imageSystemName: "music.mic",
            category: .exclusive,
            rsvpStatus: .notResponded,
            requiredMembershipTier: .black,
            requiresTokenProof: true,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "DJ Snoopadelic", role: .dj, bio: "Special guest appearance - legendary artist and NFT enthusiast.", certifications: nil, specialties: ["Hip-hop", "Funk", "Electronic"]),
                    EventStaffMember(name: "DJ 3LAU", role: .dj, bio: "Pioneer of NFT music and platinum-selling electronic producer.", certifications: nil, specialties: ["Electronic", "House", "NFT drops"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "All-night food stations and premium open bar",
                    menuHighlights: ["Taco bar", "Sushi station", "Slider bar", "Late-night pizza"],
                    dietaryOptions: ["Vegetarian", "Vegan", "Gluten-free options"],
                    beverages: ["Premium open bar", "Signature BAYC cocktails", "Rare spirits"],
                    isOpenBar: true,
                    isIncluded: true
                ),
                includedItems: ["6-hour event", "Premium open bar", "Food stations", "Exclusive merch drop", "NFT airdrop for attendees"],
                whatToBring: ["Your TokenProof-verified wallet", "Party energy", "Camera for memories"],
                dressCode: "ApeFest vibes - express yourself!",
                specialNotes: "Surprise celebrity appearances confirmed. NFT holder airdrops throughout the night!",
                entertainment: EntertainmentInfo(type: "Live DJs", performer: "DJ Snoopadelic, DJ 3LAU + surprise guests", genre: "Hip-hop, Electronic, House", setTimes: "8PM - 2AM")
            )
        ),
        // MARK: - Spa Events
        ClubEvent(
            title: "Signature Hot Stone Massage",
            description: "Experience deep relaxation with our signature hot stone massage. Smooth, heated basalt stones combined with expert massage techniques melt away tension and stress.",
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!.addingTimeInterval(10 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!.addingTimeInterval(11.5 * 3600),
            location: "Spa & Wellness Center",
            locationDetail: "4th Floor, Treatment Room 1",
            organizer: EventOrganizer(name: "Elena Martinez", role: "Spa Director", avatarSystemName: "person.crop.circle.fill"),
            attendees: [],
            totalSpots: 4,
            spotsLeft: 2,
            imageSystemName: "sparkles",
            category: .spa,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Lucia Santos", role: .massageTherapist, bio: "Licensed massage therapist with 12 years experience specializing in hot stone therapy. Trained at the Thai Massage School of Chiang Mai.", certifications: ["LMT", "NCBTMB", "Hot Stone Certification"], specialties: ["Hot stone massage", "Deep tissue", "Swedish massage", "Aromatherapy"])
                ],
                includedItems: ["90-minute treatment", "Aromatherapy oils", "Heated massage table", "Post-treatment herbal tea", "Use of relaxation lounge"],
                whatToBring: ["Nothing required - we provide everything"],
                specialNotes: "Please arrive 15 minutes early to complete your wellness questionnaire and begin relaxation."
            )
        ),
        ClubEvent(
            title: "Couples Spa Retreat",
            description: "Share a luxurious spa experience with your partner. Includes side-by-side massages, champagne, chocolate-covered strawberries, and access to private relaxation lounge.",
            date: Calendar.current.date(byAdding: .day, value: 4, to: Date())!.addingTimeInterval(14 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!.addingTimeInterval(17 * 3600),
            location: "Spa & Wellness Center",
            locationDetail: "4th Floor, Couples Suite",
            organizer: EventOrganizer(name: "Elena Martinez", role: "Spa Director", avatarSystemName: "person.crop.circle.fill"),
            attendees: [],
            totalSpots: 6,
            spotsLeft: 4,
            imageSystemName: "heart.fill",
            category: .spa,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Lucia Santos", role: .massageTherapist, bio: "Specializes in couples treatments and romantic spa experiences.", certifications: ["LMT", "NCBTMB"], specialties: ["Couples massage", "Hot stone", "Swedish"]),
                    EventStaffMember(name: "Andrei Volkov", role: .massageTherapist, bio: "Former Olympic sports massage therapist, expert in deep tissue work.", certifications: ["LMT", "Sports Massage Certified"], specialties: ["Deep tissue", "Sports massage", "Trigger point"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "Romantic refreshments included",
                    menuHighlights: ["Chocolate-covered strawberries", "Artisan chocolate truffles", "Fresh fruit platter"],
                    dietaryOptions: ["Sugar-free options available"],
                    beverages: ["Champagne (Veuve Clicquot)", "Sparkling cider option"],
                    isOpenBar: false,
                    isIncluded: true
                ),
                includedItems: ["Side-by-side 90-minute massage", "Champagne & strawberries", "Private jacuzzi access", "Rose petal ambiance", "Couples relaxation lounge"],
                dressCode: "We provide robes and slippers",
                specialNotes: "Perfect for anniversaries, birthdays, or just because! Add on a private dinner in the spa garden for an additional $200."
            )
        ),
        ClubEvent(
            title: "CBD Recovery Treatment",
            description: "Ultimate recovery session combining CBD-infused massage oil, cryotherapy, and compression therapy. Perfect after a workout or long travel. Black tier exclusive.",
            date: Calendar.current.date(byAdding: .day, value: 6, to: Date())!.addingTimeInterval(11 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 6, to: Date())!.addingTimeInterval(12.5 * 3600),
            location: "Spa & Wellness Center",
            locationDetail: "4th Floor, Recovery Suite",
            organizer: EventOrganizer(name: "Dr. James Park", role: "Wellness Physician", avatarSystemName: "person.crop.circle.fill"),
            attendees: [],
            totalSpots: 2,
            spotsLeft: 2,
            imageSystemName: "leaf.circle.fill",
            category: .spa,
            rsvpStatus: .notResponded,
            requiredMembershipTier: .black,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Dr. James Park", role: .wellnessCoach, bio: "Board-certified sports medicine physician specializing in recovery optimization.", certifications: ["MD", "Sports Medicine Board Certified", "CBD Therapy Specialist"], specialties: ["Athletic recovery", "CBD therapy", "Cryotherapy protocols"]),
                    EventStaffMember(name: "Marcus Chen", role: .massageTherapist, bio: "Former NBA massage therapist specializing in athletic recovery.", certifications: ["LMT", "Sports Massage", "Cryotherapy Certified"], specialties: ["Sports recovery", "CBD massage", "Compression therapy"])
                ],
                includedItems: ["Full-body CBD massage", "Localized cryotherapy", "NormaTec compression boots session", "Recovery smoothie", "Take-home CBD balm sample"],
                whatToBring: ["Comfortable clothes for compression therapy", "List of any medications (for CBD safety check)"],
                specialNotes: "Please inform us of any medications you're taking, as CBD may interact with certain drugs. Our doctor will review before treatment."
            )
        ),
        ClubEvent(
            title: "Luxury Facial Experience",
            description: "Customized facial treatment using premium organic skincare products. Includes skin analysis, deep cleansing, extraction, and hydrating mask.",
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!.addingTimeInterval(13 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!.addingTimeInterval(14.5 * 3600),
            location: "Spa & Wellness Center",
            locationDetail: "4th Floor, Treatment Room 3",
            organizer: EventOrganizer(name: "Sophie Chen", role: "Lead Esthetician", avatarSystemName: "person.crop.circle.fill"),
            attendees: [],
            totalSpots: 4,
            spotsLeft: 3,
            imageSystemName: "face.smiling.inverse",
            category: .spa,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Sophie Chen", role: .esthetician, bio: "Celebrity esthetician with 18 years experience. Former lead esthetician at Four Seasons Beverly Hills. Known for her 'glass skin' technique.", certifications: ["Licensed Esthetician", "Advanced Facial Certification", "Dermaplaning Certified"], specialties: ["Anti-aging facials", "Glass skin treatment", "Acne solutions", "LED therapy"])
                ],
                includedItems: ["90-minute treatment", "Skin analysis with digital imaging", "Deep cleansing & extractions", "Custom serum application", "LED light therapy", "Hydrating mask", "Eye treatment", "Take-home skincare samples"],
                whatToBring: ["Come with clean face, no makeup"],
                specialNotes: "Sophie will create a personalized skincare regimen based on your skin analysis. All products used are organic and cruelty-free (La Mer, SkinCeuticals, Augustinus Bader)."
            )
        ),
        ClubEvent(
            title: "Himalayan Salt Room Session",
            description: "Breathe easy in our Himalayan salt room. 45-minute session promotes respiratory health, reduces stress, and rejuvenates skin. Group session, reservations required.",
            date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!.addingTimeInterval(15 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!.addingTimeInterval(15.75 * 3600),
            location: "Spa & Wellness Center",
            locationDetail: "4th Floor, Salt Room",
            organizer: EventOrganizer(name: "Elena Martinez", role: "Spa Director", avatarSystemName: "person.crop.circle.fill"),
            attendees: [
                EventAttendee(name: "RelaxedApe", avatarSystemName: "person.crop.circle.fill", tokenId: "2468"),
            ],
            totalSpots: 8,
            spotsLeft: 5,
            imageSystemName: "mountain.2.fill",
            category: .spa,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Elena Martinez", role: .spaDirector, bio: "Wellness expert specializing in halotherapy and holistic treatments.", certifications: ["Halotherapy Certified", "Spa Management"], specialties: ["Salt therapy", "Respiratory wellness", "Holistic health"])
                ],
                includedItems: ["45-minute salt room session", "Reclining zero-gravity chair", "Himalayan salt air therapy", "Meditation guidance", "Post-session herbal tea"],
                whatToBring: ["Comfortable, light-colored clothing (salt may affect dark fabrics)"],
                specialNotes: "Salt therapy is excellent for allergies, asthma, and skin conditions. The room is kept at a comfortable 68°F with 50% humidity. Up to 8 guests per session creates a serene group experience."
            )
        ),
        // MARK: - Fitness Events
        ClubEvent(
            title: "Morning HIIT Class",
            description: "High-intensity interval training to kickstart your day. All fitness levels welcome. Towels and post-workout smoothies provided.",
            date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!.addingTimeInterval(7 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!.addingTimeInterval(8 * 3600),
            location: "Fitness Center",
            locationDetail: "3rd Floor, Studio A",
            organizer: EventOrganizer(name: "Mike Torres", role: "Head Trainer", avatarSystemName: "person.crop.circle.fill"),
            attendees: [],
            totalSpots: 15,
            spotsLeft: 8,
            imageSystemName: "figure.run",
            category: .fitness,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Mike Torres", role: .fitnessInstructor, bio: "Former professional athlete turned elite fitness coach. 10+ years training celebrities and executives. Known for high-energy, results-driven classes.", certifications: ["NASM-CPT", "CrossFit Level 3", "TRX Certified", "Precision Nutrition"], specialties: ["HIIT", "Strength training", "Athletic performance", "Weight loss"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "Post-workout nutrition",
                    menuHighlights: ["Protein smoothie bar", "Energy balls", "Fresh fruit"],
                    dietaryOptions: ["Vegan protein option", "Dairy-free"],
                    beverages: ["Protein smoothies", "Coconut water", "Electrolyte drinks"],
                    isOpenBar: false,
                    isIncluded: true
                ),
                includedItems: ["60-minute class", "All equipment provided", "Towel service", "Post-workout smoothie", "Shower facilities"],
                whatToBring: ["Athletic shoes", "Workout clothes", "Water bottle", "Positive attitude!"],
                dressCode: "Athletic wear",
                specialNotes: "Mike offers modifications for all fitness levels - beginners absolutely welcome! Arrive 10 minutes early for equipment setup."
            )
        ),
        ClubEvent(
            title: "Personal Training Session",
            description: "One-on-one training session with our certified personal trainers. Customized workout plan based on your goals. Equipment and post-workout nutrition included.",
            date: Calendar.current.date(byAdding: .day, value: 4, to: Date())!.addingTimeInterval(9 * 3600),
            endDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!.addingTimeInterval(10 * 3600),
            location: "Fitness Center",
            locationDetail: "3rd Floor, Private Training Area",
            organizer: EventOrganizer(name: "Mike Torres", role: "Head Trainer", avatarSystemName: "person.crop.circle.fill"),
            attendees: [],
            totalSpots: 3,
            spotsLeft: 2,
            imageSystemName: "dumbbell.fill",
            category: .fitness,
            rsvpStatus: .notResponded,
            details: EventDetails(
                staff: [
                    EventStaffMember(name: "Mike Torres", role: .personalTrainer, bio: "Elite personal trainer with celebrity clientele. Specializes in body transformation and strength building.", certifications: ["NASM-CPT", "CSCS", "CrossFit Level 3", "Corrective Exercise Specialist"], specialties: ["Strength training", "Body transformation", "Sports performance", "Injury prevention"]),
                    EventStaffMember(name: "Jessica Williams", role: .personalTrainer, bio: "Former professional dancer turned fitness coach. Expert in functional movement and flexibility.", certifications: ["ACE-CPT", "Yoga RYT-200", "Pilates Certified"], specialties: ["Functional fitness", "Flexibility", "Core strength", "Dance fitness"])
                ],
                foodAndBeverage: FoodAndBeverageInfo(
                    description: "Post-workout recovery nutrition",
                    menuHighlights: ["Custom protein shake", "Recovery snack"],
                    dietaryOptions: ["Vegan", "Dairy-free", "Low-carb options"],
                    beverages: ["Protein shakes", "BCAAs", "Coconut water"],
                    isOpenBar: false,
                    isIncluded: true
                ),
                includedItems: ["60-minute private session", "Fitness assessment", "Customized workout plan", "Body composition analysis", "Post-workout nutrition", "30-day program to continue at home"],
                whatToBring: ["Athletic shoes", "Workout clothes", "Any previous fitness assessments"],
                dressCode: "Athletic wear",
                specialNotes: "Your trainer will be assigned based on your goals. First session includes comprehensive fitness assessment and goal-setting discussion."
            )
        )
    ]
}

// MARK: - Event Database Helper

extension ClubEvent {
    /// Search events by category
    static func events(forCategory category: EventCategory) -> [ClubEvent] {
        sampleEvents.filter { $0.category == category }
    }

    /// Search events by keyword
    static func searchEvents(keyword: String) -> [ClubEvent] {
        let lowercased = keyword.lowercased()
        return sampleEvents.filter { event in
            event.title.lowercased().contains(lowercased) ||
            event.description.lowercased().contains(lowercased) ||
            event.location.lowercased().contains(lowercased) ||
            event.category.rawValue.lowercased().contains(lowercased)
        }
    }

    /// Find category from user query
    static func detectCategory(from query: String) -> EventCategory? {
        let lowercased = query.lowercased()
        for category in EventCategory.allCases {
            for keyword in category.keywords {
                if lowercased.contains(keyword) {
                    return category
                }
            }
        }
        return nil
    }

    /// Get upcoming events sorted by date
    static var upcomingEvents: [ClubEvent] {
        sampleEvents
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }
    }

    /// Get events available today
    static var todayEvents: [ClubEvent] {
        let calendar = Calendar.current
        return sampleEvents.filter { event in
            calendar.isDateInToday(event.date)
        }
    }

    /// Get events this week
    static var thisWeekEvents: [ClubEvent] {
        let calendar = Calendar.current
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: Date())!
        return sampleEvents.filter { event in
            event.date > Date() && event.date <= weekFromNow
        }.sorted { $0.date < $1.date }
    }
}
