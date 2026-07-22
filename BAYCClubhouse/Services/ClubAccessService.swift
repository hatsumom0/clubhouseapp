import Foundation
import CoreLocation
import SwiftUI
import Combine

// MARK: - Club Access Service

@MainActor
class ClubAccessService: NSObject, ObservableObject {
    static let shared = ClubAccessService()

    // MARK: - Published Properties

    @Published var isAtClubhouse: Bool = false
    @Published var arrivalStatus: ArrivalStatus = .notArriving
    @Published var currentLocker: LockerAssignment?
    @Published var valetRequest: ValetRequest?
    @Published var lastCheckIn: Date?
    @Published var locationAuthStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    private var locationManager: CLLocationManager?
    private let clubhouseLocation = CLLocationCoordinate2D(
        latitude: 25.7617,  // Miami Beach area
        longitude: -80.1918
    )
    private let geofenceRadius: CLLocationDistance = 200 // meters

    // Valet progress timers (cancellable)
    private var valetProgressTimers: [Timer] = []

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationManager()
        loadPersistedData()
    }

    // MARK: - Location Setup

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.allowsBackgroundLocationUpdates = false
    }

    func requestLocationPermission() {
        locationManager?.requestWhenInUseAuthorization()
    }

    func startMonitoringArrival() {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("Geofencing not available")
            return
        }

        let region = CLCircularRegion(
            center: clubhouseLocation,
            radius: geofenceRadius,
            identifier: "BAYCMiamiClubhouse"
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager?.startMonitoring(for: region)
        locationManager?.startUpdatingLocation()
    }

    func stopMonitoringArrival() {
        locationManager?.stopUpdatingLocation()
        if let region = locationManager?.monitoredRegions.first(where: { $0.identifier == "BAYCMiamiClubhouse" }) {
            locationManager?.stopMonitoring(for: region)
        }
    }

    // MARK: - QR Code Generation

    func generateEntryQRCode(for member: MemberQRData) -> String {
        // Create a signed payload for QR code
        let payload = EntryQRPayload(
            memberId: member.memberId,
            walletAddress: member.walletAddress,
            tokenId: member.tokenId,
            tier: member.tier,
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(300), // 5 minutes validity
            nonce: UUID().uuidString
        )

        // In production, this would be cryptographically signed
        if let jsonData = try? JSONEncoder().encode(payload),
           let base64 = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlSafe) {
            return "bayc://entry/\(base64)"
        }

        return "bayc://entry/\(member.memberId)"
    }

    func refreshQRCode(for member: MemberQRData) -> String {
        // Generate a fresh QR code with new timestamp and nonce
        return generateEntryQRCode(for: member)
    }

    // MARK: - Locker Management

    func assignLocker(for memberId: String, memberName: String = "Member") -> LockerAssignment {
        // In production, this would call an API
        // For demo, generate a consistent locker based on member ID
        let lockerNumber = abs(memberId.hashValue % 200) + 1
        let accessCode = String(format: "%04d", abs(memberId.hashValue % 10000))
        let floor = lockerNumber <= 100 ? "Main Floor" : "Upper Floor"
        let section = lockerNumber % 2 == 0 ? "A" : "B"
        let expiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let assignment = LockerAssignment(
            id: UUID(),
            lockerId: UUID(),
            lockerNumber: lockerNumber,
            accessCode: accessCode,
            floor: floor,
            section: section,
            assignedDate: Date(),
            expiresAt: expiresAt
        )

        currentLocker = assignment
        savePersistedData()

        // Sync locker info to Apple Wallet membership pass
        PassKitService.shared.assignLockerToPass(
            lockerNumber: assignment.displayNumber,
            lockerCode: accessCode,
            floor: floor,
            expiresAt: expiresAt
        )

        // Schedule locker expiration notification
        NotificationService.shared.scheduleLockerExpirationWarning(locker: assignment)

        // Start Locker Live Activity
        Task {
            try? await LiveActivityManager.shared.startLockerActivity(locker: assignment, memberName: memberName)
        }

        return assignment
    }

    func releaseLocker() {
        // Cancel locker expiration notification
        if let locker = currentLocker {
            NotificationService.shared.cancelLockerExpirationWarning(lockerId: locker.id)
        }

        currentLocker = nil
        savePersistedData()

        // Remove locker info from Apple Wallet membership pass
        PassKitService.shared.removeLockerFromPass()

        // End Locker Live Activity
        Task {
            await LiveActivityManager.shared.endLockerActivity()
        }
    }

    func regenerateLockerCode() -> String? {
        guard var locker = currentLocker else { return nil }

        // Generate new 4-digit code
        let newCode = String(format: "%04d", Int.random(in: 1000...9999))
        locker.accessCode = newCode
        currentLocker = locker
        savePersistedData()

        return newCode
    }

    // MARK: - Valet Service

    func requestValet(vehicleInfo: VehicleInfo, arrivalTime: Date? = nil, specialRequests: String? = nil) -> ValetRequest {
        // Cancel any existing timers
        valetProgressTimers.forEach { $0.invalidate() }
        valetProgressTimers.removeAll()

        let request = ValetRequest(
            id: UUID(),
            memberId: "", // Would be filled from auth
            vehicleInfo: vehicleInfo,
            requestType: .arrival,
            status: .requestReceived,
            requestedAt: Date(),
            estimatedArrival: arrivalTime ?? Date().addingTimeInterval(900), // 15 min default
            specialRequests: specialRequests,
            assignedValet: nil,
            ticketNumber: generateTicketNumber(),
            deliveryLocation: nil,
            parkedLocation: nil
        )

        valetRequest = request
        savePersistedData()

        // Start Valet Live Activity
        Task {
            try? await LiveActivityManager.shared.startValetActivity(request: request)
        }

        // Simulate parking progress
        simulateValetParking()

        return request
    }

    func requestCarRetrieval(ticketNumber: String? = nil, deliveryLocation: ValetRequest.DeliveryLocation = .mainEntrance) -> ValetRequest? {
        guard var request = valetRequest else { return nil }

        // Cancel any existing timers
        valetProgressTimers.forEach { $0.invalidate() }
        valetProgressTimers.removeAll()

        request.requestType = .departure
        request.status = .retrievalRequested
        request.requestedAt = Date()
        request.deliveryLocation = deliveryLocation
        valetRequest = request

        // Simulate car being brought
        simulateCarRetrieval()

        return request
    }

    func cancelValetRequest() {
        // Cancel timers
        valetProgressTimers.forEach { $0.invalidate() }
        valetProgressTimers.removeAll()

        valetRequest = nil
        savePersistedData()

        // End Valet Live Activity
        Task {
            await LiveActivityManager.shared.endValetActivity()
        }
    }

    func updateValetStatus(_ status: ValetRequest.ValetStatus) {
        guard var request = valetRequest else { return }
        request.status = status
        valetRequest = request
        savePersistedData()
    }

    private func generateTicketNumber() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let prefix = String((0..<2).map { _ in letters.randomElement()! })
        let number = String(format: "%03d", Int.random(in: 1...999))
        return "\(prefix)-\(number)"
    }

    // MARK: - Valet Progress Simulation

    private func simulateValetParking() {
        // Request Received -> Valet Assigned (3 seconds)
        let assignedTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                guard var request = strongSelf.valetRequest else { return }
                request.status = .valetAssigned
                request.assignedValet = ValetRequest.randomValet()
                strongSelf.valetRequest = request

                // Update Live Activity
                await LiveActivityManager.shared.updateValetActivity(
                    status: .received,
                    valetName: request.assignedValet,
                    estimatedMinutes: 6
                )
            }
        }
        valetProgressTimers.append(assignedTimer)

        // Valet Assigned -> Driving to Park (6 seconds)
        let drivingTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                guard var request = strongSelf.valetRequest else { return }
                request.status = .drivingToPark
                strongSelf.valetRequest = request

                await LiveActivityManager.shared.updateValetActivity(
                    status: .fetching,
                    valetName: request.assignedValet,
                    estimatedMinutes: 4
                )
            }
        }
        valetProgressTimers.append(drivingTimer)

        // Driving to Park -> Car Parked (10 seconds)
        let parkedTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                guard var request = strongSelf.valetRequest else { return }
                request.status = .carParked
                request.parkedLocation = "Level 2, Spot B-\(Int.random(in: 10...99))"
                strongSelf.valetRequest = request

                await LiveActivityManager.shared.updateValetActivity(
                    status: .here,
                    valetName: request.assignedValet,
                    estimatedMinutes: 0
                )

                // Send notification
                NotificationService.shared.sendValetUpdateNotification(
                    ticketNumber: request.ticketNumber,
                    status: "Parked",
                    message: "Your \(request.vehicleInfo.displayName) has been parked at \(request.parkedLocation ?? "the garage")."
                )
            }
        }
        valetProgressTimers.append(parkedTimer)
    }

    private func simulateCarRetrieval() {
        // Retrieval Requested -> Valet Assigned (3 seconds)
        let assignedTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                guard var request = strongSelf.valetRequest else { return }
                request.status = .valetAssigned
                // Keep same valet or assign new one
                if request.assignedValet == nil {
                    request.assignedValet = ValetRequest.randomValet()
                }
                strongSelf.valetRequest = request

                await LiveActivityManager.shared.updateValetActivity(
                    status: .received,
                    valetName: request.assignedValet,
                    estimatedMinutes: 6
                )
            }
        }
        valetProgressTimers.append(assignedTimer)

        // Valet Assigned -> Valet On the Way to car (5 seconds)
        let onWayTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                guard var request = strongSelf.valetRequest else { return }
                request.status = .valetOnTheWay
                strongSelf.valetRequest = request

                await LiveActivityManager.shared.updateValetActivity(
                    status: .fetching,
                    valetName: request.assignedValet,
                    estimatedMinutes: 4
                )
            }
        }
        valetProgressTimers.append(onWayTimer)

        // On the Way -> Bringing Car (8 seconds)
        let bringingTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                guard var request = strongSelf.valetRequest else { return }
                request.status = .bringingCar
                strongSelf.valetRequest = request

                await LiveActivityManager.shared.updateValetActivity(
                    status: .onTheWay,
                    valetName: request.assignedValet,
                    estimatedMinutes: 2
                )

                NotificationService.shared.sendValetUpdateNotification(
                    ticketNumber: request.ticketNumber,
                    status: "On the Way",
                    message: "\(request.assignedValet ?? "Valet") is bringing your \(request.vehicleInfo.displayName)."
                )
            }
        }
        valetProgressTimers.append(bringingTimer)

        // Bringing Car -> Car Ready (11 seconds)
        let readyTimer = Timer.scheduledTimer(withTimeInterval: 11.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                guard var request = strongSelf.valetRequest else { return }
                request.status = .carReady
                strongSelf.valetRequest = request

                await LiveActivityManager.shared.updateValetActivity(
                    status: .here,
                    valetName: request.assignedValet,
                    estimatedMinutes: 0
                )

                let locationText = request.deliveryLocation?.rawValue ?? "the entrance"
                NotificationService.shared.sendValetUpdateNotification(
                    ticketNumber: request.ticketNumber,
                    status: "Ready",
                    message: "Your \(request.vehicleInfo.displayName) is ready at \(locationText)!"
                )
            }
        }
        valetProgressTimers.append(readyTimer)
    }

    // MARK: - Arrival Notification

    func notifyArriving(eta: Int = 15, guests: Int = 0, specialRequests: String? = nil, memberName: String = "Member") {
        arrivalStatus = .arriving(eta: eta, guests: guests)

        // In production, this would send a notification to the club
        print("Notifying club: Member arriving in \(eta) minutes with \(guests) guests")

        // Start Arrival Live Activity
        Task {
            try? await LiveActivityManager.shared.startArrivalActivity(
                memberId: "",
                memberName: memberName,
                eta: eta,
                guestCount: guests,
                specialRequests: specialRequests
            )
        }

        // Simulate club acknowledgment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.arrivalStatus = .confirmed(eta: eta)

            // Update Live Activity to confirmed
            Task {
                await LiveActivityManager.shared.confirmArrival()
            }
        }
    }

    func cancelArrivalNotification() {
        arrivalStatus = .notArriving

        // End Arrival Live Activity
        Task {
            await LiveActivityManager.shared.endArrivalActivity()
        }
    }

    // MARK: - Check-In

    func checkIn() {
        lastCheckIn = Date()
        savePersistedData()

        // In production, this would notify the club system
    }

    func checkOut() {
        releaseLocker()
        cancelValetRequest()
        arrivalStatus = .notArriving
        isAtClubhouse = false
        savePersistedData()
    }

    // MARK: - Persistence

    private func savePersistedData() {
        if let locker = currentLocker,
           let data = try? JSONEncoder().encode(locker) {
            UserDefaults.standard.set(data, forKey: "currentLocker")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentLocker")
        }

        if let checkIn = lastCheckIn {
            UserDefaults.standard.set(checkIn, forKey: "lastCheckIn")
        }
    }

    private func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: "currentLocker"),
           let locker = try? JSONDecoder().decode(LockerAssignment.self, from: data) {
            // Only restore if not expired
            if let expires = locker.expiresAt, expires > Date() {
                currentLocker = locker
            }
        }

        lastCheckIn = UserDefaults.standard.object(forKey: "lastCheckIn") as? Date
    }
}

