//
//  DataSource.swift
//  DataSender
//
//  Created by smlab_drone on 07/05/24.
//

import Foundation
import CoreLocation
import CoreMotion
import ARKit
import AVFoundation


class MotionSensor{
    private let motionManager = CMMotionManager()
    
    func startMotionUpdates(completion: @escaping(Result<Data,Error>) -> Void){
        
        guard motionManager.isDeviceMotionAvailable else {
            completion(.failure(MotionSensorError.unavailable))
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1/50
        
        motionManager.startDeviceMotionUpdates(to: .main){ (motionData, error) in
            if let error = error{
                completion(.failure(error))
            }else if let motionData = motionData{
                do{
                    let jsonData = try self.motionDataToJSON(motionData: motionData)
                    
                    DataManager.shared.motionData = jsonData
                    completion(.success(jsonData))
                }catch{
                    completion(.failure(error))
                }
            }
        }
    }
    
    func stopMotionUpdates(){
        motionManager.stopDeviceMotionUpdates()
    }
    
    private func motionDataToJSON(motionData: CMDeviceMotion) throws -> Data{
        let jsonDict: [String: Any] = [
            "acceleration" : [
                "x" : motionData.userAcceleration.x,
                "y" : motionData.userAcceleration.y,
                "z" : motionData.userAcceleration.z
            ],
            "gyroscope" : [
                "x" : motionData.rotationRate.x,
                "y" : motionData.rotationRate.y,
                "z" : motionData.rotationRate.z
            ]
        ]
        
        return try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
    }
    
    enum MotionSensorError: Error {
        case unavailable
    }
}


class LocationSensor: NSObject, CLLocationManagerDelegate{
    private let locationManager = CLLocationManager()
    private var completion: ((Result<CLLocation, Error>) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

    }
    
    func startUpdatingLocation(completion: @escaping(Result<CLLocation, Error>) -> Void) {
        self.completion = completion
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first{
            completion?(.success(location))
            do {
                let jsonData = try locationDataToJSON(location: location)
                DataManager.shared.locationData = jsonData
            }catch{
                print("Error serialising location data : \(error)")
            }
        }else{
            completion?(.failure(LocationSensorError.noLocationData))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(.failure(error))
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .denied || status == .restricted{
            completion?(.failure(LocationSensorError.authorizationDenied))
        }
    }
    
    func locationDataToJSON(location: CLLocation) throws -> Optional<Data>{
        let jsonDict: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ]
        
        return try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
    }
    
    enum LocationSensorError: Error{
        case noLocationData
        case authorizationDenied
    }
}


class CameraSensor : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate{
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    
    
    override init(){
        super.init()
        setupCaptureSession()
    }
    
    
    private func setupCaptureSession(){
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else {return}
        
        if let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video,position: .back){
            do {
                let input = try AVCaptureDeviceInput(device: captureDevice)
                if captureSession.canAddInput(input){
                    captureSession.addInput(input)
                }else{
                    print("Unable to add input to capture session")
                }
            }catch{
                print("Error setting up capture device input: \(error.localizedDescription)")
            }
        }
        
        
        videoOutput = AVCaptureVideoDataOutput()
        if let videoOutput = videoOutput{
            if captureSession.canAddOutput(videoOutput){
                captureSession.addOutput((videoOutput))
                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
            }
        }
        
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer){
            do{
                let jsonData = try imageDataToJSON(image: image)
                DataManager.shared.imageData = jsonData
            } catch{
                print("Error serializing image data: \(error.localizedDescription)")
            }
        }
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage?{
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return nil}
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {return nil}
        return UIImage(cgImage: cgImage)
    }
    
    private func imageDataToJSON(image: UIImage) throws -> Data{
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            throw CameraSensorError.serializationFailed
        }
        
        return imageData
    }
    
    
    
    enum CameraSensorError: Error{
        case serializationFailed
    }
}

class LidarSensor: NSObject, AVCaptureDepthDataOutputDelegate{
    private var captureSession: AVCaptureSession?
    private var depthOutput: AVCaptureDepthDataOutput?
    private var depthDataBinary: Data? // Store depth data locally

