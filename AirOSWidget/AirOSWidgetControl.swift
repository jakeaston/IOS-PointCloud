//
//  AirOSWidgetControl.swift
//  AirOSWidget
//
//  Created by Jake Aston on 27/01/2025.
//  Copyright © 2025 Apple. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)  // Add this to explicitly mark iOS 17 requirement
struct AirOSWidgetControl: ControlWidget {
    static let kind: String = "com.yourdomain.airos.widget.control"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
            // .containerBackground(.fill.tertiary, for: .widget)
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
    
    // Move these to the widget level
    // .configurationDisplayName("Timer Control")
    // .description("A control widget that runs a timer.")
}

extension AirOSWidgetControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            AirOSWidgetControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let isRunning = true // Check if the timer is running
            return AirOSWidgetControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Timer Name Configuration"

    @Parameter(title: "Timer Name", default: "Timer")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"

    @Parameter(title: "Timer Name")
    var name: String

    @Parameter(title: "Timer is running")
    var value: Bool

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        // Start the timer…
        return .result()
    }
}
