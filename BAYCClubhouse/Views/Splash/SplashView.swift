import SwiftUI

struct SplashView: View {
    @Binding var showSplash: Bool
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background gradient - BAYC inspired colors
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

            // Animated background particles (subtle)
            GeometryReader { geo in
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: CGFloat.random(in: 20...60))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .blur(radius: 10)
                }
            }

            VStack(spacing: 40) {
                Spacer()

                // Logo area - Liquid Glass style container
                VStack(spacing: 24) {
                    // Placeholder logo with glass effect
                    ZStack {
                        // Glass background
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.ultraThinMaterial)
                            .frame(width: 160, height: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.4), .clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

                        // BAYC Logo
                        Image("LaunchLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    // Title with Liquid Glass styling
                    VStack(spacing: 8) {
                        Text("BORED APE")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .tracking(4)
                            .foregroundColor(.white)

                        Text("YACHT CLUB")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(6)
                            .foregroundColor(.white.opacity(0.9))

                        Text("MIAMI CLUBHOUSE")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .tracking(3)
                            .foregroundColor(Color(hex: "f39c12"))
                            .padding(.top, 4)
                    }
                    .opacity(titleOpacity)
                }

                Spacer()

                // For Members Button - Floating Liquid Glass style
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSplash = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("FOR MEMBERS")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .tracking(2)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 20)
                    .glassCard(
                        cornerRadius: 28,
                        tint: Color(hex: "f39c12").opacity(0.55),
                        interactive: true
                    )
                    .shadow(color: Color(hex: "f39c12").opacity(0.4), radius: 20, y: 10)
                }
                .opacity(buttonOpacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Staggered animations
            withAnimation(.easeOut(duration: 0.8)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                titleOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                buttonOpacity = 1.0
            }
        }
    }
}

// Color extension for hex values
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    SplashView(showSplash: .constant(true))
}
