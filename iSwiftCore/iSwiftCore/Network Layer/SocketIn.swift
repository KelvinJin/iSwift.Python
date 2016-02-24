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
    
    static func run(socket: Socket, outMessageQueue: BlockingQueue<Message>) {
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
                            
                            // Added to the queue
                            outMessageQueue.add(message)
                        } catch let e {
                            Logger.Info.print(e)
                        }
                        
                        // Remove the previous blobs.
                        messageBlobs.removeAll(keepCapacity: true)
                        
                        // Start reading...
                        startReading = true
                    } else if startReading {
                        messageBlobs.append(recv)
                    }
                }
            } catch let e {
                Logger.Info.print(e)
            }
        }
    }
    
    static private func constructMessage(messageBlobs: [String]) throws -> Message {
        // Make sure there are enough blobs.
        guard messageBlobs.count >= 5 else {
            throw Error.SocketError("message blobs are not enough.")
        }
        
        // Signature.
        let signature = messageBlobs[0]
        
        // Must have a header.
        Logger.Debug.print("Parsing header...")
        let header = try parse(messageBlobs[1], converter: Header.fromJSON)
        
        // May not have a parent header.
        Logger.Debug.print("Parsing parent header...")
        let parentHeaderStr = try parse(messageBlobs[2]) { $0 }
        let parentHeader = Header.fromJSON(parentHeaderStr)
        
        // Can be an empty metadata.
        Logger.Debug.print("Parsing metadata...")
        let metadata = try parse(messageBlobs[3]) { $0 }
        
        // For content, it's a bit complicated.
        Logger.Debug.print("Parsing content...")
        
        // FIXME: Rewrite the following codes.
        let content: Contentable
        switch header.msgType {
        case .KernelInfoRequest:
            content = try parse(messageBlobs[4], converter: KernelInfoRequest.fromJSON)
        case .KernelInfoReply:
            content = try parse(messageBlobs[4], converter: KernelInfoReply.fromJSON)
        case .ExecuteRequest:
            content = try parse(messageBlobs[4], converter: ExecuteRequest.fromJSON)
        case .ExecuteReply:
            content = try parse(messageBlobs[4], converter: ExecuteReply.fromJSON)
        case .HistoryRequest:
            content = try parse(messageBlobs[4], converter: HistoryRequest.fromJSON)
        case .HistoryReply:
            content = try parse(messageBlobs[4], converter: HistoryReply.fromJSON)
        }
        
        // The rest would be extra blobs.
        Logger.Debug.print("Parsing extraBlobs...")
        let extraBlobs: [String] = messageBlobs.count >= 6 ? messageBlobs.suffixFrom(5).flatMap { $0 } : []
        
        return Message(signature: signature, header: header, parentHeader: parentHeader, metadata: metadata, content: content, extraBlobs: extraBlobs)
    }
    
    static private func parse<T>(str: String, converter: (([String: AnyObject]) -> T?)) throws -> T {
        guard let json = str.toJSON(), re = converter(json) else {
            throw Error.SocketError("Parse \(str) to object \(T.self) failed.")
        }
        
        return re
    }
}