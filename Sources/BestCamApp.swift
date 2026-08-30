import SwiftUI

@main
struct BestCamApp: App {
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var permissionsManager = PermissionsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraManager)
                .environmentObject(speechManager)
                .environmentObject(permissionsManager)
                .onAppear {
                    permissionsManager.requestAllPermissions { success in
                        if success {
                            cameraManager.setupSession()
                            speechManager.cameraManager = cameraManager
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                if permissionsManager.allPermissionsGranted {
                    cameraManager.startSession()
                    speechManager.startListening()
                }
            case .inactive, .background:
                speechManager.stopListening()
                cameraManager.stopSession()
            @unknown default:
                break
            }
        }
    }
}
