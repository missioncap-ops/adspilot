import UIKit
import AVFoundation
import UserNotifications

class CommandHandler {

    // MARK: - Screenshot

    func takeScreenshot(completion: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
                completion(["error": "No window found"])
                return
            }

            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let image = renderer.image { ctx in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }

            if let data = image.jpegData(compressionQuality: 0.7) {
                let base64 = data.base64EncodedString()
                completion([
                    "format": "jpeg",
                    "width": Int(image.size.width),
                    "height": Int(image.size.height),
                    "base64": base64,
                    "size_bytes": data.count
                ])
            } else {
                completion(["error": "Failed to capture screenshot"])
            }
        }
    }

    // MARK: - Clipboard

    func getClipboard() -> [String: Any] {
        var result: [String: Any] = [:]
        DispatchQueue.main.sync {
            let pasteboard = UIPasteboard.general
            result = [
                "hasStrings": pasteboard.hasStrings,
                "hasURLs": pasteboard.hasURLs,
                "hasImages": pasteboard.hasImages,
                "content": pasteboard.string ?? "",
                "changeCount": pasteboard.changeCount
            ]
        }
        return result
    }

    func setClipboard(body: String?) -> [String: Any] {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            return ["error": "Missing 'text' field in body"]
        }

        DispatchQueue.main.sync {
            UIPasteboard.general.string = text
        }

        return ["status": "ok", "action": "clipboard_set", "text": text]
    }

    // MARK: - Open URL / App

    func openURL(body: String?, completion: @escaping ([String: Any]) -> Void) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["url"] as? String,
              let url = URL(string: urlString) else {
            completion(["error": "Missing or invalid 'url' field"])
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                completion([
                    "status": success ? "ok" : "failed",
                    "action": "open_url",
                    "url": urlString
                ])
            }
        }
    }

    // MARK: - Notifications

    func sendNotification(body: String?, completion: @escaping ([String: Any]) -> Void) {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            completion(["error": "Invalid body"])
            return
        }

        let title = json["title"] as? String ?? "AdsPilot"
        let message = json["message"] as? String ?? ""

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                UNUserNotificationCenter.current().add(request) { error in
                    completion([
                        "status": error == nil ? "ok" : "failed",
                        "action": "notification",
                        "title": title,
                        "message": message
                    ])
                }
            } else {
                completion(["error": "Notification permission denied"])
            }
        }
    }

    // MARK: - Vibrate

    func vibrate() {
        DispatchQueue.main.async {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }

    // MARK: - Brightness

    func getBrightness() -> [String: Any] {
        var brightness: CGFloat = 0
        DispatchQueue.main.sync {
            brightness = UIScreen.main.brightness
        }
        return [
            "brightness": brightness,
            "percentage": Int(brightness * 100)
        ]
    }

    func setBrightness(body: String?) -> [String: Any] {
        guard let body = body,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["value"] as? Double else {
            return ["error": "Missing 'value' field (0.0 to 1.0)"]
        }

        let clamped = max(0, min(1, value))
        DispatchQueue.main.sync {
            UIScreen.main.brightness = CGFloat(clamped)
        }

        return ["status": "ok", "action": "brightness_set", "value": clamped]
    }

    // MARK: - Volume

    func getVolume() -> [String: Any] {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true)
        return [
            "volume": session.outputVolume,
            "percentage": Int(session.outputVolume * 100)
        ]
    }
}
