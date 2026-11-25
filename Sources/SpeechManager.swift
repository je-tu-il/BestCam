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
    private var commandWork: DispatchWorkItem?
    private var countdown: [DispatchWorkItem] = []
    private var consumedTranscript = ""
    
    func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            print("Speech recognizer not available for fr-FR")
            return
        }
        
        // Stop ongoing tasks
        stopListening()
        
        consumedTranscript = ""
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
                let isFinal = result.isFinal
                
                DispatchQueue.main.async {
                    guard self.recognitionID == recognitionID else { return }
                    self.recognizedText = text
                    self.commandWork?.cancel()
                    if isFinal {
                        self.processKeywords(in: text)
                    } else {
                        let work = DispatchWorkItem { [weak self] in
                            self?.processKeywords(in: text)
                        }
                        self.commandWork = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85, execute: work)
                    }
                }
            }
            
            if error != nil || result?.isFinal == true {
                let shouldRestart = error == nil
                DispatchQueue.main.async {
                    guard self.recognitionID == recognitionID else { return }
                    if shouldRestart {
                        self.startListening()
                    } else {
                        self.stopListening()
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.isListening = true
        }
    }
    
    func stopListening() {
        commandWork?.cancel()
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
    
    private func processKeywords(in transcript: String) {
        let normalized = transcript.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr-FR"))
        guard normalized != consumedTranscript else { return }
        let text = normalized.hasPrefix(consumedTranscript)
            ? String(normalized.dropFirst(consumedTranscript.count))
            : normalized
        guard let camera = cameraManager else { return }

        switch text {
        case let command where command.contains("decompte") || command.contains("retardateur"):
            countdown.forEach { $0.cancel() }
            countdown.removeAll()
            if command.contains("flash") {
                for second in [0.0, 1.0, 2.0, 3.0, 3.7, 4.2, 4.6] {
                    let pulse = DispatchWorkItem { [weak camera] in camera?.pulseTorch() }
                    countdown.append(pulse)
                    DispatchQueue.main.asyncAfter(deadline: .now() + second, execute: pulse)
                }
            }
            let capture = DispatchWorkItem { [weak camera] in camera?.takePhoto() }
            countdown.append(capture)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: capture)
        case let command where command.contains("rafale"):
            camera.takeBurst()
        case let command where command.contains("reprends") || command.contains("reprendre"):
            camera.resumeRecording()
        case let command where command.contains("pause"):
            camera.pauseRecording()
        case let command where command.contains("fin video") || command.contains("arrete la video"):
            camera.stopRecording()
        case let command where command.contains("ralenti"):
            camera.startRecording(rate: .slowMo)
        case let command where command.contains("accelere"):
            camera.startRecording(rate: .timelapse)
        case let command where command.contains("debut video") || command.contains("lance la video"):
            camera.startRecording()
        case let command where command.contains("retire le grand angle") || command.contains("objectif standard"):
            camera.switchToNormalWide()
        case let command where command.contains("grand angle"):
            camera.switchToUltraWide()
            if command.contains("photo") { camera.takePhoto() }
        case let command where command.contains("photo"):
            camera.takePhoto()
        default:
            return
        }
        consumedTranscript = normalized
    }
}
