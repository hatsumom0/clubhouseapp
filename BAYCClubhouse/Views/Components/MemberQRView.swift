import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

// The one member QR. Single source of truth for entry credentials:
// a real CIFilter-generated QR over ClubAccessService's signed payload,
// auto-rotating every 5 minutes. Replaces the decorative SF-Symbol "QR"
// that the old Membership sheet showed, and the duplicate generator that
// lived in ClubAccessView.

/// Embeddable QR panel — used inline in Club Access and inside MemberQRSheet.
struct MemberQRView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var accessService = ClubAccessService.shared
    @State private var qrCodeString: String = ""
    @State private var timeRemaining: Int = 300

    var qrSize: CGFloat = 220

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            // QR Code
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .frame(width: qrSize, height: qrSize)

                if let qrImage = Self.generateQRCode(from: qrCodeString, size: qrSize - 20) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: qrSize - 20, height: qrSize - 20)
                }
            }
            .shadow(color: Color(hex: "f39c12").opacity(0.3), radius: 20, y: 10)

            // Member info + refresh
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "f39c12"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(authViewModel.userNickname ?? "Member")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(authViewModel.membershipTier.displayName) Member")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.78))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Refreshes in")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))

                    Text(formatTime(timeRemaining))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(timeRemaining < 60 ? .orange : Color(hex: "f39c12"))
                }

                Button {
                    refreshQRCode()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "f39c12"))
                        .padding(10)
                }
                .glassCircle(tint: Color(hex: "f39c12").opacity(0.3), interactive: true)
            }

            // Security note
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                Text("Cryptographically signed • Single use")
                    .font(.system(size: 11, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.65))
        }
        .onAppear { refreshQRCode() }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                refreshQRCode()
            }
        }
    }

    private func refreshQRCode() {
        let memberData = MemberQRData(
            memberId: authViewModel.walletAddress ?? UUID().uuidString,
            walletAddress: authViewModel.walletAddress ?? "",
            tokenId: authViewModel.primaryNFTId,
            tier: authViewModel.membershipTier,
            nickname: authViewModel.userNickname
        )
        qrCodeString = accessService.refreshQRCode(for: memberData)
        timeRemaining = 300
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func generateQRCode(from string: String, size: CGFloat) -> UIImage? {
        guard !string.isEmpty else { return nil }
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"

        guard let outputImage = filter.outputImage else { return nil }

        let scale = size / outputImage.extent.size.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}

/// Full-screen presentation — what "Show QR" opens.
struct MemberQRSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    private var tier: MembershipTier { authViewModel.membershipTier }
    private var collectionName: String { tier == .black ? "BAYC" : "MAYC" }

    var body: some View {
        ZStack {
            Color(hex: "1a1a2e").ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.78))
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

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

                MemberQRView(qrSize: 260)
                    .padding(.horizontal, 32)

                Text("\(collectionName) #\(authViewModel.primaryNFTId ?? "0000")")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(tier.accentColor)

                Spacer()

                Text("Present this QR code at the clubhouse entrance.\nStaff will scan to verify your membership.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
    }
}
