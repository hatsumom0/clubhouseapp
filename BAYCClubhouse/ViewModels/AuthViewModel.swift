import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var hasCompletedOnboarding = false
    @Published var walletAddress: String?
    @Published var userNickname: String?
    @Published var userBio: String?
    @Published var profileImageData: Data?
    @Published var primaryNFTId: String?
    @Published var ownedNFTs: [NFTAsset] = []
    @Published var selectedAvatarNFT: NFTAsset?
    @Published var isLoading = false
    @Published var error: Error?

    // Social links
    @Published var xHandle: String?
    @Published var instagramHandle: String?
    @Published var blueskyHandle: String?
    @Published var kakaoId: String?
    @Published var wechatId: String?

    // Membership tier - computed based on NFT holdings
    var membershipTier: MembershipTier {
        // Check if user has BAYC (Black tier) or only MAYC (Platinum tier)
        let hasBAYC = ownedNFTs.contains { $0.collection == .bayc }
        return hasBAYC ? .black : .platinum
    }

    var membershipNumber: String {
        // Generate a membership number based on wallet
        if let wallet = walletAddress {
            let hash = wallet.hash
            return String(format: "%08d", abs(hash) % 100000000)
        }
        return "00000000"
    }

    // MARK: - Services
    private let glyphService = GlyphService()
    private let alchemyService = AlchemyService()

    // Proof-of-ownership signature returned by Glyph at sign-in
    @Published var membershipSignature: String?
    @Published var membershipSignedMessage: String?

    // MARK: - Storage Keys
    private enum StorageKeys {
        static let walletAddress = "wallet_address"
        static let nickname = "user_nickname"
        static let bio = "user_bio"
        static let profileImage = "profile_image_data"
        static let primaryNFT = "primary_nft_id"
        static let hasOnboarded = "has_completed_onboarding"
        static let selectedAvatarId = "selected_avatar_nft_id"
        static let xHandle = "social_x_handle"
        static let instagramHandle = "social_instagram_handle"
        static let blueskyHandle = "social_bluesky_handle"
        static let kakaoId = "social_kakao_id"
        static let wechatId = "social_wechat_id"
    }

    // MARK: - Init
    init() {
        // UI tests exercise the sign-in flow from a clean slate
        if CommandLine.arguments.contains("--uitest-reset-auth") {
            clearPersistedData()
        }
        loadPersistedData()
    }

    // MARK: - Authentication Methods

    func connectWithGlyph() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            // Real Glyph sign-in (web bridge running @use-glyph/sdk-react)
            let session = try await glyphService.signIn()
            walletAddress = session.address
            membershipSignature = session.signature
            membershipSignedMessage = session.message

            // Fetch owned NFTs
            await fetchUserNFTs()

            // Check if user owns BAYC or MAYC
            guard !ownedNFTs.isEmpty else {
                throw AuthError.noEligibleNFTs
            }

            // Set primary NFT
            if let firstNFT = ownedNFTs.first {
                primaryNFTId = firstNFT.tokenId
            }

            // Persist data
            persistData()

            // Set authenticated
            isAuthenticated = true

            // Check if onboarding is complete
            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: StorageKeys.hasOnboarded)

        } catch {
            self.error = error
            throw error
        }
    }

    func logout() {
        // Clear local data (the Glyph web session persists in the browser
        // cookie jar, so re-login is one tap; use Glyph's own UI to fully
        // sign out of Glyph itself)
        membershipSignature = nil
        membershipSignedMessage = nil
        isAuthenticated = false
        hasCompletedOnboarding = false
        walletAddress = nil
        userNickname = nil
        userBio = nil
        profileImageData = nil
        primaryNFTId = nil
        ownedNFTs = []
        selectedAvatarNFT = nil
        xHandle = nil
        instagramHandle = nil
        blueskyHandle = nil
        kakaoId = nil
        wechatId = nil

        // Clear persisted data
        clearPersistedData()
    }

    // MARK: - NFT Methods

    func fetchUserNFTs() async {
        guard let address = walletAddress else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let nfts = try await alchemyService.fetchOwnedNFTs(for: address)
            ownedNFTs = nfts

            // Restore selected avatar if exists, otherwise select first NFT
            if let savedAvatarId = UserDefaults.standard.string(forKey: StorageKeys.selectedAvatarId) {
                selectedAvatarNFT = nfts.first { $0.tokenId == savedAvatarId }
            }

            // Auto-select first NFT if no avatar selected yet
            if selectedAvatarNFT == nil, let firstNFT = nfts.first {
                selectAvatar(firstNFT)
            }
        } catch {
            self.error = error
            print("Failed to fetch NFTs: \(error)")
        }
    }

    // MARK: - Profile Methods

    func setNickname(_ nickname: String) {
        userNickname = nickname.isEmpty ? nil : nickname
        UserDefaults.standard.set(nickname, forKey: StorageKeys.nickname)
    }

    func setBio(_ bio: String) {
        userBio = bio.isEmpty ? nil : bio
        UserDefaults.standard.set(bio, forKey: StorageKeys.bio)
    }

    func setProfileImage(_ imageData: Data?) {
        profileImageData = imageData
        if let data = imageData {
            UserDefaults.standard.set(data, forKey: StorageKeys.profileImage)
        } else {
            UserDefaults.standard.removeObject(forKey: StorageKeys.profileImage)
        }
    }

    func setSocialLinks(
        x: String?,
        instagram: String?,
        bluesky: String?,
        kakao: String?,
        wechat: String?
    ) {
        xHandle = x?.isEmpty == true ? nil : x
        instagramHandle = instagram?.isEmpty == true ? nil : instagram
        blueskyHandle = bluesky?.isEmpty == true ? nil : bluesky
        kakaoId = kakao?.isEmpty == true ? nil : kakao
        wechatId = wechat?.isEmpty == true ? nil : wechat

        UserDefaults.standard.set(x, forKey: StorageKeys.xHandle)
        UserDefaults.standard.set(instagram, forKey: StorageKeys.instagramHandle)
        UserDefaults.standard.set(bluesky, forKey: StorageKeys.blueskyHandle)
        UserDefaults.standard.set(kakao, forKey: StorageKeys.kakaoId)
        UserDefaults.standard.set(wechat, forKey: StorageKeys.wechatId)
    }

    func selectAvatar(_ nft: NFTAsset) {
        selectedAvatarNFT = nft
        primaryNFTId = nft.tokenId
        UserDefaults.standard.set(nft.tokenId, forKey: StorageKeys.selectedAvatarId)
        UserDefaults.standard.set(nft.tokenId, forKey: StorageKeys.primaryNFT)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: StorageKeys.hasOnboarded)
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        if let address = UserDefaults.standard.string(forKey: StorageKeys.walletAddress) {
            walletAddress = address
            userNickname = UserDefaults.standard.string(forKey: StorageKeys.nickname)
            userBio = UserDefaults.standard.string(forKey: StorageKeys.bio)
            profileImageData = UserDefaults.standard.data(forKey: StorageKeys.profileImage)
            primaryNFTId = UserDefaults.standard.string(forKey: StorageKeys.primaryNFT)
            hasCompletedOnboarding = UserDefaults.standard.bool(forKey: StorageKeys.hasOnboarded)

            // Load social links
            xHandle = UserDefaults.standard.string(forKey: StorageKeys.xHandle)
            instagramHandle = UserDefaults.standard.string(forKey: StorageKeys.instagramHandle)
            blueskyHandle = UserDefaults.standard.string(forKey: StorageKeys.blueskyHandle)
            kakaoId = UserDefaults.standard.string(forKey: StorageKeys.kakaoId)
            wechatId = UserDefaults.standard.string(forKey: StorageKeys.wechatId)

            // A persisted wallet address means a prior Glyph sign-in — restore
            // the session locally and refresh NFT holdings in the background.
            isAuthenticated = true
            Task {
                await fetchUserNFTs()
            }
        }
    }

    private func persistData() {
        if let address = walletAddress {
            UserDefaults.standard.set(address, forKey: StorageKeys.walletAddress)
        }
        if let nickname = userNickname {
            UserDefaults.standard.set(nickname, forKey: StorageKeys.nickname)
        }
        if let nftId = primaryNFTId {
            UserDefaults.standard.set(nftId, forKey: StorageKeys.primaryNFT)
        }
    }

    private func clearPersistedData() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.walletAddress)
        UserDefaults.standard.removeObject(forKey: StorageKeys.nickname)
        UserDefaults.standard.removeObject(forKey: StorageKeys.bio)
        UserDefaults.standard.removeObject(forKey: StorageKeys.profileImage)
        UserDefaults.standard.removeObject(forKey: StorageKeys.primaryNFT)
        UserDefaults.standard.removeObject(forKey: StorageKeys.hasOnboarded)
        UserDefaults.standard.removeObject(forKey: StorageKeys.selectedAvatarId)
        UserDefaults.standard.removeObject(forKey: StorageKeys.xHandle)
        UserDefaults.standard.removeObject(forKey: StorageKeys.instagramHandle)
        UserDefaults.standard.removeObject(forKey: StorageKeys.blueskyHandle)
        UserDefaults.standard.removeObject(forKey: StorageKeys.kakaoId)
        UserDefaults.standard.removeObject(forKey: StorageKeys.wechatId)
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case noEligibleNFTs
    case walletConnectionFailed
    case signatureFailed

    var errorDescription: String? {
        switch self {
        case .noEligibleNFTs:
            return "No BAYC or MAYC NFTs found in your wallet. Membership requires owning at least one eligible NFT."
        case .walletConnectionFailed:
            return "Failed to connect wallet. Please try again."
        case .signatureFailed:
            return "Failed to sign verification message. Please try again."
        }
    }
}
