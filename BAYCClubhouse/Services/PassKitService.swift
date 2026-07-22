import Foundation
import PassKit
import Combine

// MARK: - PassKit Service

@MainActor
class PassKitService: ObservableObject {
    static let shared = PassKitService()

    @Published var isPassLibraryAvailable: Bool = false
    @Published var lastError: String?

    private init() {
        checkPassLibraryAvailability()
    }

    private func checkPassLibraryAvailability() {
        isPassLibraryAvailable = PKPassLibrary.isPassLibraryAvailable()
    }

    // MARK: - Pass Data Generation

    /// Generates membership pass data for the given user
    /// In production, this would be signed on a server
    func generateMembershipPassData(
        memberName: String,
        memberId: String,
        tier: MembershipTier,
        tokenId: String?,
        walletAddress: String?
    ) -> MembershipPassData {
        return MembershipPassData(
            memberName: memberName,
            memberId: memberId,
            tier: tier,
            tokenId: tokenId,
            walletAddress: walletAddress,
            validFrom: Date(),
            clubName: "BAYC Miami Clubhouse",
            clubLocation: "Miami, FL"
        )
    }

    // MARK: - Add Pass to Wallet

    /// Attempts to add a pass to Apple Wallet
    /// Note: This requires a properly signed .pkpass file from a server
    func addPassToWallet(passData: MembershipPassData, completion: @escaping (Result<Bool, PassKitError>) -> Void) {
        guard isPassLibraryAvailable else {
            completion(.failure(.passLibraryNotAvailable))
            return
        }

        // In a real implementation, you would:
        // 1. Send passData to your server
        // 2. Server creates and signs the .pkpass file
        // 3. Server returns the signed pass data
        // 4. Use PKAddPassesViewController to present it

        // For demo purposes, we'll simulate the flow
        // Real implementation would look like:
        /*
        Task {
            do {
                let passFileData = try await fetchSignedPassFromServer(passData: passData)
                let pass = try PKPass(data: passFileData)

                await MainActor.run {
                    let addPassVC = PKAddPassesViewController(pass: pass)
                    // Present the view controller
                    completion(.success(true))
                }
            } catch {
                completion(.failure(.serverError(error.localizedDescription)))
            }
        }
        */

        // Since we don't have a signing server, we'll simulate success
        // but store the pass data locally for the demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Store pass data in UserDefaults for demo
            self.savePassDataLocally(passData)
            completion(.success(true))
        }
    }

    // MARK: - Check if Pass Exists

    func isMembershipPassInWallet(memberId: String) -> Bool {
        guard isPassLibraryAvailable else { return false }

        let passLibrary = PKPassLibrary()
        let passes = passLibrary.passes()

        // Check if any pass matches our membership ID
        // In production, you'd check the pass type identifier and serial number
        return passes.contains { pass in
            pass.serialNumber == memberId
        }
    }

    // MARK: - Local Storage (Demo)

    private func savePassDataLocally(_ passData: MembershipPassData) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(passData) {
            UserDefaults.standard.set(encoded, forKey: "membershipPassData")
            UserDefaults.standard.set(true, forKey: "membershipPassAddedToWallet")
        }
    }

    func isPassAddedLocally() -> Bool {
        return UserDefaults.standard.bool(forKey: "membershipPassAddedToWallet")
    }

    func getLocalPassData() -> MembershipPassData? {
        guard let data = UserDefaults.standard.data(forKey: "membershipPassData") else {
            return nil
        }
        return try? JSONDecoder().decode(MembershipPassData.self, from: data)
    }

    func removeLocalPass() {
        UserDefaults.standard.removeObject(forKey: "membershipPassData")
        UserDefaults.standard.removeObject(forKey: "membershipPassAddedToWallet")
    }

    // MARK: - Locker Integration

    /// Updates the membership pass with locker information
    /// In production, this would push an update to the Apple Wallet pass
    func assignLockerToPass(lockerNumber: String, lockerCode: String, floor: String, expiresAt: Date) {
        guard var passData = getLocalPassData() else { return }

        passData.lockerNumber = lockerNumber
        passData.lockerCode = lockerCode
        passData.lockerFloor = floor
        passData.lockerExpiresAt = expiresAt

        savePassDataLocally(passData)

        // In production, you would push an update to Apple Wallet:
        /*
        Task {
            do {
                let updatedPassData = try await pushPassUpdateToServer(passData: passData)
                // Apple Wallet automatically updates passes with the same serial number
            } catch {
                print("Failed to update pass: \(error)")
            }
        }
        */
    }

    /// Removes locker information from the membership pass
    func removeLockerFromPass() {
        guard var passData = getLocalPassData() else { return }

        passData.lockerNumber = nil
        passData.lockerCode = nil
        passData.lockerFloor = nil
        passData.lockerExpiresAt = nil

        savePassDataLocally(passData)
    }

    /// Gets current locker info from the pass
    func getLockerInfo() -> (number: String, code: String, floor: String, expires: Date)? {
        guard let passData = getLocalPassData(),
              let number = passData.lockerNumber,
              let code = passData.lockerCode,
              let floor = passData.lockerFloor,
              let expires = passData.lockerExpiresAt,
              passData.hasActiveLocker else {
            return nil
        }
        return (number, code, floor, expires)
    }
}

