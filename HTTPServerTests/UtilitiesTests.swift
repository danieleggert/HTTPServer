//
//  UtilitiesTests.swift
//  HTTPServer
//
//  Created by Daniel Eggert on 04/05/2015.
//  Copyright (c) 2015 Wire. All rights reserved.
//

import Foundation
import XCTest

class UtilitiesTests: XCTestCase {
    func testCreatingDateStrings() {
        let d = NSDate(timeIntervalSinceReferenceDate: 452457730)
        XCTAssertEqual(d.HTTPFormattedDateString(timeZone: NSTimeZone(abbreviation: "GMT")!), "Mon, 04 May 2015 18:42:10 GMT")
    }
}
