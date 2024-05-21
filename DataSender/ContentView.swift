//
//  ContentView.swift
//  DataSender
//
//  Created by smlab_drone on 07/05/24.
//

import SwiftUI

struct ContentView: View {
    @State private var ipAddress: String = ""
    @State private var port: String = ""
    
    let dataStreamer = DataStreamer()
    
    var body: some View {
        VStack {
            TextField("Enter IP Address", text: $ipAddress)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            TextField("Enter Port", text: $port)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button("Start Streaming") {
                guard let portNumber = UInt16(port) else {
                    // Handle invalid port number
                    return
                }
                dataStreamer.startStreaming(to: ipAddress, port: portNumber) { error in
                    if let error = error {
                        // Handle error
                        print("Error: \(error.localizedDescription)")
                    } else {
                        // Handle successful start
                        print("Streaming started successfully")
                    }
                }
            }
            .padding()
            Button("Stop Streaming") {
                dataStreamer.stopStreaming()
            }
            .padding()
        }
        .padding()
    }
}

//
//func /*startDataCollection*/() {
//    let motionSensor = MotionSensor()
//    let locationSensor = LocationSensor()
//    let cameraSensor = CameraSensor()
//    let lidarSensor = LidarSensor()
//    let arCameraSensor = ARCameraSensor()
    
    // Start data collection using instances of sensor
//    motionSensor.startMotionUpdates { result in
//         switch result {
//         case .success(let jsonData):
//             DataManager.shared.updateMotionData(jsonData)
//         case .failure(let error):
//             print("Error collecting motion data: \(error)")
//         }
//     }
     
//     locationSensor.requestLocation { result in
//         switch result {
//         case .success(let locationData):
//             DataManager.shared.updateLocationData(locationData)
//         case .failure(let error):
//             print("Error collecting location data: \(error)")
//         }
//     }
//}


#Preview {
    ContentView()
}
