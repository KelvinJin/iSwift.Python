//
//  ConcurrentArray.swift
//  iSwiftCore
//
//  Created by Jin Wang on 25/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

class ConcurrentArray<T> {
    private var dataSource: Array<T>
    
    init() {
        self.dataSource = [T]()
    }
    
    func append(element: T) {
        synchronized(self) {
            dataSource.append(element)
        }
    }
    
    func removeLast() -> T {
        return synchronized(self) { () -> T in
            return dataSource.removeLast()
        }
    }
    
    func removeFirst() -> T {
        return synchronized(self) { () -> T in
            return dataSource.removeFirst()
        }
    }
    
    func removeAtIndex(index: Int) -> T {
        return synchronized(self) { () -> T in
            return dataSource.removeAtIndex(index)
        }
    }
    
    func removeAll(keepCapacity keepCapacity: Bool = false) {
        synchronized(self) {
            dataSource.removeAll(keepCapacity: keepCapacity)
        }
    }
}