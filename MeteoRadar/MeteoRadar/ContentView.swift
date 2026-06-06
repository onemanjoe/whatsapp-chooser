import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var viewModel = RadarViewModel()
    @StateObject private var locationManager = LocationManager()

    // Wide fallback view used until the user's location is available
    // (or if location access is denied).
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 30, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 90)
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            RadarMapView(tileURLTemplate: viewModel.tileURLTemplate, region: $region)
                .ignoresSafeArea()

            controls

            if viewModel.isLoading && viewModel.frames.isEmpty {
                ProgressView("Loading radar…")
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .overlay(alignment: .topTrailing) { locateButton }
        .overlay(alignment: .topLeading) { IntensityLegend() }
        .task {
            // Center on the user as soon as the app launches.
            locationManager.requestLocation()
            await viewModel.load()
        }
        .onChange(of: locationManager.coordinate?.latitude) { _ in
            if let coordinate = locationManager.coordinate {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
                )
            }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("Retry") { Task { await viewModel.load() } }
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
                    Text(viewModel.isForecastFrame ? "Forecast" : "Observed")
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

            Text("Radar data © RainViewer · OpenStreetMap")
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
        return formatter.string(from: date)
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
