import NIOCore
import NIOPosix
import Foundation

let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
let bootstrap = ServerBootstrap(group: group)
    .serverChannelOption(.backlog, value: 256)
    .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
    .childChannelInitializer { channel in
        /*
         Pipeline:
         -> BackPressure (ByteBuffer)
         -> SessionHandler(TextCommand)
         -> VerbHandler(VerbCommand)
         -> ParseHandler(MUDResponse)
         -> ResponseHandler(ByteBuffer)
         -> DONE!
        */
        channel.pipeline.addHandlers([
            BackPressureHandler(),
            SessionHandler(),
            VerbHandler(),
            ParseHandler(),
            ResponseHandler(),
            EchoHandler()
        ])
    }

    .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
    .childChannelOption(.maxMessagesPerRead, value: 16)
    .childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

let host = "::1" // locahost
let port = 8888

let channel = try bootstrap.bind(host: host, port: port).wait()
print("✅ Server started successfully, listening on address: \(channel.localAddress!)")
try channel.closeFuture.wait()
print("❌ Server Closed.")
