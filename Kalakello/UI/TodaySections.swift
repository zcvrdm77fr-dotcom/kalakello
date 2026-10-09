import SwiftUI
import Charts

// MARK: - Best windows

struct WindowsSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: "Parhaat lähtöajat", systemImage: "clock.fill")
                Spacer()
                Menu {
                    Picker("Vuorokaudenaika", selection: periodBinding) {
                        ForEach(DayPeriod.allCases) { p in Text(p.title).tag(p) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(app.period.title)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .font(.footnote.weight(.semibold))
                }
            }

            Picker("Reissun kesto", selection: hoursBinding) {
                ForEach(1...4, id: \.self) { n in Text("\(n) h").tag(n) }
            }
            .pickerStyle(.segmented)

            let list = app.windows
            if list.isEmpty {
                Text("Ei yhtenäistä ikkunaa. Kokeile eri kestoa tai vuorokaudenaikaa.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, window in
                    WindowRow(rank: index + 1, window: window)
                }
            }
        }
        .glass()
    }

    private var periodBinding: Binding<DayPeriod> {
        Binding(get: { app.period }, set: { app.setPeriod($0) })
    }

    private var hoursBinding: Binding<Int> {
        Binding(get: { app.windowHours }, set: { app.setWindowHours($0) })
    }
}

private struct WindowRow: View {
    @Environment(AppState.self) private var app
    let rank: Int
    let window: RankedWindow

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.range(window.start, window.end, app.timeZone))
                    .font(.headline.monospacedDigit())
                Text("\(Fmt.dayLabel(window.start, app.timeZone, now: app.now)) · \(Fmt.num(window.avgTemp, 0))° · \(Fmt.num(window.avgWind, 1)) m/s")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            ScorePill(score: window.score)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 48 h timeline

struct TimelineSection: View {
    @Environment(AppState.self) private var app
    @State private var selectedDate: Date?

    private struct Bar: Identifiable {
        let date: Date
        let score: Int
        var id: Date { date }
    }

    private struct SunMark: Identifiable {
        let id = UUID()
        let date: Date
        let symbol: String
    }

    var body: some View {
        let hours = app.chartHours
        let bars: [Bar] = hours.compactMap { h in h.score.map { Bar(date: h.point.timestamp, score: $0) } }

        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "48 tunnin kalakello", systemImage: "chart.bar.fill")

            readout(hours)

