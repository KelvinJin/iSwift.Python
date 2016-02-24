//
//  SocketOut.swift
//  iSwiftCore
//
//  Created by Jin Wang on 23/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation
import SwiftZMQ

class SocketOut {
    static func run(socket: Socket, inMessageQueue: BlockingQueue<Message>) {
        while true {
            do {
                // Blockingly take message from the queue.
                let message = inMessageQueue.take()
                
                // Sequently send each part of the message.
                let messageBlobs = [message.header.session, Message.Delimiter, message.signature,
                    message.header.toJSONString(), message.parentHeader?.toJSONString() ?? "{}", "{}",
                    message.content.toJSONString()]
                for (index, dataStr) in messageBlobs.enumerate() {
                    try socket.sendString(dataStr, mode: index == messageBlobs.count - 1 ? .DontWait : .SendMore)
                }
            } catch let e {
                Logger.Info.print(e)
            }
        }
    }
}