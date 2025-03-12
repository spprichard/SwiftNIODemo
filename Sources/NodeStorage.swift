//
//  NodeStorage.swift
//  SwiftNIODemo
//
//  Created by Steven Prichard on 2025-03-11.
//

import Foundation

struct Node: Identifiable, Codable, Hashable {
    var id: UUID
    var host: String
    var port: Int

    struct Draft: Codable {
        var host: String
        var port: Int
    }
}

extension Node {
    enum Errors: Error {
        case alreadyExists
        case encodingFailed(String)
        case writeFailed(String)
    }
}

actor NodeStorage {
    static let filename: String = "nodes.json"
    static var fileURL: URL { URL.documentsDirectory.appending(component: filename) }
    let encoder: JSONEncoder = .init()
    var nodeSet: Set<Node> = []

    init() throws {
        self.nodeSet = try Self.fetchFromDisc()
    }

    func save(_ draft: Node.Draft) throws(Node.Errors) -> Node {
        let node = Node(
            id: UUID(),
            host: draft.host,
            port: draft.port
        )

        do {
            nodeSet.insert(node)
            let nodeSetData = try encode(nodeSet)
            try write(nodeSetData)
        } catch {
            nodeSet.remove(node)
            throw error
        }

        return node
    }

    static func fetchFromDisc() throws -> Set<Node> {
        if let data = FileManager.default.contents(atPath: fileURL.path()) {
            return try JSONDecoder().decode(Set<Node>.self, from: data)
        } else {
            return []
        }
    }

    private func encode(_ nodes: Set<Node>) throws(Node.Errors) -> Data {
        do {

            return try encoder.encode(nodes)
        } catch {
            throw .encodingFailed(error.localizedDescription)
        }
    }

    private func write(_ data: Data) throws(Node.Errors) {
        do {
            try data.write(to: Self.fileURL)
        } catch {
            throw .writeFailed(error.localizedDescription)
        }
    }
}
