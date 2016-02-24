//
//  NSTask+PTY.swift
//  InteractiveShell
//
//  Created by Jin Wang on 22/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

extension NSTask {
    func masterSideOfPTY() throws -> NSFileHandle {
        var fdMaster: Int32 = 0
        var fdSlave: Int32 = 0
        
        let rc = openpty(&fdMaster, &fdSlave, nil, nil, nil)
        
        if rc != 0 {
            let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            throw error
        }
        
        c_fcntl(fdMaster, F_SETFD, FD_CLOEXEC)
        c_fcntl(fdSlave, F_SETFD, FD_CLOEXEC)
        
        let masterHandle = NSFileHandle(fileDescriptor: fdMaster, closeOnDealloc: true)
        let slaveHandle = NSFileHandle(fileDescriptor: fdSlave, closeOnDealloc: true)
        
        standardInput = slaveHandle
        standardOutput = slaveHandle
        
        return masterHandle
    }
}