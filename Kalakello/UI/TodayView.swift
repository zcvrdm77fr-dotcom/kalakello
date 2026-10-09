import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(AppState.self) private var app
    @Query private var catches: [CatchRecord]
    @State private var showPlaces = false
    @State private var showAddCatch = false

    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Backdrop(phase: app.currentHour?.light)
                ScrollView {
                    VStack(spacing: 18) {
                        SpeciesPicker()
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .refreshable { await app.load(force: true) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showPlaces = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                            Text(app.place.name).lineLimit(1)
                            Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddCatch = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .accessibilityLabel("Kirjaa saalis")
                }
            }
            .sheet(isPresented: $showPlaces) { PlacePickerView() }
            .sheet(isPresented: $showAddCatch) { AddCatchView() }
            .onReceive(minuteTimer) { _ in app.tick() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if app.forecast != nil {
            HeroSection()
            ConditionsGrid()
            WindowsSection()
            TimelineSection()
            AdviceSection()
            MatchSection(catches: catches, onAdd: { showAddCatch = true })
            Footnote()
        } else if case .failed(let message) = app.status {
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                Text(message).multilineTextAlignment(.center)
                Button("Yritä uudelleen") { Task { await app.load(force: true) } }
                    .buttonStyle(.borderedProminent)
            }
            .glass()
        } else {
            VStack(spacing: 14) {
                ProgressView()
                Text("Haetaan kalakeliä…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
        }
    }
}

// MARK: - Species

struct SpeciesPicker: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Species.allCases) { s in
                let selected = app.species == s
                Button {
                    withAnimation(.snappy) { app.setSpecies(s) }
                } label: {
                    Text(s.name)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected ? Theme.accent : Color.white.opacity(0.10), in: Capsule())
                        .foregroundStyle(selected ? Color.black.opacity(0.85) : Color.white)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: app.species)
    }
}

// MARK: - Hero

struct HeroSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 16) {
            ScoreDial(score: app.currentScore)
                .frame(width: 236, height: 236)
                .padding(.top, 4)

            if let c = app.currentHour {
                Text("\(app.species.name) · klo \(Fmt.hm(c.timestamp, app.timeZone))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            bestWindow
        }
    }

    @ViewBuilder
    private var bestWindow: some View {
        if let w = app.windows.first {
            VStack(spacing: 6) {
                Text("PARAS IKKUNA")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(Fmt.dayLabel(w.start, app.timeZone, now: app.now)) \(Fmt.range(w.start, w.end, app.timeZone))")
                    .font(.title3.weight(.semibold))
                HStack(spacing: 8) {
                    ScorePill(score: w.score)
                    Text(FishingScore.band(w.score).title)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .glass()
            .multilineTextAlignment(.center)
        } else {
            Text("Ei yhtenäistä ikkunaa valituilla rajauksilla.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Conditions

struct ConditionsGrid: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let c = app.currentHour {
            let moon = Moon.phase(at: app.now)
            let delta = c.pressureDelta
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                Tile(icon: "thermometer.medium", value: "\(Fmt.num(c.temp, 0))°", label: "Lämpötila")
                Tile(icon: "wind", value: "\(Fmt.num(c.wind, 1)) m/s", label: "Tuuli")
                Tile(icon: "cloud.fill", value: "\(Fmt.num(c.cloud, 0)) %", label: "Pilvisyys")
                Tile(icon: "gauge.medium", value: "\(Fmt.num(c.pressure, 0)) hPa", label: "Ilmanpaine")
                Tile(icon: trendIcon(delta), value: delta.map { "\(Fmt.signed($0)) hPa" } ?? "–", label: trendLabel(delta))
                Tile(icon: moon.symbol, value: "\(Fmt.num(moon.illumination * 100, 0)) %", label: moon.name)
            }
        }
    }

    private func trendIcon(_ delta: Double?) -> String {
        guard let d = delta else { return "arrow.right" }
        if d <= -0.5 { return "arrow.down.right" }
        if d >= 0.5 { return "arrow.up.right" }
        return "arrow.right"
    }

    private func trendLabel(_ delta: Double?) -> String {
        guard let d = delta else { return "Paineen trendi" }
        if d <= -0.5 { return "Laskeva (6 h)" }
        if d >= 0.5 { return "Nouseva (6 h)" }
        return "Tasainen (6 h)"
    }

    private struct Tile: View {
        let icon: String
        let value: String
        let label: String

        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(height: 24)
                Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
