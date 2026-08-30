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
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Pour éviter de déclencher plusieurs fois la même commande rapidement
    private var lastCommandTime = Date.distantPast
    
    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Speech recognizer not available for fr-FR")
            return
        }
        
        // Stop ongoing tasks
        stopListening()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        // Force offline recognition
        recognitionRequest.requiresOnDeviceRecognition = true
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString.lowercased()
                
                DispatchQueue.main.async {
                    self.recognizedText = text
                    self.processKeywords(in: text)
                }
            }
            
            if let error = error {
                print("Recognition error: \(error.localizedDescription)")
                self.stopListening()
                // Relancer l'écoute si l'erreur n'est pas fatale (parfois nécessaire si le moteur s'arrête)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if UIApplication.shared.applicationState == .active {
                        self.startListening()
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.isListening = true
        }
    }
    
    func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    func didReceiveAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Appelé depuis le thread audio de CameraManager
        if let request = recognitionRequest {
            request.appendAudioSampleBuffer(sampleBuffer)
        }
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
