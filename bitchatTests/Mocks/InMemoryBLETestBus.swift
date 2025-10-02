//
// LocalBLETestMesh.swift (was InMemoryBLETestBus.swift)
// bitchatTests
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
@testable import bitchat

/// Local, per-test mesh that simulates BLE topology and routing.
/// - No singletons
/// - No global state
/// - No locking (assumes tests run operations synchronously)
/// - Adjacency keyed by MockBLEService identity; minimal registry for peerID lookup
final class LocalBLETestMesh {

    // Registry (peerID -> service) for addressing by ID
    private var registry: [String: MockBLEService] = [:]

    // Adjacency: service -> neighbors
    private var adjacency: [MockBLEService: Set<MockBLEService>] = [:]

    // MARK: - Lifecycle

    init() {}

    // MARK: - Registration

    func register(_ service: MockBLEService, peerID: String) {
        registry[peerID] = service
        if adjacency[service] == nil { adjacency[service] = [] }
    }

    // MARK: - Topology

    func connect(_ aPeerID: String, _ bPeerID: String) {
        guard let a = registry[aPeerID], let b = registry[bPeerID] else { return }
        var setA = adjacency[a] ?? []
        setA.insert(b)
        adjacency[a] = setA
        var setB = adjacency[b] ?? []
        setB.insert(a)
        adjacency[b] = setB
    }

    func disconnect(_ aPeerID: String, _ bPeerID: String) {
        guard let a = registry[aPeerID], let b = registry[bPeerID] else { return }
        if var setA = adjacency[a] { setA.remove(b); adjacency[a] = setA }
        if var setB = adjacency[b] { setB.remove(a); adjacency[b] = setB }
    }

    func isDirectNeighbor(_ a: MockBLEService, _ b: MockBLEService) -> Bool {
        adjacency[a]?.contains(b) ?? false
    }

    func neighbors(of service: MockBLEService) -> [MockBLEService] {
        Array(adjacency[service] ?? [])
    }

    func service(for peerID: String) -> MockBLEService? {
        registry[peerID]
    }

    // MARK: - Routing

    /// Route a public packet to all neighbors of the sender.
    func routePublicPacket(_ packet: BitchatPacket, from sender: MockBLEService) {
        for neighbor in neighbors(of: sender) {
            neighbor.simulateIncomingPacket(packet)
        }
    }

    /// Route a private packet either directly (if adjacent) or via neighbors plus direct deliver if known.
    func routePrivatePacket(_ packet: BitchatPacket, from sender: MockBLEService, toPeerID recipientPeerID: String) {
        if let target = service(for: recipientPeerID), isDirectNeighbor(sender, target) {
            target.simulateIncomingPacket(packet)
            return
        }

        // Not directly connected: deliver to target if known, and relay to neighbors excluding the target
        let maybeTarget = service(for: recipientPeerID)
        maybeTarget?.simulateIncomingPacket(packet)

        for neighbor in neighbors(of: sender) where neighbor !== maybeTarget {
            neighbor.simulateIncomingPacket(packet)
        }
    }
}

