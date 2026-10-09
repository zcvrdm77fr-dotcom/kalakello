import SwiftUI
import SwiftData

struct CatchLogView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \CatchRecord.date, order: .reverse) private var catches: [CatchRecord]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if catches.isEmpty {
                    ContentUnavailableView {
                        Label("Ei vielä saaliita", systemImage: "fish.fill")
                    } description: {
                        Text("Kirjaa saalis kuvan kanssa. Sovellus tallentaa säätilan ja oppii missä olosuhteissa sinä saat kalaa.")
                    } actions: {
                        Button("Kirjaa ensimmäinen saalis") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Saaliskirja")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                        .accessibilityLabel("Kirjaa saalis")
                }
            }
            .sheet(isPresented: $showAdd) { AddCatchView() }
        }
    }

    private var list: some View {
        List {
            Section { StatsHeader(catches: catches) }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

            if let insights = PersonalInsights.make(from: catches.compactMap { $0.sample }) {
                Section("Sinun kalakelisi") {
                    InsightsSummary(insights: insights)
                }
            }

            Section("Saaliit") {
                ForEach(catches) { c in
                    NavigationLink {
                        CatchDetailView(record: c)
                    } label: {
                        CatchRow(record: c)
                    }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(catches[i]) }
                    try? context.save()
                }
            }
        }
    }
}

private struct StatsHeader: View {
    let catches: [CatchRecord]

    var body: some View {
        let species = Set(catches.map { $0.species.lowercased() }.filter { !$0.isEmpty }).count
        let heaviest = catches.compactMap { $0.weightKg }.max()
        let longest = catches.compactMap { $0.lengthCm }.max()

        HStack(spacing: 10) {
            stat("\(catches.count)", "saalista")
            stat("\(species)", "lajia")
            stat(heaviest.map { Fmt.num($0, 1) } ?? "–", "kg ennätys")
            stat(longest.map { Fmt.num($0, 0) } ?? "–", "cm pisin")
        }
        .padding(.vertical, 4)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Theme.accent)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct InsightsSummary: View {
    let insights: PersonalInsights

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tuuli osui yleensä välille \(Fmt.num(insights.windLow, 1))–\(Fmt.num(insights.windHigh, 1)) m/s")
            Text("Keskilämpötila saaliin hetkellä \(Fmt.num(insights.tempMean, 0))°")
            if !insights.partOfDay.isEmpty {
                Text("Eniten saaliita \(insights.partOfDay) (\(Int((insights.partOfDayShare * 100).rounded())) %)")
            }
            if let f = insights.fallingShare {
                Text("Ilmanpaine laski \(Int((f * 100).rounded())) % saaliista")
            }
            if let s = insights.avgScore {
                Text("Kalakelipiste oli keskimäärin \(s)")
            }
            if insights.count < 15 {
                Text("Pieni otos (\(insights.count)) — suuntaa-antava.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}

struct CatchRow: View {
    let record: CatchRecord

    var body: some View {
        HStack(spacing: 12) {
            Thumb(data: record.photoData)
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.species.isEmpty ? "Saalis" : record.species).font(.headline)
                Text(details).font(.subheadline).foregroundStyle(.secondary)
                Text("\(Fmt.dateTime(record.date)) · \(record.placeName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let s = record.snapScore { ScorePill(score: s) }
        }
    }

    private var details: String {
        var parts: [String] = []
        if let l = record.lengthCm { parts.append("\(Fmt.num(l, 0)) cm") }
        if let w = record.weightKg { parts.append("\(Fmt.num(w, 2)) kg") }
        if !record.lure.isEmpty { parts.append(record.lure) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

struct Thumb: View {
    let data: Data?

    var body: some View {
        if let data = data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(Image(systemName: "fish.fill").foregroundStyle(Theme.accent))
        }
    }
}
