import Foundation
import AVFoundation
import UIKit

protocol CameraAudioDelegate: AnyObject {
    func didReceiveAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    
    @Published var isSessionRunning = false
    @Published var isRecording = false
    
    let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    let audioDataOutput = AVCaptureAudioDataOutput()
    
    private let sessionQueue = DispatchQueue(label: "com.bestcam.sessionQueue")
    private let audioQueue = DispatchQueue(label: "com.bestcam.audioQueue")
    
    weak var audioDelegate: CameraAudioDelegate?
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var isUltraWide = false
    
    func setupSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            
            // Set session preset
            self.session.sessionPreset = .high
            
            // Add video input
            self.addVideoInput(deviceType: .builtInWideAngleCamera)
            
            // Add audio input
            do {
                if let audioDevice = AVCaptureDevice.default(for: .audio) {
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    if self.session.canAddInput(audioInput) {
                        self.session.addInput(audioInput)
                    }
                }
            } catch {
                print("Error adding audio input: \(error)")
            }
            
            // Add outputs
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            if self.session.canAddOutput(self.movieOutput) {
                self.session.addOutput(self.movieOutput)
            }
            
            if self.session.canAddOutput(self.audioDataOutput) {
                self.session.addOutput(self.audioDataOutput)
                self.audioDataOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
            }
            
            self.session.commitConfiguration()
        }
    }
    
    private func addVideoInput(deviceType: AVCaptureDevice.DeviceType) {
        do {
            guard let videoDevice = AVCaptureDevice.default(deviceType, for: .video, position: .back) else {
                print("Camera \(deviceType) unavailable")
                return
            }
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }
            
            if self.session.canAddInput(videoInput) {
                self.session.addInput(videoInput)
                self.videoDeviceInput = videoInput
                self.isUltraWide = (deviceType == .builtInUltraWideCamera)
            }
        } catch {
            print("Error adding video input: \(error)")
        }
    }
    
    func switchToUltraWide() {
        sessionQueue.async {
            if !self.isUltraWide {
                self.session.beginConfiguration()
                self.addVideoInput(deviceType: .builtInUltraWideCamera)
                self.session.commitConfiguration()
            }
        }
    }
    
    func switchToNormalWide() {
        sessionQueue.async {
            if self.isUltraWide {
                self.session.beginConfiguration()
                self.addVideoInput(deviceType: .builtInWideAngleCamera)
                self.session.commitConfiguration()
            }
        }
    }
    
    func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    func takePhoto() {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func startRecording() {
        sessionQueue.async {
            guard !self.movieOutput.isRecording else { return }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".mov"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            self.movieOutput.startRecording(to: fileURL, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
            }
        }
    }
    
    func stopRecording() {
        sessionQueue.async {
            guard self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
            DispatchQueue.main.async {
                self.isRecording = false
            }
        }
    }
}

extension CameraManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Forward the audio buffer to the speech manager
        audioDelegate?.didReceiveAudioSampleBuffer(sampleBuffer)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), error == nil else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        
        // Save photo to gallery
        if let image = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            print("Photo saved successfully")
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        } else {
            // Save video to gallery
            UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
            print("Video saved successfully")
        }
    }
}
