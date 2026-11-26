<p align="center"><img src="docs/icon.png" width="128" alt="Wachmacher-Icon"></p>

# Wachmacher ☕️

Kleine Menüleisten-App für macOS, die den Mac wach hält – kein Bildschirmschoner, keine Sperre.

## Funktionen

- **Mac wach halten** (⌘W) – hält das Display wach und setzt den Inaktivitäts-Timer alle 30 s zurück (offizielle IOKit-Power-Assertions, keine Berechtigungen nötig).
- **Maus bewegen, wenn inaktiv** – nach 25 s ohne Eingabe wird die Maus um 1 px hin und zurück bewegt (z. B. gegen „Abwesend“ in Teams). Benötigt die Freigabe unter *Datenschutz & Sicherheit → Bedienungshilfen*.
- **Beim Anmelden starten** – über `SMAppService`.
- Gefüllte Tasse = aktiv, leere Tasse = pausiert.

## Bauen

Voraussetzung: macOS 14+, Xcode Command Line Tools (Swift 6).

```bash
./build.sh            # baut build/Wachmacher.app
./build.sh --install  # baut, kopiert nach /Applications und startet
```

Die App wird ad-hoc signiert. Nach jedem Neubau muss die Bedienungshilfen-Freigabe ggf. neu erteilt werden.

## Aufbau

- `Sources/WachmacherApp.swift` – SwiftUI-`MenuBarExtra` und die Wach-Logik
- `Tools/make-icon.swift` – zeichnet das App-Icon
- `build.sh` – kompiliert, erzeugt `.icns`, `Info.plist` und signiert
