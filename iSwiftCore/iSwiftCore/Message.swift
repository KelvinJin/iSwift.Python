//
//  Message.swift
//  iSwiftCore
//
//  Created by Jin Wang on 19/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

enum MessageType: String {
    case KernelInfoRequest = "kernel_info_request"
    case KernelInfoReply = "kernel_info_reply"
    case ExecuteRequest = "execute_request"
    case ExecuteReply = "execute_reply"
    case HistoryRequest = "history_request"
    case HistoryReply = "history_reply"
}

struct Message {
    /// The message header contains a pair of unique identifiers for the
    /// originating session and the actual message id, in addition to the
    /// username for the process that generated the message.  This is useful in
    /// collaborative settings where multiple users may be interacting with the
    /// same kernel simultaneously, so that frontends can label the various
    /// messages in a meaningful way.
    let header: Header
    
    /// In a chain of messages, the header from the parent is copied so that
    /// clients can track where messages come from.
    let parentHeader: Header?
    
    /// Any metadata associated with the message.
    let metadata: [String: AnyObject]
    
    /// The actual content of the message must be a dict, whose structure
    /// depends on the message type.
    let content: Contentable
    
    func toSHA256(key: String) -> String {
        let digestor = SHA256(key: key)
        
        let emptyDict: [String: AnyObject] = [:]
        
        digestor.update(header.toBytes())
        digestor.update(parentHeader?.toBytes() ?? emptyDict.toBytes())
        digestor.update(emptyDict.toBytes())
        digestor.update(content.toBytes())
        
        return digestor.hexDigest()
        
    }
}