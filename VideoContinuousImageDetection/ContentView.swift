//
//  ContentView.swift
//  VideoContinuousImageDetection
//
//  Created by Danika Gupta on 3/12/24.
//

import AVFoundation
import SwiftUI

class VideoCapture: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession?
    let videoOutput = AVCaptureVideoDataOutput()
    let sessionQueue = DispatchQueue(label: "sessionQueue")
    let model = DRDetection_1()

    @Published var processedText: String = ""

    override init() {
        super.init()
        self.setupCaptureSession()
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoDeviceInput) else {
            return
        }

        session.addInput(videoDeviceInput)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        }

        session.commitConfiguration()
        self.captureSession = session
    }

    func startSession() {
        sessionQueue.async {
            self.captureSession?.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async {
            self.captureSession?.stopRunning()
        }
    }

    func captureOutputPrev(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Process each video frame here
        DispatchQueue.main.async {
            self.processedText = "Frame captured"
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        do {
            let prediction = try self.model.prediction(image: pixelBuffer).target
            DispatchQueue.main.async {
                self.processedText = "Prediction: \(prediction)"
                print("\(prediction)")
            }
        } catch {
            print("Error processing frame: \(error)")
        }
    }
    
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var videoCapture: VideoCapture
    
    func makeUIViewOld(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: videoCapture.captureSession!)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func makeUIView(context: Context) -> UIView {
            let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.70)) // Adjust the height to 75% of the screen height
            let previewLayer = AVCaptureVideoPreviewLayer(session: videoCapture.captureSession!)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            return view
        }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject var videoCapture = VideoCapture()
    @State var isRecording = false
    
    var body: some View {
        VStack {
            Text("DR Diagnosis")
                .font(.system(size: 40))
            Text(videoCapture.processedText)
            CameraPreview(videoCapture: videoCapture)
                .padding()
            Button(action: {
                if isRecording {
                    videoCapture.stopSession()
                } else {
                    videoCapture.startSession()
                }
                isRecording.toggle()
                videoCapture.processedText = ""
            }) {
                Image(systemName: isRecording ? "record.circle" : "record.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(isRecording ? .red : .gray)
            }
            .padding()
        }
    }
}

