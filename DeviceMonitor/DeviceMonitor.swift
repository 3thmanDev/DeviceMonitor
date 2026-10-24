import SwiftUI
import UIKit
import Darwin

/// Polls battery, storage, memory and CPU stats every couple of seconds.
final class DeviceMonitor: ObservableObject {
    @Published private(set) var batteryLevel: Double? = nil
    @Published private(set) var batteryState: UIDevice.BatteryState = .unknown
    @Published private(set) var storageTotal: Int64 = 0
    @Published private(set) var storageFree: Int64 = 0
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var cpuUsage: Double? = nil
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var isLowPowerMode = false
    @Published private(set) var uptime: TimeInterval = 0

    let memoryTotal = ProcessInfo.processInfo.physicalMemory
    let cpuCores = ProcessInfo.processInfo.processorCount
    let systemVersion = UIDevice.current.systemVersion
    let modelIdentifier: String
    let modelName: String
    let screenDescription: String

    private let refreshInterval: TimeInterval = 2
    private let host = mach_host_self()
    private var timer: Timer?
    private var previousCPUTicks: (used: UInt64, total: UInt64)?

    init() {
        modelIdentifier = DeviceMonitor.readModelIdentifier()
        modelName = DeviceMonitor.friendlyName(for: modelIdentifier)

        let screen = UIScreen.main
        let pixels = screen.nativeBounds.size
        screenDescription = "\(Int(pixels.width))×\(Int(pixels.height)) · \(screen.maximumFramesPerSecond)Hz"
    }

    var storageUsedFraction: Double? {
        guard storageTotal > 0 else { return nil }
        return Double(storageTotal - storageFree) / Double(storageTotal)
    }

    var memoryUsedFraction: Double? {
        guard memoryTotal > 0, memoryUsed > 0 else { return nil }
        return Double(memoryUsed) / Double(memoryTotal)
    }

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let device = UIDevice.current
        batteryLevel = device.batteryLevel >= 0 ? Double(device.batteryLevel) : nil
        batteryState = device.batteryState

        let processInfo = ProcessInfo.processInfo
        thermalState = processInfo.thermalState
        isLowPowerMode = processInfo.isLowPowerModeEnabled
        uptime = processInfo.systemUptime

        readStorage()
        memoryUsed = readMemoryUsed() ?? memoryUsed
        if let usage = readCPUUsage() {
            cpuUsage = usage
        }
    }

    // MARK: - Readers

    private func readStorage() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? home.resourceValues(forKeys: keys) else { return }
        storageTotal = Int64(values.volumeTotalCapacity ?? 0)
        storageFree = values.volumeAvailableCapacityForImportantUsage ?? 0
    }

    private func readMemoryUsed() -> UInt64? {
        let host = self.host
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return pages * UInt64(pageSize)
    }

    /// CPU load is a delta between two samples, so the first call only primes the counters.
    private func readCPUUsage() -> Double? {
        let host = self.host
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let user = UInt64(info.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let used = user + system + nice
        let total = used + idle

        let previous = previousCPUTicks
        previousCPUTicks = (used, total)
        guard let previous = previous, total > previous.total, used >= previous.used else { return nil }
        return min(Double(used - previous.used) / Double(total - previous.total), 1)
    }

    private static func readModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(Character(UnicodeScalar(UInt8(value))))
        }
    }

    private static func friendlyName(for identifier: String) -> String {
        let names: [String: String] = [
            "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
            "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone12,8": "iPhone SE (2nd gen)",
            "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,6": "iPhone SE (3rd gen)",
            "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,5": "iPhone 16e",
            "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air",
            "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max",
        ]
        if let name = names[identifier] { return name }
        if identifier == "x86_64" || identifier == "arm64" { return "Simulator" }
        if identifier.hasPrefix("iPad") { return "iPad" }
        if identifier.hasPrefix("iPhone") { return "iPhone" }
        return identifier
    }
}
