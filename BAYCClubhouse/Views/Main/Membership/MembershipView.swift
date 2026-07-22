import SwiftUI
import PassKit

struct MembershipView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var chatManager: ChatManager
    @State private var showQRCode = false
    @State private var showAppleWalletPreview = false
    @State private var showClubAccess = false
    @State private var showQuickAccess = false
    @State private var showSpaceBooking = false
    @State private var showFoodOrder = false
    @StateObject private var orderService = FoodOrderService.shared
    @StateObject private var bookingService = SpaceBookingService.shared
    @StateObject private var clubAccessService = ClubAccessService.shared

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
                        // Membership Card (Flippable)
                        MembershipCardView()

                        // Active Order Tracker (if order in progress)
                        OrderTrackerCard(orderService: orderService)

                        // Active Valet Tracker (if valet in progress)
                        ValetTrackerCard(clubAccess: clubAccessService)

                        // Active Space Booking (if booking active)
                        if let booking = bookingService.currentBooking, booking.isActive {
                            SpaceBookingCard(booking: booking)
                        }

                        // Club Access Section (NEW - prominent feature)
                        ClubAccessSection(showClubAccess: $showClubAccess)

                        // Quick Actions (with space booking and food order)
                        QuickActionsSection(
                            showQRCode: $showQRCode,
                            showClubAccess: $showClubAccess,
                            showSpaceBooking: $showSpaceBooking,
                            showFoodOrder: $showFoodOrder
                        )

                        // Apple Wallet Section
                        AppleWalletSection(showAppleWalletPreview: $showAppleWalletPreview)

                        // Chat with Concierge Section
                        ConciergeSection()

                        // Verification Info
                        VerificationInfoSection()

                        // Membership Benefits
                        MembershipBenefitsSection()

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
                    ToolbarTitleView(title: "MEMBERSHIP")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        QuickAccessPillButton(showQuickAccess: $showQuickAccess)

                        ChatToolbarButton()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showQRCode) {
                QRCodeView()
            }
            .sheet(isPresented: $showAppleWalletPreview) {
                AppleWalletPreviewView()
            }
            .sheet(isPresented: $showClubAccess) {
                ClubAccessView()
            }
            .sheet(isPresented: $showQuickAccess) {
                QuickAccessSheet()
            }
            .sheet(isPresented: $showSpaceBooking) {
                SpaceBookingView()
            }
            .sheet(isPresented: $showFoodOrder) {
                if orderService.currentOrder != nil {
                    CurrentTabSheet()
                } else {
                    FoodOrderView()
                }
            }
        }
    }
}

// MARK: - Membership Card (Flippable with NFT on back)

struct MembershipCardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isFlipped = false
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Your Membership Card")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            // Flippable Card Container
            ZStack {
                // Back of card (NFT Avatar)
                CardBackView()
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                // Front of card
                CardFrontView()
                    .opacity(isFlipped ? 0 : 1)
            }
            .frame(height: 200)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    rotation += 180
                    isFlipped.toggle()
                }
            }

            Text("Tap card to flip")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

