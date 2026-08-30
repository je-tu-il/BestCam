import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var speechManager: SpeechManager
    @EnvironmentObject var permissionsManager: PermissionsManager
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if permissionsManager.allPermissionsGranted {
                if cameraManager.isSessionRunning {
                    CameraPreviewView(session: cameraManager.session)
                        .edgesIgnoringSafeArea(.all)
                }
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Text(speechManager.isListening ? "🎙️ Écoute vocale active" : "🎙️ Écoute en pause")
                            .foregroundColor(speechManager.isListening ? .green : .red)
                            .padding(.top, 8)
                        
                        Text("Dernière commande : \(speechManager.recognizedText)")
                            .foregroundColor(.white)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            Circle()
                                .fill(cameraManager.isRecording ? Color.red : Color.white)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 2)
                                )
                                .onTapGesture {
                                    if cameraManager.isRecording {
                                        cameraManager.stopRecording()
                                    } else {
                                        cameraManager.takePhoto() // Par défaut bouton physique pour la photo
                                    }
                                }
                        }
                        .padding(.bottom, 30)
                    }
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(15)
                    .padding()
                }
            } else {
                VStack {
                    Text("Permissions requises")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Veuillez autoriser l'accès à la caméra, au microphone et à la reconnaissance vocale dans les réglages de votre appareil.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding()
                    Button("Réessayer") {
                        permissionsManager.requestAllPermissions { success in
                            if success {
                                cameraManager.setupSession()
                                speechManager.cameraManager = cameraManager
                                cameraManager.startSession()
                                speechManager.startListening()
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}
