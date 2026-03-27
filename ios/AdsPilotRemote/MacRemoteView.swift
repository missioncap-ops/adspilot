import SwiftUI
import WebKit

struct MacRemoteView: View {
    @Binding var macIP: String
    var onSetIP: (String) -> Void
    @State private var inputIP: String = ""
    @State private var isConnected = false
    @State private var reloadID = UUID()

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

            VStack(spacing: 12) {
                HStack {
                    TextField("IP du Mac (ex: 192.168.1.103)", text: $inputIP)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()

                    Button("Go") {
                        let ip = inputIP.trimmingCharacters(in: .whitespaces)
                        if !ip.isEmpty {
                            onSetIP(ip)
                            reloadID = UUID()
                            isConnected = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                if !macIP.isEmpty {
                    Button("Reconnect to \(macIP)") {
                        reloadID = UUID()
                        isConnected = true
                    }
                    .foregroundColor(.blue)
                }
            }

            Spacer()
        }
        .navigationTitle("Mac Remote")
        .onAppear {
            inputIP = macIP.isEmpty ? "100.86.36.26" : macIP
        }
    }

    private var remoteView: some View {
        ZStack {
            MacWebView(url: "http://\(macIP):9090", reloadID: reloadID)
                .ignoresSafeArea(edges: .bottom)

            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        reloadID = UUID()
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 8)

                    Button(action: { isConnected = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 8)
                }
                .padding(.top, 4)
                Spacer()
            }
        }
        .navigationTitle("Mac Remote")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MacWebView: UIViewRepresentable {
    let url: String
    let reloadID: UUID

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // Disable all caching
        config.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false

        loadURL(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Reload when reloadID changes
        loadURL(uiView)
    }

    private func loadURL(_ webView: WKWebView) {
        // Clear cache then load
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast
        ) {
            let urlString = "\(url)?nocache=\(UUID().uuidString)"
            if let requestURL = URL(string: urlString) {
                var request = URLRequest(url: requestURL)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                webView.load(request)
            }
        }
    }
}
