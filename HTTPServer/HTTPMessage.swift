//
//  HTTPMessage.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 07/12/2015.
//  Copyright © 2015 Wire. All rights reserved.
//

import Foundation



/// This is a HTTP request that a client has sent us.
public struct HTTPRequest {
    private let message: CFHTTPMessageRef
    
    init(message m: CFHTTPMessageRef) {
        message = m
        assert(CFHTTPMessageIsRequest(message), "Message is a response, not a request.")
    }
    
    public var bodyData: NSData {
        return CFHTTPMessageCopyBody(message)?.takeRetainedValue() ?? NSData()
    }
    
    public var method: String {
        return CFHTTPMessageCopyRequestMethod(message)!.takeRetainedValue() as String
    }
    
    public var URL: NSURL {
        return CFHTTPMessageCopyRequestURL(message)!.takeRetainedValue()
    }
    
    public var allHeaderFields: [String:String] {
        if let fields = CFHTTPMessageCopyAllHeaderFields(message)?.takeRetainedValue() as? NSDictionary {
            if let f = fields as? [String:String] {
                return f
            }
        }
        return [:]
    }
    
    public func headerField(fieldName: String) -> String? {
        return CFHTTPMessageCopyHeaderFieldValue(message, fieldName)?.takeRetainedValue() as? String
    }
}

/// This is a HTTP response we'll be sending back to the client.
public struct HTTPResponse {
    private var message: Message
    public init(statusCode: Int, statusDescription: String?) {
        let status  = statusDescription ?? statusCode.defaultHTTPStatusDescription ?? "Unknown"
        message = Message(message: CFHTTPMessageCreateResponse(kCFAllocatorDefault, CFIndex(statusCode), status, kCFHTTPVersion1_1).takeRetainedValue())
        // We don't support keep-alive
        CFHTTPMessageSetHeaderFieldValue(message.backing, "Connection", "close")
    }
    
    public var bodyData: NSData {
        get {
            return CFHTTPMessageCopyBody(message.backing)?.takeRetainedValue() ?? NSData()
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
}

extension HTTPResponse : CustomStringConvertible {
    public var description: String {
        return String(data: message.backing.serialized() as! NSData, encoding: NSUTF8StringEncoding) ?? ""
    }
}



extension HTTPResponse {
    var serializedData: dispatch_data_t {
        return message.backing.serialized()
    }
    
    private mutating func ensureUnique() {
        if !isUniquelyReferencedNonObjC(&message) {
            message = message.copy()
        }
    }
}

extension HTTPResponse {
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


extension CFHTTPMessage {
    func messsageBodyLength() -> Int {
        // https://tools.ietf.org/html/rfc2616 section 4.4 "Message Length"
        let contentLenght = CFHTTPMessageCopyHeaderFieldValue(self, "Content-Length")?.takeRetainedValue() as? NSString
        let transferEncoding = CFHTTPMessageCopyHeaderFieldValue(self, "Transfer-Encoding")?.takeRetainedValue() as? String
        guard let l = contentLenght where transferEncoding != nil else { return 0 }
        return Int(l.integerValue)
    }
    func appendDispatchData(data: dispatch_data_t) {
        dispatch_data_apply(data, { (d, o, buffer, length) -> Bool in
            CFHTTPMessageAppendBytes(self, UnsafePointer<UInt8>(buffer), CFIndex(length))
            return true
        })
    }
    func serialized() -> dispatch_data_t {
        let data = CFHTTPMessageCopySerializedMessage(self)!.takeRetainedValue() as NSData
        let gcdData = dispatch_data_create(UnsafePointer<Void>(CFDataGetBytePtr(data)), Int(CFDataGetLength(data)), dispatch_get_global_queue(0, 0)) { () -> Void in
            let _ = Unmanaged.passRetained(data)
            return
        }
        return gcdData
    }
}
