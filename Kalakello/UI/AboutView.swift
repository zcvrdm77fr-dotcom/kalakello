import SwiftUI

struct AboutView: View {
    @Environment(AppState.self) private var app
    @State private var notificationDenied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Muistutukset") {
                    Toggle("Muistuta hyvistä ikkunoista", isOn: notifyBinding)
                    if app.notificationsEnabled {
                        Stepper("Vähintään \(app.notifyThreshold) pistettä",
                                value: thresholdBinding, in: 40...95, step: 5)
                        Text("Muistutus ajastetaan, kun ennuste päivittyy (sovellus avattu). Ei palvelinta, ei taustaseurantaa.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Miten kalakeli lasketaan") {
                    Text("Kalakelipiste (0–94) on heuristinen vertailuarvo. Se yhdistää tuulen, pilvisyyden, ilmanpaineen muutoksen kuuteen tuntiin, lämpötilan ja valaistuksen sekä lajikohtaiset tekijät. Se EI ole saalistodennäköisyys eikä saalistakuu.")
                        .font(.subheadline)
                    Text("Eroa verkkosovellukseen: valaistus lasketaan oikeasta auringonnoususta ja -laskusta (hämärä = ikkunat ±1–2 h), ei kiinteistä kellonajoista. Kuun vaihe näytetään vain tiedoksi, se ei vaikuta pisteisiin. Lisäksi Sinun kalakelisi vertaa nykyhetkeä omiin saaliisiisi.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Lähteet") {
                    Link("Säädata: Open-Meteo.com", destination: URL(string: "https://open-meteo.com/")!)
                    Link("Kalapaikat: © OpenStreetMap-tekijät (ODbL)", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                    Link("Kalastusrajoitukset ja luvat", destination: URL(string: "https://www.kalastusrajoitukset.fi/")!)
                }

                Section("Tietosuoja") {
                    Text("Saaliskirja, kuvat ja tallennetut paikat pysyvät vain tällä laitteella. Sijainti lähetetään ainoastaan Open-Meteolle sään hakemiseksi.")
                        .font(.subheadline)
                }

                Section {
                    LabeledContent("Versio", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Tietoa")
            .alert("Ilmoitukset on estetty", isPresented: $notificationDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Salli ilmoitukset iPhonen Asetukset-sovelluksessa.")
            }
        }
    }

    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { app.notificationsEnabled },
            set: { on in
                Task {
                    let ok = await app.setNotifications(on)
                    if on && !ok { notificationDenied = true }
                }
            })
    }

    private var thresholdBinding: Binding<Int> {
        Binding(get: { app.notifyThreshold }, set: { app.setThreshold($0) })
    }
}
