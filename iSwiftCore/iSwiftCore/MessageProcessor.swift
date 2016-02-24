//
//  MessageProcessor.swift
//  iSwiftCore
//
//  Created by Jin Wang on 24/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

class MessageProcessor {
    static var executionCount: Int {
        _executionCount += 1
        return _executionCount
    }
    
    static var _executionCount: Int = 0
    
    static func run(inMessageQueue: BlockingQueue<Message>, outMessageQueue: BlockingQueue<Message>) {
        while true {
            let message = inMessageQueue.take()
            let requestHeader = message.header
            
            Logger.Debug.print("Processing new message...")
            
            guard let replyType = requestHeader.msgType.replyType else { continue }
            
            let replyHeader = Header(session: requestHeader.session, msgType: replyType)
            
            let replyContent: Contentable
            switch replyType {
            case .KernelInfoReply:
                replyContent = KernelInfoReply()
            case .HistoryReply:
                replyContent = HistoryReply(history: [])
            case .ExecuteReply:
                replyContent = ExecuteReply(status: .Ok, executionCount: executionCount, userExpressions: nil)
            default:
                continue
            }
            
            let replyMessage = Message(header: replyHeader, parentHeader: requestHeader, metadata: [:], content: replyContent)
            
            outMessageQueue.add(replyMessage)
        }
    }
}