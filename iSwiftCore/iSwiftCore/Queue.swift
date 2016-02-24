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
    
    init() {
        dataSource = [Element]()
        dataSemaphore = dispatch_semaphore_create(0)
    }
    
    func add(e: Element) {
        dataSource.append(e)
        
        Logger.Debug.print("Blocking Queue adding element.")
        
        // New data available.
        dispatch_semaphore_signal(dataSemaphore)
    }
    
    func take(timeout: NSTimeInterval? = nil) -> Element {
        let t: dispatch_time_t
        if let timeout = timeout {
            t = dispatch_time(DISPATCH_TIME_NOW, Int64(timeout * Double(NSEC_PER_SEC)))
        } else {
            t = DISPATCH_TIME_FOREVER
        }
        
        dispatch_semaphore_wait(dataSemaphore, t)
        
        // This will throw error if there's no element.
        return dataSource.removeFirst()
    }
}