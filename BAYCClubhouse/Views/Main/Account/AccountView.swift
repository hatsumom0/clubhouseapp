import SwiftUI
import PhotosUI

struct AccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatManager: ChatManager
    @State private var showEditProfile = false
    @State private var showQuickAccess = false

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

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 24) {
                        // Profile Header
                        ProfileHeaderCard()

                        // Connected Wallets Section
                        ConnectedWalletSection()

                        // Social Connections Section
                        SocialConnectionsSection()

                        // NFT Gallery Preview
                        NFTGallerySection()

                        // Settings Section
                        SettingsSection()

                        // Logout Button
                        LogoutButton()

                        Spacer()
                            .frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .scrollIndicators(.visible)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarTitleView(title: "ACCOUNT")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        QuickAccessPillButton(showQuickAccess: $showQuickAccess)

                        ChatToolbarButton()

                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: "f39c12"))
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditProfile) {
                ProfileEditView()
            }
            .sheet(isPresented: $showQuickAccess) {
                QuickAccessSheet()
            }
        }
    }
}

struct ProfileHeaderCard: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    private var profileImage: UIImage? {
        if let data = authViewModel.profileImageData {
            return UIImage(data: data)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "f39c12").opacity(0.3),
                                Color(hex: "e74c3c").opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 116, height: 116)
                        .clipShape(Circle())
                } else {
                    // Placeholder avatar
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }

            // Name and wallet
            VStack(spacing: 8) {
                Text(authViewModel.userNickname ?? "Set Nickname")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Bio
                if let bio = authViewModel.userBio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                }

                if let walletAddress = authViewModel.walletAddress {
                    HStack(spacing: 6) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 12))

                        Text(walletAddress.prefix(6) + "..." + walletAddress.suffix(4))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }

            // Member since badge
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "f39c12"))

                Text("Member since 2024")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(hex: "f39c12").opacity(0.2))
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.05))

                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
    }
}

struct ConnectedWalletSection: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Wallet")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "8b5cf6").opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "8b5cf6"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Glyph Wallet")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    if let address = authViewModel.walletAddress {
                        Text(address.prefix(8) + "..." + address.suffix(6))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct SocialConnectionsSection: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Socials")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                SocialConnectionRow(
                    platform: "X (Twitter)",
                    icon: "bird.fill",
                    username: authViewModel.xHandle ?? "Not connected",
                    isConnected: authViewModel.xHandle != nil && !authViewModel.xHandle!.isEmpty,
                    color: Color.white
                )

                SocialConnectionRow(
                    platform: "Instagram",
                    icon: "camera.fill",
                    username: authViewModel.instagramHandle ?? "Not connected",
                    isConnected: authViewModel.instagramHandle != nil && !authViewModel.instagramHandle!.isEmpty,
                    color: Color(hex: "E1306C")
                )

                SocialConnectionRow(
                    platform: "Bluesky",
                    icon: "cloud.fill",
                    username: authViewModel.blueskyHandle ?? "Not connected",
                    isConnected: authViewModel.blueskyHandle != nil && !authViewModel.blueskyHandle!.isEmpty,
                    color: Color(hex: "0085FF")
                )

                if authViewModel.kakaoId != nil && !authViewModel.kakaoId!.isEmpty {
                    SocialConnectionRow(
                        platform: "KakaoTalk",
                        icon: "message.fill",
                        username: authViewModel.kakaoId!,
                        isConnected: true,
                        color: Color(hex: "FEE500")
                    )
                }

                if authViewModel.wechatId != nil && !authViewModel.wechatId!.isEmpty {
                    SocialConnectionRow(
                        platform: "WeChat",
                        icon: "bubble.left.and.bubble.right.fill",
                        username: authViewModel.wechatId!,
                        isConnected: true,
                        color: Color(hex: "07C160")
                    )
                }
            }
        }
    }
}

