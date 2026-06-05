import Foundation

/// Top-level response of the RainViewer "weather-maps" endpoint.
/// See: https://www.rainviewer.com/api/weather-maps-api.html
struct WeatherMaps: Decodable {
    let version: String
    let generated: Int
    let host: String
    let radar: RadarData
}

struct RadarData: Decodable {
    /// Observed (past) radar frames, oldest first.
    let past: [RadarFrame]
    /// Forecast (nowcast) frames, soonest first.
    let nowcast: [RadarFrame]
}

/// A single radar frame. `path` is appended to `WeatherMaps.host` to build tile URLs.
struct RadarFrame: Decodable, Identifiable, Equatable {
    let time: Int
    let path: String

    var id: Int { time }
    var date: Date { Date(timeIntervalSince1970: TimeInterval(time)) }
}
