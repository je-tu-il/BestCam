import Combine
import Foundation
import AVFoundation
import Speech

class PermissionsManager: ObservableObject {
    @Published var cameraAuthorized: Bool = false
    @Published private(set) var speechAuthorized = false
    
    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        requestCameraPermission { granted in
            guard granted else {
                DispatchQueue.main.async {
                    self.cameraAuthorized = false
                    self.speechAuthorized = false
                    completion(false)
                }
                return
            }
            self.requestMicrophonePermission { microphone in
                guard microphone else {
                    DispatchQueue.main.async {
                        self.cameraAuthorized = true
                        self.speechAuthorized = false
                        completion(true)
                    }
                    return
                }
                self.requestSpeechPermission { speech in
                    DispatchQueue.main.async {
                        self.cameraAuthorized = true
                        self.speechAuthorized = speech
                        completion(true)
                    }
                }
            }
        }
    }
    
    private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
    
    private func requestSpeechPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            completion(status == .authorized)
        }
    }
}
