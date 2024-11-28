//
//  ContentView1.swift
//  Tide Times
//
//  Created by Tatiana Kornilova on 18.11.2024.
// From https://www.youtube.com/watch?v=oe3Jn6FRoII
// I Made an iOS App in MINUTES with This AI Tool!
//
/*
import SwiftUI
import CoreLocation
import Charts

struct TideData: Codable {
    let height: Double
    let time: Date
    let type: TideType
}

enum TideType: String, Codable {
    case high = "HIGH"
    case low = "LOW"
}

class TideViewModel: ObservableObject {
    @Published var selectedLocation: CLLocation?
    @Published var locationName: String = ""
    @Published var tideData: [TideData] = []
    @Published var suggestedLocations: [String] = []
    
    private let locationManager = CLLocationManager()
    private let apiKey = "97505ca5-7a08-4d70-8cb6-9cd003cb08b0" // Get free API key from https://www.worldtides.info/developer
    private let calendar = Calendar.current
    
    init() {
        loadSavedLocation()
    }
    
    private func loadSavedLocation() {
        let savedLatitude = UserDefaults.standard.double(forKey: "savedLatitude")
           let savedLongitude = UserDefaults.standard.double(forKey: "savedLongitude")
           let savedLocationName = UserDefaults.standard.string(forKey: "savedLocationName")
            selectedLocation = CLLocation(latitude: savedLatitude, longitude: savedLongitude)
        locationName = savedLocationName ?? "San Francisco"
            fetchTideData()
    }
    
    func fetchTideData() {
        guard let location = selectedLocation else { return }
        
        // Get time window: 24 hours before and after current time
        let now = Date()
        let start = Int(now.addingTimeInterval(-24 * 3600).timeIntervalSince1970)
        let end = Int(now.addingTimeInterval(24 * 3600).timeIntervalSince1970)
        
        let urlString = "https://www.worldtides.info/api/v3?extremes&heights&datum=LAT" +
            "&lat=\(location.coordinate.latitude)" +
            "&lon=\(location.coordinate.longitude)" +
            "&start=\(start)" +
            "&end=\(end)" +
            "&key=\(apiKey)"
        print (urlString)
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Error fetching tide data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(TideResponse.self, from: data)
                
                DispatchQueue.main.async {
                    // Convert extremes to TideData
                    self?.tideData = response.extremes.map { extreme in
                        TideData(
                            height: extreme.height,
                            time: Date(timeIntervalSince1970: TimeInterval(extreme.dt)),
                            type: extreme.type == "High" ? .high : .low
                        )
                    }.sorted { $0.time < $1.time }
                }
            } catch {
                print("Error decoding tide data: \(error)")
            }
        }.resume()
    }
    
    func searchLocations(query: String) {
        guard !query.isEmpty else {
            suggestedLocations = []
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { [weak self] places, error in
            DispatchQueue.main.async {
                self?.suggestedLocations = places?.compactMap { $0.name } ?? []
            }
        }
    }
    
    func selectLocation(_ name: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(name) { [weak self] places, error in
            guard let place = places?.first else { return }
            
            DispatchQueue.main.async {
                self?.selectedLocation = place.location
                self?.locationName = name
                
                // Save to UserDefaults
                UserDefaults.standard.set(place.location?.coordinate.latitude, forKey: "savedLatitude")
                UserDefaults.standard.set(place.location?.coordinate.longitude, forKey: "savedLongitude")
                UserDefaults.standard.set(name, forKey: "savedLocationName")
                
                self?.fetchTideData()
            }
        }
    }
}

// Add these structures for JSON decoding
struct TideResponse: Codable {
    let status: Int
    let extremes: [Extreme]
    let error: String?
}

struct Extreme: Codable {
    let dt: Int
    let date: String
    let height: Double
    let type: String
}

struct ContentView: View {
    @StateObject private var viewModel = TideViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Location Search
                searchBar
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Current Location Card
                        if !viewModel.locationName.isEmpty {
                            locationCard
                        }
                        
                        // Tide Graph Card
                        tideGraphCard
                        
                        // Tide List Card
                        tideListCard
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Tide Times")
        }
    }
    
    private var searchBar: some View {
        VStack(spacing: 0) {
            TextField("Search location...", text: $searchText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .onChange(of: searchText) { _, newValue in
                    viewModel.searchLocations(query: newValue)
                }
            
            if !viewModel.suggestedLocations.isEmpty {
                List(viewModel.suggestedLocations, id: \.self) { location in
                    Button(action: {
                        viewModel.selectLocation(location)
                        searchText = ""
                    }) {
                        Text(location)
                            .padding(.vertical, 8)
                    }
                }
                .listStyle(.plain)
                .frame(maxHeight: 200)
            }
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.locationName)
                .font(.system(size: 28, weight: .bold))
            
            if let currentTide = viewModel.tideData.first {
                Text("Current tide: \(String(format: "%.1f ft", currentTide.height))")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var tideGraphCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tide Graph")
                .font(.headline)
                .foregroundColor(.secondary)
            
            TideGraphView(tideData: viewModel.tideData)
                .frame(height: 200)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var tideListCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Tides")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ForEach(viewModel.tideData, id: \.time) { tide in
                HStack(spacing: 16) {
                    Image(systemName: tide.type == .high ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(tide.type == .high ? .blue : .green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tide.type == .high ? "High Tide" : "Low Tide")
                            .font(.system(.body, design: .rounded))
                        Text(formatDate(tide.time))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.1f ft", tide.height))
                        .font(.system(.title3, design: .rounded, weight: .medium))
                }
                .padding(.vertical, 8)
                
                if tide.time != viewModel.tideData.last?.time {
                    Divider()
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct TideGraphView: View {
    let tideData: [TideData]
    
    private var minHeight: Double {
        (tideData.map(\.height).min() ?? 0) - 0.5
    }
    
    private var maxHeight: Double {
        (tideData.map(\.height).max() ?? 1) + 0.5
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Chart {
                // Draw the tide curve
                ForEach(Array(zip(tideData.indices, tideData)), id: \.0) { index, tide in
                    if index < tideData.count - 1 {
                        LineMark(
                            x: .value("Time", tide.time),
                            y: .value("Height", tide.height)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Gradient(colors: [.blue.opacity(0.8), .blue.opacity(0.4)]))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                }
                
                // Draw tide points with labels
                ForEach(tideData, id: \.time) { tide in
                    PointMark(
                        x: .value("Time", tide.time),
                        y: .value("Height", tide.height)
                    )
                    .foregroundStyle(tide.type == .high ? Color.blue : Color.green)
                    .symbolSize(100)
                    .annotation(position: tide.type == .high ? .top : .bottom, spacing: 0) {
                        VStack(spacing: 4) {
                            Text(formatTime(tide.time))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f ft", tide.height))
                                .font(.caption)
                                .bold()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.background)
                                .shadow(radius: 2)
                        )
                    }
                }
                
                // Draw current time indicator
                RuleMark(
                    x: .value("Current", Date())
                )
                .foregroundStyle(.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel("\(String(describing: (value.as(Double.self) ?? 0.0).formatted(.number.precision(.fractionLength(1)))))ft")
                }
            }
            .chartYScale(domain: minHeight...maxHeight)
         //   .frame(height: 260)
            
            // Legend
            HStack(spacing: 16) {
                legendItem(color: .blue, label: "High Tide")
                legendItem(color: .green, label: "Low Tide")
                legendItem(color: .red, label: "Current Time")
            }
            .font(.caption)
            .padding(.top,8)
        }
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
        ContentView()
}
*/
