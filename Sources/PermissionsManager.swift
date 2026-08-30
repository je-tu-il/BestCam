import Foundation
import AVFoundation
import Speech

class PermissionsManager: ObservableObject {
    @Published var allPermissionsGranted: Bool = false
    
    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        requestCameraPermission { cameraGranted in
            guard cameraGranted else {
                completion(false)
                return
            }
            
            self.requestMicrophonePermission { micGranted in
                guard micGranted else {
                    completion(false)
                    return
                }
                
                self.requestSpeechPermission { speechGranted in
                    DispatchQueue.main.async {
                        self.allPermissionsGranted = speechGranted
                        completion(speechGranted)
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
