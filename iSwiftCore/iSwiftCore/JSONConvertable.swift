//
//  JSONConvertable.swift
//  iSwiftCore
//
//  Created by Jin Wang on 19/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

protocol JSONConvertable {
    static func fromJSON(json: [String: AnyObject]) -> Self?
    func toJSON() -> [String: AnyObject]
}

extension JSONConvertable {
    func toData() -> NSData { return toJSON().toData() }
    func toBytes() -> [UInt8] { return toJSON().toBytes() }
    func toJSONString() -> String {
        return (NSString(data: toData(), encoding: NSUTF8StringEncoding) ?? "") as String
    }
}

extension Dictionary where Key: StringLiteralConvertible, Value: AnyObject {
    func toData() -> NSData {
        do {
            if let dict = (self as? AnyObject) as? Dictionary<String, AnyObject> {
                return try NSJSONSerialization.dataWithJSONObject(dict, options: [])
            }
            return NSData()
        } catch let e {
            print("NSJSONSerialization Error: \(e)")
            return NSData()
        }
    }
    
    func toBytes() -> [UInt8] {
        let data = toData()
        let count = data.length
        var bytes = [UInt8](count: count, repeatedValue: 0)
        data.getBytes(&bytes, length: count)
        
        return bytes
    }
}
