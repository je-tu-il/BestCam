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
    @Published var isPaused = false
    @Published var statusMessage: String?
    @Published var isUltraWide = false

    let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    let audioDataOutput = AVCaptureAudioDataOutput()

    private let sessionQueue = DispatchQueue(label: "com.bestcam.sessionQueue")
    private let audioQueue = DispatchQueue(label: "com.bestcam.audioQueue")

    weak var audioDelegate: CameraAudioDelegate?

    private var videoDeviceInput: AVCaptureDeviceInput?
    private var configured = false
    private var wantsSessionRunning = false
    private var setupGeneration = 0

    // MARK: - Setup with retry

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .videoRecording,
                                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AudioSession error: \(error)")
        }
    }

    private func attemptSetup(retryCount: Int, generation: Int) {
        sessionQueue.async {
            guard self.wantsSessionRunning, self.setupGeneration == generation, !self.configured else { return }
            self.session.beginConfiguration()

            self.session.sessionPreset = .high
            self.addVideoInput(deviceType: .builtInWideAngleCamera)

            do {
                if !self.session.inputs.contains(where: { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.audio) == true }),
                   AVCaptureDevice.authorizationStatus(for: .audio) == .authorized,
                   let audioDevice = AVCaptureDevice.default(for: .audio) {
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    if self.session.canAddInput(audioInput) {
                        self.session.addInput(audioInput)
                    }
                }
            } catch {
                print("Error adding audio input: \(error)")
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
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

            if self.configured {
                self.runConfiguredSession()
            } else if retryCount > 0 {
                self.sessionQueue.asyncAfter(deadline: .now() + 1) {
                    self.attemptSetup(retryCount: retryCount - 1, generation: generation)
                }
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = "La caméra est indisponible."
                }
            }
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
                let wide = (deviceType == .builtInUltraWideCamera)
                DispatchQueue.main.async { self.isUltraWide = wide }
            } else if let previous = self.videoDeviceInput, self.session.canAddInput(previous) {
                self.session.addInput(previous)
            }
        } catch {
            print("Error adding video input: \(error)")
        }
    }

    // MARK: - Lens switch

    func switchToUltraWide() {
        sessionQueue.async {
            guard !self.isUltraWide else { return }
            self.session.beginConfiguration()
            self.addVideoInput(deviceType: .builtInUltraWideCamera)
            self.session.commitConfiguration()
        }
    }

    func switchToNormalWide() {
        sessionQueue.async {
            guard self.isUltraWide else { return }
            self.session.beginConfiguration()
            self.addVideoInput(deviceType: .builtInWideAngleCamera)
            self.session.commitConfiguration()
        }
    }

    // MARK: - Session lifecycle

    func startSession() {
        sessionQueue.async {
            guard !self.wantsSessionRunning else { return }
            self.wantsSessionRunning = true
            self.setupGeneration += 1
            self.configureAudioSession()
            if self.configured {
                self.runConfiguredSession()
            } else {
                self.attemptSetup(retryCount: 3, generation: self.setupGeneration)
            }
        }
    }

    private func runConfiguredSession() {
        guard !session.isRunning else { return }
        session.startRunning()
        let started = session.isRunning
        DispatchQueue.main.async {
            self.isSessionRunning = started
            self.statusMessage = started ? nil : "La caméra n’a pas pu démarrer."
        }
    }

    func stopSession() {
        sessionQueue.async {
            self.wantsSessionRunning = false
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { self.isSessionRunning = false }
            }
        }
    }

    // MARK: - Photo capture

    func takePhoto() {
        sessionQueue.async {
            guard self.session.isRunning,
                  self.photoOutput.connection(with: .video)?.isActive == true else { return }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Burst

    func takeBurst(count: Int = 5) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                self.takePhoto()
            }
        }
    }

    // MARK: - Video with speed settings

    func startRecording(rate: VideoRate = .normal) {
        sessionQueue.async {
            guard self.session.isRunning, !self.movieOutput.isRecording,
                  self.movieOutput.connection(with: .video)?.isActive == true else { return }

            if rate == .slowMo {
                // Switch to 240fps if available
                self.applyFrameRate(240)
            } else if rate == .timelapse {
                self.applyFrameRate(2)
            } else {
                self.applyFrameRate(30)
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".mov"
            let fileURL = tempDir.appendingPathComponent(fileName)

            self.movieOutput.startRecording(to: fileURL, recordingDelegate: self)
            DispatchQueue.main.async { self.isRecording = true; self.isPaused = false }
        }
    }

    func stopRecording() {
        sessionQueue.async {
            guard self.movieOutput.isRecording else { return }
            self.movieOutput.stopRecording()
            DispatchQueue.main.async { self.isRecording = false; self.isPaused = false }
        }
    }

    func pauseRecording() {
        sessionQueue.async {
            guard self.movieOutput.isRecording else { return }
            guard #available(iOS 18.0, *) else {
                DispatchQueue.main.async { self.statusMessage = "La pause vidéo nécessite iOS 18." }
                return
            }
            guard !self.movieOutput.isRecordingPaused else { return }
            self.movieOutput.pauseRecording()
            DispatchQueue.main.async { self.isPaused = true }
        }
    }

    func resumeRecording() {
        sessionQueue.async {
            guard #available(iOS 18.0, *),
                  self.movieOutput.isRecording, self.movieOutput.isRecordingPaused else { return }
            self.movieOutput.resumeRecording()
            DispatchQueue.main.async { self.isPaused = false }
        }
    }

    func pulseTorch() {
        sessionQueue.async {
            guard self.session.isRunning, let device = self.videoDeviceInput?.device,
                  device.isTorchAvailable, device.isTorchModeSupported(.on), device.torchMode == .off else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = .on
                device.unlockForConfiguration()
            } catch { return }
            self.sessionQueue.asyncAfter(deadline: .now() + 0.10) {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = .off
                    device.unlockForConfiguration()
                } catch { print("Torch error: \(error)") }
            }
        }
    }

    private func applyFrameRate(_ fps: Int) {
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            let targetFPS = CMTime(value: 1, timescale: CMTimeScale(fps))
            // Find a format that supports the requested FPS
            let format = device.formats.first {
                let ranges = $0.videoSupportedFrameRateRanges
                return ranges.contains { $0.minFrameRate <= Double(fps) && Double(fps) <= $0.maxFrameRate }
            }
            if let fmt = format {
                device.activeFormat = fmt
                device.activeVideoMinFrameDuration = targetFPS
                device.activeVideoMaxFrameDuration = targetFPS
            }
            device.unlockForConfiguration()
        } catch {
            print("Frame rate error: \(error)")
        }
    }
}

// MARK: - VideoRate enum

enum VideoRate {
    case normal, slowMo, timelapse
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
