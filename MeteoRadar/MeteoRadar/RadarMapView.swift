import SwiftUI
import MapKit

/// Wraps an `MKMapView` and overlays the current radar frame as semi-transparent tiles.
struct RadarMapView: UIViewRepresentable {
    /// `MKTileOverlay` URL template (`.../{z}/{x}/{y}/...png`) for the visible frame.
    let tileURLTemplate: String?
    @Binding var region: MKCoordinateRegion

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Keep the camera in sync when the region is changed programmatically
        // (e.g. the "locate me" button), avoiding feedback loops from user pans.
        if !context.coordinator.regionMatches(region, map.region) {
            map.setRegion(region, animated: true)
        }

        guard context.coordinator.currentTemplate != tileURLTemplate else { return }
        context.coordinator.currentTemplate = tileURLTemplate

        map.removeOverlays(map.overlays)
        guard let template = tileURLTemplate else { return }

        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false
        overlay.tileSize = CGSize(width: 256, height: 256)
        map.addOverlay(overlay, level: .aboveLabels)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var currentTemplate: String?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.7
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// Rough equality so tiny floating-point drift doesn't trigger constant resets.
        func regionMatches(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
            abs(a.center.latitude - b.center.latitude) < 0.01
                && abs(a.center.longitude - b.center.longitude) < 0.01
                && abs(a.span.latitudeDelta - b.span.latitudeDelta) < 0.01
        }
    }
}
