import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var currentStep = 0
    @State private var nickname = ""
    @State private var selectedNFT: NFTAsset?

    private let totalSteps = 3

    var body: some View {
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

            VStack(spacing: 0) {
                // Progress indicator
                ProgressHeader(currentStep: currentStep, totalSteps: totalSteps)
                    .padding(.top, 20)

                // Step content
                TabView(selection: $currentStep) {
                    NicknameStep(nickname: $nickname)
                        .tag(0)

                    AvatarSelectionStep(selectedNFT: $selectedNFT)
                        .tag(1)

                    SocialConnectionStep()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Navigation buttons
                NavigationButtons(
                    currentStep: $currentStep,
                    totalSteps: totalSteps,
                    canProceed: canProceedFromCurrentStep,
                    onComplete: completeSetup
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private var canProceedFromCurrentStep: Bool {
        switch currentStep {
        case 0:
            return !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return selectedNFT != nil
        case 2:
            return true // Social connections are optional
        default:
            return true
        }
    }

    private func completeSetup() {
        authViewModel.setNickname(nickname)
        if let nft = selectedNFT {
            authViewModel.selectAvatar(nft)
        }
        authViewModel.completeOnboarding()
    }
}

// MARK: - Progress Header

struct ProgressHeader: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 16) {
            // Step indicators
            HStack(spacing: 12) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color(hex: "f39c12") : Color.white.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 40)

            // Step title
            Text(stepTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Create Your Profile"
        case 1: return "Choose Your Avatar"
        case 2: return "Connect Socials"
        default: return ""
        }
    }
}

// MARK: - Nickname Step

struct NicknameStep: View {
    @Binding var nickname: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)

                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("What should we call you?")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                Text("This will be displayed on your membership card")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Nickname input
            VStack(spacing: 8) {
                TextField("", text: $nickname, prompt: Text("Enter nickname").foregroundColor(.white.opacity(0.3)))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        isFocused ? Color(hex: "f39c12") : Color.white.opacity(0.1),
                                        lineWidth: isFocused ? 2 : 1
                                    )
                            )
                    )

                Text("\(nickname.count)/20 characters")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Avatar Selection Step

struct AvatarSelectionStep: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var selectedNFT: NFTAsset?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 20)

            Text("Select your profile avatar from your NFTs")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // NFT Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(authViewModel.ownedNFTs) { nft in
                        AvatarNFTCard(
                            nft: nft,
                            isSelected: selectedNFT?.id == nft.id
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedNFT = nft
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
    }
}

struct AvatarNFTCard: View {
    let nft: NFTAsset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // NFT Image placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "2d3436"), Color(hex: "636e72")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(1, contentMode: .fit)

                    Image(systemName: "face.smiling")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.3))

                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "f39c12"), lineWidth: 3)

                        // Checkmark
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color(hex: "f39c12"))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }

                VStack(spacing: 4) {
                    Text(nft.collection.rawValue)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "f39c12"))

                    Text("#\(nft.tokenId)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? Color(hex: "f39c12").opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Social Connection Step

struct SocialConnectionStep: View {
    @State private var twitterConnected = false
    @State private var instagramConnected = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)

                Image(systemName: "link.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("Connect your socials")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))

                Text("Optional - You can always do this later")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Social buttons
            VStack(spacing: 16) {
                SocialConnectButton(
                    platform: "X (Twitter)",
                    icon: "bird.fill",
                    color: .white,
                    isConnected: twitterConnected
                ) {
                    // TODO: Implement Twitter OAuth
                    twitterConnected = true
                }

                SocialConnectButton(
                    platform: "Instagram",
                    icon: "camera.fill",
                    color: Color(hex: "E1306C"),
                    isConnected: instagramConnected
                ) {
                    // TODO: Implement Instagram OAuth
                    instagramConnected = true
                }
            }
            .padding(.horizontal, 30)

            Spacer()
            Spacer()
        }
    }
}

struct SocialConnectButton: View {
    let platform: String
    let icon: String
    let color: Color
    let isConnected: Bool
    let onConnect: () -> Void

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                Text(platform)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                if isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                } else {
                    Text("Connect")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "f39c12"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color(hex: "f39c12").opacity(0.2))
                        )
                }
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
        .buttonStyle(PlainButtonStyle())
        .disabled(isConnected)
    }
}

// MARK: - Navigation Buttons

struct NavigationButtons: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let canProceed: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Back button
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                    )
                }
            }

            Spacer()

            // Next/Complete button
            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    onComplete()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentStep < totalSteps - 1 ? "Next" : "Complete")
                    Image(systemName: currentStep < totalSteps - 1 ? "chevron.right" : "checkmark")
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            canProceed
                                ? LinearGradient(
                                    colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                )
                .shadow(color: canProceed ? Color(hex: "f39c12").opacity(0.4) : .clear, radius: 10, y: 5)
            }
            .disabled(!canProceed)
        }
    }
}

#Preview {
    ProfileSetupView()
        .environmentObject(AuthViewModel())
}