struct CardFrontView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    private var tier: MembershipTier {
        authViewModel.membershipTier
    }

    private var collectionName: String {
        tier == .black ? "BAYC" : "MAYC"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BORED APE YACHT CLUB")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(tier.textColor.opacity(0.8))

                    Text("MIAMI CLUBHOUSE")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(tier.accentColor)
                }

                Spacer()

                // Membership Tier Badge
                HStack(spacing: 4) {
                    Image(systemName: tier.badgeIcon)
                        .font(.system(size: 12))
                    Text(tier.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                }
                .foregroundColor(tier == .black ? Color(hex: "f39c12") : Color(hex: "1a1a2e"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(tier == .black ? Color.white.opacity(0.15) : Color.white.opacity(0.9))
                )
            }
            .padding(20)

            Spacer()

            // Member info section
            HStack(alignment: .bottom) {
                // Profile Avatar
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 70, height: 70)

                    if let imageData = authViewModel.profileImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let avatarNFT = authViewModel.selectedAvatarNFT,
                              let localAsset = avatarNFT.localAssetName,
                              UIImage(named: localAsset) != nil {
                        // Use local asset from Assets.xcassets
                        Image(localAsset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let avatarNFT = authViewModel.selectedAvatarNFT,
                              let imageUrlString = avatarNFT.imageUrl,
                              let imageURL = URL(string: imageUrlString) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 36))
                                    .foregroundColor(tier.textColor.opacity(0.5))
                            @unknown default:
                                ProgressView()
                            }
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 36))
                            .foregroundColor(tier.textColor.opacity(0.5))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(authViewModel.userNickname ?? "APE MEMBER")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(tier.textColor)

                    Text("\(collectionName) #\(authViewModel.primaryNFTId ?? "0000")")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(tier.accentColor)

                    if let address = authViewModel.walletAddress {
                        Text(address.prefix(6) + "..." + address.suffix(4))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(tier.textColor.opacity(0.5))
                    }
                }

                Spacer()

                // Member badge
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundColor(tier.accentColor)

                    Text("VERIFIED")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(tier.accentColor)
                }
            }
            .padding(20)
        }
        .background(
            ZStack {
                // Tier-based gradient background
                LinearGradient(
                    colors: tier.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Pattern overlay
                GeometryReader { geo in
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(tier.accentColor.opacity(0.03))
                            .frame(width: 100, height: 100)
                            .offset(
                                x: CGFloat(i % 4) * 100 - 50,
                                y: CGFloat(i / 4) * 100
                            )
                    }
                }

                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial.opacity(0.3))

                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [tier.accentColor.opacity(0.6), tier.accentColor.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: tier.accentColor.opacity(0.3), radius: 20, y: 10)
    }
}

struct CardBackView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    private var tier: MembershipTier {
        authViewModel.membershipTier
    }

    private var collectionName: String {
        tier == .black ? "BAYC" : "MAYC"
    }

    private var collectionFullName: String {
        tier == .black ? "Bored Ape Yacht Club" : "Mutant Ape Yacht Club"
    }

    var body: some View {
        VStack(spacing: 0) {
            // NFT Avatar Display
            ZStack {
                // Large NFT image
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                // Show actual NFT image or profile image
                if let imageData = authViewModel.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else if let avatarNFT = authViewModel.selectedAvatarNFT,
                          let localAsset = avatarNFT.localAssetName,
                          UIImage(named: localAsset) != nil {
                    // Use local asset from Assets.xcassets
                    Image(localAsset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else if let avatarNFT = authViewModel.selectedAvatarNFT,
                          let imageUrlString = avatarNFT.imageUrl,
                          let imageURL = URL(string: imageUrlString) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            Image(systemName: "face.smiling")
                                .font(.system(size: 70))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [tier.accentColor, Color(hex: "e74c3c")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        @unknown default:
                            ProgressView()
                        }
                    }
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tier.accentColor, Color(hex: "e74c3c")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Collection badge
                VStack {
                    HStack {
                        Spacer()
                        Text(collectionName)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(tier.accentColor)
                            )
                    }
                    Spacer()
                }
                .frame(width: 140, height: 140)
                .padding(8)
            }
            .padding(.top, 20)

            Spacer()

            // Token info
            VStack(spacing: 4) {
                Text("#\(authViewModel.primaryNFTId ?? "0000")")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text(collectionFullName)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))

                // Tier badge
                HStack(spacing: 6) {
                    Image(systemName: tier.badgeIcon)
                        .font(.system(size: 12))
                    Text("\(tier.displayName) Member")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(tier.accentColor)
                .padding(.top, 8)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                LinearGradient(
                    colors: tier.gradientColors.reversed(),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial.opacity(0.3))

                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [tier.accentColor.opacity(0.6), tier.accentColor.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: tier.accentColor.opacity(0.3), radius: 20, y: 10)
    }
}

