<p align="center"><img src="docs/icon.png" width="128" alt="Wachmacher-Icon"></p>

# Wachmacher ☕️

Kleine Menüleisten-App für macOS, die den Mac wach hält – kein Bildschirmschoner, keine Sperre.

## Funktionen

- **Klick auf die Tasse** schaltet an/aus, **Rechtsklick** (oder ⌃-Klick) öffnet das Menü.
- **Mac wach halten** – hält das Display wach und setzt den Inaktivitäts-Timer zurück (offizielle IOKit-Power-Assertions, keine Berechtigungen nötig).
- **Timer** – 15 Min bis 4 Std oder „Bis Feierabend“. Die Tasse in der Menüleiste leert sich, während die Zeit abläuft.
- **Akku-Schutz** – pausiert automatisch, wenn der Akku unter eine einstellbare Grenze fällt (am Netzteil nie).
- **Apps** – automatisch wach, solange bestimmte Apps (z. B. Teams, Zoom, Keynote) geöffnet oder im Vordergrund sind.
- **Maus bewegen, wenn inaktiv** – nach 25 s ohne Eingabe 1 px hin und zurück (z. B. gegen „Abwesend“ in Teams). Benötigt die Freigabe unter *Datenschutz & Sicherheit → Bedienungshilfen*.
- **Einstellungen** (⌘,) – Anmeldestart, Feierabend-Zeit, Akku-Grenze und App-Liste.

| Tasse | Bedeutung |
|---|---|
| voll | wach (unbegrenzt oder durch eine App) |
| teilweise gefüllt | Timer läuft |
| leer | aus |
| leer, ausgegraut | pausiert wegen niedrigem Akku |

## Bauen

Voraussetzung: macOS 14+, Xcode 16+ (Swift 6).

```bash
./build.sh            # baut build/Wachmacher.app
./build.sh --install  # baut, kopiert nach /Applications und startet
swift test            # Unit-Tests der Entscheidungslogik
```

Die App wird ad-hoc signiert. Nach jedem Neubau muss die Bedienungshilfen-Freigabe ggf. neu erteilt werden.

## Aufbau

Swift Package mit zwei Modulen:

- `Sources/WachmacherCore/` – reine Logik ohne UI (`AwakeEngine`: Timer, Akku-Schutz, App-Auslöser, Klick-Verhalten), mit Tests in `Tests/`
- `Sources/Wachmacher/`
  - `App/` – Einstiegspunkt und `AppDelegate`
  - `Core/` – `Preferences` (UserDefaults), `Services/AwakeController` (verbindet Logik mit System), `Services/PowerService` (IOKit, Akku, Maus)
  - `Features/StatusItem/` – Menüleisten-Symbol, Menü, gezeichnete Tasse
  - `Features/Settings/` – Einstellungsfenster (SwiftUI)
- `Tools/make-icon.swift` – zeichnet das App-Icon
- `build.sh` – baut, erzeugt `.icns` und `Info.plist`, signiert

## Lizenz

[MIT](LICENSE)
