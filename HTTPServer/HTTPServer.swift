//
//  HTTPServer.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 03/02/2015.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import Foundation
import SocketHelpers



public typealias RequestHandler = (request: HTTPRequest, clientAddress: SocketServer.SocketAddress, responseHandler:(HTTPResponse?) -> ()) -> ()


public struct HTTPRequest {
    private let message: CFHTTPMessageRef
    
    private init(message m: CFHTTPMessageRef) {
        message = m
        assert(CFHTTPMessageIsRequest(message) != 0, "Message is a response, not a request.")
    }
    
    public var bodyData: NSData {
        return CFHTTPMessageCopyBody(message).takeRetainedValue()
    }
    
    public var method: String {
        return CFHTTPMessageCopyRequestMethod(message).takeRetainedValue() as String
    }
    
    public var URL: NSURL {
        return CFHTTPMessageCopyRequestURL(message).takeRetainedValue()
    }
    
    public var allHeaderFields: [String:String] {
        return CFHTTPMessageCopyAllHeaderFields(message).takeRetainedValue() as! [String:String]
    }
    
    public func headerField(fieldName: String) -> String? {
        let v = CFHTTPMessageCopyHeaderFieldValue(message, fieldName)
        if v.toOpaque() == COpaquePointer(nilLiteral: ()) {
            return nil
        } else {
            return v.takeRetainedValue() as String
        }
    }
}

public struct HTTPResponse : Printable {
    private var message: Message
    
    public init(statusCode: Int, statusDescription: String) {
        message = Message(message: CFHTTPMessageCreateResponse(kCFAllocatorDefault, CFIndex(statusCode), statusDescription, kCFHTTPVersion1_1).takeRetainedValue())
        // We don't support keep-alive
        CFHTTPMessageSetHeaderFieldValue(message.backing, "Connection", "close")
    }
    
    public var bodyData: NSData {
        get {
            return CFHTTPMessageCopyBody(message.backing).takeRetainedValue()
        }
        set(data) {
            ensureUnique()
            CFHTTPMessageSetBody(message.backing, data)
        }
    }
    
    public mutating func setHeaderField(fieldName: String, value: String?) {
        ensureUnique()
        if let v = value {
            CFHTTPMessageSetHeaderFieldValue(message.backing, fieldName, v)
        } else {
            CFHTTPMessageSetHeaderFieldValue(message.backing, fieldName, nil)
        }
    }
    
    public var description: String {
        return NSString(data: message.backing.serialized() as! NSData, encoding: NSUTF8StringEncoding)! as String
    }
}

/// This handler can be passed to SocketServer.withAcceptHandler to create an HTTP server.
public func httpConnectionHandler(channel: dispatch_io_t, clientAddress: SocketServer.SocketAddress, queue: dispatch_queue_t, handler: RequestHandler) -> () {
    //dispatch_io_set_low_water(channel, 1);
    // high water mark defaults to SIZE_MAX
    dispatch_io_set_interval(channel, 10 * NSEC_PER_MSEC, DISPATCH_IO_STRICT_INTERVAL)
    
    var accumulated: dispatch_data_t = dispatch_data_create(nil, 0, queue, nil)
    
    var request = RequestInProgress.None
    
    let OperationCancelledError = Int32(89)
    
    dispatch_io_read(channel, 0, Int.max, queue) {
        (done, data: dispatch_data_t!, error) in
        if (error != 0 && error != OperationCancelledError) {
            println("Error on channel: \(String.fromCString(strerror(error))!) (\(error))")
        }
        // Append the data and update the request:
        if let d = data {
            accumulated = dispatch_data_create_concat(accumulated, d)
            let r = request.consumeData(accumulated)
            request = r.request
            accumulated = r.remainder
        }
        switch request {
        case let .Complete(completeRequest, _):
            handler(request: HTTPRequest(message: completeRequest), clientAddress: clientAddress, responseHandler: { (maybeResponse) -> () in
                if let response = maybeResponse {
                    assert(CFHTTPMessageIsRequest(response.message.backing) == 0, "Response can not be a request.")
                    dispatch_io_write(channel, 0, response.serializedData, queue) {
                        (done, data, error) in
                        if error != 0 || done {
                            dispatch_io_close(channel, dispatch_io_close_flags_t(DISPATCH_IO_STOP))
                        }
                    }
                } else {
                    dispatch_io_close(channel, dispatch_io_close_flags_t(0))
                }
            })
        case .Error:
            dispatch_io_close(channel, dispatch_io_close_flags_t(DISPATCH_IO_STOP))
        default:
            break
        }
        if (done) {
            dispatch_io_close(channel, dispatch_io_close_flags_t(0))
        }
    }
}



