import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""

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

            // Animated background elements
            GeometryReader { geo in
                ForEach(0..<15, id: \.self) { i in
                    Circle()
                        .fill(Color(hex: "f39c12").opacity(0.03))
                        .frame(width: CGFloat.random(in: 50...150))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .blur(radius: 20)
                }
            }

            VStack(spacing: 40) {
                Spacer()

                // Logo and branding
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(.clear)
                            .frame(width: 120, height: 120)
                            .glassCircle()

                        Image(systemName: "face.smiling")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "f39c12"), Color(hex: "e74c3c")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: Color(hex: "f39c12").opacity(0.3), radius: 20, y: 10)

                    VStack(spacing: 8) {
                        Text("BAYC MIAMI")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .tracking(4)
                            .foregroundColor(.white)

                        Text("CLUBHOUSE")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .tracking(6)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Connect wallet section
                VStack(spacing: 24) {
                    Text("Connect your wallet to verify\nBAYC or MAYC membership")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    // Glyph Wallet Button
                    Button {
                        connectWithGlyph()
                    } label: {
                        HStack(spacing: 14) {
                            // Glyph icon placeholder
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "8b5cf6").opacity(0.3))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "diamond.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "8b5cf6"))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign in with Glyph")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                Text("X, email or wallet")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            if isConnecting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "8b5cf6"))
                            }
                        }
                        .padding(16)
                        .glassCard(
                            cornerRadius: 22,
                            tint: Color(hex: "8b5cf6").opacity(0.35),
                            interactive: true
                        )
                        .shadow(color: Color(hex: "8b5cf6").opacity(0.3), radius: 15, y: 8)
                    }
                    .disabled(isConnecting)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(height: 1)

                        Text("or")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 12)

                        Rectangle()
                            .fill(.white.opacity(0.1))
                            .frame(height: 1)
                    }

                    // Other wallet options
                    Button {
                        connectWithOtherWallet()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 18))

                            Text("Other Wallet")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .glassCard(cornerRadius: 18)
                    }
                    .disabled(isConnecting)
                }
                .padding(.horizontal, 30)

                Spacer()

                // Footer info
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))

                        Text("Secure wallet connection via Glyph")
                            .font(.system(size: 12, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.4))

                    Text("By connecting, you agree to our Terms of Service")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.bottom, 40)
            }
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func connectWithGlyph() {
        isConnecting = true

        Task {
            do {
                try await authViewModel.connectWithGlyph()
            } catch GlyphError.cancelled {
                // User closed the sign-in sheet — not an error worth an alert.
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isConnecting = false
        }
    }

    private func connectWithOtherWallet() {
        // Glyph's login page includes external-wallet options, so this routes
        // through the same bridge.
        connectWithGlyph()
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
