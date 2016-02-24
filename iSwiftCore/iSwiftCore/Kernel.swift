//
//  Kernel.swift
//  iSwiftCore
//
//  Created by Jin Wang on 17/02/2016.
//  Copyright © 2016 Uthoft. All rights reserved.
//

import Foundation
import SwiftZMQ
import CommandLine

private let loggerLevel = 30

enum Error: ErrorType {
    case SocketError(String)
    case GeneralError(String)
}

enum Logger: Int {
    case Debug = 10
    case Info = 20
    case Warning = 30
    
    func print(items: Any..., file: String = __FILE__, function: String = __FUNCTION__, line: Int = __LINE__) {
        if rawValue >= loggerLevel {
            Swift.print(items)
        }
    }
}

let connectionFileOption = StringOption(shortFlag: "f", longFlag: "file", required: true,
    helpMessage: "Path to the output file.")
let socketQueueName = "com.uthoft.iswift.kernel.socketqueue" as NSString

extension String {
    func isUUID() -> Bool {
        return NSUUID(UUIDString: self) != nil
    }
    
    func toJSON() -> [String: AnyObject]? {
        guard let data = dataUsingEncoding(NSASCIIStringEncoding),
            json = (try? NSJSONSerialization.JSONObjectWithData(data, options: [])) as? [String: AnyObject] else {
                Logger.Info.print("Convert to JSON failed.")
                return nil
        }
        
        return json
    }
}

@objc public class Kernel: NSObject {
    public static let sharedInstance = Kernel()
    
    private var totalExecutionCount = 0
    
    let context = try? Context()
    let socketQueue = dispatch_queue_create(socketQueueName.cStringUsingEncoding(NSASCIIStringEncoding),  DISPATCH_QUEUE_CONCURRENT)
    
    public func start(arguments: [String]) {
        let cli = CommandLine(arguments: arguments)
        cli.addOptions(connectionFileOption)
        try! cli.parse()
        
        guard let connectionFilePath = connectionFileOption.value else {
            Logger.Info.print("No connection file path given.")
            return
        }
        
        guard let connectionFileData = NSData(contentsOfFile: connectionFilePath), connectionFile = (try? NSJSONSerialization.JSONObjectWithData(connectionFileData, options: [])) as? [String: AnyObject], connection = Connection.mapToObject(connectionFile) else {
            Logger.Info.print("Connection file invalid.")
            return
        }
        
        Logger.Info.print("Current connection: \(connection)")
        listen(connection)
    }
    
    private func listen(connection: Connection) {
        guard let context = context else {
            Logger.Info.print("Context is not initialised.")
            return
        }
        
        var shellControlMessageQueue: [String] = []
        let MaxShellControlMessageQueueSize = 10
        
        do {
            try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.hbPort, type: SocketType.Rep) { data, socket in
                Logger.Info.print("Received heart beat data.")
                let _ = try? socket.send(data)
            }
            
            try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.controlPort, type: SocketType.Router) { data, socket in
                Logger.Info.print("Received control data.")
                
            }
            
