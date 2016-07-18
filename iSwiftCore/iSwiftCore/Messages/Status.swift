//
//  Status.swift
//  iSwiftCore
//
//  Created by Jin Wang on 25/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

struct Status: Contentable {
    let executionState: String
    
    func toJSON() -> [String : AnyObject] {
        return ["execution_state": executionState]
    }
    
    static func fromJSON(_ json: [String : AnyObject]) -> Status? {
        return nil
    }
}
