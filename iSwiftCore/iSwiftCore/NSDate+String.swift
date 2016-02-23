//
//  NSDate+String.swift
//  iSwiftCore
//
//  Created by Jin Wang on 19/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

private var ISO8601DateFormatter: NSDateFormatter {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
    return dateFormatter
}

extension NSDate {
    func toISO8601String() -> String {
        return ISO8601DateFormatter.stringFromDate(self)
    }
}

extension String {
    func toISO8601Date() -> NSDate? {
        return ISO8601DateFormatter.dateFromString(self)
    }
}