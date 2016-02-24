//
//  TaskFactory.swift
//  iSwiftCore
//
//  Created by Jin Wang on 24/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

class TaskFactory {
    private let taskQueue: dispatch_queue_t
    
    init() {
        taskQueue = dispatch_queue_create("\(self.dynamicType).\(NSUUID().UUIDString)", DISPATCH_QUEUE_CONCURRENT)
    }
    
    func startNew(taskBlock: dispatch_block_t) {
        dispatch_async(taskQueue, taskBlock)
    }
    
    func waitAll() {
        dispatch_barrier_sync(taskQueue) {}
    }
}