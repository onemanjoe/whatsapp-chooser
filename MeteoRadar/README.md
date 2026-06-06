# Météo Radar (iOS)

A lightweight SwiftUI iOS app that shows an animated precipitation radar over a
map, powered by the free [RainViewer](https://www.rainviewer.com/api.html)
public API (no API key required).

## Features

- **Live precipitation radar** overlaid on an Apple Maps base map.
- **Animated timeline** combining past observations and short-term nowcast
  forecast frames.
- **Play / pause** the animation, or scrub through frames with a slider.
- **Centers on your location** at launch (with a "locate me" button to re-center);
  falls back to a world view if location access is denied.
- **Precipitation-intensity legend** (light → heavy).
- Clear label distinguishing *Observed* (past) from *Forecast* (nowcast).

## Requirements

- Xcode 15 or later
- iOS 16.0+ deployment target

## Running

1. Open `MeteoRadar.xcodeproj` in Xcode.
2. Select the **MeteoRadar** scheme and an iOS Simulator (or a device).
3. Press **Run** (⌘R).

The app fetches `https://api.rainviewer.com/public/weather-maps.json` on launch
to discover the available radar frames, then loads the corresponding tiles as a
semi-transparent `MKTileOverlay`.

## Architecture

| File | Responsibility |
| --- | --- |
| `MeteoRadarApp.swift` | App entry point. |
| `ContentView.swift` | Main screen: map + playback controls. |
| `IntensityLegend.swift` | Precipitation-intensity color legend. |
| `RadarMapView.swift` | `UIViewRepresentable` wrapping `MKMapView` with the radar tile overlay. |
| `RadarViewModel.swift` | Loads frames, owns playback state, builds tile URL templates. |
| `RainViewerService.swift` | Networking against the RainViewer API. |
| `LocationManager.swift` | `CLLocationManager` wrapper publishing the user's coordinate. |
| `Models.swift` | `Codable` models for the RainViewer response. |

## Attribution

Radar data © [RainViewer](https://www.rainviewer.com/). Map data ©
OpenStreetMap contributors / Apple Maps.
