import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let accent = Color(hex: 0x74CEB9)
    static let amber = Color(hex: 0xE89A3C)

    static func color(for band: ScoreBand) -> Color {
        switch band {
        case .exceptional: return Color(hex: 0x7FD66B)
        case .veryGood: return Color(hex: 0x58C77C)
        case .good: return Color(hex: 0x3DB5B0)
        case .fair: return Color(hex: 0xF0A04B)
        case .poor: return Color(hex: 0xE2705D)
        }
    }

    static func color(forScore score: Int?) -> Color {
        guard let s = score else { return .gray }
        return color(for: FishingScore.band(s))
    }

    /// The whole Today screen is tinted by the actual light outside.
    static func background(for phase: LightPhase?) -> [Color] {
        switch phase {
        case .day?: return [Color(hex: 0x1F6A72), Color(hex: 0x0D3038), Color(hex: 0x081C22)]
        case .twilight?: return [Color(hex: 0x9A5B45), Color(hex: 0x2C3F55), Color(hex: 0x0A1A26)]
        case .night?: return [Color(hex: 0x0E2438), Color(hex: 0x081521), Color(hex: 0x040A10)]
        case nil: return [Color(hex: 0x1B5560), Color(hex: 0x0C2D35), Color(hex: 0x071A20)]
        }
    }
}

struct Backdrop: View {
    let phase: LightPhase?

    var body: some View {
        LinearGradient(colors: Theme.background(for: phase), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.0), value: phase)
    }
}

extension View {
    /// Frosted card used across the app.
    func glass(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            )
    }
}

struct ScorePill: View {
    let score: Int?

    var body: some View {
        Text(score.map { String($0) } ?? "–")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(Color.black.opacity(0.85))
            .frame(minWidth: 38)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(Theme.color(forScore: score), in: Capsule())
    }
}

struct SectionTitle: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage = systemImage {
                Image(systemName: systemImage).foregroundStyle(Theme.accent)
            }
            Text(text).font(.headline)
        }
    }
}
