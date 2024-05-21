//
//  DataManager.swift
//  DataSender
//
//  Created by smlab_drone on 07/05/24.
//

import Foundation
import CoreLocation
import UIKit
import Combine


class DataManager {
    // Shared instance (singleton)
    static let shared = DataManager()
    
    // Properties to store data collected by sensors
    var motionData: Data?
    var locationData: Data?
    var imageData: Data?
    var depthData: Data?
    var arDepthData: Data?
    
    let dataPublisher = PassthroughSubject<DataUpdate, Never>()

    // Private initializer to enforce singleton pattern
    private init() {}
    
    
    func updateMotionData(_ newData: Data) {
        motionData = newData
        dataPublisher.send(.motion(newData))
    }
    
    func updateLocationData(_ newLocation: CLLocation) {
        do {
            let jsonData = try locationDataToJSON(location: newLocation)
            locationData = jsonData
            dataPublisher.send(.location(jsonData))
        } catch {
            print("Error serializing location data: \(error)")
        }
    }
    
    func locationDataToJSON(location: CLLocation) throws -> Data {
        let jsonDict: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ]
        
        return try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
    }

    

    enum DataUpdate{
        case motion(Data)
        case location(Data)
        case image(Data)
        case depth(Data)
        case arDepth(Data)
    }
}
