import SwiftUI

@main
struct AdsPilotRemoteApp: App {
    @StateObject private var server = HTTPServer()

    var body: some Scene {
        WindowGroup {
            ContentView(server: server)
                .onAppear {
                    server.start()
                }
        }
    }
}