// MARK: - Quick Actions

// MARK: - Club Access Section

struct ClubAccessSection: View {
    @Binding var showClubAccess: Bool
    @StateObject private var accessService = ClubAccessService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Club Access")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                if accessService.isAtClubhouse {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("At Clubhouse")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.green)
                }
            }

            // Main access button
            Button {
                showClubAccess = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "8b5cf6"), Color(hex: "6366f1")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)

                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Entry, Locker & Valet")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("QR code, locker access, arrival notification")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(hex: "8b5cf6").opacity(0.3), lineWidth: 1)
                        )
                )
            }

            // Quick status cards
            HStack(spacing: 12) {
                // Locker status
                if let locker = accessService.currentLocker {
                    AccessQuickCard(
                        icon: "lock.fill",
                        title: "Locker \(locker.displayNumber)",
                        subtitle: locker.floor,
                        color: Color(hex: "3498db")
                    )
                }

                // Valet status
                if let valet = accessService.valetRequest {
                    AccessQuickCard(
                        icon: "car.fill",
                        title: valet.status.rawValue,
                        subtitle: valet.ticketNumber,
                        color: Color(hex: "f39c12")
                    )
                }

                // Arrival status
                if case .confirmed(let eta) = accessService.arrivalStatus {
                    AccessQuickCard(
                        icon: "location.fill",
                        title: "Arriving",
                        subtitle: "\(eta) min",
                        color: .green
                    )
                }
            }
        }
    }
}

struct AccessQuickCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct QuickActionsSection: View {
    @Binding var showQRCode: Bool
    @Binding var showClubAccess: Bool
    @Binding var showSpaceBooking: Bool
    @Binding var showFoodOrder: Bool
    @StateObject private var orderService = FoodOrderService.shared

    var body: some View {
        VStack(spacing: 12) {
            // First row: QR Code and Valet
            HStack(spacing: 12) {
                Button {
                    showQRCode = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 20))
                        Text("Show QR")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(hex: "f39c12").opacity(0.3))
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "f39c12").opacity(0.5), lineWidth: 1)
                        }
                    )
                }

                Button {
                    showClubAccess = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 20))
                        Text("Valet")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
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

            // Second row: Book Space and Order Food/Drinks
            HStack(spacing: 12) {
                Button {
                    showSpaceBooking = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 20))
                        Text("Book Space")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(hex: "3498db").opacity(0.3))
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "3498db").opacity(0.5), lineWidth: 1)
                        }
                    )
                }

                Button {
                    showFoodOrder = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: orderService.currentOrder != nil ? "takeoutbag.and.cup.and.straw.fill" : "fork.knife")
                            .font(.system(size: 20))
                        Text(orderService.currentOrder != nil ? "View Tab" : "Order")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        // Show item count badge if tab is open
                        if let order = orderService.currentOrder, !order.items.isEmpty {
                            Text("\(order.totalItems)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "1a1a2e"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "f39c12"))
                                )
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(hex: "e67e22").opacity(0.3))
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "e67e22").opacity(0.5), lineWidth: 1)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Apple Wallet Section with Preview

struct AppleWalletSection: View {
    @Binding var showAppleWalletPreview: Bool
    @StateObject private var passKitService = PassKitService.shared

    private var isPassAdded: Bool {
        passKitService.isPassAddedLocally()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Apple Wallet")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if isPassAdded {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("Added")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                    )
                }
            }

            Button {
                showAppleWalletPreview = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 28))
                        .foregroundColor(isPassAdded ? .green : .white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isPassAdded ? "View Wallet Pass" : "Add to Apple Wallet")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text(isPassAdded ? "NFC membership pass ready" : "Use NFC to verify membership at the door")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    if isPassAdded {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 20))
                            .foregroundColor(.green.opacity(0.8))
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "f39c12"))
                    }
                }
                .padding(18)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isPassAdded ? Color.green.opacity(0.1) : .black)
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: isPassAdded
                                        ? [Color.green.opacity(0.4), Color.green.opacity(0.1)]
                                        : [.white.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
            }
        }
    }
}

