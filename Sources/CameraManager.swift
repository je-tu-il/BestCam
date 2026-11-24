import Combine
import Foundation
import Photos
import AVFoundation
import UIKit

protocol CameraAudioDelegate: AnyObject {
    func didReceiveAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var statusMessage: String?
    
    let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    let audioDataOutput = AVCaptureAudioDataOutput()
    
    private let sessionQueue = DispatchQueue(label: "com.bestcam.sessionQueue")
    private let audioQueue = DispatchQueue(label: "com.bestcam.audioQueue")
    
    weak var audioDelegate: CameraAudioDelegate?
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var isUltraWide = false
    private var configured = false
    
    func setupSession() {
        sessionQueue.async {
            guard !self.configured else { return }
            self.session.beginConfiguration()
            
            // Set session preset
            self.session.sessionPreset = .high
            
            // Add video input
            self.addVideoInput(deviceType: .builtInWideAngleCamera)
            
            // Add audio input
            do {
                if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
                   let audioDevice = AVCaptureDevice.default(for: .audio) {
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
            self.configured = self.videoDeviceInput != nil
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
            } else if let previous = self.videoDeviceInput, self.session.canAddInput(previous) {
                self.session.addInput(previous)
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
            if self.configured && !self.session.isRunning {
                self.session.startRunning()
                let started = self.session.isRunning
                DispatchQueue.main.async {
                    self.isSessionRunning = started
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
            guard self.session.isRunning, self.photoOutput.connection(with: .video)?.isActive == true else { return }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    func startRecording() {
        sessionQueue.async {
            guard self.session.isRunning, !self.movieOutput.isRecording,
                  self.movieOutput.connection(with: .video)?.isActive == true else { return }
            
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
        guard error == nil, let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.statusMessage = "La photo n’a pas pu être capturée." }
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
        } completionHandler: { saved, _ in
            DispatchQueue.main.async {
                self.statusMessage = saved ? "Photo ajoutée à Photos." : "Autorisez l’ajout à Photos dans Réglages."
            }
        }
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { self.isRecording = false }
        let recorded = error == nil || (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true
        guard recorded else {
            try? FileManager.default.removeItem(at: outputFileURL)
            DispatchQueue.main.async { self.statusMessage = "La vidéo n’a pas pu être capturée." }
            return
        }
        PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: outputFileURL, options: nil)
        } completionHandler: { saved, _ in
            if saved { try? FileManager.default.removeItem(at: outputFileURL) }
            DispatchQueue.main.async {
                self.statusMessage = saved ? "Vidéo ajoutée à Photos." : "La vidéo n’a pas pu être ajoutée à Photos."
            }
        }
    }
}
