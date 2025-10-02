//
// MockBLEService.swift
// bitchatTests
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CoreBluetooth
@testable import bitchat

/// In-memory BLE test harness used by E2E/Integration tests.
///
/// Design:
/// - Topology and routing are delegated to LocalBLETestMesh (per-test, no singletons).
/// - Tests create a LocalBLETestMesh and pass it to each MockBLEService they create.
/// - `_testRegister()` registers a node immediately on creation for deterministic routing.
/// - `messageDeliveryHandler` and `packetDeliveryHandler` let tests observe messages/packets
///   as they flow, enabling scenarios like manual encryption/relay.
/// - A thread-safe `seenMessageIDs` set prevents double-delivery races during flooding.
///
/// Flooding:
/// - `autoFloodEnabled` is disabled by default; Integration tests enable it in `setUp()` to
///   simulate broadcast propagation across the mesh. E2E tests keep it off and perform explicit
///   relays when needed.
final class MockBLEService: NSObject {
    // Enable automatic flooding for public messages in integration tests only
    static var autoFloodEnabled: Bool = false
    
    // MARK: - Properties matching BLEService
    
    weak var delegate: BitchatDelegate?
    var myPeerID: String = "MOCK1234"
    var myNickname: String = "MockUser"
    
    private let mockKeychain = MockKeychain()

    // Mesh is owned by the test; service just holds a reference
    private unowned let mesh: LocalBLETestMesh
    
    // Test-specific properties
    var sentMessages: [(message: BitchatMessage, packet: BitchatPacket)] = []
    var sentPackets: [BitchatPacket] = []
    var connectedPeers: Set<String> = []
    var messageDeliveryHandler: ((BitchatMessage) -> Void)?
    var packetDeliveryHandler: ((BitchatPacket) -> Void)?
    
    // Compatibility properties for old tests
    var mockNickname: String {
        get { return myNickname }
        set { myNickname = newValue }
    }
    
    var nickname: String {
        return myNickname
    }
    
    var peerID: String {
        return myPeerID
    }
    
    // MARK: - Initialization
    
    init(mesh: LocalBLETestMesh) {
        self.mesh = mesh
        super.init()
    }
    
    // MARK: - Methods matching BLEService
    
    func setNickname(_ nickname: String) {
        self.myNickname = nickname
    }
    
    // MARK: - Backward compatibility hook
    /// No-op now; kept to avoid breaking old tests that call it.
    static func resetTestBus() {
        // Intentionally empty: each test should create a fresh LocalBLETestMesh
    }

    /// Registers this instance on first use.
    private func registerIfNeeded() {
        mesh.register(self, peerID: myPeerID)
    }

    /// Returns adjacent neighbors based on the current simulated topology.
    private func neighbors() -> [MockBLEService] {
        mesh.neighbors(of: self)
    }

    /// Test-only: register this instance on the mesh immediately.
    func _testRegister() {
        registerIfNeeded()
    }

    func startServices() {
        // Mock implementation - do nothing
    }
    
    func stopServices() {
        // Mock implementation - do nothing
    }
    
    func isPeerConnected(_ peerID: String) -> Bool {
        return connectedPeers.contains(peerID)
    }

    func peerNickname(peerID: String) -> String? {
        "MockPeer_\(peerID)"
    }

    func getPeerNicknames() -> [String: String] {
        var nicknames: [String: String] = [:]
        for peer in connectedPeers {
            nicknames[peer] = "MockPeer_\(peer)"
        }
        return nicknames
    }
    
    func getPeers() -> [String: String] {
        return getPeerNicknames()
    }
    
