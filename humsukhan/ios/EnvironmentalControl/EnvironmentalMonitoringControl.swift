import AppIntents
import SwiftUI
import WidgetKit

/// iOS 18+ Control Center implementation.
///
/// Add this source file to a Widget Extension target with "Include Control"
/// enabled in Xcode. It deliberately shares the same App Group state key as
/// the Runner app and calls the app intent that owns the explicit monitoring
/// transition. The Runner target alone cannot expose a Control Center module.
struct EnvironmentalMonitoringControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.humsukhan.environmental-monitor") {
            ControlWidgetButton(action: ToggleEnvironmentalMonitoringIntent()) {
                Label("Environmental", systemImage: "ear.badge.waveform")
            }
        }
        .displayName("Environmental Monitoring")
        .description("Explicitly start or stop local environmental sound monitoring.")
    }
}

struct ToggleEnvironmentalMonitoringIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Environmental Monitoring"
    static let description = IntentDescription("Starts or stops HumSukhan local environmental monitoring.")

    func perform() async throws -> some IntentResult {
        // The ControlWidget target should call into the same app-owned state
        // transition. Opening the app is required when microphone permission
        // has not yet been granted; the app then requests permission explicitly.
        await MainActor.run {
            NotificationCenter.default.post(name: .humsukhanEnvironmentalToggle, object: nil)
        }
        return .result()
    }
}

extension Notification.Name {
    static let humsukhanEnvironmentalToggle = Notification.Name("HumSukhan.Environmental.Toggle")
}

@main
struct HumSukhanControlsBundle: WidgetBundle {
    var body: some Widget {
        EnvironmentalMonitoringControl()
    }
}
