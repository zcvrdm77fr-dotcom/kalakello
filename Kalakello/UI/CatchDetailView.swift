import SwiftUI
import SwiftData

struct CatchDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let record: CatchRecord
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let data = record.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(record.species.isEmpty ? "Saalis" : record.species).font(.largeTitle.weight(.bold))
                    Spacer()
                    if let s = record.snapScore { ScorePill(score: s) }
                }

                Text("\(Fmt.dateTime(record.date)) · \(record.placeName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if let l = record.lengthCm { chip("\(Fmt.num(l, 0)) cm", "ruler") }
                    if let w = record.weightKg { chip("\(Fmt.num(w, 2)) kg", "scalemass") }
                    if !record.lure.isEmpty { chip(record.lure, "circle.hexagongrid.fill") }
                }

                if let t = record.snapTemp, let w = record.snapWind, let c = record.snapCloud {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(text: "Sää saaliin hetkellä", systemImage: "cloud.sun.fill")
                        Text("\(Fmt.num(t, 0))° · \(Fmt.num(w, 1)) m/s · pilvisyys \(Fmt.num(c, 0)) %")
                        if let p = record.snapPressure {
                            let trend = record.snapPressureDelta.map { " (\(Fmt.signed($0)) hPa / 6 h)" } ?? ""
                            Text("Ilmanpaine \(Fmt.num(p, 0)) hPa\(trend)")
                        }
                    }
                    .font(.subheadline)
                    .glass()
                } else {
                    Text("Säätietoa ei saatu tälle saaliille (esim. ei verkkoyhteyttä tallennushetkellä tai yli 90 päivää vanha).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !record.notes.isEmpty {
                    Text(record.notes).font(.body).glass()
                }

                ShareLink(item: shareText) {
                    Label("Jaa saalis", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Poista saalis", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Poistetaanko saalis?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Poista", role: .destructive) {
                context.delete(record)
                try? context.save()
                dismiss()
            }
        }
    }

    private var shareText: String {
        var parts = [record.species.isEmpty ? "Saalis" : record.species]
        if let l = record.lengthCm { parts.append("\(Fmt.num(l, 0)) cm") }
        if let w = record.weightKg { parts.append("\(Fmt.num(w, 2)) kg") }
        if !record.lure.isEmpty { parts.append(record.lure) }
        return parts.joined(separator: " · ") + " — \(record.placeName), \(Fmt.dateTime(record.date)) 🎣 Kalakello"
    }

    private func chip(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
    }
}
