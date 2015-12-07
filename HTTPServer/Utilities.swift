//
//  Utilities.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 04/05/2015.
//  Copyright (c) 2015 Wire. All rights reserved.
//

import Foundation


extension NSDate {
    /// Returns the date formatted according to RFC 2616 section 3.3.1
    /// specifically RFC 822, updated by RFC 1123
    public func HTTPFormattedDateString(timeZone timeZone: NSTimeZone = NSTimeZone.systemTimeZone()) -> String {
        let timeZoneString = timeZone.abbreviation ?? "GMT"
        var dateString: String? = nil
        timeZoneString.withCString { (timeZonePointer) -> () in
            var t = time_t(self.timeIntervalSince1970)
            var timeptr = tm()
            gmtime_r(&t, &timeptr)
            timeptr.tm_zone = UnsafeMutablePointer<Int8>(timeZonePointer)
            let locale = newlocale(0, "POSIX", locale_t())
            var buffer = ContiguousArray<Int8>(count: 40, repeatedValue: 0)
            let bufferSize = buffer.count
            buffer.withUnsafeMutableBufferPointer { (inout b: UnsafeMutableBufferPointer<Int8>) -> () in
                if 0 < strftime_l(b.baseAddress, bufferSize, "%a, %d %b %Y %H:%M:%S %Z", &timeptr, locale) {
                    dateString = String.fromCString(UnsafePointer<CChar>(b.baseAddress))
                }
            }
            freelocale(locale)
        }
        return dateString!
    }
}


extension Int {
    
    public var defaultHTTPStatusDescription: String? {
        switch self {
        case 100: return "Continue"
        case 101: return "Switching Protocols"
        case 102: return "Processing"
            
        case 200: return "Ok"
        case 201: return "Created"
        case 202: return "Accepted"
        case 203: return "Non-Authoritative Information"
        case 204: return "No Content"
        case 205: return "Reset Content"
        case 206: return "Partial Content"
        case 207: return "Multi-Status"
        case 208: return "Already Reported"
        case 226: return "IM Used"
            
        case 300: return "Multiple Choices"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 303: return "See Other"
        case 304: return "Not Modified"
        case 305: return "Use Proxy"
        case 306: return "Switch Proxy"
        case 307: return "Temporary Redirect"
        case 308: return "Permanent Redirect"
            
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 402: return "Payment Required"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 406: return "Not Acceptable"
        case 407: return "Proxy Authentication Required"
        case 408: return "Request Timeout"
        case 409: return "Conflict"
        case 410: return "Gone"
        case 411: return "Length Required"
        case 412: return "Precondition Failed"
        case 413: return "Request Entity Too Large"
        case 414: return "Request-URI Too Long"
        case 415: return "Unsupported Media Type"
        case 416: return "Requested Range Not Satisfiable"
        case 417: return "Expectation Failed"
        case 418: return "I'm a teapot"
        case 419: return "Authentication Timeout"
        case 420: return "Method Failure"
        case 421: return "Misdirected Request"
        case 422: return "Unprocessed Entity"
        case 423: return "Locked"
        case 424: return "Failed Dependency"
        case 426: return "Upgrade Required"
        case 428: return "Precondition Required"
        case 429: return "Too Many Requests"
        case 431: return "Request Header Fields Too Large"
        case 440: return "Login Timeout"
        case 444: return "No Response"
        case 449: return "Retry With"
        case 450: return "Blocked by Windows Parental Controls"
        case 451: return "Unavailable For Legal Reasons"
        case 494: return "Request Header Too Large"
        case 495: return "Cert Error"
        case 496: return "No Cert"
        case 497: return "HTTP to HTTPS"
        case 498: return "Token expired/invalid"
        case 499: return "Client Closed Request"

        case 500: return "Internal Server Error"
        case 501: return "Not Implemented"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        case 504: return "Gateway Timeout"
        case 505: return "HTTP Version Not Supported"
        case 506: return "Variant Also Negotiates"
        case 507: return "Insufficient Storage"
        case 508: return "Loop Detected"
        case 509: return "Bandwidth Limit Exceeded"
        case 510: return "Not Extended"
        case 511: return "Network Authentication Required"
        case 598: return "Network read timeout error"
        case 599: return "Network connect timeout error"
        default: return nil
        }
    }
}
