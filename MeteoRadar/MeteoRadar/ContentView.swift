import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = RadarViewModel()
    @StateObject private var locationManager = LocationManager()

    // Default view: Western Europe, centered on France.
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.2),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            RadarMapView(tileURLTemplate: viewModel.tileURLTemplate, region: $region)
                .ignoresSafeArea()

            controls

            if viewModel.isLoading && viewModel.frames.isEmpty {
                ProgressView("Chargement du radar…")
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .overlay(alignment: .topTrailing) { locateButton }
        .task { await viewModel.load() }
        .onChange(of: locationManager.coordinate?.latitude) { _ in
            if let coordinate = locationManager.coordinate {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
                )
            }
        }
        .alert("Erreur", isPresented: errorBinding) {
            Button("Réessayer") { Task { await viewModel.load() } }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var locateButton: some View {
        Button {
            locationManager.requestLocation()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .tint(.primary)
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timestampText)
                        .font(.title3.monospacedDigit().weight(.semibold))
                    Text(viewModel.isForecastFrame ? "Prévision" : "Observation")
                        .font(.caption)
                        .foregroundStyle(viewModel.isForecastFrame ? .orange : .green)
                }
                Spacer()
                Button {
                    viewModel.togglePlay()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 48, height: 48)
                        .background(.tint, in: Circle())
                        .foregroundStyle(.white)
                }
                .disabled(viewModel.frames.count < 2)
            }

            if viewModel.frames.count > 1 {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentIndex) },
                        set: {
                            viewModel.pause()
                            viewModel.currentIndex = Int($0.rounded())
                        }
                    ),
                    in: 0...Double(viewModel.frames.count - 1),
                    step: 1
                )
            }

            Text("Données radar © RainViewer · OpenStreetMap")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private var timestampText: String {
        guard let date = viewModel.currentFrame?.date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date).capitalized
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    ContentView()
}
