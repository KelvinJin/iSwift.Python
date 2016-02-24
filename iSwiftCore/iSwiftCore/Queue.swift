//
//  Queue.swift
//  iSwiftCore
//
//  Created by Jin Wang on 24/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

class BlockingQueue<Element> {
    private var dataSource: [Element]
    private let dataSemaphore: dispatch_semaphore_t
    private let operationQueue: dispatch_queue_t
    
    init() {
        dataSource = [Element]()
        dataSemaphore = dispatch_semaphore_create(0)
        operationQueue = dispatch_queue_create("\(self.dynamicType).\(NSUUID().UUIDString)", DISPATCH_QUEUE_SERIAL)
    }
    
    func add(e: Element) throws {
        try sync { (queue) -> Void in
            queue.dataSource.append(e)
            dispatch_semaphore_signal(queue.dataSemaphore)
        }
    }
    
    func take(timeout: NSTimeInterval? = nil) throws {
        try sync { (queue) -> Void in
            queue.dataSource.popLast()
            
            let t: dispatch_time_t
            if let timeout = timeout {
                t = dispatch_time(DISPATCH_TIME_NOW, Int64(timeout * Double(NSEC_PER_SEC)))
            } else {
                t = DISPATCH_TIME_FOREVER
            }
            
            dispatch_semaphore_wait(queue.dataSemaphore, t)
        }
    }
    
    private func sync(operate: (BlockingQueue) -> Void) throws {
        var complete = false
        dispatch_sync(operationQueue) { [weak self] in
            guard let _self = self else { return }
            
            operate(_self)
            
            complete = true
        }
        guard complete else {
            throw Error.GeneralError("Queue is released before operation is done.")
        }
    }
}