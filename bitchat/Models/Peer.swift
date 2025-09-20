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

// MARK: - Validation

extension Peer {
    private enum Constants {
        static let maxIDLength = 64
        static let hexIDLength = 16 // 8 bytes = 16 hex chars
    }
    
    /// Validates a peer ID from any source (short 16-hex, full 64-hex, or internal alnum/-/_ up to 64)
    var isValid: Bool {
        // Accept short routing IDs (exact 16-hex) or Full Noise key hex (exact 64-hex)
        if isShort || isNoiseKeyHex {
            return true
        }
        
        // If length equals short or full but isn't valid hex, reject
        if id.count == Constants.hexIDLength || id.count == Constants.maxIDLength {
            return false
        }
        
        // Internal format: alphanumeric + dash/underscore up to 63 (not 16 or 64)
        let validCharset = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return !id.isEmpty &&
                id.count < Constants.maxIDLength &&
                id.rangeOfCharacter(from: validCharset.inverted) == nil
    }
    
    /// Short routing IDs (exact 16-hex)
    var isShort: Bool {
        id.count == Constants.hexIDLength && Data(hexString: id) != nil
    }
    
    /// Full Noise key hex (exact 64-hex)
    var isNoiseKeyHex: Bool {
        id.count == Constants.maxIDLength && Data(hexString: id) != nil
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
