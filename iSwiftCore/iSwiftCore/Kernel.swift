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
    case Critical = 40
    
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
        guard let data = dataUsingEncoding(NSUTF8StringEncoding),
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
        
        do {
            try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.hbPort, type: SocketType.Rep) { data, socket in
                Logger.Info.print("Received heart beat data.")
                let _ = try? socket.send(data)
            }
            
            try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.controlPort, type: SocketType.Router) { data, socket in
                Logger.Info.print("Received control data.")
                
            }
            
            let ioPubSocket = try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.iopubPort, type: .Pub)
            
            NSNotificationCenter.defaultCenter().addObserverForName("IOPubNotification", object: nil, queue: NSOperationQueue(), usingBlock: { (notification) -> Void in
                if let resultMessage = notification.userInfo?["message"] as? Message {
                    do {
                        try ioPubSocket.sendMessage(resultMessage)
                    } catch let e {
                        Logger.Critical.print(e)
                    }
                }
            })
            
            try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.stdinPort, type: SocketType.Router) { data, socket in
                Logger.Info.print("Received stdin data.")
                
            }
            
            dispatch_async(socketQueue) {
                do {
                    try self.startShell(context, connection: connection)
                } catch let e {
                    print(e)
                }
            }
            
        } catch let e {
            Logger.Info.print("Socket creation error: \(e)")
        }
        
        dispatch_barrier_sync(socketQueue) {
            Logger.Info.print("Listening completed...")
        }
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
    
    private func startShell(context: Context, connection: Connection) throws {
        let taskFactory = TaskFactory()
        let socket = try createSocket(context, transport: connection.transport, ip: connection.ip, port: connection.shellPort, type: .Router)
        let inSocketMessageQueue = BlockingQueue<Message>()
        let decodedMessageQueue = BlockingQueue<Message>()
        let processedMessageQueue = BlockingQueue<Message>()
        let encodedMessageQueue = BlockingQueue<Message>()
        taskFactory.startNew {
            SocketIn.run(socket, outMessageQueue: inSocketMessageQueue)
        }
        taskFactory.startNew {
            Decoder.run(connection.key, inMessageQueue: inSocketMessageQueue, outMessageQueue: decodedMessageQueue)
        }
        taskFactory.startNew {
            MessageProcessor.run(decodedMessageQueue, outMessageQueue: processedMessageQueue)
        }
        taskFactory.startNew {
            Encoder.run(connection.key, inMessageQueue: processedMessageQueue, outMessageQueue: encodedMessageQueue)
        }
        taskFactory.startNew {
            SocketOut.run(socket, inMessageQueue: encodedMessageQueue)
        }
        taskFactory.waitAll()
    }
}