struct SocialConnectionRow: View {
    let platform: String
    let icon: String
    let username: String
    let isConnected: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(platform)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(username)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            } else {
                Text("Connect")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "f39c12"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(hex: "f39c12").opacity(0.2))
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct NFTGallerySection: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingNFTSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your NFTs")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    showingNFTSelector = true
                } label: {
                    Text("Select PFP")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "f39c12"))
                }
            }

            if authViewModel.ownedNFTs.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No NFTs found")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))

                    Text("Connect a wallet with BAYC or MAYC NFTs")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(authViewModel.ownedNFTs) { nft in
                            NFTPreviewCard(
                                nft: nft,
                                isSelected: authViewModel.selectedAvatarNFT?.id == nft.id,
                                onSelect: {
                                    withAnimation(.spring(response: 0.3)) {
                                        authViewModel.selectAvatar(nft)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNFTSelector) {
            NFTSelectorView()
        }
    }
}

struct NFTPreviewCard: View {
    let nft: NFTAsset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // NFT Image
                ZStack {
                    if let localAsset = nft.localAssetName, UIImage(named: localAsset) != nil {
                        Image(localAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else if let imageUrlString = nft.imageUrl, let imageURL = URL(string: imageUrlString) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            case .failure(_):
                                NFTPlaceholder()
                            case .empty:
                                NFTPlaceholder()
                                    .overlay(ProgressView().tint(.white))
                            @unknown default:
                                NFTPlaceholder()
                            }
                        }
                    } else {
                        NFTPlaceholder()
                    }

                    // Selected checkmark
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "f39c12"))
                                .frame(width: 28, height: 28)

                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 35, y: -35)
                    }
                }
                .frame(width: 100, height: 100)

                VStack(spacing: 2) {
                    Text(nft.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    if isSelected {
                        Text("Current PFP")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "f39c12"))
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isSelected ? Color(hex: "f39c12") : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NFTPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "face.smiling")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

// MARK: - NFT Selector View

struct NFTSelectorView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

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

                if authViewModel.ownedNFTs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No NFTs Found")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Connect a wallet with BAYC or MAYC NFTs to select your profile picture")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("Select an NFT as your profile picture. This will be displayed on your membership card.")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(authViewModel.ownedNFTs) { nft in
                                    NFTSelectorCard(
                                        nft: nft,
                                        isSelected: authViewModel.selectedAvatarNFT?.id == nft.id,
                                        onSelect: {
                                            withAnimation(.spring(response: 0.3)) {
                                                authViewModel.selectAvatar(nft)
                                            }
                                            dismiss()
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SELECT PFP")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "f39c12"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct NFTSelectorCard: View {
    let nft: NFTAsset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // NFT Image
                ZStack {
                    if let localAsset = nft.localAssetName, UIImage(named: localAsset) != nil {
                        Image(localAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if let imageUrlString = nft.imageUrl, let imageURL = URL(string: imageUrlString) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            case .failure(_):
                                NFTSelectorPlaceholder()
                            case .empty:
                                NFTSelectorPlaceholder()
                                    .overlay(ProgressView().tint(.white))
                            @unknown default:
                                NFTSelectorPlaceholder()
                            }
                        }
                    } else {
                        NFTSelectorPlaceholder()
                    }

                    // Selected indicator
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "f39c12"), lineWidth: 3)
                            .frame(width: 140, height: 140)

                        ZStack {
                            Circle()
                                .fill(Color(hex: "f39c12"))
                                .frame(width: 32, height: 32)

                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 50, y: -50)
                    }
                }

                VStack(spacing: 4) {
                    Text(nft.displayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(nft.collection.displayName)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))

                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Current PFP")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "f39c12"))
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? Color(hex: "f39c12") : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NFTSelectorPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 140, height: 140)
            .overlay(
                Image(systemName: "face.smiling")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

struct SettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 2) {
                SettingsRow(icon: "bell.fill", title: "Notifications", hasToggle: true)
                SettingsRow(icon: "lock.fill", title: "Privacy", hasToggle: false)
                SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", hasToggle: false)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let hasToggle: Bool
    @State private var isOn = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "f39c12"))
                .frame(width: 24)

            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            if hasToggle {
                Toggle("", isOn: $isOn)
                    .tint(Color(hex: "f39c12"))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
    }
}

struct LogoutButton: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Button {
            authViewModel.logout()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))

                Text("Disconnect Wallet")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

