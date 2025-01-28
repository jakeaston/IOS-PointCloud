import WidgetKit
import SwiftUI

// Model to store API data
struct ScanStatus: Codable {
    let totalScans: Int
    let lastScanDate: Date?
    let storageUsed: Double // in GB
    // Add any other status fields you need
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), status: ScanStatus(totalScans: 0, lastScanDate: nil, storageUsed: 0))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        fetchStatus { status in
            let entry = SimpleEntry(date: Date(), status: status)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        fetchStatus { status in
            let entry = SimpleEntry(date: Date(), status: status)
            
            // Update widget every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
    
    private func fetchStatus(completion: @escaping (ScanStatus) -> Void) {
        guard let url = URL(string: "https://s1.air-os.app/api/status") else {
            return completion(ScanStatus(totalScans: 0, lastScanDate: nil, storageUsed: 0))
        }
        
        var request = URLRequest(url: url)
        
        // Get shared cookies from App Group container
        if let sharedCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: "group.com.yourcompany.airos") {
            if let cookies = sharedCookieStorage.cookies {
                let headers = HTTPCookie.requestHeaderFields(with: cookies)
                request.allHTTPHeaderFields = headers
            }
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let status = try? JSONDecoder().decode(ScanStatus.self, from: data) else {
                return completion(ScanStatus(totalScans: 0, lastScanDate: nil, storageUsed: 0))
            }
            
            completion(status)
        }
        
        task.resume()
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let status: ScanStatus
}

struct AirOSWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("Air OS Status")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Scans: \(entry.status.totalScans)")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                if let lastScan = entry.status.lastScanDate {
                    Text("Last Scan: \(lastScan, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                
                Text("Storage: \(String(format: "%.1f", entry.status.storageUsed))GB")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 16/255, green: 22/255, blue: 67/255))
    }
}

@main
struct AirOSWidget: Widget {
    let kind: String = "AirOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AirOSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Air OS Status")
        .description("Shows your scanning statistics.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AirOSWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleStatus = ScanStatus(
            totalScans: 42,
            lastScanDate: Date().addingTimeInterval(-3600),
            storageUsed: 1.5
        )
        
        AirOSWidgetEntryView(entry: SimpleEntry(date: Date(), status: sampleStatus))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        
        AirOSWidgetEntryView(entry: SimpleEntry(date: Date(), status: sampleStatus))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
} 