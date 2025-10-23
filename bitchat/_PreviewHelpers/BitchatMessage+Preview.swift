//
// BitchatMessage+Preview.swift
// bitchat
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation

extension BitchatMessage {
    static var preview: BitchatMessage {
        BitchatMessage(
            id: UUID().uuidString,
            sender: "John Doe",
            senderPeerID: PeerID(str: "abc123"),
            content: "Hello",
            timestamp: Date(),
            isRelay: false,
            originalSender: nil,
            isPrivate: false,
            recipientNickname: "Jane Doe",
            mentions: nil,
            deliveryStatus: .sent
        )
    }
}
