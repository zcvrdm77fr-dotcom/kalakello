import SwiftUI
import SwiftData
import PhotosUI

struct AddCatchView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    static let speciesOptions = ["Kuha", "Hauki", "Ahven", "Taimen", "Lahna", "Siika", "Made", "Lohi", "Muikku", "Muu"]

    @State private var species = ""
    @State private var length = ""
    @State private var weight = ""
    @State private var lure = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    photoPreview
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoData == nil ? "Lisää kuva" : "Vaihda kuva", systemImage: "camera.fill")
                    }
                }

                Section("Kala") {
                    Picker("Laji", selection: $species) {
                        ForEach(Self.speciesOptions, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Pituus (cm)", text: $length).keyboardType(.decimalPad)
                    TextField("Paino (kg)", text: $weight).keyboardType(.decimalPad)
                    TextField("Viehe / syötti", text: $lure)
                }

                Section("Milloin ja missä") {
                    DatePicker("Aika", selection: $date, in: ...Date())
                    LabeledContent("Paikka", value: app.place.name)
                    Text("Paikka on Nyt-välilehdellä valittu paikka. Sää haetaan automaattisesti ja tallennetaan saaliin mukaan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Muistiinpanot") {
                    TextField("Esim. vedenpinta, syvyys, mitä tapahtui…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Kirjaa saalis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Peruuta") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("Tallenna") { Task { await save() } }.bold()
                    }
                }
            }
            .onAppear { if species.isEmpty { species = app.species.name } }
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let item = item,
                          let raw = try? await item.loadTransferable(type: Data.self) else { return }
                    photoData = ImageTools.downscaledJPEG(raw)
                }
            }
            .interactiveDismissDisabled(saving)
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let data = photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }

    private func number(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let v = Double(cleaned), v > 0, v.isFinite else { return nil }
        return v
    }

    private func save() async {
        saving = true
        let place = app.place
        let record = CatchRecord(date: date, species: species, lengthCm: number(length), weightKg: number(weight),
                                 lure: lure.trimmingCharacters(in: .whitespacesAndNewlines),
                                 notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                                 placeName: place.name, latitude: place.lat, longitude: place.lon,
                                 photoData: photoData)
        if let point = await app.snapshot(lat: place.lat, lon: place.lon, date: date) {
            let score = record.species4.flatMap { FishingScore.score(point.conditions, species: $0) }
            record.apply(snapshot: point, score: score)
        }
        context.insert(record)
        try? context.save()
        saving = false
        dismiss()
    }
}
