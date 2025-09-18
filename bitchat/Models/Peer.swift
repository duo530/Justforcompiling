//
// Peer.swift
// BitLogger
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation

struct Peer: Equatable, Hashable {
    let id: String
    
    var isShort: Bool {
        id.count == 16 && Data(hexString: id) != nil
    }
}

extension Peer {
    var data: Data? {
        id.data(using: .utf8)
    }
    
    var isNostr: Bool {
        id.hasPrefix("nostr")
    }
    
    var isNostrColon: Bool {
        id.hasPrefix("nostr:")
    }
}

// MARK: - ExpressibleByStringLiteral

extension Peer: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(str: value)
    }
}

// MARK: - ExpressibleByStringInterpolation

extension Peer: ExpressibleByStringInterpolation {
    init(extendedGraphemeClusterLiteral value: String) {
        self.init(str: value)
    }
}

// MARK: - Codable

extension Peer: Codable {
    init(from decoder: any Decoder) throws {
        id = try decoder.singleValueContainer().decode(String.self)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

// MARK: - Convenience Inits

extension Peer {
    init(str: String) {
        id = str.lowercased()
    }
    
    init(str: String.SubSequence) {
        self.init(str: String(str))
    }
    
    init?(data: Data) {
        guard let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        self.init(str: str)
    }
}
