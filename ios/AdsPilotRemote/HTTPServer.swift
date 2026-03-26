import Foundation
import Network
import SwiftUI
import UIKit

class HTTPServer: ObservableObject {
    @Published var isRunning = false
    @Published var requestCount = 0
    @Published var lastCommand = "-"
    @Published var logs: [String] = []
    @Published var localIP: String?

    let port: UInt16 = 8085
    private var listener: NWListener?
    private let commandHandler = CommandHandler()

    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.localIP = self?.getLocalIP()
                        self?.log("Serveur demarre sur le port \(self?.port ?? 0)")
                    case .failed(let error):
                        self?.isRunning = false
                        self?.log("Erreur: \(error)")
                    default:
                        break
                    }
                }
            }
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            log("Impossible de demarrer: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        DispatchQueue.main.async {
            self.isRunning = false
            self.log("Serveur arrete")
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else {
                connection.cancel()
                return
            }

            let request = String(data: data, encoding: .utf8) ?? ""
            self.processHTTPRequest(request, connection: connection)
        }
    }

    private func processHTTPRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection: connection, status: 400, body: ["error": "Bad request"])
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: 400, body: ["error": "Bad request"])
            return
        }

        let method = parts[0]
        let path = parts[1]

        // Extract body for POST requests
        var body: String? = nil
        if let bodyStart = request.range(of: "\r\n\r\n") {
            body = String(request[bodyStart.upperBound...])
        }

        DispatchQueue.main.async {
            self.requestCount += 1
            self.lastCommand = "\(method) \(path)"
            self.log("\(method) \(path)")
        }

        // Route requests
        switch (method, path) {
        case ("GET", "/"):
            sendResponse(connection: connection, status: 200, body: [
                "app": "AdsPilot Remote",
                "version": "1.0",
                "status": "running",
                "endpoints": [
                    "GET /info - Device info",
                    "GET /battery - Battery status",
                    "GET /network - Network info",
                    "GET /screenshot - Take screenshot (base64)",
                    "GET /clipboard - Get clipboard content",
                    "POST /clipboard - Set clipboard content",
                    "POST /open - Open URL or app",
                    "POST /notify - Send local notification",
                    "POST /vibrate - Vibrate device",
                    "GET /brightness - Get screen brightness",
                    "POST /brightness - Set screen brightness",
                    "GET /volume - Get volume level",
                ]
            ])

        case ("GET", "/info"):
            let info = DeviceInfo.getAll()
            sendResponse(connection: connection, status: 200, body: info)

        case ("GET", "/battery"):
            let battery = DeviceInfo.getBattery()
            sendResponse(connection: connection, status: 200, body: battery)

        case ("GET", "/network"):
            let network = DeviceInfo.getNetwork(localIP: localIP)
            sendResponse(connection: connection, status: 200, body: network)

        case ("GET", "/screenshot"):
            commandHandler.takeScreenshot { [weak self] result in
                self?.sendResponse(connection: connection, status: 200, body: result)
            }
            return

        case ("GET", "/clipboard"):
            let content = commandHandler.getClipboard()
            sendResponse(connection: connection, status: 200, body: content)

        case ("POST", "/clipboard"):
            let result = commandHandler.setClipboard(body: body)
            sendResponse(connection: connection, status: 200, body: result)

        case ("POST", "/open"):
            commandHandler.openURL(body: body) { [weak self] result in
                self?.sendResponse(connection: connection, status: 200, body: result)
            }
            return

        case ("POST", "/notify"):
            commandHandler.sendNotification(body: body) { [weak self] result in
                self?.sendResponse(connection: connection, status: 200, body: result)
            }
            return

        case ("POST", "/vibrate"):
            commandHandler.vibrate()
            sendResponse(connection: connection, status: 200, body: ["status": "ok", "action": "vibrate"])

        case ("GET", "/brightness"):
            let brightness = commandHandler.getBrightness()
            sendResponse(connection: connection, status: 200, body: brightness)

        case ("POST", "/brightness"):
            let result = commandHandler.setBrightness(body: body)
            sendResponse(connection: connection, status: 200, body: result)

        case ("GET", "/volume"):
            let volume = commandHandler.getVolume()
            sendResponse(connection: connection, status: 200, body: volume)

        default:
            sendResponse(connection: connection, status: 404, body: ["error": "Not found", "path": path])
        }
    }

    private func sendResponse(connection: NWConnection, status: Int, body: [String: Any]) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        default: statusText = "Error"
        }

        let jsonData = (try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Content-Length: \(jsonData.count)\r
        Connection: close\r
        \r
        \(jsonString)
        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    private func getLocalIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }

    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > 100 {
                self.logs.removeFirst()
            }
        }
    }
}
