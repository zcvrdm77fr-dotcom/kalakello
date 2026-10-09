import SwiftUI

struct ScoreDial: View {
    let score: Int?

    var body: some View {
        let value = Double(score ?? 0)
        let band = FishingScore.band(score ?? 0)
        let tint = Theme.color(for: band)

        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75 * value / 100)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(135))
                .shadow(color: tint.opacity(0.55), radius: 14)

            VStack(spacing: 2) {
                Text(score.map { String($0) } ?? "–")
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(score == nil ? "ei dataa" : band.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .animation(.smooth(duration: 0.8), value: score)
    }
}
