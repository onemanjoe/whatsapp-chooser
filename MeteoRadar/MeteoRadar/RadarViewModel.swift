import Foundation

@MainActor
final class RadarViewModel: ObservableObject {
    @Published private(set) var frames: [RadarFrame] = []
    @Published private(set) var host: String = ""
    @Published private(set) var pastCount: Int = 0
    @Published var currentIndex: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?

    private let service: RadarServicing
    private var timer: Timer?

    /// Seconds each frame is shown while animating.
    private let frameInterval: TimeInterval = 0.6

    init(service: RadarServicing = RainViewerService()) {
        self.service = service
    }

    var currentFrame: RadarFrame? {
        frames.indices.contains(currentIndex) ? frames[currentIndex] : nil
    }

    /// True when the current frame is a forecast (nowcast) rather than an observation.
    var isForecastFrame: Bool {
        currentIndex >= pastCount
    }

    var tileURLTemplate: String? {
        guard let frame = currentFrame, !host.isEmpty else { return nil }
        return RainViewerService.tileURLTemplate(host: host, frame: frame)
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let maps = try await service.fetchWeatherMaps()
            host = maps.host
            pastCount = maps.radar.past.count
            frames = maps.radar.past + maps.radar.nowcast
            // Start on the most recent observation.
            currentIndex = max(0, maps.radar.past.count - 1)
        } catch {
            errorMessage = "Impossible de charger le radar. Vérifiez votre connexion puis réessayez."
        }
        isLoading = false
    }

    // MARK: - Animation

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard frames.count > 1 else { return }
        isPlaying = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    private func advance() {
        guard !frames.isEmpty else { return }
        currentIndex = (currentIndex + 1) % frames.count
    }

    deinit {
        timer?.invalidate()
    }
}
