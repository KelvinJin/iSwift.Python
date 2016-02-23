//
//  Header.swift
//  iSwiftCore
//
//  Created by Jin Wang on 19/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation

struct Header: JSONConvertable {
    /// typically UUID, must be unique per message
    let msgId: String
    
    let username: String
    
    /// typically UUID, should be unique per session
    let session: String
    
    /// ISO 8601 timestamp for when the message is created
    let date: NSDate
    
    /// All recognized message type strings are listed below
    let msgType: MessageType
    
    /// the message protocol version
    let version: String
    
    init(msgId: String = NSUUID().UUIDString, username: String = "kernel",
        session: String, date: NSDate = NSDate(), msgType: MessageType, version: String = "5.0") {
        self.msgId = msgId
        self.username = username
        self.session = session
        self.date = date
        self.msgType = msgType
        self.version = version
    }
    
    func toJSON() -> [String : AnyObject] {
        return ["msg_id": msgId,
            "username": username,
            "session": session,
            "date": date.toISO8601String(),
            "msg_type": msgType.rawValue,
            "version": version]
    }
    
    static func fromJSON(json: [String : AnyObject]) -> Header? {
        guard let msgId = json["msg_id"] as? String,
            username = json["username"] as? String,
            session = json["session"] as? String,
            date = (json["date"] as? String)?.toISO8601Date(),
            msgTypeStr = json["msg_type"] as? String,
            msgType = MessageType(rawValue: msgTypeStr),
            version = json["version"] as? String
            else { return nil }
        
        return Header(msgId: msgId, username: username, session: session, date: date, msgType: msgType, version: version)
    }
}