import WidgetKit
import SwiftUI

// Model to store API data
struct Aircraft: Codable {
    let label: String
    let status: Int
}

struct APIResponse: Codable {
    let aircraft: [Aircraft]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), aircraft: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        fetchStatus { aircraft in
            let entry = SimpleEntry(date: Date(), aircraft: aircraft)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        fetchStatus { aircraft in
            let entry = SimpleEntry(date: Date(), aircraft: aircraft)
            
            // Update widget every 30 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
    
    private func fetchStatus(completion: @escaping ([Aircraft]) -> Void) {
        // Temporary sample data for testing
        let sampleAircraft = [
            Aircraft(label: "G-ABCD", status: 1),
            Aircraft(label: "G-WXYZ", status: 3),
            Aircraft(label: "G-1234", status: 4),
            Aircraft(label: "G-5678", status: 5)
        ]
        completion(sampleAircraft)
        
        /* Commenting out network code for now
        guard let url = URL(string: "https://shared.air-os.app/ios/widget/status") else {
            print("Invalid URL")
            return completion([])
        }
        
        var request = URLRequest(url: url)
        
        // Create a shared URL session configuration with correct group identifier
        let config = URLSessionConfiguration.default
        config.sharedContainerIdentifier = "group.com.airos"
        
        // Get shared cookies with correct group identifier
        let sharedCookieStorage = HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier: "group.com.airos")
        if let cookies = sharedCookieStorage.cookies {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            request.allHTTPHeaderFields = headers
        }
        
        // Use the configured session
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { data, response, error in
            // Add HTTP response logging
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            if let error = error {
                print("Network error: \(error)")
                return completion([])
            }
            
            guard let data = data else {
                print("No data received")
                return completion([])
            }
            
            do {
                let response = try JSONDecoder().decode(APIResponse.self, from: data)
                print("Received aircraft: \(response.aircraft.count)")
                completion(response.aircraft)
            } catch {
                print("Decoding error: \(error)")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(dataString)")
                }
                completion([])
            }
        }
        
        task.resume()
        */
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let aircraft: [Aircraft]
}

struct AirOSWidgetEntryView : View {
    var entry: Provider.Entry
    
    // Add this new helper view
    struct FlowLayout: View {
        let aircraft: [Aircraft]
        let statusColor: (Int) -> Color
        let spacing: CGFloat
        
        var body: some View {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        
        private func generateContent(in geometry: GeometryProxy) -> some View {
            var width = CGFloat.zero
            var height = CGFloat.zero
            let verticalSpacing: CGFloat = 24 // Fixed vertical spacing
            
            return ZStack(alignment: .topLeading) {
                ForEach(aircraft.sorted(by: { a, b in
                    // Custom sorting: status 3 first, then 4, then others
                    switch (a.status, b.status) {
                    case (3, 3): return a.label < b.label  // If both status 3, sort by label
                    case (3, _): return true               // Status 3 comes first
                    case (_, 3): return false              // Status 3 comes first
                    case (4, 4): return a.label < b.label  // If both status 4, sort by label
                    case (4, _): return true               // Status 4 comes second
                    case (_, 4): return false              // Status 4 comes second
                    default: return a.label < b.label      // All other cases, sort by label
                    }
                }), id: \.label) { aircraft in
                    VStack(alignment: .center, spacing: 2) {
                        Circle()
                            .fill(statusColor(aircraft.status))
                            .frame(width: 8, height: 8)
                            .shadow(color: statusColor(aircraft.status), radius: 2)
                        Text(aircraft.label)
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 4)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height += verticalSpacing
                        }
                        let result = width
                        
                        // Calculate remaining space in the row
                        let remainingSpace = geometry.size.width - width
                        let itemCount = self.aircraft.filter { item in
                            // Count items that would fit in the current row
                            let itemStart = width - (dimension.width + spacing)
                            return itemStart >= 0 && itemStart < geometry.size.width
                        }.count
                        
                        // Distribute remaining space evenly
                        let adjustedSpacing = itemCount > 1 ? remainingSpace / CGFloat(itemCount - 1) : spacing
                        
                        if aircraft.label == self.aircraft.last?.label {
                            width = 0
                        } else {
                            width -= dimension.width + adjustedSpacing
                        }
                        return result
                    }
                    .alignmentGuide(.top) { dimension in
                        let result = height
                        if aircraft.label == self.aircraft.last?.label {
                            height = 0
                        }
                        return result
                    }
                }
            }
        }
    }
    
    // Updated status color function with more distinct colors
    private func statusColor(_ status: Int) -> Color {
        switch status {
        case 3: return Color(red: 1.0, green: 0.65, blue: 0.0) // More distinct orange
        case 4: return Color(red: 0.0, green: 0.48, blue: 1.0) // Brighter blue
        case 1, 5: return Color.gray
        default: return Color.gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top section with right-aligned logo
            HStack {
                Text("Aircraft Status")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            .padding(.top, 2)
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Replace ScrollView with FlowLayout
            FlowLayout(aircraft: entry.aircraft, statusColor: statusColor, spacing: 8)
                .padding(.horizontal, 4)
        }
        .padding([.horizontal, .bottom], 12)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(red: 0.063, green: 0.086, blue: 0.263).opacity(0.95), for: .widget)
    }
}


struct AirOSWidget: Widget {
    let kind: String = "AirOSWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AirOSWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Fleet Status")
        .description("Shows your fleet status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AirOSWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleAircraft = [
            Aircraft(label: "Aircraft A", status: 1),
            Aircraft(label: "Aircraft B", status: 3),
            Aircraft(label: "Aircraft C", status: 4),
            Aircraft(label: "Aircraft D", status: 5)
        ]
        
        Group {
            AirOSWidgetEntryView(entry: SimpleEntry(date: Date(), aircraft: sampleAircraft))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            AirOSWidgetEntryView(entry: SimpleEntry(date: Date(), aircraft: sampleAircraft))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
        .background(Color.black) // Add background to make white text visible in preview
    }
} 