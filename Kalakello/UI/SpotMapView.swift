import SwiftUI
import SwiftData
import MapKit

extension SpotKind {
    var tint: Color {
        switch self {
        case .known: return Color(hex: 0x3DB5B0)
        case .rapids: return Color(hex: 0x4C8DE0)
        case .strait: return Color(hex: 0x8E7CE0)
        case .shoal: return Color(hex: 0xE0A04C)
        case .water: return Color(hex: 0x5E8FA0)
        case .other: return Color.gray
        }
    }
}

struct SpotMapView: View {
    @Environment(AppState.self) private var app
    @Query private var catches: [CatchRecord]
    @Query private var saved: [SavedPlace]

    @State private var camera: MapCameraPosition = .automatic
    @State private var region: MKCoordinateRegion?
    @State private var selected: Spot?
    @State private var hybrid = false

    private let maxSpan = 2.0

    var body: some View {
        Map(position: $camera) {
            UserAnnotation()

            Marker(app.place.name, systemImage: "scope", coordinate: app.place.coordinate)
                .tint(Theme.accent)

            ForEach(saved) { p in
                Marker(p.name, systemImage: "star.fill", coordinate: p.coordinate)
                    .tint(.yellow)
            }

            ForEach(catches) { c in
                Annotation(c.species, coordinate: c.coordinate) {
                    Image(systemName: "fish.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Theme.amber, in: Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
            }

            ForEach(visibleSpots) { spot in
                Annotation("", coordinate: spot.coordinate) {
                    Button { selected = spot } label: {
                        Image(systemName: spot.kind.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(spot.kind.tint, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                    }
                }
            }
        }
        .mapStyle(hybrid ? .hybrid(elevation: .flat) : .standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            region = context.region
        }
        .overlay(alignment: .top) {
            if tooWide {
                Text("Zoomaa lähemmäs nähdäksesi kalapaikat")
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button { hybrid.toggle() } label: {
                Image(systemName: hybrid ? "map" : "globe.europe.africa.fill")
                    .font(.title3)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(14)
            .accessibilityLabel("Vaihda karttatyyppi")
        }
        .onAppear { recenter() }
        .onChange(of: app.place) { _, _ in recenter() }
        .sheet(item: $selected) { spot in
            SpotSheet(spot: spot)
                .presentationDetents([.height(320), .large])
        }
    }

    private var tooWide: Bool { (region?.span.latitudeDelta ?? 0) > maxSpan }

    private var visibleSpots: [Spot] {
        guard let r = region, r.span.latitudeDelta <= maxSpan else { return [] }
        return SpotStore.within(minLat: r.center.latitude - r.span.latitudeDelta / 2,
                                maxLat: r.center.latitude + r.span.latitudeDelta / 2,
                                minLon: r.center.longitude - r.span.longitudeDelta / 2,
                                maxLon: r.center.longitude + r.span.longitudeDelta / 2,
                                limit: 250)
    }

    private func recenter() {
        let r = MKCoordinateRegion(center: app.place.coordinate,
                                   span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4))
        region = r
        camera = .region(r)
    }
}

struct SpotSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    let spot: Spot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: spot.kind.symbol)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(spot.kind.tint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.displayName).font(.title3.weight(.bold))
                    Text(spot.kind.title).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            if let note = spot.accessNote {
                Label(note, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.amber)
            }

            Button {
                app.setPlace(Place(name: spot.displayName, lat: spot.la, lon: spot.lo))
                app.tab = .today
                dismiss()
            } label: {
                Label("Katso kalakeli täältä", systemImage: "gauge.with.dots.needle.67percent")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let url = spot.websiteURL {
                Link(destination: url) { Label("Avaa verkkosivu", systemImage: "safari") }
            }

            Text("Tarkista aina voimassa olevat luvat ja rajoitukset viranomaislähteistä (kalastusrajoitukset.fi). Kartan paikat ovat suunnittelun apuväline, eivät navigointiohje. © OpenStreetMap-tekijät (ODbL).")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
