//
//  Errors.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 10/06/2015.
//  Copyright © 2015 Wire. All rights reserved.
//

import Foundation



struct Error : ErrorType {
    let operation: String
    let backing: POSIXError
    let file: String
    let line: UInt
    var _code: Int { return backing._code }
    var _domain: String { return backing._domain }
}

extension Error {
    init(operation: String, errno: CInt, file: String = __FILE__, line: UInt = __LINE__) {
        self.operation = operation
        self.backing = POSIXError(rawValue: errno)!
        self.file = file
        self.line = line
    }
}


extension Error : CustomStringConvertible {
    var description: String {
        let s = String.fromCString(strerror(errno))
        return "\(operation) failed: \(s) (\(_code))"
    }
}


/// The 1st closure must return `true` is the result is an error.
/// The 2nd closure is the operation to be performed.
func attempt(name: String, file: String = __FILE__, line: UInt = __LINE__, @noescape valid: (CInt) -> Bool, @autoclosure _ b: () -> CInt) throws -> CInt {
    let r = b()
    guard valid(r) else {
        throw Error(operation: name, errno: r, file: file, line: line)
    }
    return r
}

func isNotNegative1(r: CInt) -> Bool {
    return r != -1
}
func is0(r: CInt) -> Bool {
    return r != -1
}


///
func ignoreAndLogErrors(@noescape b: () throws -> ()) {
    do {
        try b()
    } catch let e {
        print("error: \(e)")
    }
}
