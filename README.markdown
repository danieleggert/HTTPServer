# HTTPServer

A simple embedded HTTP server written in Swift.

## Goals

This framework provides an embeddable HTTP/1.1 server. It was written to be used for testing [NSURLSession](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/URLLoadingSystem/Articles/UsingNSURLSession.html) based code in [XCTest](https://developer.apple.com/library/ios/documentation/DeveloperTools/Conceptual/testing_with_xcode/) based test setups.

## Non-Goals

This is not a replacement for [Nginx](http://nginx.com).

This does not implement serving any files etc. It simply exposes an API for clients of the framework to fill in as needed.

The point is to _not_ provide any HTTP routing. This framework is intentionally simple and bare bones (A µ-Framework if you will) -- to be used as a building block for more complex setups.

## How To Use

The test shows how this can be used. A `SocketServer` in instanciated and the `httpConnectionHandler()` function passed to it to handle new incomming connections like so:

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
        fatalError("Unable to create HTTP server: \($0)")
    })

Note how the inner most handler receives a `HTTPRequest` and in response calls the `response` handler with a `HTTPResponse` it generates.

## Known Issues

 * Better documentaiton. ;)
 * No support for [HTTP persistent connection](https://en.wikipedia.org/wiki/HTTP_persistent_connection). This could be added.
 * Clean up GCD queue usage. Currently this is a bit confusing and not streamlined.
 * Better shutdown support. It may be good to be able to wait for the server to have shut down, e.g. by exposing a `dispatch_group_t`.

Please file issues or send pull requests.

## License

Permissive [ISC License](https://en.wikipedia.org/wiki/ISC_license)
