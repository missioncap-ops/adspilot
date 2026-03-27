import SwiftUI

@main
struct AdsPilotRemoteApp: App {
    @StateObject private var server = HTTPServer()

    var body: some Scene {
        WindowGroup {
            MainTabView(server: server)
                .onAppear {
                    server.start()
                }
        }
    }
}