// MARK: - CLLocationManagerDelegate

extension ClubAccessService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.locationAuthStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                self.startMonitoringArrival()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == "BAYCMiamiClubhouse" {
            Task { @MainActor in
                self.isAtClubhouse = true
                self.checkIn()

                // End Arrival Live Activity (we've arrived!)
                await LiveActivityManager.shared.endArrivalActivity()

                // Start Clubhouse Live Activity
                // Note: Would get member info from AuthViewModel in production
                try? await LiveActivityManager.shared.startClubhouseActivity(
                    memberId: "",
                    memberName: "Member",
                    tier: .black,
                    locker: self.currentLocker,
                    upcomingEvent: nil // Would fetch from EventManager
                )
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == "BAYCMiamiClubhouse" {
            Task { @MainActor in
                self.isAtClubhouse = false

                // End Clubhouse Live Activity
                await LiveActivityManager.shared.endClubhouseActivity()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let clubLocation = CLLocation(latitude: clubhouseLocation.latitude, longitude: clubhouseLocation.longitude)
        let distance = location.distance(from: clubLocation)

        Task { @MainActor in
            self.isAtClubhouse = distance <= self.geofenceRadius
        }
    }
}

// MARK: - Models

struct MemberQRData {
    let memberId: String
    let walletAddress: String
    let tokenId: String?
    let tier: MembershipTier
    let nickname: String?
}

struct EntryQRPayload: Codable {
    let memberId: String
    let walletAddress: String
    let tokenId: String?
    let tier: MembershipTier
    let timestamp: Date
    let expiresAt: Date
    let nonce: String
}

struct LockerAssignment: Codable, Identifiable {
    let id: UUID
    let lockerId: UUID
    let lockerNumber: Int
    var accessCode: String
    let floor: String
    let section: String
    let assignedDate: Date
    let expiresAt: Date?

    var displayNumber: String {
        "\(section)\(lockerNumber)"
    }
}

struct VehicleInfo: Codable {
    let make: String
    let model: String
    let color: String
    let licensePlate: String?

    var displayName: String {
        "\(color) \(make) \(model)"
    }
}

struct ValetRequest: Codable, Identifiable {
    let id: UUID
    let memberId: String
    let vehicleInfo: VehicleInfo
    var requestType: ValetRequestType
    var status: ValetStatus
    var requestedAt: Date
    var estimatedArrival: Date?
    var specialRequests: String?
    var assignedValet: String?
    let ticketNumber: String
    var deliveryLocation: DeliveryLocation?
    var parkedLocation: String?  // e.g., "Level 2, Spot B-42"

    enum ValetRequestType: String, Codable {
        case arrival   // Parking the car
        case departure // Retrieving the car
    }

    enum ValetStatus: String, Codable {
        // Arrival (parking) statuses
        case requestReceived = "Request Received"
        case valetAssigned = "Valet Assigned"
        case drivingToPark = "Driving to Park"
        case carParked = "Car Parked"

        // Departure (retrieval) statuses
        case retrievalRequested = "Retrieval Requested"
        case valetOnTheWay = "Valet On the Way"
        case bringingCar = "Bringing Your Car"
        case carReady = "Car Ready"

        // Legacy/general statuses
        case pending = "Pending"
        case confirmed = "Confirmed"
        case inProgress = "In Progress"
        case ready = "Ready"
        case completed = "Completed"
        case cancelled = "Cancelled"

        var color: Color {
            switch self {
            case .requestReceived, .retrievalRequested, .pending: return .orange
            case .valetAssigned, .confirmed: return .blue
            case .drivingToPark, .valetOnTheWay, .inProgress: return .purple
            case .bringingCar: return Color(hex: "f39c12")
            case .carParked, .carReady, .ready: return .green
            case .completed: return .gray
            case .cancelled: return .red
            }
        }

        var icon: String {
            switch self {
            case .requestReceived, .retrievalRequested, .pending: return "clock.fill"
            case .valetAssigned, .confirmed: return "person.fill.checkmark"
            case .drivingToPark: return "car.fill"
            case .valetOnTheWay: return "figure.walk"
            case .bringingCar, .inProgress: return "car.side.fill"
            case .carParked: return "parkingsign.circle.fill"
            case .carReady, .ready: return "key.fill"
            case .completed: return "checkmark.seal.fill"
            case .cancelled: return "xmark.circle.fill"
            }
        }

        var progressPercent: Double {
            switch self {
            case .requestReceived, .retrievalRequested, .pending: return 0.25
            case .valetAssigned, .confirmed: return 0.5
            case .drivingToPark, .valetOnTheWay, .inProgress: return 0.75
            case .bringingCar: return 0.85
            case .carParked, .carReady, .ready, .completed: return 1.0
            case .cancelled: return 0.0
            }
        }

        var displayText: String {
            rawValue
        }
    }

    enum DeliveryLocation: String, Codable, CaseIterable {
        case mainEntrance = "Main Entrance"
        case vipEntrance = "VIP Entrance"
        case poolsideDrop = "Poolside Drop-off"
        case valetCircle = "Valet Circle"

        var icon: String {
            switch self {
            case .mainEntrance: return "door.left.hand.open"
            case .vipEntrance: return "crown.fill"
            case .poolsideDrop: return "figure.pool.swim"
            case .valetCircle: return "arrow.triangle.2.circlepath.car"
            }
        }
    }

    var statusDisplayText: String {
        if status == .carReady, let location = deliveryLocation {
            return "Car Ready at \(location.rawValue)"
        }
        return status.displayText
    }
}

// MARK: - Sample Valets
extension ValetRequest {
    static let sampleValets = ["Carlos M.", "Miguel R.", "Antonio S.", "David L.", "Jorge P."]

    static func randomValet() -> String {
        sampleValets.randomElement()!
    }
}

enum ArrivalStatus: Equatable {
    case notArriving
    case arriving(eta: Int, guests: Int)
    case confirmed(eta: Int)
    case arrived

    var isArriving: Bool {
        switch self {
        case .notArriving: return false
        default: return true
        }
    }
}

// MARK: - Character Set Extension

extension CharacterSet {
    static let urlSafe = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
