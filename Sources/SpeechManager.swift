import Combine
import Foundation
import Speech
import UIKit

class SpeechManager: ObservableObject, CameraAudioDelegate {
    
    @Published var recognizedText: String = ""
    @Published var isListening: Bool = false
    
    weak var cameraManager: CameraManager? {
        didSet {
            cameraManager?.audioDelegate = self
        }
    }
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let requestLock = NSLock()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Pour éviter de déclencher plusieurs fois la même commande rapidement
    private var recognitionID: UUID?
    private var lastCommandTime = Date.distantPast
    
    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            print("Speech recognizer not available for fr-FR")
            return
        }
        
        // Stop ongoing tasks
        stopListening()
        
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        requestLock.lock()
        self.recognitionRequest = recognitionRequest
        requestLock.unlock()
        
        // Force offline recognition
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        
        let recognitionID = UUID()
        self.recognitionID = recognitionID
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString.lowercased()
                
                DispatchQueue.main.async {
                    guard self.recognitionID == recognitionID else { return }
                    self.recognizedText = text
                    self.processKeywords(in: text)
                }
            }
            
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    if self.recognitionID == recognitionID { self.stopListening() }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.isListening = true
        }
    }
    
    func stopListening() {
        recognitionID = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        requestLock.lock()
        let stoppedRequest = recognitionRequest
        recognitionRequest = nil
        requestLock.unlock()
        stoppedRequest?.endAudio()
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    func didReceiveAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Appelé depuis le thread audio de CameraManager
        requestLock.lock()
        recognitionRequest?.appendAudioSampleBuffer(sampleBuffer)
        requestLock.unlock()
    }
    
    private func processKeywords(in text: String) {
        // Obtenir seulement les derniers mots pour la détection
        // On cherche des mots-clés spécifiques dans le texte récent.
        let now = Date()
        guard now.timeIntervalSince(lastCommandTime) > 2.0 else { return } // debounce 2 secondes
        
        if text.contains("photo grand angle") {
            print("Action: Photo Grand Angle")
            lastCommandTime = now
            cameraManager?.switchToUltraWide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.cameraManager?.takePhoto()
            }
        } else if text.contains("photo") {
            print("Action: Photo")
            lastCommandTime = now
            cameraManager?.switchToNormalWide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.cameraManager?.takePhoto()
            }
        } else if text.contains("début vidéo") {
            print("Action: Début Vidéo")
            lastCommandTime = now
            cameraManager?.startRecording()
        } else if text.contains("fin vidéo") {
            print("Action: Fin Vidéo")
            lastCommandTime = now
            cameraManager?.stopRecording()
        }
    }
}
