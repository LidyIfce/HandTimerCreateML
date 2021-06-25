//
//  ViewController.swift
//  MLChallenge
//
//  Created by Lidiane Gomes Barbosa on 23/06/21.
//

import UIKit
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    let configuration = MLModelConfiguration()
    var currentMLModel: MLModel!
    private let serialQueue = DispatchQueue(label: "com.handTimer.dispatchqueueml")
    private var visionRequests = [VNRequest]()
    
    @IBOutlet weak var timerLabel: UILabel!
    
    var timer = Timer()
    var fractions: Int = 60
    var seconds: Int = 59
    var minutes: Int = 2
    
    var timerStarted: Bool = false
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        currentMLModel = try! handModel(configuration: configuration).model
        timerLabel.text = "00:00:00"
        
        //camera
        let captureSession = AVCaptureSession()
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        
        guard let input = try? AVCaptureDeviceInput(device: frontCamera) else { return }
        captureSession.addInput(input)
        captureSession.startRunning()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
        self.previewLayer.opacity = 0.1
        
        let  dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        setupCoreML()
    }
    
    private func setupCoreML() {
        guard let selectedModel = try? VNCoreMLModel(for: currentMLModel) else {
            fatalError("Could not load model.")
        }
        
        let classificationRequest = VNCoreMLRequest(model: selectedModel,
                                                    completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        visionRequests = [classificationRequest]
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let deviceOrientation =  UIDevice.current.orientation.getImagePropertyOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: deviceOrientation,options: [:])
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
    
    @objc func decrementTimer(){
        fractions -= 1
        
        if fractions == 0 {
            fractions = 60
            seconds -= 1
            
        }
        
        if seconds == 0 {
            minutes -= 1
            seconds = 60
        }
        
        if minutes == 0 {
            timer.invalidate()
            self.timerLabel.text = "00:00:00"
        }
        
        
        let fracStr: String = fractions > 9 ? "\(fractions)" : "0\(fractions)"
        let secStr: String = seconds > 9 ? "\(seconds)" : "0\(seconds)"
        let minStr: String = minutes > 9 ? "\(minutes)" : "0\(minutes)"
        
        timerLabel.text = "\(minStr):\(secStr).\(fracStr)"
    }
    
}

extension ViewController {
    
    private func classificationCompleteHandler(request: VNRequest, error: Error?) {
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
            return
        }
        
        let classifications = observations[0...2]
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        print("Classifications: \(classifications)")
        
        DispatchQueue.main.async { [self] in
            
            let topPrediction = classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            
            guard let topPredictionScore: Float = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces)) else { return }
            
            if (topPredictionScore > 0.95) {
                print("Top prediction: \(topPredictionName) - score: \(String(describing: topPredictionScore))")
              
                if topPredictionName == "start" {
                    if self.timerStarted == false {
                        self.timerStarted = true
                        self.timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(self.decrementTimer), userInfo: nil, repeats: true)
                        return
                    }
                    
                } else if topPredictionName == "two" {
                    self.timer.invalidate()
                    
                    self.fractions = 60
                    self.seconds = 59
                    self.minutes = 2
                    
                    self.timerStarted = false
                    self.timerLabel.text = "02:00:00"

                } else if topPredictionName == "five" {
                    self.timer.invalidate()
                    
                    self.fractions = 60
                    self.seconds = 59
                    self.minutes = 5
                    
                    self.timerStarted = false
                    self.timerLabel.text = "05:00:00"

                } else if topPredictionName == "zero" {
                    self.timer.invalidate()
                    self.timerStarted = false
                    self.timerLabel.text = "00:00:00"
                } 
            }
        }
    }
}
