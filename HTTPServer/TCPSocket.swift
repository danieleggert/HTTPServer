//
//  TCPSocket.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 06/12/2015.
//  Copyright © 2015 Wire. All rights reserved.
//

import Foundation
import SocketHelpers



struct TCPSocket {
    enum Domain {
        case Inet
        case Inet6
    }
    private let domain: Domain
    private let backingSocket: CInt
    init(domain d: Domain) throws {
        domain = d
        backingSocket = try attempt("socket(2)",  valid: isNotNegative1, socket(d.rawValue, SOCK_STREAM, IPPROTO_TCP))
    }
}

extension TCPSocket {
    /// Close the socket.
    func close() throws {
        try attempt("close(2)", valid: is0, Darwin.close(backingSocket))
    }
    /// Listen for connections.
    /// Start accepting incoming connections and set the queue limit for incoming connections.
    func listen(backlog: CInt = SOMAXCONN) throws {
        try attempt("listen(2)", valid: is0, Darwin.listen(backingSocket, backlog))
    }
}

extension TCPSocket {
    /// Accept a connection.
    /// Retruns the resulting client socket.
    func accept() throws -> ClientSocket {
        // The address has the type `sockaddr`, but could have more data than `sizeof(sockaddr)`. Hence we put it inside an NSData instance.
        let addressData = NSMutableData(length: Int(SOCK_MAXADDRLEN))!
        let p = UnsafeMutablePointer<sockaddr>(addressData.bytes)
        var length = socklen_t(sizeof(sockaddr_in))
        let socket = try attempt("accept(2)", valid: isNotNegative1, Darwin.accept(backingSocket, p, &length))
        addressData.length = Int(length)
        let address = SocketAddress(addressData: addressData)
        return ClientSocket(address: address, backingSocket: socket)
    }
}

extension TCPSocket {
    struct StatusFlag : OptionSetType {
        let rawValue: CInt
        static let O_NONBLOCK = StatusFlag(rawValue: 0x0004)
        static let O_APPEND = StatusFlag(rawValue: 0x0008)
        static let O_ASYNC = StatusFlag(rawValue: 0x0040)
    }
    /// Set the socket status flags.
    /// Uses `fnctl(2)` with `F_SETFL`.
    func setStatusFlags(flag: StatusFlag) throws {
        try attempt("fcntl(2)", valid: isNotNegative1, SocketHelper_fcntl_setFlags(backingSocket, flag.rawValue))
    }
    /// Get the socket status flags.
    /// Uses `fnctl(2)` with `F_GETFL`.
    func getStatusFlags(flag: StatusFlag) -> StatusFlag {
        return StatusFlag(rawValue: SocketHelper_fcntl_getFlags(backingSocket)) ?? StatusFlag()
    }
}

extension TCPSocket {
    func createDispatchReadSourceWithQueue(queue: dispatch_queue_t) -> dispatch_source_t {
        return dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(backingSocket), 0, queue)
    }
}

//extension TCPSocket.StatusFlag {
//    init?(rawValue: Self.RawValue) {
//        switch
//    }
//}


extension TCPSocket.Domain {
    private var rawValue: CInt {
        switch self {
        case .Inet: return PF_INET
        case .Inet6: return PF_INET6
        }
    }
    private var addressFamily: sa_family_t {
        switch self {
        case .Inet: return sa_family_t(AF_INET)
        case .Inet6: return sa_family_t(AF_INET6)
        }
    }
}


private let INADDR_ANY = in_addr(s_addr: in_addr_t(0))

extension TCPSocket {
    private func withUnsafeAnySockAddrWithPort(port: UInt16, @noescape block: (UnsafePointer<sockaddr>) throws -> ()) rethrows {
        let portN = in_port_t(CFSwapInt16HostToBig(port))
        let addr = UnsafeMutablePointer<sockaddr_in>.alloc(1)
        addr.initialize(sockaddr_in(sin_len: 0, sin_family: domain.addressFamily, sin_port: portN, sin_addr: INADDR_ANY, sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)))
        defer { addr.destroy() }
        try block(UnsafePointer<sockaddr>(addr))
    }
    func bindToPort(port: UInt16) throws {
        try withUnsafeAnySockAddrWithPort(port) { addr in
            try attempt("bind(2)", valid: is0, bind(backingSocket, addr, socklen_t(sizeof(sockaddr))))
        }
    }
}
