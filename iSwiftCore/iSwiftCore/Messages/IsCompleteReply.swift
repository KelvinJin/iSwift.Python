//
//  IsCompleteReply.swift
//  iSwiftCore
//
//  Created by Jin Wang on 25/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

struct IsCompleteReply: Contentable {
    let status: String
    let indent: String?
    
    func toJSON() -> [String : AnyObject] {
        if let indent = indent {
            return ["status": status, "indent": indent]
        } else {
            return ["status": status]
        }
    }
    
    static func fromJSON(_ json: [String : AnyObject]) -> IsCompleteReply? {
        return nil
    }
}
