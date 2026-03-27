import SwiftUI

struct MainTabView: View {
    @ObservedObject var server: HTTPServer
    @State private var macIP: String = ""
    @State private var savedMacIP: String = UserDefaults.standard.string(forKey: "macIP") ?? ""

    var body: some View {
        TabView {
            MacRemoteView(macIP: $savedMacIP, onSetIP: { ip in
                savedMacIP = ip
                UserDefaults.standard.set(ip, forKey: "macIP")
            })
            .tabItem {
                Label("Mac", systemImage: "desktopcomputer")
            }

            ContentView(server: server)
                .tabItem {
                    Label("iPhone", systemImage: "iphone")
                }

            SettingsView(server: server, macIP: $savedMacIP)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
    }
}
