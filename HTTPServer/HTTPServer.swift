//
//  HTTPServer.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 03/02/2015.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import Foundation
import SocketHelpers



public typealias RequestHandler = (request: HTTPRequest, clientAddress: SocketAddress, responseHandler:(HTTPResponse?) -> ()) -> ()



/// This handler can be passed to SocketServer.withAcceptHandler to create an HTTP server.
public func httpConnectionHandler(channel: dispatch_io_t, clientAddress: SocketAddress, queue: dispatch_queue_t, handler: RequestHandler) -> () {
    //dispatch_io_set_low_water(channel, 1);
    // high water mark defaults to SIZE_MAX
    dispatch_io_set_interval(channel, 10 * NSEC_PER_MSEC, DISPATCH_IO_STRICT_INTERVAL)
    
    var accumulated: dispatch_data_t = dispatch_data_create(nil, 0, queue, nil)
    
    var request = RequestInProgress.None
    
    let OperationCancelledError = Int32(89)
    
    dispatch_io_read(channel, 0, Int.max, queue) {
        (done, data: dispatch_data_t!, error) in
        if (error != 0 && error != OperationCancelledError) {
            print("Error on channel: \(String.fromCString(strerror(error))!) (\(error))")
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
            let r = d.rangeOfData(NSData(bytes: "\r\n\r\n", length: 4), options: NSDataSearchOptions(rawValue: 0), range: NSMakeRange(0, d.length))
            if r.location == NSNotFound {
                return RequestInProgressAndRemainder(.IncompleteHeader, data)
            } else {
                let end = Int(r.location + 4)
                let (header, tail) = splitData(data, location: end)
                let message = CFHTTPMessageCreateEmpty(nil, true).takeRetainedValue()
                message.appendDispatchData(header)
                if !CFHTTPMessageIsHeaderComplete(message) {
                    return RequestInProgressAndRemainder(.Error, data)
                } else {
                    let bodyLength = message.messsageBodyLength()
                    if bodyLength <= dispatch_data_get_size(tail) {
                        let (head, tail2) = splitData(tail, location: bodyLength)
                        message.appendDispatchData(head) // CFHTTPMessageSetBody() ?
                        return RequestInProgressAndRemainder(.Complete(message, bodyLength), tail2)
                    }
                    return RequestInProgressAndRemainder(.IncompleteMessage(message, bodyLength), tail)
                }
            }
        case let .IncompleteMessage(message, bodyLength):
            if bodyLength <= dispatch_data_get_size(data) {
                let (head, tail) = splitData(data, location: bodyLength)
                message.appendDispatchData(head) // CFHTTPMessageSetBody() ?
                return RequestInProgressAndRemainder(.Complete(message, bodyLength), tail)
            }
            return RequestInProgressAndRemainder(.IncompleteMessage(message, bodyLength), data)
        case let .Complete(message, bodyLength):
            return RequestInProgressAndRemainder(.Complete(message, bodyLength), data)
        }
    }
}