    override init(){
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession(){
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else {return}
        
        if let captureDevice = AVCaptureDevice.default(.builtInLiDARDepthCamera,for: .depthData,position: .back){
            do{
                let input = try AVCaptureDeviceInput(device: captureDevice)
                if captureSession.canAddInput(input){
                    captureSession.addInput(input)
                }
            }catch{
                print("Error setting up capture device input: \(error.localizedDescription)")
            }
        }
        
        depthOutput = AVCaptureDepthDataOutput()
        if let depthOutput = depthOutput{
            if captureSession.canAddOutput(depthOutput){
                captureSession.addOutput(depthOutput)
                depthOutput.setDelegate(self, callbackQueue: DispatchQueue.main)
            }
        }
        
        captureSession.startRunning()
    }
    
    func updateDepthMap(completion: @escaping(Result<Data,Error>) -> Void){
        Timer.scheduledTimer(withTimeInterval: 1.0/50.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Ensure depthData is available
                    guard let depthDataBinary = self.depthDataBinary else {
                        completion(.failure(LidarSensorError.invalidDepthData))
                        return
                    }
                    
                    // Send depthData
                    completion(.success(depthDataBinary))
                }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection){
        do{
//            let depthDataBinary = try depthDataToBinary(depthData: depthData)
//            DataManager.shared.depthData = depthDataBinary
            self.depthDataBinary = try depthDataToBinary(depthData: depthData)
        }
        catch{
            print("Error serializing depth data: \(error.localizedDescription)")
        }
    }
    
    private func depthDataToBinary(depthData: AVDepthData) throws -> Data{
        let depthDataMap = depthData.depthDataMap
        
        let width = CVPixelBufferGetWidth(depthDataMap)
        let height = CVPixelBufferGetHeight(depthDataMap)
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthData.depthDataMap) else {
            throw LidarSensorError.invalidDepthData
        }
        let depthDataArray = Array(UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: Float.self), count: width * height))

        var depthDataBytes = [UInt8]()
               for depthValue in depthDataArray {
                   let floatBytes = withUnsafeBytes(of: depthValue) { Array($0) }
                   depthDataBytes.append(contentsOf: floatBytes)
               }
        let depthData = Data(bytes: &depthDataBytes, count: depthDataBytes.count * MemoryLayout<Float32>.size)

        return depthData
    }
    
    enum LidarSensorError: Error {
        case invalidDepthData
    }
}


class ARCameraSensor: NSObject, ARSessionDelegate{
    private var arSession: ARSession?
    private var isRecording = false
    
    override init(){
        super.init()
        setupARSession()
    }
    
    private func setupARSession(){
        arSession = ARSession()
        arSession?.delegate = self
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        
        
        arSession?.run(configuration)
    }
    
    func startRecording(){
        guard !isRecording else{
            print("Recording already in progress")
            return
        }
        
        isRecording = true
    }
    
    func stopRecording(){
        guard isRecording else{
            print("No recording in progress")
            return
        }
        
        isRecording = false
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if isRecording{
            guard let sceneDepth = frame.sceneDepth else{
                print("No scene depth available")
                return
            }
            
            do {
                let sceneDepthDataBinary = try sceneDepthToBinary(sceneDepth: sceneDepth)
                // TODO: Handle sceneDepth (display to user in ContentView)
                DataManager.shared.arDepthData = sceneDepthDataBinary
            }catch{
                print("Error serializing scene depth data : \(error.localizedDescription)")
            }
        }
    }
    
    private func sceneDepthToBinary(sceneDepth: ARDepthData) throws -> Data{
        
        
        let depthDataMap = sceneDepth.depthMap
        
        
        let width = CVPixelBufferGetWidth(depthDataMap)
        let height = CVPixelBufferGetHeight(depthDataMap)
        guard let baseAddress = CVPixelBufferGetBaseAddress(sceneDepth.depthMap) else {
            throw ARCameraSensorError.invalidDepthData
        }
        let depthDataArray = Array(UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: Float.self), count: width * height))
        
        var depthDataBytes = [UInt8]()
        for depthValue in depthDataArray {
            let floatBytes = withUnsafeBytes(of: depthValue) { Array($0) }
            depthDataBytes.append(contentsOf: floatBytes)
        }
        let depthData = Data(bytes: &depthDataBytes, count: depthDataBytes.count * MemoryLayout<Float32>.size)
        
        return depthData}
    
    enum ARCameraSensorError:Error{
        case invalidDepthData
    }
}