// MARK: - Apple Wallet Preview View

struct AppleWalletPreviewView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var passKitService = PassKitService.shared
    @State private var isAdding = false
    @State private var isAdded = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var tier: MembershipTier {
        authViewModel.membershipTier
    }

    private var collectionName: String {
        tier == .black ? "BAYC" : "MAYC"
    }

    var body: some View {
        ZStack {
            Color(hex: "1a1a2e")
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)

                Text("Add to Apple Wallet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Pass Preview
                VStack(spacing: 0) {
                    // Pass Header - tier-based color
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BAYC MIAMI")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(tier == .black ? .white : Color(hex: "1a1a2e"))
                            Text("CLUBHOUSE")
                                .font(.system(size: 10))
                                .foregroundColor(tier == .black ? .white.opacity(0.7) : Color(hex: "1a1a2e").opacity(0.7))
                        }

                        Spacer()

                        // Tier badge
                        HStack(spacing: 4) {
                            Image(systemName: tier.badgeIcon)
                                .font(.system(size: 10))
                            Text(tier.displayName)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(tier == .black ? Color(hex: "f39c12") : Color(hex: "1a1a2e"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(tier == .black ? Color.white.opacity(0.2) : Color.white.opacity(0.5))
                        )
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: tier.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                    // Pass Body
                    VStack(spacing: 16) {
                        // Profile Avatar
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)

                            if let imageData = authViewModel.profileImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if let avatarNFT = authViewModel.selectedAvatarNFT,
                                      let localAsset = avatarNFT.localAssetName,
                                      UIImage(named: localAsset) != nil {
                                Image(localAsset)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else if let avatarNFT = authViewModel.selectedAvatarNFT,
                                      let imageUrlString = avatarNFT.imageUrl,
                                      let imageURL = URL(string: imageUrlString) {
                                AsyncImage(url: imageURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure, .empty:
                                        Image(systemName: "face.smiling")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    @unknown default:
                                        ProgressView()
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            }
                        }

                        VStack(spacing: 4) {
                            Text(authViewModel.userNickname ?? "APE MEMBER")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)

                            Text("\(collectionName) #\(authViewModel.primaryNFTId ?? "0000")")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(tier.accentColor)

                            Text("Member #\(authViewModel.membershipNumber)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray)
                        }

                        // NFC indicator
                        HStack(spacing: 8) {
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text("NFC Enabled")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )

                        // Barcode
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black)
                            .frame(height: 60)
                            .overlay(
                                Image(systemName: "barcode")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                            .padding(.horizontal, 20)
                    }
                    .padding(20)
                    .background(Color.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: tier.accentColor.opacity(0.3), radius: 20, y: 10)
                .padding(.horizontal, 40)

                Spacer()

                // Add to Wallet Button
                if isAdded || passKitService.isPassAddedLocally() {
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)

                            Text("Added to Apple Wallet")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.green)
                        }

                        // NFC usage info
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .font(.system(size: 14))
                                Text("Hold your iPhone near the door reader")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 16)
                } else {
                    Button {
                        addToWallet()
                    } label: {
                        HStack(spacing: 12) {
                            if isAdding {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20))
                            }

                            Text(isAdding ? "Adding..." : "Add to Apple Wallet")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.black)
                        )
                    }
                    .padding(.horizontal, 40)
                    .disabled(isAdding)
                }

                Text("Your membership pass will be available in\nApple Wallet for NFC door access.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Check if pass was already added
            isAdded = passKitService.isPassAddedLocally()
        }
        .alert("Unable to Add Pass", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func addToWallet() {
        isAdding = true

        // Generate pass data
        let passData = passKitService.generateMembershipPassData(
            memberName: authViewModel.userNickname ?? "APE MEMBER",
            memberId: authViewModel.membershipNumber,
            tier: tier,
            tokenId: authViewModel.primaryNFTId,
            walletAddress: authViewModel.walletAddress
        )

        // Add to wallet
        passKitService.addPassToWallet(passData: passData) { result in
            DispatchQueue.main.async {
                isAdding = false

                switch result {
                case .success:
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isAdded = true
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Concierge Section

struct ConciergeSection: View {
    @EnvironmentObject var chatManager: ChatManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Concierge")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Button {
                chatManager.openChat()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chat with Concierge")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Get help with reservations, events & more")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Verification & Benefits (unchanged)

struct VerificationInfoSection: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    private var tier: MembershipTier {
        authViewModel.membershipTier
    }

    private var collectionName: String {
        tier == .black ? "BAYC" : "MAYC"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verification Status")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                VerificationRow(title: "Wallet Connected", subtitle: "Glyph Wallet via Privy", isVerified: true)
                VerificationRow(title: "\(collectionName) Ownership", subtitle: "Token #\(authViewModel.primaryNFTId ?? "0000") verified on-chain", isVerified: true)
                VerificationRow(title: "Cryptographic Signature", subtitle: "Membership proof signed", isVerified: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
        }
    }
}

struct VerificationRow: View {
    let title: String
    let subtitle: String
    let isVerified: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isVerified ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(isVerified ? .green : .white.opacity(0.3))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
    }
}

struct MembershipBenefitsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Membership Benefits")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 8) {
                BenefitRow(icon: "door.left.hand.open", text: "Priority clubhouse access")
                BenefitRow(icon: "ticket.fill", text: "Exclusive event invitations")
                BenefitRow(icon: "gift.fill", text: "Member-only merchandise")
                BenefitRow(icon: "person.2.fill", text: "Private networking areas")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "f39c12"))
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }
}

