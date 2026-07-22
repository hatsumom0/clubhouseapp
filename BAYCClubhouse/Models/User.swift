import Foundation

struct User: Codable, Identifiable {
    let id: String
    var walletAddress: String
    var nickname: String?
    var avatarNFTId: String?
    var primaryNFTId: String?
    var connectedSocials: ConnectedSocials
    var memberSince: Date
    var lastActive: Date

    struct ConnectedSocials: Codable {
        var twitter: SocialConnection?
        var instagram: SocialConnection?

        struct SocialConnection: Codable {
            let platform: String
            let username: String
            let profileUrl: String?
            let connectedAt: Date
        }
    }

    var displayName: String {
        nickname ?? "Ape #\(primaryNFTId ?? "????")"
    }
}

// MARK: - Mock Data

extension User {
    static let mock = User(
        id: UUID().uuidString,
        walletAddress: "0x1234567890abcdef1234567890abcdef12345678",
        nickname: "DiamondHands",
        avatarNFTId: "1234",
        primaryNFTId: "1234",
        connectedSocials: ConnectedSocials(
            twitter: ConnectedSocials.SocialConnection(
                platform: "twitter",
                username: "@apehodler",
                profileUrl: "https://x.com/apehodler",
                connectedAt: Date()
            ),
            instagram: nil
        ),
        memberSince: Date().addingTimeInterval(-86400 * 365),
        lastActive: Date()
    )
}
