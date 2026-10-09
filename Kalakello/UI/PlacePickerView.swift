import SwiftUI
import SwiftData
import MapKit

private struct SearchHit: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let lat: Double
    let lon: Double
}

struct PlacePickerView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedPlace.createdAt, order: .reverse) private var saved: [SavedPlace]

    @State private var query = ""
    @State private var hits: [SearchHit] = []
    @State private var locating = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    nowSection
                    savedSection
                } else {
                    resultsSection
                }
            }
            .navigationTitle("Paikka")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Hae paikkaa tai kalapaikkaa")
            .task(id: query) { await runSearch() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Valmis") { dismiss() } }
            }
        }
    }

    // MARK: Sections

    private var nowSection: some View {
        Section {
            Button {
                Task {
                    locating = true
                    message = await app.useCurrentLocation()
                    locating = false
                    if message == nil { dismiss() }
                }
            } label: {
                HStack {
                    Label("Käytä sijaintiani", systemImage: "location.fill")
                    Spacer()
                    if locating { ProgressView() }
                }
            }
            if let message = message {
                Text(message).font(.footnote).foregroundStyle(Theme.amber)
            }
            Button {
                saveCurrent()
            } label: {
                Label("Tallenna \"\(app.place.name)\" suosikiksi", systemImage: "star")
            }
            .disabled(isAlreadySaved)
        }
    }

    private var savedSection: some View {
        Section("Tallennetut paikat") {
            if saved.isEmpty {
                Text("Ei vielä tallennettuja paikkoja.").foregroundStyle(.secondary)
            }
            ForEach(saved) { p in
                Button {
                    app.setPlace(Place(name: p.name, lat: p.latitude, lon: p.longitude))
                    dismiss()
                } label: {
                    Label(p.name, systemImage: "star.fill").foregroundStyle(.primary)
                }
                .swipeActions {
                    Button(role: .destructive) { context.delete(p) } label: { Label("Poista", systemImage: "trash") }
                }
            }
        }
    }

    private var resultsSection: some View {
        Section("Tulokset") {
            if hits.isEmpty {
                Text("Ei tuloksia.").foregroundStyle(.secondary)
            }
            ForEach(hits) { hit in
                Button {
                    app.setPlace(Place(name: hit.name, lat: (hit.lat * 10_000).rounded() / 10_000,
                                       lon: (hit.lon * 10_000).rounded() / 10_000))
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hit.name).foregroundStyle(.primary)
                        if !hit.subtitle.isEmpty {
                            Text(hit.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Logic

    private var isAlreadySaved: Bool {
        saved.contains { abs($0.latitude - app.place.lat) < 0.0005 && abs($0.longitude - app.place.lon) < 0.0005 }
    }

    private func saveCurrent() {
        guard !isAlreadySaved else { return }
        context.insert(SavedPlace(name: app.place.name, latitude: app.place.lat, longitude: app.place.lon))
        try? context.save()
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { hits = []; return }
        try? await Task.sleep(for: .milliseconds(300))
        if Task.isCancelled { return }

        // 1) Bundled fishing spots by name  2) MapKit places
        var results: [SearchHit] = SpotStore.search(q, limit: 5).map { spot in
            SearchHit(name: spot.displayName, subtitle: "\(spot.kind.title) · kalapaikka", lat: spot.la, lon: spot.lo)
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = q
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 64.5, longitude: 26.0),
                                            span: MKCoordinateSpan(latitudeDelta: 14, longitudeDelta: 14))
        if let response = try? await MKLocalSearch(request: request).start() {
            for item in response.mapItems.prefix(8) {
                let c = item.placemark.coordinate
                results.append(SearchHit(name: item.name ?? q, subtitle: item.placemark.title ?? "",
                                         lat: c.latitude, lon: c.longitude))
            }
        }
        if Task.isCancelled { return }
        hits = results
    }
}
