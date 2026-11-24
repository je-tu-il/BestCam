import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var speechManager: SpeechManager
    @EnvironmentObject var permissionsManager: PermissionsManager
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if permissionsManager.cameraAuthorized {
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
                        
                        if let status = cameraManager.statusMessage {
                            Text(status).font(.footnote).foregroundStyle(.white)
                        }
                        Button(speechManager.isListening ? "Couper l’écoute" : "Activer l’écoute") {
                            if speechManager.isListening { speechManager.stopListening() }
                            else if permissionsManager.speechAuthorized { speechManager.startListening() }
                            else {
                                permissionsManager.requestAllPermissions { _ in
                                    if permissionsManager.speechAuthorized { speechManager.startListening() }
                                }
                            }
                        }
                        .buttonStyle(.bordered)

                        HStack(spacing: 20) {
                            Button {
                                cameraManager.takePhoto()
                            } label: {
                                Label("Photo", systemImage: "camera")
                            }
                            .disabled(!cameraManager.isSessionRunning || cameraManager.isRecording)

                            Button {
                                if cameraManager.isRecording { cameraManager.stopRecording() }
                                else { cameraManager.startRecording() }
                            } label: {
                                Label(cameraManager.isRecording ? "Arrêter" : "Vidéo",
                                      systemImage: cameraManager.isRecording ? "stop.circle" : "record.circle")
                            }
                            .disabled(!cameraManager.isSessionRunning)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 18)
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
                    Text("Autorisez la caméra dans Réglages pour prendre des photos ou filmer.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding()
                    Button("Réessayer") {
                        permissionsManager.requestAllPermissions { _ in }
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
