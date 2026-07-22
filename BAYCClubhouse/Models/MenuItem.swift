import Foundation
import SwiftUI

// MARK: - Menu Item Model

struct MenuItem: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let price: Double
    let category: MenuCategory
    let prepTime: Int  // minutes
    let imageSystemName: String
    let isAvailable: Bool

    init(id: UUID = UUID(), name: String, description: String, price: Double, category: MenuCategory, prepTime: Int, imageSystemName: String, isAvailable: Bool = true) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.category = category
        self.prepTime = prepTime
        self.imageSystemName = imageSystemName
        self.isAvailable = isAvailable
    }

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }

    // MARK: - Menu Categories

    enum MenuCategory: String, Codable, CaseIterable {
        case appetizers = "Appetizers"
        case mains = "Mains"
        case sides = "Sides"
        case cocktails = "Cocktails"
        case wine = "Wine"
        case beer = "Beer"
        case spirits = "Spirits"
        case nonAlcoholic = "Non-Alcoholic"
        case desserts = "Desserts"

        var icon: String {
            switch self {
            case .appetizers: return "leaf.fill"
            case .mains: return "fork.knife"
            case .sides: return "square.stack.fill"
            case .cocktails: return "wineglass"
            case .wine: return "wineglass.fill"
            case .beer: return "mug.fill"
            case .spirits: return "drop.fill"
            case .nonAlcoholic: return "cup.and.saucer.fill"
            case .desserts: return "birthday.cake.fill"
            }
        }

        var color: Color {
            switch self {
            case .appetizers: return Color(hex: "27ae60")
            case .mains: return Color(hex: "e74c3c")
            case .sides: return Color(hex: "f39c12")
            case .cocktails: return Color(hex: "9b59b6")
            case .wine: return Color(hex: "8e44ad")
            case .beer: return Color(hex: "d35400")
            case .spirits: return Color(hex: "2c3e50")
            case .nonAlcoholic: return Color(hex: "3498db")
            case .desserts: return Color(hex: "e91e63")
            }
        }

        var requiresAgeVerification: Bool {
            switch self {
            case .cocktails, .wine, .beer, .spirits: return true
            default: return false
            }
        }
    }
}

// MARK: - Sample Menu Data