// MARK: - QR Code View

struct QRCodeView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    private var tier: MembershipTier {
        authViewModel.membershipTier
    }

    private var collectionName: String {
        tier == .black ? "BAYC" : "MAYC"
    }

    var body: some View {
        ZStack {
            Color(hex: "1a1a2e").ignoresSafeArea()

            VStack(spacing: 32) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 24) {
                    // Tier badge
                    HStack(spacing: 6) {
                        Image(systemName: tier.badgeIcon)
                            .font(.system(size: 12))
                        Text("\(tier.displayName.uppercased()) MEMBER")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .tracking(2)
                    }
                    .foregroundColor(tier.accentColor)

                    Text("SCAN TO VERIFY")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.7))

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white)
                            .frame(width: 260, height: 260)

                        Image(systemName: "qrcode")
                            .font(.system(size: 180))
                            .foregroundColor(.black)

                        // Small profile picture overlay
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 50, height: 50)

                                    if let imageData = authViewModel.profileImageData,
                                       let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "face.smiling")
                                            .font(.system(size: 24))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .offset(x: -15, y: -15)
                            }
                        }
                        .frame(width: 260, height: 260)
                    }
                    .shadow(color: tier.accentColor.opacity(0.4), radius: 30, y: 15)

                    VStack(spacing: 8) {
                        Text(authViewModel.userNickname ?? "APE MEMBER")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("\(collectionName) #\(authViewModel.primaryNFTId ?? "0000")")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(tier.accentColor)

                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill").font(.system(size: 10))
                            Text("Cryptographically signed").font(.system(size: 11, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 4)
                    }
                }

                Spacer()

                Text("Present this QR code at the clubhouse entrance.\nStaff will scan to verify your membership.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    MembershipView()
        .environmentObject(AuthViewModel())
        .environmentObject(ChatManager())
}
