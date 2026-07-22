import Foundation

struct NFTAsset: Identifiable, Codable, Equatable {
    let id: String
    let tokenId: String
    let contractAddress: String
    let collection: NFTCollection
    let name: String
    let imageUrl: String?
    let thumbnailUrl: String?
    let localAssetName: String? // For bundled images in Assets.xcassets
    let attributes: [NFTAttribute]

    enum NFTCollection: String, Codable {
        case bayc = "BAYC"
        case mayc = "MAYC"
        case unknown = "Unknown"

        var displayName: String {
            switch self {
            case .bayc: return "Bored Ape Yacht Club"
            case .mayc: return "Mutant Ape Yacht Club"
            case .unknown: return "Unknown Collection"
            }
        }

        var contractAddress: String {
            switch self {
            case .bayc: return Constants.Contracts.bayc
            case .mayc: return Constants.Contracts.mayc
            case .unknown: return ""
            }
        }
    }

    var displayName: String {
        "\(collection.rawValue) #\(tokenId)"
    }

    static func == (lhs: NFTAsset, rhs: NFTAsset) -> Bool {
        lhs.id == rhs.id
    }
}

struct NFTAttribute: Codable, Identifiable {
    var id: String { "\(traitType)-\(value)" }
    let traitType: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case traitType = "trait_type"
        case value
    }
}

// MARK: - Mock Data for Development

extension NFTAsset {
    static let mockBAYC = NFTAsset(
        id: "bayc-7246",
        tokenId: "7246",
        contractAddress: Constants.Contracts.bayc,
        collection: .bayc,
        name: "Bored Ape #7246",
        imageUrl: "https://gateway.pinata.cloud/ipfs/QmdkuSoZRijjbh2RWzD9xus9oBizPRq2ZqQeQL6axFmzbK",
        thumbnailUrl: "https://gateway.pinata.cloud/ipfs/QmdkuSoZRijjbh2RWzD9xus9oBizPRq2ZqQeQL6axFmzbK",
        localAssetName: "7246", // Local asset in Assets.xcassets
        attributes: [
            NFTAttribute(traitType: "Background", value: "Orange"),
            NFTAttribute(traitType: "Fur", value: "Brown"),
            NFTAttribute(traitType: "Eyes", value: "Bored"),
            NFTAttribute(traitType: "Clothes", value: "Striped Tee"),
            NFTAttribute(traitType: "Mouth", value: "Bored Unshaven")
        ]
    )

    static let mockMAYC = NFTAsset(
        id: "mayc-5678",
        tokenId: "5678",
        contractAddress: Constants.Contracts.mayc,
        collection: .mayc,
        name: "Mutant Ape #5678",
        imageUrl: "https://i.seadn.io/gcs/files/3831f264c52b7a8e79b680fc5b54e24c.png?w=500",
        thumbnailUrl: "https://i.seadn.io/gcs/files/3831f264c52b7a8e79b680fc5b54e24c.png?w=500",
        localAssetName: nil,
        attributes: [
            NFTAttribute(traitType: "Background", value: "Gray"),
            NFTAttribute(traitType: "Fur", value: "Zombie"),
            NFTAttribute(traitType: "Eyes", value: "Laser Eyes"),
            NFTAttribute(traitType: "Mouth", value: "Bored Unshaven")
        ]
    )

    static let mockCollection: [NFTAsset] = [
        mockBAYC,
        mockMAYC
    ]
}
