import UIKit

struct DeviceInfo {

    static func getAll() -> [String: Any] {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        return [
            "name": device.name,
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "identifierForVendor": device.identifierForVendor?.uuidString ?? "unknown",
            "batteryLevel": device.batteryLevel,
            "batteryState": batteryStateString(device.batteryState),
            "screenBounds": [
                "width": UIScreen.main.bounds.width,
                "height": UIScreen.main.bounds.height
            ],
            "screenScale": UIScreen.main.scale,
            "brightness": UIScreen.main.brightness,
            "isMultitaskingSupported": device.isMultitaskingSupported,
            "processorCount": ProcessInfo.processInfo.processorCount,
            "physicalMemory": ProcessInfo.processInfo.physicalMemory,
            "thermalState": thermalStateString(ProcessInfo.processInfo.thermalState),
            "uptime": ProcessInfo.processInfo.systemUptime
        ]
    }

    static func getBattery() -> [String: Any] {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        return [
            "level": device.batteryLevel,
            "state": batteryStateString(device.batteryState),
            "isCharging": device.batteryState == .charging || device.batteryState == .full,
            "percentage": Int(device.batteryLevel * 100)
        ]
    }

    static func getNetwork(localIP: String?) -> [String: Any] {
        return [
            "localIP": localIP ?? "unknown",
            "hostname": ProcessInfo.processInfo.hostName
        ]
    }

    private static func batteryStateString(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown: return "unknown"
        case .unplugged: return "unplugged"
        case .charging: return "charging"
        case .full: return "full"
        @unknown default: return "unknown"
        }
    }

    private static func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