            if let first = hours.first, let last = hours.last {
                let start = first.point.timestamp
                let end = last.point.timestamp.addingTimeInterval(3600)
                let marks = sunMarks(start, end)
                let selected = selectedHour(hours)

                Chart {
                    ForEach(app.windows) { w in
                        RectangleMark(xStart: .value("Alku", w.start), xEnd: .value("Loppu", w.end),
                                      yStart: .value("Min", 0), yEnd: .value("Max", 100))
                            .foregroundStyle(Color.white.opacity(0.12))
                    }
                    ForEach(bars) { b in
                        BarMark(x: .value("Aika", b.date, unit: .hour), y: .value("Pisteet", b.score))
                            .foregroundStyle(Theme.color(forScore: b.score))
                            .cornerRadius(2)
                    }
                    ForEach(marks) { m in
                        RuleMark(x: .value("Aurinko", m.date))
                            .foregroundStyle(Theme.amber.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .annotation(position: .top, spacing: 2) {
                                Image(systemName: m.symbol).font(.caption2).foregroundStyle(Theme.amber)
                            }
                    }
                    RuleMark(x: .value("Nyt", app.now))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    if let s = selected {
                        RuleMark(x: .value("Valittu", s.point.timestamp.addingTimeInterval(1800)))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartXSelection(value: $selectedDate)
                .chartXScale(domain: start...end)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.15))
                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel {
                            if let d = value.as(Date.self) {
                                Text(Fmt.hm(d, app.timeZone)).font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 190)
            }

            Text("Vaalea alue = parhaat ikkunat · katkoviiva = nyt · aurinko = nousu/lasku")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .glass()
    }

    @ViewBuilder
    private func readout(_ hours: [ScoredHour]) -> some View {
        if let h = selectedHour(hours) {
            HStack(spacing: 10) {
                Text("\(Fmt.dayLabel(h.point.timestamp, app.timeZone, now: app.now)) \(Fmt.hm(h.point.timestamp, app.timeZone))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                ScorePill(score: h.score)
                Text("\(Fmt.num(h.point.temp, 0))° · \(Fmt.num(h.point.wind, 1)) m/s · \(Fmt.num(h.point.cloud, 0)) %")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else {
            Text("Vedä sormella käyrää nähdäksesi tuntikohtaiset tiedot.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func selectedHour(_ hours: [ScoredHour]) -> ScoredHour? {
        guard let d = selectedDate else { return nil }
        return hours.last { $0.point.timestamp <= d }
    }

    private func sunMarks(_ start: Date, _ end: Date) -> [SunMark] {
        guard let f = app.forecast else { return [] }
        var marks: [SunMark] = []
        for day in f.sun {
            if let r = day.sunrise, r >= start, r < end { marks.append(SunMark(date: r, symbol: "sunrise.fill")) }
            if let s = day.sunset, s >= start, s < end { marks.append(SunMark(date: s, symbol: "sunset.fill")) }
        }
        return marks
    }
}

// MARK: - Advice ("Kalastusnyt")

struct AdviceSection: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let c = app.currentHour {
            let advice = app.species.advice(for: c.conditions)
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Kalastusnyt · \(app.species.name)", systemImage: "fish.fill")
                row("Viehe", advice.lure, "circle.hexagongrid.fill")
                row("Syvyys", advice.depth, "arrow.down.to.line")
                row("Väri", advice.color, "paintpalette.fill")
                row("Tekniikka", advice.technique, "figure.fishing")
                Text("Nykyisten olosuhteiden mukaan.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .glass()
        }
    }

    private func row(_ title: String, _ text: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                Text(text).font(.subheadline)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Personal match (the "different" part)

struct MatchSection: View {
    @Environment(AppState.self) private var app
    let catches: [CatchRecord]
    let onAdd: () -> Void

    var body: some View {
        let all = catches.compactMap { $0.sample }
        let mine = catches.filter { $0.species4 == app.species }.compactMap { $0.sample }
        let samples = mine.count >= PersonalInsights.minForSimilarity ? mine : all
        let insights = PersonalInsights.make(from: samples)
        let match: Double? = {
            guard let i = insights, let c = app.currentHour else { return nil }
            return i.similarity(to: c.conditions)
        }()

        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Sinun kalakelisi", systemImage: "person.fill.checkmark")

            if let i = insights, let m = match {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(Int((m * 100).rounded())) %")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Text("nykyisistä olosuhteista vastaa sinun omien saaliittesi olosuhteita.")
                        .font(.subheadline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Tuuli osui yleensä välille \(Fmt.num(i.windLow, 1))–\(Fmt.num(i.windHigh, 1)) m/s")
                    if !i.partOfDay.isEmpty {
                        Text("• Eniten saaliita \(i.partOfDay) (\(Int((i.partOfDayShare * 100).rounded())) %)")
                    }
                    if let f = i.fallingShare {
                        Text("• Ilmanpaine laski \(Int((f * 100).rounded())) % saaliista")
                    }
                    if let s = i.avgScore {
                        Text("• Kalakelipiste oli saaliin hetkellä keskimäärin \(s)")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                if i.count < 15 {
                    Text("Pieni otos (\(i.count) saalista) — suuntaa-antava.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Text("Kirjaa saaliit Saaliskirjaan, niin sovellus tallentaa säätilan jokaisesta ja oppii missä olosuhteissa SINÄ saat kalaa. \(max(0, PersonalInsights.minForSimilarity - all.count)) saalista vielä tarvitaan.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                Button("Kirjaa saalis", action: onAdd)
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
            }
        }
        .glass()
    }
}

// MARK: - Footnote

struct Footnote: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(spacing: 6) {
            if app.isStale {
                Label("Näytetään tallennettu ennuste — verkkoyhteys ei vastannut.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.amber)
            }
            Text("Kalakelipiste on heuristinen vertailuarvo, ei saalistodennäköisyys eikä saalistakuu.")
            if let f = app.forecast {
                Text("Sää: Open-Meteo · päivitetty \(Fmt.hm(f.fetchedAt, .current))")
            }
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.5))
        .multilineTextAlignment(.center)
        .padding(.top, 4)
    }
}
