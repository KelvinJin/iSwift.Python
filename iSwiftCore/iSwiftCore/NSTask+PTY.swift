//
//  NSTask+PTY.swift
//  InteractiveShell
//
//  Created by Jin Wang on 22/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

extension NSTask {
    func masterSideOfPTY(echoOn: Bool = false) throws -> NSFileHandle {
        var fdMaster: Int32 = 0
        var fdSlave: Int32 = 0
        
        let rc = openpty(&fdMaster, &fdSlave, nil, nil, nil)
        
        if rc != 0 {
            let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
            throw error
        }
        
        c_fcntl(fdMaster, F_SETFD, FD_CLOEXEC)
        c_fcntl(fdSlave, F_SETFD, FD_CLOEXEC)
        
        if !echoOn {
            try turnOffEcho(fdMaster)
        }
        
        let masterHandle = NSFileHandle(fileDescriptor: fdMaster, closeOnDealloc: true)
        let slaveHandle = NSFileHandle(fileDescriptor: fdSlave, closeOnDealloc: true)
        
        standardInput = slaveHandle
        standardOutput = slaveHandle
        
        return masterHandle
    }
    
    private func turnOffEcho(fd: Int32) throws {
        // Code from http://man7.org/tlpi/code/online/book/tty/no_echo.c.html
        
        /* Retrieve current terminal settings, turn echoing off */
        var tp = termios()
        
        if (tcgetattr(fd, &tp) == -1) {
            throw Error.GeneralError("tcgetattr error.")
        }
        
        /* ECHO off, other bits unchanged */
        tp.c_lflag &= ~UInt(ECHO);
        if (tcsetattr(fd, TCSAFLUSH, &tp) == -1) {
            throw Error.GeneralError("tcsetattr error.")
        }
    }
}