            let ioPubSocket = try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.iopubPort, type: .Pub)
            
            try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.stdinPort, type: SocketType.Router) { data, socket in
                Logger.Info.print("Received stdin data.")
                
            }
            
            try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.shellPort, type: SocketType.Router) { [unowned self] data, socket in
                guard let dataStr = NSString(bytes: data, length: data.count, encoding: NSASCIIStringEncoding) as? String else {
                    Logger.Info.print("Can't parse string.")
                    return
                }
                
                Logger.Info.print("Received shell data. \(data.count): \(dataStr)")
                
                if dataStr == "<IDS|MSG>" {
                    // All right, we get a new message.
                    
                    defer {
                        // No matter what's going on below, we'll clear the queue.
                        shellControlMessageQueue.removeAll(keepCapacity: true)
                    }
                    
                    // First, the last string must be a UUID.
                    guard let uuid = shellControlMessageQueue.last where uuid.isUUID() else {
                        // Wrong message. We'll clear the queue and return.
                        Logger.Info.print("Got message without UUID.")
                        return
                    }
                    
                    // All good for now. We'll read the next six strings.
                    
                    // 1. HMAC signature
                    do {
                        guard let hmacSignature = try socket.receiveString() else {
                            Logger.Info.print("Read hmac signature failed.")
                            return
                        }
                        
                        guard let headerStr = try socket.receiveString(), headerJSON = headerStr.toJSON() else {
                            Logger.Info.print("Read header data failed.")
                            return
                        }
                        
                        guard let parentHeaderStr = try socket.receiveString(), parentHeaderJSON = parentHeaderStr.toJSON() else {
                            Logger.Info.print("Read parent header data failed.")
                            return
                        }
                        
                        guard let metadataStr = try socket.receiveString(), metadataJSON = metadataStr.toJSON() else {
                            Logger.Info.print("Read meta data failed.")
                            return
                        }
                        
                        guard let contentStr = try socket.receiveString(), contentJSON = contentStr.toJSON() else {
                            Logger.Info.print("Read content data failed.")
                            return
                        }
                        
                        Logger.Info.print("Header str: \(headerStr)")
                        Logger.Info.print("The content str: \(contentStr)")
                        
                        // Seems good.
                        guard let header = Header.fromJSON(headerJSON) else {
                            Logger.Info.print("Header parse error \(headerStr)")
                            return
                        }
                        
                        let _content: Contentable?
                        let _replyMessageType: MessageType?
                        let _replyMessageContent: Contentable?
                        
                        switch header.msgType {
                        case .ExecuteRequest:
                            _content = ExecuteRequest.fromJSON(contentJSON)
                            _replyMessageType = .ExecuteReply
                            
                            self.totalExecutionCount += 1
                            
                            _replyMessageContent = ExecuteReply(status: .Ok, executionCount: self.totalExecutionCount, userExpressions: nil)
                        case .KernelInfoRequest:
                            _content = KernelInfoRequest.fromJSON(contentJSON)
                            _replyMessageType = .KernelInfoReply
                            _replyMessageContent = KernelInfoReply()
                        case .HistoryRequest:
                            _content = HistoryRequest.fromJSON(contentJSON)
                            _replyMessageType = .HistoryReply
                            _replyMessageContent = HistoryReply(history: [])
                        default:
                            _replyMessageType = nil
                            _replyMessageContent = nil
                            _content = nil
                            Logger.Warning.print("Message not implemented.")
                        }
                        
                        guard let content = _content,
                            replyMessageContent = _replyMessageContent,
                            replyMessageType = _replyMessageType else {
                            Logger.Info.print("Content parse error")
                            return
                        }
                        
                        let requestMessage = Message(header: header,
                            parentHeader: Header.fromJSON(parentHeaderJSON),
                            metadata: metadataJSON,
                            content: content)
                        
                        Logger.Info.print("Request HMAC SHA256: \(hmacSignature)")
                        Logger.Info.print("Expected HMAC SHA256: \(requestMessage.toSHA256(connection.key))")
                        
                        let replyHeader = Header(session: header.session, msgType: replyMessageType)
                        
                        let replyMessage = Message(header: replyHeader, parentHeader: header, metadata: [:], content: replyMessageContent)
                        
                        Logger.Info.print("Sending reply back....\(replyMessageType)")
                        Logger.Info.print("Reply header: \(replyMessage.header.toJSONString())")
                        Logger.Info.print("Reply content: \(replyMessage.content.toJSONString())")
                        
                        // Now, process the message and make reply.
                        try socket.sendString(uuid, mode: .SendMore)
                        try socket.sendString("<IDS|MSG>", mode: .SendMore)
                        try socket.sendString(replyMessage.toSHA256(connection.key), mode: .SendMore)
                        try socket.sendString(replyMessage.header.toJSONString(), mode: .SendMore)
                        try socket.sendString(replyMessage.parentHeader?.toJSONString() ?? "{}", mode: .SendMore)
                        try socket.sendString("{}", mode: .SendMore)
                        try socket.sendString(replyMessage.content.toJSONString())
                    } catch let e {
                        Logger.Info.print("Read message failed. \(e)")
                    }
                    
                } else {
                    // Just put it in the queue.
                    shellControlMessageQueue.append(dataStr)
                }
                
                // We'll clean up the queue if it's too big.
                if shellControlMessageQueue.count > MaxShellControlMessageQueueSize {
                    let last = shellControlMessageQueue.last
                    shellControlMessageQueue.removeAll(keepCapacity: true)
                    
                    // Don't forget put back.
                    if let last = last {
                        shellControlMessageQueue.append(last)
                    }
                }
            }
        } catch let e {
            Logger.Info.print("Socket creation error: \(e)")
        }
        
        dispatch_barrier_sync(socketQueue) {
            Logger.Info.print("Listening completed...")
        }
    }
    
    private func processMessage(header: [String: AnyObject]) {
        
    }
    
    private func createSocket(context: Context, transport: TransportType, ip: String, port: Int, type: SocketType, dataHandler: (data: [Int8], socket: Socket) -> Void) throws {
        // Create a heart beat connection that will reply anything it receives.
        let socket = try context.socket(type)
        try socket.bind("\(transport.rawValue)://\(ip):\(port)")
        
        dispatch_async(socketQueue) {
            do {
                while let data = try socket.receive() where data.count > 0 {
                    dataHandler(data: data, socket: socket)
                }
            } catch let e {
                Logger.Info.print("Socket exception...\(e)")
            }
        }
    }
    
    private func createSocket(context: Context, transport: TransportType, ip: String, port: Int, type: SocketType) throws -> Socket {
        let socket = try context.socket(type)
        try socket.bind("\(transport.rawValue)://\(ip):\(port)")
        return socket
    }
}
