//
//  HistoryReply.swift
//  iSwiftCore
//
//  Created by Jin Wang on 20/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

struct HistoryReply: Contentable {
    /// If True, also return output history in the resulting dict.
    let history: [(Int, Int, String)]
    
    func toJSON() -> [String : AnyObject] {
        return ["history": []]
    }
    
    static func fromJSON(_ json: [String : AnyObject]) -> HistoryReply? {
        return nil
    }
}
