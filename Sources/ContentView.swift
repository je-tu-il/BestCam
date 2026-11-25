import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var speechManager: SpeechManager
    @EnvironmentObject var permissionsManager: PermissionsManager

    @State private var isUltraWide = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permissionsManager.cameraAuthorized {
                if cameraManager.isSessionRunning {
                    CameraPreviewView(session: cameraManager.session)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.mint)
                        Text("Initialisation optique...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                    }
                }

                VStack(spacing: 0) {
                    topHudBar
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    Spacer()

                    bottomControlDeck
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            } else {
                permissionsPlaceholder
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topHudBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(cameraManager.isRecording ? Color.red : Color.mint)
                    .frame(width: 9, height: 9)
                Text(cameraManager.isRecording ? "REC" : "BestCam")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()

            HStack(spacing: 6) {
                Button {
                    isUltraWide = false
                    cameraManager.switchToNormalWide()
                } label: {
                    Text("1x")
                        .font(.caption.weight(.bold))
                        .foregroundColor(!isUltraWide ? .black : .white)
                        .frame(width: 34, height: 28)
                        .background(!isUltraWide ? Color.mint : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }

                Button {
                    isUltraWide = true
                    cameraManager.switchToUltraWide()
                } label: {
                    Text("0.5x")
                        .font(.caption.weight(.bold))
                        .foregroundColor(isUltraWide ? .black : .white)
                        .frame(width: 38, height: 28)
                        .background(isUltraWide ? Color.mint : Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .disabled(!cameraManager.isSessionRunning || cameraManager.isRecording)
        }
    }

    private var bottomControlDeck: some View {
        VStack(spacing: 14) {
            if let status = cameraManager.statusMessage {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.mint.opacity(0.24))
                    .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: speechManager.isListening ? "waveform.circle.fill" : "mic.slash.circle.fill")
                        .font(.title3)
                        .foregroundColor(speechManager.isListening ? .mint : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(speechManager.isListening ? "Contrôle vocal actif" : "Écoute vocale en pause")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                        Text(speechManager.recognizedText.isEmpty ? "Dites « Photo », « Photo grand angle » ou « Début vidéo »" : speechManager.recognizedText)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.72))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        if speechManager.isListening {
                            speechManager.stopListening()
                        } else if permissionsManager.speechAuthorized {
                            speechManager.startListening()
                        } else {
                            permissionsManager.requestAllPermissions { _ in
                                if permissionsManager.speechAuthorized {
                                    speechManager.startListening()
                                }
                            }
                        }
                    } label: {
                        Text(speechManager.isListening ? "Pause" : "Activer")
                            .font(.caption.weight(.bold))
                            .foregroundColor(speechManager.isListening ? .white : .black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(speechManager.isListening ? Color.white.opacity(0.16) : Color.mint)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 28) {
                    Button {
                        cameraManager.takePhoto()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                            Text("Photo")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(width: 68, height: 54)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!cameraManager.isSessionRunning || cameraManager.isRecording)

                    Button {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording()
                        } else {
                            cameraManager.takePhoto()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            if cameraManager.isRecording {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                                    .frame(width: 28, height: 28)
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 58, height: 58)
                            }
                        }
                    }
                    .disabled(!cameraManager.isSessionRunning)
                    .accessibilityLabel(cameraManager.isRecording ? "Arrêter la vidéo" : "Prendre une photo")

                    Button {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording()
                        } else {
                            cameraManager.startRecording()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: cameraManager.isRecording ? "stop.fill" : "video.fill")
                                .font(.title3)
                            Text(cameraManager.isRecording ? "Stop" : "Vidéo")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(cameraManager.isRecording ? .white : .red)
                        .frame(width: 68, height: 54)
                        .background(cameraManager.isRecording ? Color.red : Color.red.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!cameraManager.isSessionRunning)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private var permissionsPlaceholder: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.15))
                    .frame(width: 84, height: 84)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(.mint)
            }

            Text("BestCam")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundColor(.white)

            Text("Autorisez la caméra, le micro et la reconnaissance vocale pour capturer photos et vidéos à la voix.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.72))
                .padding(.horizontal, 28)

            Button {
                permissionsManager.requestAllPermissions { _ in }
            } label: {
                Text("Autoriser l'accès")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.mint)
                    .clipShape(Capsule())
            }
        }
        .padding()
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
