import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var monitor = DeviceMonitor()
    @Environment(\.scenePhase) private var scenePhase

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.06, green: 0.08, blue: 0.20), .black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    metrics
                    details
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                monitor.start()
            } else {
                monitor.stop()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("مباشر")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.green)
            }
            Text(monitor.modelName)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
            HStack(spacing: 8) {
                Chip(text: "iOS \(monitor.systemVersion)")
                Chip(text: monitor.modelIdentifier)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var metrics: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            MetricCard(
                title: "البطارية",
                icon: batteryIcon,
                progress: monitor.batteryLevel,
                detail: batteryStateText,
                colors: [.green, .mint, .green]
            )
            MetricCard(
                title: "التخزين",
                icon: "internaldrive.fill",
                progress: monitor.storageUsedFraction,
                detail: "متاح \(Format.bytes(monitor.storageFree))",
                colors: [.cyan, .blue, .cyan]
            )
            MetricCard(
                title: "الذاكرة",
                icon: "memorychip.fill",
                progress: monitor.memoryUsedFraction,
                detail: "\(Format.bytes(monitor.memoryUsed)) من \(Format.bytes(monitor.memoryTotal))",
                colors: [.purple, .pink, .purple]
            )
            MetricCard(
                title: "المعالج",
                icon: "cpu.fill",
                progress: monitor.cpuUsage,
                detail: "\(monitor.cpuCores) أنوية",
                colors: [.orange, .red, .orange]
            )
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            InfoRow(icon: "iphone", title: "الطراز", value: monitor.modelName)
            Divider()
            InfoRow(icon: "gearshape.fill", title: "إصدار النظام", value: "iOS \(monitor.systemVersion)")
            Divider()
            InfoRow(icon: "rectangle.on.rectangle", title: "الشاشة", value: monitor.screenDescription)
            Divider()
            InfoRow(icon: "thermometer", title: "حرارة الجهاز", value: thermalText, valueColor: thermalColor)
            Divider()
            InfoRow(
                icon: "leaf.fill",
                title: "وضع توفير الطاقة",
                value: monitor.isLowPowerMode ? "مفعّل" : "غير مفعّل",
                valueColor: monitor.isLowPowerMode ? .yellow : .primary
            )
            Divider()
            InfoRow(icon: "clock.fill", title: "مدة التشغيل", value: Format.duration(monitor.uptime))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .cardBackground()
    }

    private var footer: some View {
        Text("يتحدّث تلقائياً كل ثانيتين")
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }

    // MARK: - Labels

    private var batteryIcon: String {
        switch monitor.batteryState {
        case .charging, .full: return "battery.100.bolt"
        default: return "battery.75"
        }
    }

    private var batteryStateText: String {
        switch monitor.batteryState {
        case .charging: return "يشحن الآن"
        case .full: return "مشحونة بالكامل"
        case .unplugged: return "غير موصول بالشاحن"
        default: return "غير معروف"
        }
    }

    private var thermalText: String {
        switch monitor.thermalState {
        case .nominal: return "طبيعية"
        case .fair: return "دافئة"
        case .serious: return "مرتفعة"
        case .critical: return "حرجة"
        @unknown default: return "غير معروفة"
        }
    }

    private var thermalColor: Color {
        switch monitor.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }
}

enum Format {
    static func bytes<T: BinaryInteger>(_ value: T) -> String {
        let gigabytes = Double(value) / 1_073_741_824
        return String(format: "%.1f GB", gigabytes)
    }

    private static let durationFormatter: DateComponentsFormatter = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ar@numbers=latn")
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        return formatter
    }()

    static func duration(_ interval: TimeInterval) -> String {
        durationFormatter.string(from: interval) ?? "--"
    }
}
