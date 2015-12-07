//
//  SocketServer.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 03/02/2015.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import Foundation
import SocketHelpers



public enum SocketError : ErrorType {
    case NoPortAvailable
}




public final class SocketServer {
    public struct Channel {
        public let channel: dispatch_io_t
        public let address: SocketAddress
    }
    
    public let port: UInt16
    
    /// The accept handler will be called with a suspended dispatch I/O channel and the client's SocketAddress.
    public convenience init(acceptHandler: (Channel) -> ()) throws {
        let serverSocket = try TCPSocket(domain: .Inet)
        let port = try serverSocket.bindToAnyPort()
        try serverSocket.setStatusFlags(.O_NONBLOCK)
        try self.init(serverSocket: serverSocket, port: port, acceptHandler: acceptHandler)
    }
    
    let serverSocket: TCPSocket
    let acceptSource: dispatch_source_t
    
    private init(serverSocket ss: TCPSocket, port p: UInt16, acceptHandler: (Channel) -> ()) throws {
        serverSocket = ss
        port = p
        acceptSource = SocketServer.createDispatchSourceWithSocket(ss, port: p, acceptHandler: acceptHandler)
        dispatch_resume(acceptSource);
        try serverSocket.listen()
    }
    
    private static func createDispatchSourceWithSocket(socket: TCPSocket, port: UInt16, acceptHandler: (Channel) -> ()) -> dispatch_source_t {
        let queueName = "server on port \(port)"
        let queue = dispatch_queue_create(queueName, DISPATCH_QUEUE_CONCURRENT);
        let source = socket.createDispatchReadSourceWithQueue(queue)
        
        dispatch_source_set_event_handler(source) {
            source.forEachPendingConnection {
                do {
                    let clientSocket = try socket.accept()
                    let io = clientSocket.createIOChannelWithQueue(queue)
                    let channel = Channel(channel: io, address: clientSocket.address)
                    acceptHandler(channel)
                } catch let e {
                    print("Failed to accept incoming connection: \(e)")
                }
            }
        }
        return source
    }
    
    deinit {
        dispatch_source_cancel(acceptSource)
        ignoreAndLogErrors {
            try serverSocket.close()
        }
    }
}


private extension dispatch_source_t {
    func forEachPendingConnection(b: () -> ()) {
        let pendingConnectionCount = dispatch_source_get_data(self)
        for _ in 0..<pendingConnectionCount {
            b()
        }
    }
}


private extension TCPSocket {
    func bindToAnyPort() throws -> UInt16 {
        for port in UInt16(8000 + arc4random_uniform(1000))...10000 {
            do {
                try bindToPort(port)
                return port
            } catch let e as Error where e.backing == .EADDRINUSE {
                continue
            }
        }
        throw SocketError.NoPortAvailable
    }
}
