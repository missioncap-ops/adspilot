import SwiftUI

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
                NativeRemoteScreen(macIP: macIP, onDisconnect: { isConnected = false })
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
                .font(.title2).fontWeight(.semibold)

            VStack(spacing: 12) {
                HStack {
                    TextField("IP du Mac", text: $inputIP)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                    Button("Go") {
                        let ip = inputIP.trimmingCharacters(in: .whitespaces)
                        if !ip.isEmpty { onSetIP(ip); isConnected = true }
                    }.buttonStyle(.borderedProminent)
                }.padding(.horizontal)

                if !macIP.isEmpty {
                    Button("Reconnect to \(macIP)") { isConnected = true }
                        .foregroundColor(.blue)
                }
            }
            Spacer()
        }
        .navigationTitle("Mac Remote")
        .onAppear { inputIP = macIP.isEmpty ? "100.86.36.26" : macIP }
    }
}

struct NativeRemoteScreen: View {
    let macIP: String
    let onDisconnect: () -> Void

    @State private var screenImage: UIImage?
    @State private var imageWidth: CGFloat = 900
    @State private var imageHeight: CGFloat = 600
    @State private var isAutoRefresh = true
    @State private var showKeyboard = false
    @State private var textInput = ""
    @State private var statusText = "Connecting..."
    @State private var moveMode = false
    @State private var timer: Timer?
    @State private var zoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var baseURL: String { "http://\(macIP):9090" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top toolbar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        tb("Spotlight") { key("cmd+space") }
                        tb("Switch") { key("cmd+tab") }
                        tb("Copy") { key("cmd+c") }
                        tb("Paste") { key("cmd+v") }
                        tb("Undo") { key("cmd+z") }
                        tb("Close") { key("cmd+w") }
                        tb("Quit") { key("cmd+q") }
                        tb("Esc") { key("escape") }
                        tb("Tab") { key("tab") }
                        tb("Save") { key("cmd+s") }
                    }.padding(4)
                }.background(Color(white: 0.1))

                // Screen
                GeometryReader { geo in
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        if let img = screenImage {
                            Image(uiImage: img)
                                .resizable()
                                .frame(width: imageWidth * zoom, height: imageHeight * zoom)
                                .onTapGesture { location in
                                    let x = Int(location.x / zoom)
                                    let y = Int(location.y / zoom)
                                    if moveMode {
                                        move(x, y)
                                    } else {
                                        click(x, y)
                                    }
                                    statusText = (moveMode ? "Move " : "Click ") + "\(x),\(y)"
                                }
                        } else {
                            ProgressView("Loading...")
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                }

                // Status
                Text(statusText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(2)

                // Keyboard input
                if showKeyboard {
                    VStack(spacing: 6) {
                        TextField("Type here...", text: $textInput)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .onSubmit { sendText() }
                        HStack(spacing: 4) {
                            tb("Send") { sendText() }
                            tb("Enter") { key("return") }
                            tb("Del") { key("delete") }
                            tb("Space") { key("space") }
                            tb("Close") { showKeyboard = false }
                        }
                    }
                    .padding(8)
                    .background(Color(white: 0.1))
                }

                // Bottom bar
                HStack(spacing: 4) {
                    tb("Refresh") { fetchScreen() }
                    tb(isAutoRefresh ? "Auto ON" : "Auto") {
                        isAutoRefresh.toggle()
                        setupTimer()
                    }.foregroundColor(isAutoRefresh ? .blue : .white)
                    tb("Kbd") { showKeyboard.toggle() }
                    tb("RClick") { rightClick() }
                    tb(moveMode ? "Move ON" : "Move") {
                        moveMode.toggle()
                        statusText = moveMode ? "Mode: MOVE" : "Mode: CLICK"
                    }.foregroundColor(moveMode ? .blue : .white)
                    tb("+") { zoom = min(4, zoom + 0.3) }
                    tb("-") { zoom = max(0.3, zoom - 0.3) }
                    tb("X") { onDisconnect() }
                }
                .padding(6)
                .background(Color(white: 0.1))
            }
        }
        .navigationBarHidden(true)
        .onAppear { fetchScreen(); setupTimer() }
        .onDisappear { timer?.invalidate() }
    }

    func tb(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(white: 0.2))
            .foregroundColor(.white)
            .cornerRadius(6)
    }

    func setupTimer() {
        timer?.invalidate()
        if isAutoRefresh {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                fetchScreen()
            }
        }
    }

    func fetchScreen() {
        guard let url = URL(string: "\(baseURL)/screenshot?\(Int(Date().timeIntervalSince1970 * 1000))") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { statusText = "Error: \(error.localizedDescription)" }
                return
            }
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    screenImage = img
                    imageWidth = img.size.width
                    imageHeight = img.size.height
                    if statusText == "Connecting..." || statusText.hasPrefix("Error") {
                        statusText = "\(Int(img.size.width))x\(Int(img.size.height)) | Tap = Click"
                    }
                }
            }
        }.resume()
    }

    func click(_ x: Int, _ y: Int) {
        post("/click", body: ["x": x, "y": y])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { fetchScreen() }
    }

    func rightClick() {
        statusText = "Right click"
        post("/rightclick", body: ["x": Int(imageWidth/2), "y": Int(imageHeight/2)])
    }

    func move(_ x: Int, _ y: Int) {
        post("/move", body: ["x": x, "y": y])
    }

    func key(_ k: String) {
        statusText = "Key: \(k)"
        post("/key", body: ["key": k])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { fetchScreen() }
    }

    func sendText() {
        guard !textInput.isEmpty else { return }
        statusText = "Type: \(textInput.prefix(20))"
        post("/type", body: ["text": textInput])
        textInput = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { fetchScreen() }
    }

    func post(_ path: String, body: [String: Any]) {
        guard let url = URL(string: "\(baseURL)\(path)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 3
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
    }
}
