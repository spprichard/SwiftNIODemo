//
//  Types.swift
//  SwiftNIODemo
//
//  Created by Steven Prichard on 2025-03-11.
//

import NIOCore
import Foundation

struct Session: Sendable {
    let id: UUID
    let channel: Channel
    var shouldClose: Bool = false
}

struct TextCommand: Sendable {
    let session: Session
    let command: String
}

enum Verb: Equatable {
    case empty
    case illegal
    case close
    case addNode(host: String, port: Int)

    init(rawValue: String) {
        let trimmedInput = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedInput.split(separator: " ")

        if parts.isEmpty && parts[0].isEmpty {
            self = .empty
            return
        }

        let rawCommand = String(parts[0])

        guard parts.count >= Self.expectedWordCount(rawCommand) else {
            self = .illegal
            return
        }

        switch parts[0].uppercased() {
            case "CLOSE":
                self = .close
            case "ADD_NODE":
                let host = String(parts[1])
                guard let port = Int(parts[2]) else {
                    print("⚠️ Invalid port number provided for ADD_NODE command.")
                    self = .illegal
                    return
                }
                self = .addNode(host: host, port: port)
            default:
                self = .illegal
        }
    }

    private static func expectedWordCount(_ text: String) -> Int {
        switch text {
            case "CLOSE":
                return 1
            case "ADD_NODE":
                return 2
            default:
                return 0
        }
    }
}

struct VerbCommand: Sendable {
    let session: Session
    let verb: Verb
}

struct Response: Sendable {
    let session: Session
    let message: String
}
