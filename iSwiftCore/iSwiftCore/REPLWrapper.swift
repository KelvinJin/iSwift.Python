//
//  REPLWrapper.swift
//  iSwiftCore
//
//  Created by Jin Wang on 24/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

enum REPLState {
    case Prompt
    case Input
    case Output
}

class REPLWrapper {
    private let command: String
    private var prompt: String
    private var continuePrompt: String
    private var communicator: NSFileHandle!
    private var state: REPLState = .Prompt
    private var lastOutput: String = ""
    private var semaphore = dispatch_semaphore_create(0)
    
    init(command: String, prompt: String, continuePrompt: String) throws {
        self.command = command
        self.prompt = prompt
        self.continuePrompt = continuePrompt
        
        let task = NSTask()
        task.launchPath = command
        
        communicator = try task.masterSideOfPTY()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceivedData:",
            name: NSFileHandleDataAvailableNotification, object: nil)
        
        communicator.waitForDataInBackgroundAndNotify()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "taskDidTerminated:",
            name: NSTaskDidTerminateNotification, object: nil)
        
        task.launch()
    }
    
    func didReceivedData(notification: NSNotification) {
        let data = communicator.availableData
        
        guard let dataStr = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else { return }
        
        switch state {
        case .Output, .Input:
            // Although we get some input when we're expecting output, we'll still pass it through.
            didReceivedOutput(dataStr)
        case .Prompt:
            // Check if this is a valid prompt string.
            if dataStr.match(prompt) {
                didReceivedPrompt()
            }
        }
    }
    
    func taskDidTerminated(notification: NSNotification) {
        
    }
    
    func sendLine(code: String) -> String {
        if let codeData = code.dataUsingEncoding(NSUTF8StringEncoding) {
            communicator.writeData(codeData)
        }
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        
        return lastOutput
    }
    
    func expect(pattern: String) {
        
    }
    
    private func didReceivedOutput(output: String) {
        lastOutput = output
        
        dispatch_semaphore_signal(semaphore)
    }
    
    private func didReceivedPrompt() {
        
    }
}