//
//  REPLWrapper.swift
//  iSwiftCore
//
//  Created by Jin Wang on 24/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation
import Bond

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
    private var lastOutput: String = ""
    private var consoleOutput = Observable<String>("")
    
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
        
        expect([prompt])
    }
    
    func didReceivedData(notification: NSNotification) {
        let data = communicator.availableData
        
        guard let dataStr = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else { return }
        
        // For every data the console gives, it can be a new prompt or a continue prompt or an actual output.
        // We'll need to deal with it accordingly.
        if dataStr.match(prompt, options: [.AnchorsMatchLines]) {
            // It's a new prompt.
        } else if dataStr.match(continuePrompt, options: [.AnchorsMatchLines]) {
            // It's a continue prompt. It means the console is expecting more data.
        } else {
            // It's a raw output.
        }
        
        // Sometimes, the output will contain multiline string. We can't deal with them once. We
        // need to separater them, so that the prompt is dealt in time and the raw output will be captured.
        let lines = dataStr.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        
        for (index, line) in lines.enumerate() {
            guard !line.isEmpty else { continue }
            
            // Don't remember to add a new line to compensate the loss of the non last line.
            if index == lines.count - 1 && !dataStr.hasSuffix("\n") {
                consoleOutput.next(line)
            } else {
                consoleOutput.next("\(line)\n")
            }
        }
        
        communicator.waitForDataInBackgroundAndNotifyForModes(runModes)
    }
    
    func taskDidTerminated(notification: NSNotification) {
    }
    
    // The command might be a multiline command.
    func runCommand(cmd: String) -> String {
        // Clear the previous output.
        var currentOutput = ""
        
        // We'll observe the output stream and make sure all non-prompts gets recorded into output.
        
        for line in cmd.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet()) {
            // Send out this line for execution.
            sendLine(line)
            
            // For each line, the console will either give back
            // an output (might empty) + an prompt or an continue
            // prompt.
            expect([prompt, continuePrompt]) { output in
                currentOutput += output
            }
        }
        
        lastOutput = currentOutput
        
        // It doesn't matter whether there's any output or not.
        // If the command triggered no output then we'll just return
        // empty string.
        return lastOutput
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
    
    private func sendLine(code: String) {
        // Get rid of the new line stuff which make no sense.
        var trimmedLine = code.trim()
        
        // Only one new line character is needed. And we need
        // this new line if the trimmed code is empty.
        trimmedLine += "\n"
        
        if let codeData = trimmedLine.dataUsingEncoding(NSUTF8StringEncoding) {
            communicator.writeData(codeData)
        }
    }
    
    private func expect(patterns: [String], otherHandler: (String) -> Void = { _ in }) {
        let promptSemaphore = dispatch_semaphore_create(0)
        
        let dispose = consoleOutput.observeNew {(output) -> Void in
            for pattern in patterns where output.match(pattern) {
                dispatch_semaphore_signal(promptSemaphore)
                return
            }
            otherHandler(output)
        }
        
        dispatch_semaphore_wait(promptSemaphore, DISPATCH_TIME_FOREVER)
        
        dispose.dispose()
    }
}