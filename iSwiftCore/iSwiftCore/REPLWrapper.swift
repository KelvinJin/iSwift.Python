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

class REPLWrapper: NSObject {
    private let command: String
    private var prompt: String
    private var continuePrompt: String
    private var communicator: NSFileHandle!
    private var state: REPLState = .Prompt
    private var lastOutput: String = ""
    private var outputSemaphore = dispatch_semaphore_create(0)
    private var promptSemaphore = dispatch_semaphore_create(0)
    
    private let runModes = [NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode]
    
    init(command: String, prompt: String, continuePrompt: String) throws {
        self.command = command
        self.prompt = prompt
        self.continuePrompt = continuePrompt
        
        super.init()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { [unowned self] in
            do {
                try self.launchTask(command)
            } catch let e {
                Logger.Critical.print(e)
            }
        }
        
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
            } else {
                didReceivedOutput(dataStr)
            }
        }
        
        communicator.waitForDataInBackgroundAndNotifyForModes(runModes)
    }
    
    func taskDidTerminated(notification: NSNotification) {
    }
    
    // The command might be a multiline command.
    func runCommand(cmd: String, wait: Bool = true) -> String {
        // Clear the previous output.
        lastOutput = ""
        
        for line in cmd.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()) {
            // Get rid of the new line stuff which make no sense.
            let trimmedLine = line.trim()
            guard !trimmedLine.isEmpty else { continue }
            
            sendLine(cmd)
            dispatch_semaphore_wait(outputSemaphore, DISPATCH_TIME_FOREVER)
            
            if wait {
                expectPrompts()
            }
        }
        
        // Next input
        state = .Input
        
        return lastOutput
    }
    
    func expectPrompts() {
        // Ready for Prompt
        state = .Prompt
        
        expect([prompt, continuePrompt])
    }
    
    private func launchTask(command: String) throws {
        let task = NSTask()
        task.launchPath = command
        
        communicator = try task.masterSideOfPTY()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didReceivedData:",
            name: NSFileHandleDataAvailableNotification, object: nil)
        
        communicator.waitForDataInBackgroundAndNotifyForModes(runModes)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "taskDidTerminated:",
            name: NSTaskDidTerminateNotification, object: nil)
        
        task.launch()
        
        task.waitUntilExit()
    }
    
    private func sendLine(var code: String) {
        if !code.hasSuffix("\n") {
            code += "\n"
        }
        
        if let codeData = code.dataUsingEncoding(NSUTF8StringEncoding) {
            // Ready for output.
            state = .Output
            
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