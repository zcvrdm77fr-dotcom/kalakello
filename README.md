# Kalakello 🎣 (iOS)

FastFishingin ajatus natiivina iPhone-appina: **milloin kannattaa lähteä, mistä ja millä vieheellä** –
mutta niin, että appi oppii myös *sinun* kalastuksestasi.

## Ei Macia? Käytä GitHub Actionsia

Repon juureen (kansio jossa `project.yml` on) tulee mukana `.github/workflows/`:

- `ios.yml` – ajaa GitHubin pilvi-Macilla: luo projektin, kääntää, ajaa testit ja tekee **allekirjoittamattoman .ipa:n** (artifact).
  Virheet tulevat Summary-sivulle → kopioi ne Claudelle.
- `testflight.yml` – käsin käynnistettävä, lähettää buildin TestFlightiin (vaatii 99 $/v Developer-tilin + 4 salaisuutta, ohjeet tiedoston alussa).

Huom: macOS-minuutit kuluttavat yksityisessä repossa 10-kertaisesti (julkisessa ilmaisia).

## Käynnistys Macilla (2 min)

```bash
brew install xcodegen
cd Kalakello
xcodegen            # luo Kalakello.xcodeproj
open Kalakello.xcodeproj
```

1. Xcode 16 tai uudempi, iOS 17+ simulaattori/laite.
2. `project.yml`: vaihda `bundleIdPrefix` / `PRODUCT_BUNDLE_IDENTIFIER` ja lisää `DEVELOPMENT_TEAM`.
3. Run (⌘R). Testit: ⌘U.

## Mikä on sama kuin verkkosovelluksessa

- Kalakelipiste (kuha, hauki, ahven, taimen) – **sama kaava ja kalibrointi**, portattu 1:1 `fishing-advice.js`:stä.
  `KalakelloTests/GoldenVectors.swift` on generoitu ajamalla alkuperäinen JS; testit todistavat, että Swift antaa samat pisteet ja samat parhaat ikkunat.
- Parhaat lähtöajat (1–4 h, aamu/päivä/ilta), 3 erillistä vaihtoehtoa 48 h sisällä.
- Viehe-, syvyys-, väri- ja tekniikkasuositus (Kalastusnyt).
- Kalapaikkakartta (1610 OSM-paikkaa bundlattuna `spots.json`:ssa), tallennetut paikat.
- Open-Meteo-säädata, 15 min tuore / 6 h offline-välimuisti, tuntidatan validointi.

## Mikä on erilaista

| | Verkkosovellus | Kalakello |
|---|---|---|
| Valaistus | kiinteät kellonajat (≤08 / ≥18) | **oikea auringonnousu/-lasku** (hämärä-ikkunat), oikein myös keskikesällä ja joulukuussa |
| Näkymä | pistemittari + lista | iso mittari, **48 h kalakello-kaavio** (Swift Charts, sormella luettava), taustaväri seuraa valoa |
| Yhteisö | Saalisvirta + tilit + palvelin | **Henkilökohtainen Saaliskirja** (kuva, laji, pituus, paino, viehe) – ei tiliä, ei palvelinta |
| Oppiminen | – | Jokaiseen saaliiseen tallentuu **säätila saaliin hetkellä** → *Sinun kalakelisi*: "nykyhetki vastaa X % omista saaliistasi" |
| Muistutus | selain, vain sovellus auki | paikalliset ilmoitukset hyvistä ikkunoista |
| Kuu | – | kuun vaihe tiedoksi (EI vaikuta pisteisiin) |
| Haku | paikkahaku | kalapaikat nimellä + MapKit-haku + "käytä sijaintiani" |

Saalisvirta (yhteisö) on jätetty pois v1:stä tarkoituksella: se vaatisi kirjautumisen, moderoinnin ja
`api.fastfishin.com`-yhteyden. Sen voi lisätä myöhemmin samaan API:in.

## Rakenne

```
Kalakello/Core     Foundation-only logiikka (pisteet, ennuste, ikkunat, kuu, insights) – helppo testata
Kalakello/Data     SwiftData-mallit (CatchRecord, SavedPlace) + kalapaikat
Kalakello/State    AppState (@Observable), sijainti, ilmoitukset
Kalakello/UI       SwiftUI-näkymät
KalakelloTests     Golden-vektorit + parserin, kuun ja insightsien testit
```

## Ennen App Storea – tärkeää

- **Open-Meteo**: ilmainen API on vain ei-kaupalliseen käyttöön. Jos appi on maksullinen / mainoksia / IAP, tarvitaan Open-Meteon kaupallinen tilaus (tai toinen säälähde).
- **OSM-data**: ODbL – attribuutio on appissa (Tietoa-välilehti + paikan kortti).
- **Tietosuoja**: `PrivacyInfo.xcprivacy` on mukana. App Store Connectin tietosuojaselosteeseen: *Precise Location → App Functionality → ei linkitetty käyttäjään → ei seurantaa* (koordinaatit lähtevät Open-Meteolle).
- Kalakelipiste on heuristiikka, ei saalislupaus – tämä lukee appissa.
- Ikoni on paikkamerkki (1024 px). Vaihda halutessasi `Assets.xcassets/AppIcon`.

## Tunnetut rajat / seuraavat askeleet

- Muistutukset ajastetaan kun ennuste päivittyy (appi avattu). Taustapäivitys (BGAppRefresh) ja widgetit (Lock Screen "paras ikkuna") ovat luonteva v1.1.
- Vain suomi, vain iPhone, vain tumma teema (muutettavissa: `RootView.preferredColorScheme`).
- Historiasää saaliille haetaan max. 92 päivää taaksepäin.
