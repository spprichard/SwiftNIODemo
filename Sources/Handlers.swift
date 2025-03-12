//
//  Handlers.swift
//  SwiftNIODemo
//
//  Created by Steven Prichard on 2025-03-11.
//

import NIOCore
import Foundation

final class EchoHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let inboundBuffer = self.unwrapInboundIn(data)
        let input = String(buffer: inboundBuffer)
        let styledResponse = "\u{1B}[32m" + input + "\u{1B}[0m"
        print("🎤Echo> \(input)")

        var outputBuffer = context.channel.allocator.buffer(capacity: styledResponse.count)
        outputBuffer.writeString(styledResponse)
        context.writeAndFlush(self.wrapOutboundOut(outputBuffer), promise: nil)
    }
}


final class SessionHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = ByteBuffer
    typealias OutboundOut = TextCommand

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let inboundBuffer = self.unwrapInboundIn(data)
        let input = String(buffer: inboundBuffer)

        let command = TextCommand(
            session: .init(
                id: UUID(),
                channel: context.channel
            ),
            command: input
        )

        context.fireChannelRead(wrapOutboundOut(command))
    }
}


final class VerbHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = TextCommand
    typealias OutboundOut = VerbCommand

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let textCommand = self.unwrapInboundIn(data)

        let command = VerbCommand(
            session: textCommand.session,
            verb: Verb(rawValue: textCommand.command)
        )

        context.fireChannelRead(wrapOutboundOut(command))
    }
}

final class ParseHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = VerbCommand
    typealias OutboundOut = Response

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let command = self.unwrapInboundIn(data)
        let promise = context.eventLoop.makePromise(of: Void.self)

        let eventLoop = context.eventLoop
        let fireChannelRead = context.fireChannelRead

        promise.completeWithTask {
            let response = await self.response(for: command)

            eventLoop.execute {
                fireChannelRead(self.wrapOutboundOut(response))
            }
        }
    }

    private func response(for command: VerbCommand) async -> Response {
        switch command.verb {
            case .close:
                var updated = command.session
                updated.shouldClose = true
                return Response(
                    session: updated,
                    message: "Good Bye!"
                )
            case .empty:
                return Response(
                    session: command.session,
                    message: ""
                )
            case .addNode(let host, let port):
                return await handleAddNode(
                    command: command,
                    host: host,
                    port: port
                )
            case .illegal:
                return Response(
                    session: command.session,
                    message: "Invalid command"
                )
        }
    }

    func handleAddNode(command: VerbCommand, host: String, port: Int) async -> Response {
        do {
            let storage = try NodeStorage()
            let savedNode = try await storage.save(.init(host: host, port: port))
            return Response(
                session: command.session,
                message: "Saved node \(savedNode.id)"
            )
        } catch {
            print("❌ Failed to add node: \(error)")
            return Response(
                session: command.session,
                message: "Error adding node: \(error)"
            )
        }
    }
}

final class ResponseHandler: ChannelInboundHandler, Sendable {
    typealias InboundIn = Response
    typealias OutboundOut = ByteBuffer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = self.unwrapInboundIn(data)
        let styledResponse = "\u{1B}[32m" + response.message + "\u{1B}[0m" + "\n\r> "

        var outputBuffer = context.channel.allocator.buffer(capacity: styledResponse.count)
        outputBuffer.writeString(styledResponse)

        context.writeAndFlush(self.wrapOutboundOut(outputBuffer), promise: nil)

        if response.session.shouldClose {
            let _ = context.channel.close()
        }
    }
}