//MARK:
//MARK: Private
//MARK:



extension HTTPResponse {
    
    private var serializedData: dispatch_data_t {
        return message.backing.serialized()
    }
    
    private mutating func ensureUnique() {
        if !isUniquelyReferencedNonObjC(&message) {
            message = message.copy()
        }
    }
    
    private class Message {
        let backing: CFHTTPMessageRef
        init(message m: CFHTTPMessageRef) {
            backing = m
        }
        func copy() -> Message {
            return Message(message: CFHTTPMessageCreateCopy(kCFAllocatorDefault, backing).takeRetainedValue())
        }
    }
}

private func splitData(data: dispatch_data_t, location: Int) -> (dispatch_data_t, dispatch_data_t) {
    let head = dispatch_data_create_subrange(data, 0, location)
    let tail = dispatch_data_create_subrange(data, location, dispatch_data_get_size(data) - location)
    return (head, tail)
}

private struct RequestInProgressAndRemainder {
    let request: RequestInProgress
    let remainder: dispatch_data_t
    init(_ r: RequestInProgress, _ d: dispatch_data_t) {
        request = r
        remainder = d
    }
}

private enum RequestInProgress {
    case None
    case Error
    case IncompleteHeader
    case IncompleteMessage(CFHTTPMessageRef, Int)
    case Complete(CFHTTPMessageRef, Int)
    
    func consumeData(data: dispatch_data_t) -> RequestInProgressAndRemainder {
        switch self {
        case .Error:
            return RequestInProgressAndRemainder(.Error, data)
        case .None:
            fallthrough
        case .IncompleteHeader:
            let d = data as! NSData
            let r = d.rangeOfData(NSData(bytes: "\r\n\r\n", length: 4), options: NSDataSearchOptions(0), range: NSMakeRange(0, d.length))
            if r.location == NSNotFound {
                return RequestInProgressAndRemainder(.IncompleteHeader, data)
            } else {
                let end = Int(r.location + 4)
                let (header, tail) = splitData(data, end)
                let message = CFHTTPMessageCreateEmpty(nil, Boolean(1)).takeRetainedValue()
                message.appendDispatchData(header)
                if CFHTTPMessageIsHeaderComplete(message) == 0 {
                    return RequestInProgressAndRemainder(.Error, data)
                } else {
                    let bodyLength = message.messsageBodyLength()
                    if bodyLength <= dispatch_data_get_size(tail) {
                        let (head, tail2) = splitData(tail, bodyLength)
                        message.appendDispatchData(head) // CFHTTPMessageSetBody() ?
                        return RequestInProgressAndRemainder(.Complete(message, bodyLength), tail2)
                    }
                    return RequestInProgressAndRemainder(.IncompleteMessage(message, bodyLength), tail)
                }
            }
        case let .IncompleteMessage(message, bodyLength):
            if bodyLength <= dispatch_data_get_size(data) {
                let (head, tail) = splitData(data, bodyLength)
                message.appendDispatchData(head) // CFHTTPMessageSetBody() ?
                return RequestInProgressAndRemainder(.Complete(message, bodyLength), tail)
            }
            return RequestInProgressAndRemainder(.IncompleteMessage(message, bodyLength), data)
        case let .Complete(message, bodyLength):
            return RequestInProgressAndRemainder(.Complete(message, bodyLength), data)
        }
    }
}

extension CFHTTPMessage {
    private func messsageBodyLength() -> Int {
        // https://tools.ietf.org/html/rfc2616 section 4.4 "Message Length"
        // NSString * const method = CFBridgingRelease(CFHTTPMessageCopyRequestMethod(self.currentMessage));
        let contentLength = HTTPMessageHeaderField(self, "Content-Length")
        let transferEncoding = HTTPMessageHeaderField(self, "Transfer-Encoding")
        if (contentLength == nil) && (transferEncoding == nil) {
            return 0
        }
        if let l = contentLength {
            let l2 = l as NSString
            return Int(l2.integerValue)
        }
        return 0
    }
    private func appendDispatchData(data: dispatch_data_t) {
        dispatch_data_apply(data, { (d, o, buffer, length) -> Bool in
            CFHTTPMessageAppendBytes(self, UnsafePointer<UInt8>(buffer), CFIndex(length))
            return true
        })
    }
    private func serialized() -> dispatch_data_t {
        let data = CFHTTPMessageCopySerializedMessage(self).takeRetainedValue()
        let gcdData = dispatch_data_create(UnsafePointer<Void>(CFDataGetBytePtr(data)), Int(CFDataGetLength(data)), dispatch_get_global_queue(0, 0)) { () -> Void in
            Unmanaged.passRetained(data)
            return
        }
        return gcdData
    }
}
