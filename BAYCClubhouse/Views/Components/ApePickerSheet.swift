import SwiftUI

// The one NFT picker. Replaces the three previous implementations
// (NFTSelectorView, NFTAvatarPickerSheet, NFTPickerSheet) and their
// per-sheet cell/placeholder variants with a single sheet + cell.

struct ApePickerSheet: View {
    enum Mode {
        /// Choose the member's PFP/avatar — selects and dismisses.
        case avatar
        /// Choose an NFT whose image becomes the profile photo —
        /// downloads the image into `selectedImage`, then dismisses.
        case profilePhoto
        /// Browse the collection, no selection.
        case gallery
    }

    let mode: Mode
    var selectedImage: Binding<UIImage?>? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var loadingNFTId: String?

    private var brandGold: Color { Color(hex: "f39c12") }

    private var title: String {
        switch mode {
        case .avatar: return "SELECT PFP"
        case .profilePhoto: return "SELECT NFT"
        case .gallery: return "MY APES"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
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
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(authViewModel.ownedNFTs) { nft in
                                ApeCell(
                                    nft: nft,
                                    isSelected: mode != .gallery
                                        && authViewModel.selectedAvatarNFT?.id == nft.id,
                                    isLoading: loadingNFTId == nft.id,
                                    size: 140
                                ) {
                                    handleSelect(nft)
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
                    Button(mode == .gallery ? "Done" : "Cancel") {
                        dismiss()
                    }
                    .foregroundColor(brandGold)
                }

                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.55))

            Text("No NFTs Found")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.78))

            Text("Connect a wallet with BAYC or MAYC NFTs")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await authViewModel.fetchUserNFTs() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(brandGold)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassPill(interactive: true)
            }
            .padding(.top, 8)
        }
    }

    private func handleSelect(_ nft: NFTAsset) {
        switch mode {
        case .gallery:
            return

        case .avatar:
            withAnimation(.spring(response: 0.3)) {
                authViewModel.selectAvatar(nft)
            }
            dismiss()

        case .profilePhoto:
            loadingNFTId = nft.id
            authViewModel.selectAvatar(nft)

            Task {
                defer { Task { @MainActor in loadingNFTId = nil } }

                if let imageUrl = nft.imageUrl ?? nft.thumbnailUrl,
                   let url = URL(string: imageUrl),
                   let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage?.wrappedValue = image
                        dismiss()
                    }
                } else if let localAsset = nft.localAssetName,
                          let image = UIImage(named: localAsset) {
                    await MainActor.run {
                        selectedImage?.wrappedValue = image
                        dismiss()
                    }
                } else {
                    await MainActor.run { dismiss() }
                }
            }
        }
    }
}

// MARK: - The one ape cell

struct ApeCell: View {
    let nft: NFTAsset
    let isSelected: Bool
    var isLoading: Bool = false
    var size: CGFloat = 140
    let onSelect: () -> Void

    private var brandGold: Color { Color(hex: "f39c12") }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    apeImage

                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(brandGold, lineWidth: 3)
                            .frame(width: size, height: size)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: size > 100 ? 26 : 20))
                            .foregroundColor(brandGold)
                            .background(Circle().fill(Color.white))
                            .offset(x: size * 0.38, y: -size * 0.38)
                    }

                    if isLoading {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.5))
                            .frame(width: size, height: size)
                        ProgressView().tint(.white)
                    }
                }

                VStack(spacing: 2) {
                    Text(nft.collection.rawValue)
                        .font(.system(size: size > 100 ? 10 : 8, weight: .semibold, design: .rounded))
                        .foregroundColor(nft.collection == .bayc ? brandGold : Color(hex: "8b5cf6"))

                    Text("#\(nft.tokenId)")
                        .font(.system(size: size > 100 ? 13 : 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(size > 100 ? 12 : 8)
            .glassCard(
                cornerRadius: 20,
                tint: isSelected ? brandGold.opacity(0.2) : ClubhouseGlass.cardTint
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }

    @ViewBuilder
    private var apeImage: some View {
        if let localAsset = nft.localAssetName, UIImage(named: localAsset) != nil {
            Image(localAsset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if let imageUrl = nft.thumbnailUrl ?? nft.imageUrl,
                  let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                case .empty:
                    placeholder.overlay(ProgressView().tint(.white))
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "face.smiling")
                    .font(.system(size: size * 0.28))
                    .foregroundColor(.white.opacity(0.55))
            )
    }
}