    func sendMessage(_ content: String, mentions: [String] = [], to recipientID: String? = nil, messageID: String? = nil, timestamp: Date? = nil) {
        let message = BitchatMessage(
            id: messageID ?? UUID().uuidString,
            sender: myNickname,
            content: content,
            timestamp: timestamp ?? Date(),
            isRelay: false,
            originalSender: nil,
            isPrivate: recipientID != nil,
            recipientNickname: nil,
            senderPeerID: myPeerID,
            mentions: mentions.isEmpty ? nil : mentions
        )
        
        if let payload = message.toBinaryPayload() {
            let packet = BitchatPacket(
                type: 0x01,
                senderID: myPeerID.data(using: .utf8)!,
                recipientID: recipientID?.data(using: .utf8),
                timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
                payload: payload,
                signature: nil,
                ttl: 3
            )
            
            sentMessages.append((message, packet))
            sentPackets.append(packet)
            
            // Simulate local echo
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didReceiveMessage(message)
            }
            
            // Surface raw packet to tests that intercept/relay/encrypt
            packetDeliveryHandler?(packet)

            // Routing handled by mesh
            if recipientID == nil {
                mesh.routePublicPacket(packet, from: self)
            } else if let recipient = recipientID {
                mesh.routePrivatePacket(packet, from: self, toPeerID: recipient)
            }
        }
    }
    
    func sendPrivateMessage(_ content: String, to recipientPeerID: String, recipientNickname: String, messageID: String) {
        let message = BitchatMessage(
            id: messageID,
            sender: myNickname,
            content: content,
            timestamp: Date(),
            isRelay: false,
            originalSender: nil,
            isPrivate: true,
            recipientNickname: recipientNickname,
            senderPeerID: myPeerID,
            mentions: nil
        )
        
        if let payload = message.toBinaryPayload() {
            let packet = BitchatPacket(
                type: 0x01,
                senderID: myPeerID.data(using: .utf8)!,
                recipientID: recipientPeerID.data(using: .utf8)!,
                timestamp: UInt64(Date().timeIntervalSince1970 * 1000),
                payload: payload,
                signature: nil,
                ttl: 3
            )
            
            sentMessages.append((message, packet))
            sentPackets.append(packet)
            
            // Simulate local echo
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didReceiveMessage(message)
            }
            
            // Surface raw packet to tests that intercept/relay/encrypt
            packetDeliveryHandler?(packet)

            // Routing handled by mesh
            mesh.routePrivatePacket(packet, from: self, toPeerID: recipientPeerID)
        }
    }
    
    func sendFavoriteNotification(to peerID: String, isFavorite: Bool) {
        // Mock implementation
    }
    
    func sendReadReceipt(_ receipt: ReadReceipt, to peerID: String) {
        // Mock implementation
    }
    
    func sendBroadcastAnnounce() {
        // Mock implementation
    }
    
    func getPeerFingerprint(_ peerID: String) -> String? {
        return nil
    }
    
    func getNoiseSessionState(for peerID: String) -> LazyHandshakeState {
        return .none
    }
    
    func triggerHandshake(with peerID: String) {
        // Mock implementation
    }
    
    func emergencyDisconnectAll() {
        connectedPeers.removeAll()
        delegate?.didUpdatePeerList([])
    }
    
    func getNoiseService() -> NoiseEncryptionService {
        return NoiseEncryptionService(keychain: mockKeychain)
    }
    
    func getFingerprint(for peerID: String) -> String? {
        return nil
    }
    
    // MARK: - Test Helper Methods
    
    func simulateConnectedPeer(_ peerID: String) {
        registerIfNeeded()
        mesh.connect(myPeerID, peerID)
        connectedPeers.insert(peerID)
        delegate?.didConnectToPeer(peerID)
        delegate?.didUpdatePeerList(Array(connectedPeers))
    }
    
    func simulateDisconnectedPeer(_ peerID: String) {
        mesh.disconnect(myPeerID, peerID)
        connectedPeers.remove(peerID)
        delegate?.didDisconnectFromPeer(peerID)
        delegate?.didUpdatePeerList(Array(connectedPeers))
    }
    
    func simulateIncomingMessage(_ message: BitchatMessage) {
        delegate?.didReceiveMessage(message)
        // Also surface via test handler for E2E/Integration
        messageDeliveryHandler?(message)
    }
    
    private var seenMessageIDs: Set<String> = []
    private let seenLock = NSLock()

    func simulateIncomingPacket(_ packet: BitchatPacket) {
        // Process through the actual handling logic
        if let message = BitchatMessage(packet.payload) {
            var shouldDeliver = false
            seenLock.lock()
            if !seenMessageIDs.contains(message.id) {
                seenMessageIDs.insert(message.id)
                shouldDeliver = true
            }
            seenLock.unlock()
            if shouldDeliver {
                delegate?.didReceiveMessage(message)
                // Also surface via test handler for E2E/Integration
                messageDeliveryHandler?(message)
                // Optional flooding for integration-style broadcast tests.
                // When enabled, propagate a public broadcast across the entire connected
                // component regardless of the original TTL to better emulate large-network
                // broadcast expectations. De-duplication via seenMessageIDs prevents loops.
                if MockBLEService.autoFloodEnabled,
                   packet.recipientID == nil,
                   !message.isPrivate {
                    let nextTTL = packet.ttl > 0 ? packet.ttl - 1 : 0
                    for neighbor in neighbors() {
                        // Avoid immediate echo loopback to sender if known
                        if let sender = message.senderPeerID, sender == neighbor.peerID { continue }
                        var relay = packet
                        relay.ttl = nextTTL
                        neighbor.simulateIncomingPacket(relay)
                    }
                }
            }
        }
        packetDeliveryHandler?(packet)
    }
    
    func getConnectedPeers() -> [String] {
        return Array(connectedPeers)
    }
    
    // MARK: - Compatibility methods for old tests
    
    func sendPrivateMessage(_ content: String, to recipientPeerID: String, recipientNickname: String, messageID: String? = nil) {
        sendPrivateMessage(content, to: recipientPeerID, recipientNickname: recipientNickname, messageID: messageID ?? UUID().uuidString)
    }
}

// Backward compatibility for older tests
typealias MockSimplifiedBluetoothService = MockBLEService

// MARK: - Helpers

extension MockBLEService {
    convenience init(mesh: LocalBLETestMesh, peerID: String, nickname: String) {
        self.init(mesh: mesh)
        myPeerID = peerID
        mockNickname = nickname
        _testRegister()
    }
    
    func simulateConnection(with otherPeer: MockBLEService) {
        simulateConnectedPeer(otherPeer.peerID)
        otherPeer.simulateConnectedPeer(myPeerID)
    }
}