extension MenuItem {
    static let sampleMenu: [MenuItem] = [
        // MARK: - Appetizers
        MenuItem(
            name: "Truffle Fries",
            description: "Hand-cut fries, parmesan, truffle oil, fresh herbs",
            price: 14,
            category: .appetizers,
            prepTime: 8,
            imageSystemName: "leaf.fill"
        ),
        MenuItem(
            name: "Ahi Tuna Tartare",
            description: "Sushi-grade tuna, avocado, sesame, wonton crisps",
            price: 22,
            category: .appetizers,
            prepTime: 10,
            imageSystemName: "fish.fill"
        ),
        MenuItem(
            name: "Lobster Bisque",
            description: "Creamy lobster soup, cognac, chive oil",
            price: 18,
            category: .appetizers,
            prepTime: 5,
            imageSystemName: "drop.fill"
        ),
        MenuItem(
            name: "Wagyu Sliders",
            description: "Three mini wagyu burgers, caramelized onions, gruyère",
            price: 28,
            category: .appetizers,
            prepTime: 12,
            imageSystemName: "circle.grid.2x1.fill"
        ),

        // MARK: - Mains
        MenuItem(
            name: "Clubhouse Burger",
            description: "Prime angus beef, aged cheddar, bacon, house sauce, brioche bun",
            price: 24,
            category: .mains,
            prepTime: 15,
            imageSystemName: "fork.knife"
        ),
        MenuItem(
            name: "Grilled Ribeye",
            description: "16oz USDA prime ribeye, herb butter, seasonal vegetables",
            price: 58,
            category: .mains,
            prepTime: 22,
            imageSystemName: "flame.fill"
        ),
        MenuItem(
            name: "Chilean Sea Bass",
            description: "Miso-glazed sea bass, bok choy, ginger-lime sauce",
            price: 48,
            category: .mains,
            prepTime: 18,
            imageSystemName: "fish.fill"
        ),
        MenuItem(
            name: "Lobster Roll",
            description: "Maine lobster, drawn butter, toasted brioche roll",
            price: 42,
            category: .mains,
            prepTime: 12,
            imageSystemName: "water.waves"
        ),
        MenuItem(
            name: "Chicken Milanese",
            description: "Crispy pounded chicken, arugula, cherry tomatoes, lemon vinaigrette",
            price: 32,
            category: .mains,
            prepTime: 16,
            imageSystemName: "leaf.arrow.circlepath"
        ),

        // MARK: - Sides
        MenuItem(
            name: "Roasted Asparagus",
            description: "Grilled asparagus, hollandaise, shaved parmesan",
            price: 12,
            category: .sides,
            prepTime: 6,
            imageSystemName: "leaf.fill"
        ),
        MenuItem(
            name: "Loaded Baked Potato",
            description: "Sour cream, bacon, chives, aged cheddar",
            price: 10,
            category: .sides,
            prepTime: 5,
            imageSystemName: "oval.fill"
        ),
        MenuItem(
            name: "Mac & Cheese",
            description: "Four-cheese blend, truffle, breadcrumb crust",
            price: 14,
            category: .sides,
            prepTime: 8,
            imageSystemName: "square.fill.text.grid.1x2"
        ),

        // MARK: - Cocktails
        MenuItem(
            name: "Cosmopolitan",
            description: "Vodka, Cointreau, lime juice, cranberry",
            price: 18,
            category: .cocktails,
            prepTime: 4,
            imageSystemName: "wineglass"
        ),
        MenuItem(
            name: "Old Fashioned",
            description: "Bourbon, Angostura bitters, sugar, orange peel",
            price: 20,
            category: .cocktails,
            prepTime: 4,
            imageSystemName: "cup.and.saucer"
        ),
        MenuItem(
            name: "Espresso Martini",
            description: "Vodka, Kahlúa, fresh espresso, vanilla",
            price: 19,
            category: .cocktails,
            prepTime: 5,
            imageSystemName: "cup.and.saucer.fill"
        ),
        MenuItem(
            name: "Miami Vice",
            description: "Rum, piña colada, strawberry daiquiri swirl",
            price: 22,
            category: .cocktails,
            prepTime: 6,
            imageSystemName: "tropicalstorm"
        ),
        MenuItem(
            name: "Aperol Spritz",
            description: "Aperol, prosecco, soda, orange slice",
            price: 16,
            category: .cocktails,
            prepTime: 3,
            imageSystemName: "sun.max.fill"
        ),
        MenuItem(
            name: "Mojito",
            description: "White rum, mint, lime, sugar, soda",
            price: 16,
            category: .cocktails,
            prepTime: 4,
            imageSystemName: "leaf.fill"
        ),
        MenuItem(
            name: "Margarita",
            description: "Tequila, Cointreau, lime, salt rim",
            price: 17,
            category: .cocktails,
            prepTime: 4,
            imageSystemName: "drop.triangle.fill"
        ),
        MenuItem(
            name: "Negroni",
            description: "Gin, Campari, sweet vermouth, orange peel",
            price: 18,
            category: .cocktails,
            prepTime: 3,
            imageSystemName: "circle.hexagongrid.fill"
        ),

        // MARK: - Wine
        MenuItem(
            name: "Veuve Clicquot",
            description: "Champagne, France - Bottle",
            price: 180,
            category: .wine,
            prepTime: 2,
            imageSystemName: "wineglass.fill"
        ),
        MenuItem(
            name: "Dom Pérignon",
            description: "Champagne, France - Bottle",
            price: 450,
            category: .wine,
            prepTime: 2,
            imageSystemName: "wineglass.fill"
        ),
        MenuItem(
            name: "Caymus Cabernet",
            description: "Napa Valley, California - Glass",
            price: 28,
            category: .wine,
            prepTime: 2,
            imageSystemName: "wineglass.fill"
        ),
        MenuItem(
            name: "Whispering Angel Rosé",
            description: "Provence, France - Glass",
            price: 18,
            category: .wine,
            prepTime: 2,
            imageSystemName: "wineglass.fill"
        ),

        // MARK: - Beer
        MenuItem(
            name: "Stella Artois",
            description: "Belgian lager, draft",
            price: 9,
            category: .beer,
            prepTime: 2,
            imageSystemName: "mug.fill"
        ),
        MenuItem(
            name: "Local IPA",
            description: "Rotating local craft IPA",
            price: 11,
            category: .beer,
            prepTime: 2,
            imageSystemName: "mug.fill"
        ),
        MenuItem(
            name: "Corona Extra",
            description: "Mexican lager, served with lime",
            price: 8,
            category: .beer,
            prepTime: 2,
            imageSystemName: "mug.fill"
        ),

        // MARK: - Spirits
        MenuItem(
            name: "Macallan 18",
            description: "Single malt scotch, neat",
            price: 45,
            category: .spirits,
            prepTime: 1,
            imageSystemName: "drop.fill"
        ),
        MenuItem(
            name: "Clase Azul Reposado",
            description: "Premium tequila, neat or on rocks",
            price: 55,
            category: .spirits,
            prepTime: 1,
            imageSystemName: "drop.fill"
        ),

        // MARK: - Non-Alcoholic
        MenuItem(
            name: "Virgin Mojito",
            description: "Mint, lime, sugar, soda - refreshing & alcohol-free",
            price: 10,
            category: .nonAlcoholic,
            prepTime: 3,
            imageSystemName: "leaf.fill"
        ),
        MenuItem(
            name: "Fresh Lemonade",
            description: "House-squeezed lemonade, mint garnish",
            price: 8,
            category: .nonAlcoholic,
            prepTime: 2,
            imageSystemName: "drop.fill"
        ),
        MenuItem(
            name: "Espresso",
            description: "Double shot, Italian roast",
            price: 5,
            category: .nonAlcoholic,
            prepTime: 2,
            imageSystemName: "cup.and.saucer.fill"
        ),
        MenuItem(
            name: "San Pellegrino",
            description: "Sparkling mineral water, 750ml",
            price: 8,
            category: .nonAlcoholic,
            prepTime: 1,
            imageSystemName: "drop.fill"
        ),

        // MARK: - Desserts
        MenuItem(
            name: "Chocolate Lava Cake",
            description: "Warm chocolate cake, molten center, vanilla gelato",
            price: 14,
            category: .desserts,
            prepTime: 12,
            imageSystemName: "birthday.cake.fill"
        ),
        MenuItem(
            name: "Key Lime Pie",
            description: "Classic Miami style, graham crust, whipped cream",
            price: 12,
            category: .desserts,
            prepTime: 3,
            imageSystemName: "circle.fill"
        ),
        MenuItem(
            name: "Crème Brûlée",
            description: "Classic vanilla custard, caramelized sugar top",
            price: 13,
            category: .desserts,
            prepTime: 5,
            imageSystemName: "flame.fill"
        ),
        MenuItem(
            name: "Gelato Trio",
            description: "Three scoops: pistachio, stracciatella, amarena",
            price: 11,
            category: .desserts,
            prepTime: 2,
            imageSystemName: "snowflake"
        )
    ]

    static func menuByCategory() -> [MenuCategory: [MenuItem]] {
        Dictionary(grouping: sampleMenu, by: { $0.category })
    }

    static func search(_ query: String) -> [MenuItem] {
        guard !query.isEmpty else { return sampleMenu }
        let lowercased = query.lowercased()
        return sampleMenu.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.description.lowercased().contains(lowercased) ||
            $0.category.rawValue.lowercased().contains(lowercased)
        }
    }

    static func findByName(_ name: String) -> MenuItem? {
        let lowercased = name.lowercased()
        return sampleMenu.first {
            $0.name.lowercased() == lowercased ||
            $0.name.lowercased().contains(lowercased)
        }
    }
}
