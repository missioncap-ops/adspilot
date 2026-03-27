import SwiftUI

struct SettingsView: View {
    @ObservedObject var server: HTTPServer
    @Binding var macIP: String
    @State private var editIP: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("iPhone Server") {
                    HStack {
                        Text("Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(server.isRunning ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(server.isRunning ? "Active" : "Stopped")
                                .foregroundColor(.secondary)
                        }
                    }
                    if let ip = server.localIP {
                        HStack {
                            Text("Address")
                            Spacer()
                            Text("http://\(ip):\(server.port)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack {
                        Text("Requests")
                        Spacer()
                        Text("\(server.requestCount)")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Mac Connection") {
                    HStack {
                        TextField("Mac IP", text: $editIP)
                            .keyboardType(.decimalPad)
                        Button("Save") {
                            macIP = editIP
                            UserDefaults.standard.set(editIP, forKey: "macIP")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if !macIP.isEmpty {
                        HStack {
                            Text("Current")
                            Spacer()
                            Text(macIP)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Remote v1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Port")
                        Spacer()
                        Text("\(server.port)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                editIP = macIP
            }
        }
    }
}