// MARK: - Pass Data Model

struct MembershipPassData: Codable {
    let memberName: String
    let memberId: String
    let tier: MembershipTier
    let tokenId: String?
    let walletAddress: String?
    let validFrom: Date
    let clubName: String
    let clubLocation: String

    // Locker information (updated when locker is assigned)
    var lockerNumber: String?
    var lockerCode: String?
    var lockerFloor: String?
    var lockerExpiresAt: Date?

    var passDescription: String {
        "\(tier.displayName) Member"
    }

    var hasActiveLocker: Bool {
        guard let expires = lockerExpiresAt else { return false }
        return lockerNumber != nil && expires > Date()
    }

    var nfcPayload: String {
        // This would be the NFC payload for door access AND locker access
        // In production, this would be cryptographically signed
        var payload: [String: Any] = [
            "type": "bayc_membership",
            "memberId": memberId,
            "tier": tier.rawValue,
            "tokenId": tokenId ?? "",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        // Include locker info if assigned
        if let locker = lockerNumber, let code = lockerCode, hasActiveLocker {
            payload["locker"] = [
                "number": locker,
                "code": code,
                "floor": lockerFloor ?? "",
                "expires": ISO8601DateFormatter().string(from: lockerExpiresAt ?? Date())
            ]
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return memberId
    }

    var lockerNfcPayload: String {
        // Separate NFC payload specifically for locker tap
        guard let locker = lockerNumber, let code = lockerCode else {
            return ""
        }

        let payload: [String: Any] = [
            "type": "bayc_locker",
            "memberId": memberId,
            "lockerNumber": locker,
            "accessCode": code,
            "floor": lockerFloor ?? "",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "expires": ISO8601DateFormatter().string(from: lockerExpiresAt ?? Date())
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return ""
    }
}

// Make MembershipTier Codable for PassData
extension MembershipTier: Codable {}

// MARK: - PassKit Errors

enum PassKitError: LocalizedError {
    case passLibraryNotAvailable
    case invalidPassData
    case serverError(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .passLibraryNotAvailable:
            return "Apple Wallet is not available on this device"
        case .invalidPassData:
            return "Could not create membership pass"
        case .serverError(let message):
            return "Server error: \(message)"
        case .userCancelled:
            return "Pass addition was cancelled"
        }
    }
}

// MARK: - PKPass Extension for NFC (Production Use)

/*
 To implement real NFC passes, you need:

 1. Apple Developer Account with Pass Type ID certificate
 2. A backend server that can sign passes
 3. Pass.json template with NFC configuration:

 {
   "formatVersion": 1,
   "passTypeIdentifier": "pass.com.yuga.bayc.membership",
   "serialNumber": "<member_id>",
   "teamIdentifier": "<your_team_id>",
   "organizationName": "BAYC Miami Clubhouse",
   "description": "Membership Pass",
   "nfc": {
     "message": "<nfc_payload>",
     "encryptionPublicKey": "<optional_key>"
   },
   ...
 }

 The NFC reader at the clubhouse door would:
 1. Read the NFC message from the pass
 2. Verify the payload signature
 3. Check membership status against the database
 4. Grant or deny access
*/