struct ProfileEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    // Profile fields
    @State private var nickname: String = ""
    @State private var bio: String = ""

    // Social links
    @State private var xHandle: String = ""
    @State private var instagramHandle: String = ""
    @State private var kakaoId: String = ""
    @State private var wechatId: String = ""
    @State private var blueskyHandle: String = ""

    // Photo picker
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingPhotoOptions = false
    @State private var showingNFTPicker = false

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

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 24) {
                        // Profile Photo Section
                        ProfilePhotoEditSection(
                            selectedImage: $selectedImage,
                            showingPhotoOptions: $showingPhotoOptions
                        )

                        // Basic Info Section
                        BasicInfoSection(nickname: $nickname, bio: $bio)

                        // Social Links Section
                        SocialLinksEditSection(
                            xHandle: $xHandle,
                            instagramHandle: $instagramHandle,
                            kakaoId: $kakaoId,
                            wechatId: $wechatId,
                            blueskyHandle: $blueskyHandle
                        )

                        // NFT Avatar Section
                        NFTAvatarSection()

                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .scrollIndicators(.visible)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "f39c12"))
                }

                ToolbarItem(placement: .principal) {
                    Text("EDIT PROFILE")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "f39c12"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .confirmationDialog("Change Profile Photo", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
                Button("Take Photo") {
                    showingCamera = true
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("Choose from Library")
                }

                Button("Select from NFTs") {
                    showingNFTPicker = true
                }

                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingNFTPicker) {
                NFTPickerSheet(selectedImage: $selectedImage)
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
            }
            .onAppear {
                loadCurrentProfile()
            }
        }
    }

    private func loadCurrentProfile() {
        nickname = authViewModel.userNickname ?? ""
        bio = authViewModel.userBio ?? ""
        xHandle = authViewModel.xHandle ?? ""
        instagramHandle = authViewModel.instagramHandle ?? ""
        blueskyHandle = authViewModel.blueskyHandle ?? ""
        kakaoId = authViewModel.kakaoId ?? ""
        wechatId = authViewModel.wechatId ?? ""

        // Load profile image
        if let imageData = authViewModel.profileImageData,
           let image = UIImage(data: imageData) {
            selectedImage = image
        }
    }

    private func saveProfile() {
        // Save nickname
        authViewModel.setNickname(nickname)

        // Save bio
        authViewModel.setBio(bio)

        // Save social links
        authViewModel.setSocialLinks(
            x: xHandle,
            instagram: instagramHandle,
            bluesky: blueskyHandle,
            kakao: kakaoId,
            wechat: wechatId
        )

        // Save profile image
        if let image = selectedImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            authViewModel.setProfileImage(imageData)
        }
    }
}

// MARK: - Profile Photo Edit Section

struct ProfilePhotoEditSection: View {
    @Binding var selectedImage: UIImage?
    @Binding var showingPhotoOptions: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "f39c12").opacity(0.3),
                                Color(hex: "e74c3c").opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 116, height: 116)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Edit button
                Button {
                    showingPhotoOptions = true
                } label: {
                    Circle()
                        .fill(Color(hex: "f39c12"))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                }
                .offset(x: 42, y: 42)
            }

            Text("Tap to change photo")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Basic Info Section

struct BasicInfoSection: View {
    @Binding var nickname: String
    @Binding var bio: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Info")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 14) {
                // Nickname field
                ProfileTextField(
                    icon: "person.fill",
                    placeholder: "Nickname",
                    text: $nickname
                )

                // Bio field
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "f39c12"))
                            .frame(width: 24)

                        Text("Bio")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    TextEditor(text: $bio)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            Group {
                                if bio.isEmpty {
                                    Text("Tell us about yourself...")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Social Links Edit Section

struct SocialLinksEditSection: View {
    @Binding var xHandle: String
    @Binding var instagramHandle: String
    @Binding var kakaoId: String
    @Binding var wechatId: String
    @Binding var blueskyHandle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Social Links")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                SocialLinkField(
                    platform: "X (Twitter)",
                    icon: "bird.fill",
                    color: .white,
                    placeholder: "@username",
                    text: $xHandle
                )

                SocialLinkField(
                    platform: "Instagram",
                    icon: "camera.fill",
                    color: Color(hex: "E1306C"),
                    placeholder: "@username",
                    text: $instagramHandle
                )

                SocialLinkField(
                    platform: "Bluesky",
                    icon: "cloud.fill",
                    color: Color(hex: "0085FF"),
                    placeholder: "@handle.bsky.social",
                    text: $blueskyHandle
                )

                SocialLinkField(
                    platform: "KakaoTalk",
                    icon: "message.fill",
                    color: Color(hex: "FEE500"),
                    placeholder: "Kakao ID",
                    text: $kakaoId
                )

                SocialLinkField(
                    platform: "WeChat",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: Color(hex: "07C160"),
                    placeholder: "WeChat ID",
                    text: $wechatId
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct SocialLinkField: View {
    let platform: String
    let icon: String
    let color: Color
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(platform)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                TextField(placeholder, text: $text)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            Spacer()

            if !text.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProfileTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "f39c12"))
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - NFT Avatar Section

struct NFTAvatarSection: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingNFTPicker = false

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Select NFT as Avatar")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    showingNFTPicker = true
                } label: {
                    Text("View All")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(brandGold)
                }
            }

            if authViewModel.ownedNFTs.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No NFTs found")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(authViewModel.ownedNFTs.prefix(6)) { nft in
                            NFTAvatarOption(
                                nft: nft,
                                isSelected: authViewModel.selectedAvatarNFT?.id == nft.id
                            ) {
                                authViewModel.selectAvatar(nft)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNFTPicker) {
            NFTAvatarPickerSheet()
        }
    }
}

