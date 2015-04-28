//
//  HTTPServerTests.swift
//  HTTPServerTests
//
//  Created by Daniel Eggert on 03/02/2015.
//  Copyright (c) 2015 objc.io. All rights reserved.
//

import UIKit
import XCTest
import HTTPServer


class HTTPServerTests: XCTestCase {
    
    var server: SocketServer?
    var port: UInt16?
    
    override func setUp() {
        super.setUp()
        
        let q = dispatch_get_global_queue(0, 0)
        SocketServer.withAcceptHandler {
            (channel, clientAddress) in
            httpConnectionHandler(channel, clientAddress, q) {
                (request, clientAddress, response) in
                println("Request from \(clientAddress)")
                var r = HTTPResponse(statusCode: 200, statusDescription: "Ok")
                r.bodyData = "hey".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)!
                r.setHeaderField("Content-Length", value: "\(r.bodyData.length)")
                r.setHeaderField("Foo", value: "Bar")
                response(r)
            }
            println("New connection")
        }.analysis(ifSuccess: {
            server = $0
        }, ifFailure: {
            XCTFail("Unable to create HTTP server: \($0)")
        })
        port = server!.port
    }
    
    override func tearDown() {
        server = nil
        port = nil
        super.tearDown()
    }
    
    func URLComponentsForServer() -> NSURLComponents {
        let components = NSURLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = NSNumber(int: Int32(port!))
        return components
    }
    
    func URLForServerWithPath(path: String) -> NSURL {
        let components = URLComponentsForServer()
        components.path = path
        return components.URL!
    }
    
    func testASingleRequest() {
        
        let request = NSURLRequest(URL: URLForServerWithPath("/"))
        
        var response: NSURLResponse?
        var error: NSError?
        if let data = NSURLConnection.sendSynchronousRequest(request, returningResponse: &response, error: &error) {
            let httpResponse = response as! NSHTTPURLResponse
            let headers = httpResponse.allHeaderFields as! [String:String]
            XCTAssertEqual(headers["Foo"]!, "Bar")
            XCTAssertEqual(httpResponse.statusCode, 200)
        } else {
            XCTFail("Unable to get resource.")
        }
    }
    
    func testTwoRequests() {
        // Make sure both of these load without deadlocking:
        let dataA = NSData(contentsOfURL: URLForServerWithPath("/"))
        XCTAssertTrue(dataA != nil)
        let dataB = NSData(contentsOfURL: URLForServerWithPath("/"))
        XCTAssertTrue(dataB != nil)
    }
}
