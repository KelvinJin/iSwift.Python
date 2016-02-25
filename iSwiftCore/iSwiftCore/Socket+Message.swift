//
//  Socket+Message.swift
//  iSwiftCore
//
//  Created by Jin Wang on 25/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation
import SwiftZMQ

// We can only send message one by one. This is for sure.
private let SocketSendQueue = dispatch_queue_create("iSwiftCore.Socket", nil)

extension Socket {
    func sendMessage(message: Message) throws {
        dispatch_async(SocketSendQueue) { [weak self] () -> Void in
            do {
                Logger.Debug.print("Sending message header \(message.header)")
                Logger.Debug.print("Sending message signature \(message.signature)")
                Logger.Debug.print("Sending message content \(message.content)")
                let messageBlobs = [message.header.session, Message.Delimiter, message.signature,
                    message.header.toJSONString(), message.parentHeader?.toJSONString() ?? "{}", "{}",
                    message.content.toJSONString()]
                for (index, dataStr) in messageBlobs.enumerate() {
                    try self?.sendString(dataStr, mode: index == messageBlobs.count - 1 ? [] : .SendMore)
                }
            } catch let e {
                Logger.Critical.print(e)
            }
        }
    }
}