import Foundation

/// Service for fetching NFT data from Alchemy API
/// Documentation: https://docs.alchemy.com/reference/nft-api-quickstart
class AlchemyService {
    // MARK: - Properties
    private let baseURL = Constants.URLs.alchemyBaseURL
    private let apiKey = Constants.API.alchemyApiKey

    private var session: URLSession {
        URLSession.shared
    }

    // MARK: - Public Methods

    /// Fetch all BAYC and MAYC NFTs owned by an address
    func fetchOwnedNFTs(for address: String) async throws -> [NFTAsset] {
        // Fetch both BAYC and MAYC in parallel
        async let baycNFTs = fetchNFTsForContract(
            address: address,
            contractAddress: Constants.Contracts.bayc,
            collection: .bayc
        )
        async let maycNFTs = fetchNFTsForContract(
            address: address,
            contractAddress: Constants.Contracts.mayc,
            collection: .mayc
        )

        let (bayc, mayc) = try await (baycNFTs, maycNFTs)
        return bayc + mayc
    }

    /// Verify ownership of a specific NFT
    func verifyOwnership(walletAddress: String, contractAddress: String, tokenId: String) async throws -> Bool {
        // Use Alchemy's isOwner endpoint
        // TODO: Implement actual API call
        // For now, check if the token is in the owner's list
        let nfts = try await fetchOwnedNFTs(for: walletAddress)
        return nfts.contains { $0.tokenId == tokenId && $0.contractAddress.lowercased() == contractAddress.lowercased() }
    }

    // MARK: - Private Methods

    private func fetchNFTsForContract(
        address: String,
        contractAddress: String,
        collection: NFTAsset.NFTCollection
    ) async throws -> [NFTAsset] {
        // Build URL for Alchemy getNFTsForOwner endpoint
        guard var components = URLComponents(string: "\(baseURL)/\(apiKey)/getNFTsForOwner") else {
            throw AlchemyError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "owner", value: address),
            URLQueryItem(name: "contractAddresses[]", value: contractAddress),
            URLQueryItem(name: "withMetadata", value: "true")
        ]

        guard let url = components.url else {
            throw AlchemyError.invalidURL
        }

        // For development, return mock data
        // TODO: Enable actual API calls in production
        #if DEBUG
        if Constants.API.alchemyApiKey == "YOUR_ALCHEMY_API_KEY" {
            return getMockNFTs(for: collection)
        }
        #endif

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AlchemyError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw AlchemyError.apiError(statusCode: httpResponse.statusCode)
        }

        let alchemyResponse = try JSONDecoder().decode(AlchemyNFTResponse.self, from: data)
        return alchemyResponse.ownedNfts.map { nft in
            mapToNFTAsset(nft, collection: collection)
        }
    }

    private func mapToNFTAsset(_ alchemyNFT: AlchemyNFT, collection: NFTAsset.NFTCollection) -> NFTAsset {
        NFTAsset(
            id: "\(collection.rawValue.lowercased())-\(alchemyNFT.tokenId)",
            tokenId: alchemyNFT.tokenId,
            contractAddress: alchemyNFT.contract.address,
            collection: collection,
            name: alchemyNFT.name ?? "\(collection.rawValue) #\(alchemyNFT.tokenId)",
            imageUrl: alchemyNFT.image?.cachedUrl ?? alchemyNFT.image?.originalUrl,
            thumbnailUrl: alchemyNFT.image?.thumbnailUrl,
            localAssetName: nil,
            attributes: alchemyNFT.raw?.metadata?.attributes?.map { attr in
                NFTAttribute(traitType: attr.traitType, value: attr.value)
            } ?? []
        )
    }

    private func getMockNFTs(for collection: NFTAsset.NFTCollection) -> [NFTAsset] {
        // Return mock data for development
        switch collection {
        case .bayc:
            return [NFTAsset.mockBAYC]
        case .mayc:
            return [NFTAsset.mockMAYC]
        case .unknown:
            return []
        }
    }
}

// MARK: - Alchemy API Response Models

struct AlchemyNFTResponse: Codable {
    let ownedNfts: [AlchemyNFT]
    let totalCount: Int
    let pageKey: String?
}

struct AlchemyNFT: Codable {
    let contract: AlchemyContract
    let tokenId: String
    let tokenType: String?
    let name: String?
    let description: String?
    let image: AlchemyImage?
    let raw: AlchemyRawMetadata?
}

struct AlchemyContract: Codable {
    let address: String
    let name: String?
    let symbol: String?
}

struct AlchemyImage: Codable {
    let cachedUrl: String?
    let thumbnailUrl: String?
    let originalUrl: String?
}

struct AlchemyRawMetadata: Codable {
    let metadata: AlchemyMetadata?
}

struct AlchemyMetadata: Codable {
    let attributes: [AlchemyAttribute]?
}

struct AlchemyAttribute: Codable {
    let traitType: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case traitType = "trait_type"
        case value
    }
}

// MARK: - Errors

enum AlchemyError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int)
    case noNFTsFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from Alchemy API"
        case .apiError(let statusCode):
            return "Alchemy API error: HTTP \(statusCode)"
        case .noNFTsFound:
            return "No eligible NFTs found in this wallet"
        }
    }
}
