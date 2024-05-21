//
//  DataStreamer.swift
//  DataSender
//
//  Created by smlab_drone on 07/05/24.
//

import Foundation


class DataStreamer{
    private let client = TCPClient()
    private let motionSensor = MotionSensor()
    private let locationSensor = LocationSensor()
    private let lidarSensor = LidarSensor()
//    private let cameraSensor = CameraSensor()
    private var isStreaming = false
//    private let locationSensor = LocationSensor()
    
//    func startStreaming(to ipAddress: String, port: UInt16, completion: @escaping(Error?) -> Void){
//        guard !isStreaming else{
//            completion(StreamerError.alreadyStreaming)
//            return
//        }
//        
//        do{
//            try client.connect(to: ipAddress, with: port, completion: StreamerError.connectionFailed)
//        }catch{
//            completion(error)
//            return
//        }
//        
//        motionSensor.startMotionUpdates{[weak self] result in
//            switch result{
//            case .success(let jsonData):
//                self?.client.send(data: jsonData){error in
//                    if let error = error{
//                        completion(error)
//                    }
//                }
//            case .failure(let error):
//                completion(error)
//            }
//
//        }
//        
//        isStreaming = true
//        completion(nil)
//    }
    
    func startStreaming(to ipAddress: String, port: UInt16, completion: @escaping (Error?) -> Void) {
        guard !isStreaming else {
            completion(StreamerError.alreadyStreaming)
            return
        }
        
        do {
            client.connect(to: ipAddress, with: port) { error in
                if let error = error {
                    completion(error)
                } else {
                    self.client.receive{[weak self] result in
                        guard let self = self else {return}
                        switch result{
                        case .success(let recievedData):
                            let receivedString = String(data: recievedData, encoding: .utf8)
                            print(receivedString)
                        case .failure(let recieveError):
                            completion(recieveError)
                        }
                        
                    }
                    print("Hello Server")
                    self.client.send(data: "Hello Server".data(using: .utf8)!) { helloError in
                        if let helloError = helloError {
                            completion(helloError)
                        } else {
                            self.locationSensor.startUpdatingLocation { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                case .success(let location):
                                    do {
                                        if let locationData = try self.locationSensor.locationDataToJSON(location: location) {
                                            let timestamp = Date().timeIntervalSince1970
                                            var jsonDictionary = try JSONSerialization.jsonObject(with: locationData, options: []) as? [String: Any] ?? [:]
                                            jsonDictionary["timestamp"] = timestamp
                                            
                                            // Convert back to data
                                            let jsonData = try JSONSerialization.data(withJSONObject: jsonDictionary, options: [])
                                            
                                            self.client.send(data: locationData) { sendError in
                                                if let sendError = sendError {
                                                    completion(sendError)
                                                } else {
                                                    // Location data sent successfully, now start motion updates
                                                    print("Hello Server")
                                                    self.motionSensor.startMotionUpdates { [weak self] result in
                                                        guard let self = self else { return }
                                                        switch result {
                                                        case .success(let motionData):
                                                            self.client.send(data: motionData) { sendError in
                                                                if let sendError = sendError {
                                                                    completion(sendError)
                                                                } else {
                                                                    // Motion data sent successfully
                                                                    self.lidarSensor.updateDepthMap { [weak self] result in
                                                                        guard let self = self else { return }
                                                                        switch result {
                                                                        case .success(let depthMapData):
                                                                            // Send depth map data
                                                                            self.client.send(data: depthMapData) { depthSendError in
                                                                                if let depthSendError = depthSendError {
                                                                                    completion(depthSendError)
                                                                                } else {
                                                                                    // Depth map data sent successfully
                                                                                    self.isStreaming = true
                                                                                    completion(nil)
                                                                                }
                                                                            }
                                                                        case .failure(let depthError):
                                                                            completion(depthError)
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        case .failure(let motionError):
                                                            completion(motionError)
                                                        }
                                                    }
                                                }
                                            }
                                        } else {
                                            completion(StreamerError.locationDataUnavailable)
                                        }
                                    } catch {
                                        completion(error) // Handle the error thrown by locationDataToJSON
                                    }
                                case .failure(let locationError):
                                    completion(locationError)
                                }
                            }
                        }
                    
                    

//                        } else {
//                            self.motionSensor.startMotionUpdates { [weak self] result in
//                                guard let self = self else { return }
//                                switch result {
//                                case .success(let motionData): 
//                                    self.client.send(data: motionData) { sendError in
//                                        if let sendError = sendError {
//                                            completion(sendError)
//                                        } else {
//                                            if let locationData = DataManager.shared.locationData {
//                                                self.client.send(data: locationData) { sendError in
//                                                    completion(sendError)
//                                                }
//                                            } else {
//                                                completion(StreamerError.locationDataUnavailable)
//                                            }
//                                        }
//                                    }
//                                case .failure(let motionError):
//                                    completion(motionError)
//                                }
//                            }
//                            self.isStreaming = true
//                            completion(nil)
//                        }
                    }
                }
            }
        }
    }

    func stopStreaming() {
        motionSensor.stopMotionUpdates()
        locationSensor.stopUpdatingLocation()
        client.disconnect()
        isStreaming = false
    }

    
    
    enum StreamerError: Error {
        case alreadyStreaming
        case connectionFailed
        case locationDataUnavailable
    }
    
    
    
}


