//
//  TCPClient.swift
//  DataSender
//
//  Created by smlab_drone on 07/05/24.
//

import Foundation
import Network

class TCPClient {
    
    enum ConnectionError: Error {
        case invalidIPAddress
        case invalidPort
    }
    
    private lazy var queue = DispatchQueue(label: "tcp.client.queue")
    private var connection: NWConnection?
    private var state: NWConnection.State = .preparing
    
    func connect(to ipAddress: String, with port: UInt16, completion: @escaping (Error?) -> Void) {
        guard let ipAddress = IPv4Address(ipAddress) else {
            completion(ConnectionError.invalidIPAddress)
            return
        }
        guard let port = NWEndpoint.Port(rawValue: port) else {
            completion(ConnectionError.invalidPort)
            return
        }
        
        let host = NWEndpoint.Host.ipv4(ipAddress)
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] newState in
            self?.state = newState
        }
        
        connection?.start(queue: queue)
        completion(nil)
    }
    
    func send(data: Data, completion: @escaping (Error?) -> Void) {
//        guard state == .ready else {
//            let error = NSError(domain: "TCPClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection not ready"])
//            print("Error: Connection not ready")
//            completion(error)
//            return
//        }
        
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Error sending data: \(error.localizedDescription)")
            } else {
                print("Data sent successfully")
            }
            completion(error) // Pass error directly
        })
    }
    
    func receive(completion: @escaping (Result<Data, Error>) -> Void) {
            connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, isComplete, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let data = data {
                    completion(.success(data))
                }
                
                if isComplete {
                    self.connection?.cancel()
                }
            }
        }


    
    func disconnect() {
        connection?.cancel()
    }
}
