//
//  SocketIn.swift
//  iSwiftCore
//
//  Created by Jin Wang on 23/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation
import SwiftZMQ

class SocketIn {
    
    func run(socket: Socket, inputMessageQueue: BlockingQueue<Message>) {
        // Make sure the socket has been running.
        guard let _ = try? socket.getFileDescriptor() else { return }
        
        // Now, let's wait for the message identifier.
        var messageBlobs: [String] = []
        var startReading = false
        
        while true {
            do {
                if let recv = try socket.receiveString() {
                    if recv == Message.Delimiter {
                        // It seems to be a new message coming.
                        
                        do {
                            // Let's finish the previous one.
                            let message = try constructMessage(messageBlobs)
                            
                            // Added to the queuq
                            try inputMessageQueue.add(message)
                        } catch let e {
                            Logger.Info.print(e)
                        }
                        
                        // Remove the previous blobs.
                        messageBlobs.removeAll(keepCapacity: true)
                        
                        // Start reading...
                        startReading = true
                    }
                    
                    if startReading {
                        messageBlobs.append(recv)
                    }
                }
            } catch let e {
                Logger.Info.print(e)
            }
        }
    }
    
    private func constructMessage(messageBlobs: [String]) throws -> Message {
        // Make sure there are enough blobs.
        guard messageBlobs.count >= 5 else {
            throw Error.SocketError("message blobs are not enough.")
        }
        
        // Signature.
        let signature = messageBlobs[0]
        
        // Must have a header.
        let header = try parse(messageBlobs[1], converter: Header.fromJSON)
        
        // May not have a parent header.
        let parentHeaderStr = try parse(messageBlobs[2]) { $0 }
        let parentHeader = Header.fromJSON(parentHeaderStr)
        
        // Can be an empty metadata.
        let metadata = try parse(messageBlobs[3]) { $0 }
        
        // For content, it's a bit complicated.
        
        let content = try parse(messageBlobs[4], converter: header.msgType.constructFunc)
        
        // The rest would be extra blobs.
        let extraBlobs: [String] = messageBlobs.count >= 6 ? messageBlobs.suffixFrom(5).flatMap { $0 } : []
        
        return Message(signature: signature, header: header, parentHeader: parentHeader, metadata: metadata, content: content, extraBlobs: extraBlobs)
    }
    
    private func parse<T>(str: String, converter: (([String: AnyObject]) -> T?)) throws -> T {
        guard let json = str.toJSON(), re = converter(json) else {
            throw Error.SocketError("Parse string to json failed. \(str)")
        }
        
        return re
    }
}