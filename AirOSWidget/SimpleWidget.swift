import WidgetKit
import SwiftUI

struct SimpleWidget: Widget {
    let kind: String = "com.yourdomain.airos.widget.simple"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            Text("Test Widget")
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Test Widget")
        .description("A test widget")
        .supportedFamilies([.systemSmall])
    }
}

extension SimpleWidget {
    struct Provider: TimelineProvider {
        func placeholder(in context: Context) -> SimpleEntry {
            SimpleEntry(date: Date())
        }

        func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
            let entry = SimpleEntry(date: Date())
            completion(entry)
        }

        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
            let entries = [SimpleEntry(date: Date())]
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }

    struct SimpleEntry: TimelineEntry {
        let date: Date
    }
} 