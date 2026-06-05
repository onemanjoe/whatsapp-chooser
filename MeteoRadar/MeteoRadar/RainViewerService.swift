import Foundation

/// Abstraction over the radar data source so the view model can be tested with a stub.
protocol RadarServicing {
    func fetchWeatherMaps() async throws -> WeatherMaps
}

/// Fetches precipitation radar metadata from the free RainViewer public API.
struct RainViewerService: RadarServicing {
    static let weatherMapsURL = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeatherMaps() async throws -> WeatherMaps {
        let (data, response) = try await session.data(from: Self.weatherMapsURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(WeatherMaps.self, from: data)
    }

    /// Builds an `MKTileOverlay`-compatible URL template for a given frame.
    /// Placeholders `{z}/{x}/{y}` are filled by MapKit per visible tile.
    ///
    /// Format: `{host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.png`
    /// - color 4 = "Universal Blue", smooth 1 = smoothed, snow 1 = show snow.
    static func tileURLTemplate(host: String, frame: RadarFrame, tileSize: Int = 256) -> String {
        "\(host)\(frame.path)/\(tileSize)/{z}/{x}/{y}/4/1_1.png"
    }
}
