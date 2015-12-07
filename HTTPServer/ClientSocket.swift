//
//  ClientSocket.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 07/12/2015.
//  Copyright © 2015 Wire. All rights reserved.
//

import Foundation
import SocketHelpers



public struct SocketAddress {
    /// Wraps a `sockaddr`, but could have more data than `sizeof(sockaddr)`
    let addressData: NSData
}



/// A socket that connects to a client, i.e. a program that connected to us.
struct ClientSocket {
    let address: SocketAddress
    private let backingSocket: CInt
    init(address: SocketAddress, backingSocket: CInt) {
        self.address = address
        self.backingSocket = backingSocket
    }
}


extension ClientSocket {
    /// Creates a dispatch I/O channel associated with the socket.
    func createIOChannelWithQueue(queue: dispatch_queue_t) -> dispatch_io_t {
        return dispatch_io_create(DISPATCH_IO_STREAM, backingSocket, queue) {
            error in
            if let e = POSIXError(rawValue: CInt(error)) {
                print("Error on socket: \(e)")
            }
        }
    }
}


extension SocketAddress : CustomStringConvertible {
    public var description: String {
        if let addr = inAddrDescription, let port = inPortDescription {
            switch inFamily {
            case sa_family_t(AF_INET6):
                return "[" + addr + "]:" + port
            case sa_family_t(AF_INET):
                return addr + ":" + port
            default:
                break
            }
        }
        return "<unknown>"
    }
}

extension SocketAddress {
    private var inFamily: sa_family_t {
        let pointer = UnsafePointer<sockaddr_in>(addressData.bytes)
        return pointer.memory.sin_family
    }
    private var inAddrDescription: String? {
        let pointer = UnsafePointer<sockaddr_in>(addressData.bytes)
        switch inFamily {
        case sa_family_t(AF_INET6):
            fallthrough
        case sa_family_t(AF_INET):
            let data = NSMutableData(length: Int(INET6_ADDRSTRLEN))!
            let inAddr = (UnsafePointer<UInt8>(pointer) + offsetOf__sin_addr__in__sockaddr_in())
            if inet_ntop(AF_INET, inAddr, UnsafeMutablePointer<Int8>(data.mutableBytes), socklen_t(data.length)) != UnsafePointer<Int8>() {
                return (NSString(data: data, encoding: NSUTF8StringEncoding)! as String)                }
            return nil
        default:
            return nil
        }
    }
    private var inPortDescription: String? {
        let pointer = UnsafePointer<sockaddr_in>(addressData.bytes)
        switch inFamily {
        case sa_family_t(AF_INET6):
            fallthrough
        case sa_family_t(AF_INET):
            return "\(CFSwapInt16BigToHost(UInt16(pointer.memory.sin_port)))"
        default:
            return nil
        }
    }
}
