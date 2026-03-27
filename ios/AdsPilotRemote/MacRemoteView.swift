import SwiftUI
import WebKit

struct MacRemoteView: View {
    @Binding var macIP: String
    var onSetIP: (String) -> Void
    @State private var inputIP: String = ""
    @State private var isConnected = false
    @State private var reloadTrigger = false

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
                    TextField("IP du Mac", text: $inputIP)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
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
            inputIP = macIP.isEmpty ? "100.86.36.26" : macIP
        }
    }

    private var remoteView: some View {
        ZStack {
            NoCacheMacWebView(
                urlString: "http://\(macIP):9090",
                reload: $reloadTrigger
            )
            .ignoresSafeArea(edges: .bottom)

            VStack {
                HStack {
                    Spacer()
                    Button(action: { reloadTrigger.toggle() }) {
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

// Custom WebView that handles HTTP, no cache, and navigation delegate
class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var hasLoaded = false

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView error: \(error.localizedDescription)")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView provisional error: \(error.localizedDescription)")
        // Retry after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            webView.reload()
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hasLoaded = true
        print("WebView loaded OK")
    }
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
}

struct NoCacheMacWebView: UIViewRepresentable {
    let urlString: String
    @Binding var reload: Bool

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false

        guard let url = URL(string: urlString) else { return webView }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.timeoutInterval = 10
        webView.load(req)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only reload when reload button is pressed (reload binding changes)
        // Don't reload on every SwiftUI update
    }
}
