import AuthenticationServices
import Foundation
import UIKit

/// Real Glyph (ApeChain wallet by Yuga Labs) sign-in for native iOS.
///
/// Glyph ships no native SDK — only `@use-glyph/sdk-react` for web — so the
/// app opens a small self-hosted web bridge (glyph-auth-bridge/ in this repo)
/// inside `ASWebAuthenticationSession`. The bridge runs the actual Glyph SDK
/// (login via X, email, or wallet — Privy cross-app under the hood), asks the
/// connected wallet to sign a membership-proof message, then redirects to
/// `baycclubhouse://glyph-auth` with the address + signature, which completes
/// the session here.
@MainActor
final class GlyphService: NSObject {

    struct GlyphSession {
        let address: String
        /// Every wallet on the Glyph account: embedded + smart wallet +
        /// wallets the member linked to their Glyph profile.
        let allWallets: [String]
        let signature: String?
        /// The exact plaintext that was signed (EIP-191 personal_sign).
        let message: String?
        let nonce: String
    }

    private var webAuthSession: ASWebAuthenticationSession?

    // MARK: - Sign in

    func signIn() async throws -> GlyphSession {
        let nonce = Self.randomNonce()

        guard var components = URLComponents(string: Constants.Glyph.bridgeURL) else {
            throw GlyphError.invalidBridgeURL
        }
        components.queryItems = [
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "callback", value: Constants.Glyph.callbackURL),
        ]
        guard let bridgeURL = components.url else {
            throw GlyphError.invalidBridgeURL
        }

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: bridgeURL,
                callbackURLScheme: Constants.Glyph.callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: GlyphError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? GlyphError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            // Keep cookies so returning members skip the Glyph login step.
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session

            if !session.start() {
                continuation.resume(throwing: GlyphError.sessionFailedToStart)
            }
        }

        return try Self.parseCallback(callbackURL, expectedNonce: nonce)
    }

    func cancel() {
        webAuthSession?.cancel()
        webAuthSession = nil
    }

    // MARK: - Signature verification

    /// Server-side cryptographic verification of the membership proof.
    /// The bridge Worker's /verify endpoint recovers the signer (EOA) or
    /// checks ERC-1271/6492 (smart wallets) and must confirm it matches
    /// the claimed address. Fails closed: any error rejects the login.
    func verifySignature(address: String, message: String, signature: String) async throws -> Bool {
        guard let url = URL(string: Constants.Glyph.bridgeURL + "/verify") else {
            throw GlyphError.invalidBridgeURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(
            ["address": address, "message": message, "signature": signature]
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GlyphError.verificationUnavailable
        }

        struct VerifyResponse: Decodable {
            let valid: Bool
            let method: String?
        }
        return try JSONDecoder().decode(VerifyResponse.self, from: data).valid
    }

    // MARK: - Callback parsing

    static func parseCallback(_ url: URL, expectedNonce: String) throws -> GlyphSession {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GlyphError.invalidCallback
        }
        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            params[item.name] = item.value
        }

        guard let address = params["address"],
              address.range(of: #"^0x[0-9a-fA-F]{40}$"#, options: .regularExpression) != nil
        else {
            throw GlyphError.missingAddress
        }
        guard params["nonce"] == expectedNonce else {
            throw GlyphError.nonceMismatch
        }

        let signature = params["signature"].flatMap { $0.isEmpty ? nil : $0 }
        let message = params["message"].flatMap(Self.decodeBase64URL)

        var allWallets = (params["wallets"] ?? "")
            .split(separator: ",")
            .map(String.init)
            .filter { $0.range(of: #"^0x[0-9a-fA-F]{40}$"#, options: .regularExpression) != nil }
        if allWallets.isEmpty { allWallets = [address] }

        return GlyphSession(
            address: address,
            allWallets: allWallets,
            signature: signature,
            message: message,
            nonce: expectedNonce
        )
    }

    // MARK: - Helpers

    private static func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func decodeBase64URL(_ value: String) -> String? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Presentation context

extension GlyphService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return keyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - Errors

enum GlyphError: LocalizedError {
    case invalidBridgeURL
    case sessionFailedToStart
    case cancelled
    case invalidCallback
    case missingAddress
    case nonceMismatch
    case signatureInvalid
    case verificationUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidBridgeURL:
            return "The Glyph sign-in page URL is invalid. Check Constants.Glyph.bridgeURL."
        case .sessionFailedToStart:
            return "Could not open the Glyph sign-in window."
        case .cancelled:
            return "Sign-in was cancelled."
        case .invalidCallback:
            return "Glyph sign-in returned an unexpected response."
        case .missingAddress:
            return "Glyph sign-in completed but no wallet address was returned."
        case .nonceMismatch:
            return "Glyph sign-in response failed the security check (nonce mismatch). Please try again."
        case .signatureInvalid:
            return "Wallet ownership proof failed verification. Please try signing in again."
        case .verificationUnavailable:
            return "Could not verify the wallet signature right now. Please try again."
        }
    }
}
