# Spotify Notification

Eine persönliche macOS-Menüleisten-App, die die lokal installierte Spotify-App ohne Spotify-Login anzeigt und steuert.

## MVP

- Aktueller Titel, Künstler, Album und Cover
- Play/Pause, vorheriger und nächster Titel
- Wiedergabefortschritt, Laufzeit und Spulen
- Spotify-Lautstärke mit Stummschaltung
- Shuffle und Wiederholung, wenn der Wiedergabekontext sie unterstützt
- Titel in Spotify öffnen
- Native macOS-Mitteilung mit Albumcover bei einem Titelwechsel
- Optionaler Autostart beim Anmelden
- Keine Cloud, Spotify-Web-API, Statistiken oder Telemetrie

## Voraussetzungen

- macOS 14 oder neuer
- Xcode 26 oder neuer
- Installierte Spotify-Desktop-App

## Entwickeln

Das Projekt kann in Xcode über `Package.swift` geöffnet werden. Für Kommandozeilen-Builds:

```sh
make build
make test
```

## App erstellen

```sh
make app
```

Die lokal signierte App wird unter `dist/Spotify Notification.app` erzeugt. Beim ersten Start fragt macOS nach der Berechtigung, Spotify zu steuern, und nach der Erlaubnis für Mitteilungen.
