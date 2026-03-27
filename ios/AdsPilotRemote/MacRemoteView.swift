import SwiftUI
import WebKit

struct MacRemoteView: View {
    @Binding var macIP: String
    var onSetIP: (String) -> Void
    @State private var inputIP: String = ""
    @State private var isConnected = false

    var body: some View {
        NavigationStack {
            if macIP.isEmpty || !isConnected {
                connectView
            } else {
                remoteView
            }
        }
    }

    private var connectView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "desktopcomputer")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Mac Remote Control")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Entrez l'IP de votre Mac\nou scannez le reseau local")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                HStack {
                    TextField("IP du Mac (ex: 192.168.1.103)", text: $inputIP)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()

                    Button("Go") {
                        let ip = inputIP.trimmingCharacters(in: .whitespaces)
                        if !ip.isEmpty {
                            onSetIP(ip)
                            isConnected = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                if !macIP.isEmpty {
                    Button("Reconnect to \(macIP)") {
                        isConnected = true
                    }
                    .foregroundColor(.blue)
                }
            }

            Spacer()
        }
        .navigationTitle("Mac Remote")
        .onAppear {
            inputIP = macIP.isEmpty ? "192.168.1.103" : macIP
        }
    }

    private var remoteView: some View {
        ZStack {
            MacWebView(url: "http://\(macIP):9090")
                .ignoresSafeArea(edges: .bottom)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { isConnected = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Mac Remote")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MacWebView: UIViewRepresentable {
    let url: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        // Allow loading insecure local content
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        if let requestURL = URL(string: url) {
            webView.load(URLRequest(url: requestURL))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
