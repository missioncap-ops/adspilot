import SwiftUI

struct ContentView: View {
    @ObservedObject var server: HTTPServer

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Status indicator
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .fill(server.isRunning ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                            .frame(width: 30, height: 30)
                    )

                Text(server.isRunning ? "Serveur actif" : "Serveur arrete")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let ip = server.localIP {
                    VStack(spacing: 8) {
                        Text("Adresse")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("http://\(ip):\(server.port)")
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                // Stats
                VStack(spacing: 12) {
                    HStack {
                        Label("Requetes", systemImage: "arrow.up.arrow.down")
                        Spacer()
                        Text("\(server.requestCount)")
                            .fontWeight(.medium)
                    }
                    HStack {
                        Label("Derniere commande", systemImage: "clock")
                        Spacer()
                        Text(server.lastCommand)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()

                // Logs
                VStack(alignment: .leading, spacing: 8) {
                    Text("Logs")
                        .font(.headline)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(server.logs.suffix(20), id: \.self) { log in
                                Text(log)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("AdsPilot Remote")
        }
    }
}
