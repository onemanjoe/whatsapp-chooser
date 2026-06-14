import CoreLocation

/// Thin wrapper around `CLLocationManager` that publishes the latest coordinate.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Use continuous updates rather than a one-shot request: in the
            // Simulator a location often isn't available the instant the button
            // is tapped, and `requestLocation()` would simply fail. With
            // `startUpdatingLocation` we get the fix as soon as one appears.
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // One fix is enough to center the map; stop to save battery.
        manager.stopUpdatingLocation()
        Task { @MainActor in self.coordinate = location.coordinate }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignore; the map simply stays at its current region.
    }
}
