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
    private var outputSemaphore = dispatch_semaphore_create(0)
    private var promptSemaphore = dispatch_semaphore_create(0)
    
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
        
        expectPrompts()
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
    
    func runCommand(cmd: String, wait: Bool = true) -> String {
        // Ready for output.
        state = .Output
        
        sendLine(cmd)
        
        if wait {
            // Ready for Prompt
            state = .Prompt
            
            expectPrompts()
        }
        
        dispatch_semaphore_wait(outputSemaphore, DISPATCH_TIME_FOREVER)
        
        // Reset the output.
        let _lastOutput = lastOutput
        lastOutput = ""
        
        // Next input
        state = .Input
        
        return _lastOutput
    }
    
    func expectPrompts() {
        expect([prompt, continuePrompt])
    }
    
    private func sendLine(code: String) {
        if let codeData = code.dataUsingEncoding(NSUTF8StringEncoding) {
            communicator.writeData(codeData)
        }
    }
    
    private func expect(patterns: [String]) {
        dispatch_semaphore_wait(promptSemaphore, DISPATCH_TIME_FOREVER)
        
        return
    }
    
    private func didReceivedOutput(output: String) {
        lastOutput += output
        
        dispatch_semaphore_signal(outputSemaphore)
    }
    
    private func didReceivedPrompt() {
        dispatch_semaphore_signal(promptSemaphore)
    }
}