import SwiftUI

@main
struct BestCamApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var permissionsManager = PermissionsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color(red: 0.19, green: 0.37, blue: 0.47))
                .environmentObject(cameraManager)
                .environmentObject(speechManager)
                .environmentObject(permissionsManager)
                .onAppear {
                    permissionsManager.requestAllPermissions { _ in updateCapture() }
                }
                .onChange(of: scenePhase) { _ in updateCapture() }
                .onChange(of: permissionsManager.cameraAuthorized) { _ in updateCapture() }
        }
    }

    private func updateCapture() {
        if scenePhase == .active && permissionsManager.cameraAuthorized {
            speechManager.cameraManager = cameraManager
            cameraManager.startSession()
        } else {
            speechManager.stopListening()
            cameraManager.stopSession()
        }
    }
}
