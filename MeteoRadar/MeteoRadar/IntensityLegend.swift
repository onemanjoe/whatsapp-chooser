import SwiftUI

/// Compact precipitation-intensity legend matching RainViewer's
/// "Universal Blue" color scheme (light → heavy).
struct IntensityLegend: View {
    // Approximate stops of the Universal Blue palette, light to heavy.
    private let stops: [Color] = [
        Color(red: 0.78, green: 0.92, blue: 0.97), // very light
        Color(red: 0.36, green: 0.71, blue: 0.91), // light
        Color(red: 0.13, green: 0.45, blue: 0.85), // moderate
        Color(red: 0.30, green: 0.20, blue: 0.78), // heavy
        Color(red: 0.62, green: 0.16, blue: 0.66)  // very heavy
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Precipitation")
                .font(.caption2.weight(.semibold))
            LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
                .frame(width: 120, height: 8)
                .clipShape(Capsule())
            HStack {
                Text("Light")
                Spacer()
                Text("Heavy")
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .frame(width: 120)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
        .padding(.leading, 16)
    }
}

#Preview {
    IntensityLegend()
        .padding()
        .background(.gray)
}