struct NFTAvatarPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(authViewModel.ownedNFTs) { nft in
                            NFTAvatarOption(
                                nft: nft,
                                isSelected: authViewModel.selectedAvatarNFT?.id == nft.id
                            ) {
                                authViewModel.selectAvatar(nft)
                                dismiss()
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(brandGold)
                }
                ToolbarItem(placement: .principal) {
                    Text("MY NFTS")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct NFTAvatarOption: View {
    let nft: NFTAsset
    let isSelected: Bool
    let onSelect: () -> Void

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    // NFT Image
                    if let localAsset = nft.localAssetName {
                        Image(localAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if let imageUrl = nft.thumbnailUrl ?? nft.imageUrl,
                              let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            case .failure, .empty:
                                placeholderView
                            @unknown default:
                                placeholderView
                            }
                        }
                    } else {
                        placeholderView
                    }

                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(brandGold, lineWidth: 3)
                            .frame(width: 80, height: 80)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(brandGold)
                            .background(Circle().fill(Color.white))
                            .offset(x: 32, y: -32)
                    }
                }

                VStack(spacing: 1) {
                    Text(nft.collection.rawValue)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(nft.collection == .bayc ? brandGold : Color(hex: "8b5cf6"))

                    Text("#\(nft.tokenId)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? brandGold.opacity(0.15) : Color.clear)
            )
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - NFT Picker Sheet

struct NFTPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var loadingNFTId: String?

    private var brandGold: Color { Color(hex: "f39c12") }

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

                if authViewModel.ownedNFTs.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No NFTs Found")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))

                        Text("Connect your wallet to see your BAYC and MAYC NFTs")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button {
                            Task {
                                await authViewModel.fetchUserNFTs()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(brandGold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .stroke(brandGold, lineWidth: 1)
                            )
                        }
                        .padding(.top, 8)
                    }
                } else {
                    // NFT Grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(authViewModel.ownedNFTs) { nft in
                                NFTPickerCard(
                                    nft: nft,
                                    isSelected: authViewModel.selectedAvatarNFT?.id == nft.id,
                                    isLoading: loadingNFTId == nft.id
                                ) {
                                    selectNFT(nft)
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(brandGold)
                }

                ToolbarItem(placement: .principal) {
                    Text("SELECT NFT")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func selectNFT(_ nft: NFTAsset) {
        loadingNFTId = nft.id

        // Select this NFT as avatar in AuthViewModel
        authViewModel.selectAvatar(nft)

        // Load the NFT image as profile photo
        Task {
            if let imageUrl = nft.imageUrl ?? nft.thumbnailUrl,
               let url = URL(string: imageUrl) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                            loadingNFTId = nil
                            dismiss()
                        }
                    }
                } catch {
                    print("Failed to load NFT image: \(error)")
                    await MainActor.run {
                        loadingNFTId = nil
                    }
                }
            } else if let localAsset = nft.localAssetName,
                      let image = UIImage(named: localAsset) {
                // Use local asset if available
                await MainActor.run {
                    selectedImage = image
                    loadingNFTId = nil
                    dismiss()
                }
            } else {
                await MainActor.run {
                    loadingNFTId = nil
                    dismiss()
                }
            }
        }
    }
}

struct NFTPickerCard: View {
    let nft: NFTAsset
    let isSelected: Bool
    let isLoading: Bool
    let onSelect: () -> Void

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 10) {
                ZStack {
                    // NFT Image
                    if let localAsset = nft.localAssetName {
                        Image(localAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if let imageUrl = nft.thumbnailUrl ?? nft.imageUrl,
                              let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 140, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            case .failure:
                                placeholderView
                            case .empty:
                                ProgressView()
                                    .frame(width: 140, height: 140)
                            @unknown default:
                                placeholderView
                            }
                        }
                    } else {
                        placeholderView
                    }

                    // Selection overlay
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(brandGold, lineWidth: 3)
                            .frame(width: 140, height: 140)

                        // Checkmark badge
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(brandGold)
                                    .background(Circle().fill(Color.white).padding(4))
                            }
                            Spacer()
                        }
                        .frame(width: 140, height: 140)
                        .padding(6)
                    }

                    // Loading overlay
                    if isLoading {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 140, height: 140)

                        ProgressView()
                            .tint(.white)
                    }
                }

                // NFT Info
                VStack(spacing: 2) {
                    Text(nft.collection.rawValue)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(nft.collection == .bayc ? brandGold : Color(hex: "8b5cf6"))

                    Text("#\(nft.tokenId)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? brandGold.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? brandGold.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .disabled(isLoading)
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 140, height: 140)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

#Preview {
    AccountView()
        .environmentObject(AuthViewModel())
        .environmentObject(ChatManager())
}
