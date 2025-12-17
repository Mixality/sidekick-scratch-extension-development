# SIDEKICK Assistenzsystem

## Anleitung & Dokumentation

---

## 📖 Begriffe kurz erklärt

| Begriff | Erklärung |
|---------|-----------|
| **Raspberry Pi (RPi)** | Ein kleiner, günstiger Computer in Kreditkartengröße. Darauf läuft SIDEKICK. |
| **Hostname** | Der Name des Raspberry Pi im Netzwerk. Damit kann man ihn von anderen Geräten aus erreichen (z.B. `sidekick-rpi-ws1.local`). |
| **Dashboard** | Eine Webseite zum Verwalten von Videos, Projekten und zum Steuern des Displays. |
| **Scratch** | Eine visuelle Programmiersprache mit bunten Bausteinen - keine Programmierkenntnisse nötig! |
| **Kiosk-Modus** | Der Pi zeigt ein Scratch-Projekt im Vollbild an - perfekt für Displays in der Werkstatt. |
| **Hotspot** | Der Pi kann sein eigenes WLAN aufmachen, falls kein Firmennetzwerk verfügbar ist. |

---

## 📌 Was ist SIDEKICK?

SIDEKICK ist ein **Raspberry Pi-basiertes Assistenzsystem** für die Werkstatt, das:

- **Interaktive Arbeitsanleitungen** auf einem Display anzeigt
- Mit der visuellen Programmiersprache **Scratch** erstellt wird
- **Ohne Programmierkenntnisse** bedienbar ist
- **Videos, Bilder und Animationen** unterstützt
- Mit **Hardware** (LEDs, Sensoren, Buttons) erweitert werden kann

---

## 🎯 Anwendungsfälle

### Arbeitsanleitungen
- Schritt-für-Schritt Montageanleitungen
- Qualitätsprüfungen mit Checklisten
- Sicherheitsunterweisungen

### Assistenz am Arbeitsplatz
- Visuelle Hilfestellung für Mitarbeiter
- Barrierefreie Darstellung (große Schrift, klare Bilder)
- Mehrsprachige Anleitungen möglich

### Interaktive Steuerung
- Weiterschalten per Tastendruck oder Sensor
- Automatische Abläufe mit Zeitsteuerung
- Feedback durch LEDs oder Töne

---

## 🖥️ Systemübersicht

```
┌─────────────────────────────────────────────────────────────┐
│                     SIDEKICK System                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────────┐         ┌─────────────┐                  │
│   │   Laptop    │◄───────►│ Raspberry   │──► Display/TV    │
│   │  (Editor)   │  WLAN   │     Pi      │                  │
│   └─────────────┘         └─────────────┘                  │
│                                  │                          │
│                                  ▼                          │
│                           ┌─────────────┐                  │
│                           │  Hardware   │                  │
│                           │ (optional)  │                  │
│                           │ LEDs, GPIO  │                  │
│                           └─────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Komponenten

| Komponente | Funktion |
|------------|----------|
| **Raspberry Pi** | Herzstück - führt Anleitungen aus |
| **Display/TV** | Zeigt die Arbeitsanleitung an (Kiosk-Modus) |
| **Laptop/PC** | Zum Erstellen und Bearbeiten der Anleitungen |
| **WLAN** | Verbindung zwischen Laptop und Pi |

---

## 🚀 Einrichtung

Es gibt mehrere Wege, SIDEKICK auf einem Raspberry Pi einzurichten:

| Methode | Schwierigkeit | Display/Tastatur am Pi nötig? |
|---------|---------------|-------------------------------|
| USB-Stick (automatisch) | ⭐ Einfach | ❌ Nein |
| Setup-Datei | ⭐⭐ Mittel | ✅ Ja |
| Terminal-Befehl | ⭐⭐ Mittel | ✅ Ja |

---

### Methode 1: Automatisch per USB-Stick *(empfohlen)*

> **Vorteil:** Kein Display, keine Tastatur am Pi nötig!

1. Die Setup-Datei auf einen USB-Stick kopieren
   - Download: [sidekick-setup.sh](https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh)

2. Optional: Hostname festlegen
   - Datei `sidekick-hostname.txt` auf den Stick legen
   - Inhalt: gewünschter Name (z.B. `rpi-ws1`)

3. USB-Stick in den Raspberry Pi einstecken
   - Die Einrichtung startet automatisch
   - Nach Abschluss erscheint `ERGEBNIS.txt` auf dem Stick

---

### Methode 2: Manuell per Setup-Datei

> **Voraussetzung:** Display, Maus und Tastatur am Pi angeschlossen

1. Die Setup-Datei auf den Pi herunterladen
   - Download: [sidekick-setup.sh](https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh)
   - Oder per USB-Stick / anderweitig übertragen

2. Die Datei ausführbar machen und starten:
   ```bash
   chmod +x sidekick-setup.sh
   sudo ./sidekick-setup.sh
   ```

3. Optional: Eigenen Hostname setzen:
   ```bash
   sudo ./sidekick-setup.sh --hostname=rpi-ws1
   ```

4. Die Einrichtung läuft automatisch durch

---

### Methode 3: Manuell per Terminal-Befehl

> **Voraussetzung:** Display, Maus und Tastatur am Pi angeschlossen

1. Ein Terminal-Fenster auf dem Pi öffnen
   - Kann z.B. mit `Strg+Alt+T` oder über das Menü geöffnet werden

2. Folgenden Befehl eingeben und mit "Enter" bestätigen:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh | bash
   ```

3. Optional: Mit eigenem Hostname:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh | bash -s -- --hostname=rpi-ws1
   ```

4. Die Einrichtung läuft automatisch durch

---

### Einrichtung: Beispiel

**Szenario:** Wir richten einen Pi für "Workstation 1" ein.

- Gewählter Hostname: `rpi-ws1`
- Nach der Installation:
  - Hotspot-Name: `sidekick-rpi-ws1`
  - Hotspot-Passwort: `sidekick`
  - Erreichbar unter: `http://sidekick-rpi-ws1.local:8601`

---

### Was wird installiert?

Das Setup-Script installiert automatisch:
- ✅ Scratch Editor (angepasste Version mit SIDEKICK-Erweiterungen)
- ✅ Dashboard für Dateiverwaltung
- ✅ MQTT-Server für Kommunikation
- ✅ WLAN-Hotspot (`sidekick-xxxxxx`)
- ✅ Alle benötigten Abhängigkeiten

---

## 🖥️ Bedienung

### Aufrufen der SIDEKICK-Webseiten

Es gibt zwei Webseiten die auf dem Pi laufen:

| Webseite | Funktion | Port |
|----------|----------|------|
| **Dashboard** | Videos/Projekte verwalten, Display steuern | 5000 |
| **Scratch-Editor** | Anleitungen erstellen und bearbeiten | 8601 |

---

### Verbindungsmöglichkeiten

**Option 1: Im gleichen Netzwerk wie der Pi**
> z. B. am Office-PC, wenn der RPi im Firmen-WLAN ist

- **Dashboard:** `http://sidekick-HOSTNAME.local:5000`
- **Scratch-Editor:** `http://sidekick-HOSTNAME.local:8601`

**Option 2: Per Hotspot-Verbindung**
> Laptop/Tablet direkt mit dem RPi (dem WLAN / Hotspot des RPis) verbinden

1. Mit Hotspot verbinden:
   - WLAN-Name: `sidekick-HOSTNAME` (z.B. `sidekick-rpi-ws1`)
   - Passwort: `sidekick`

2. Webseiten aufrufen:
   - **Dashboard:** `http://10.42.0.1:5000`
   - **Scratch-Editor:** `http://10.42.0.1:8601`

---

### Bedienung: Beispiel

**Szenario:** Pi mit Hostname `rpi-ws1` wurde eingerichtet.

**Am Office-PC (gleiches Netzwerk):**
- Dashboard: `http://sidekick-rpi-ws1.local:5000`
- Scratch-Editor: `http://sidekick-rpi-ws1.local:8601`

**Per Hotspot:**
1. Mit WLAN `sidekick-rpi-ws1` verbinden (Passwort: `sidekick`)
2. Dashboard: `http://10.42.0.1:5000`
3. Scratch-Editor: `http://10.42.0.1:8601`

---

## 📊 Dashboard (1. SIDEKICK-Webseite)

Das Dashboard (Port 5000) bietet:

### Dateiverwaltung
- **Videos hochladen** - für Arbeitsanleitungen
- **Projekte hochladen** - Scratch .sb3 Dateien
- **Dateien umbenennen/löschen**

### Kiosk-Steuerung
- **Projekt auf Display laden** - per Dropdown auswählen
- **Start/Stop** - Grüne Flagge / Stop
- **Vollbild** - Stage-Ansicht umschalten

### Zugriff
```
http://[PI-ADRESSE]:5000
```

---

## 🎨 Scratch-Editor (2. SIDEKICK-Webseite)

Der Scratch Editor (Port 8601) ist eine **angepasste Version** von Scratch 3.0.

### Was ist Scratch?

Scratch ist eine visuelle Programmiersprache, bei der man **bunte Bausteine** zusammensteckt statt Code zu schreiben. Perfekt für Einsteiger!

### SIDEKICK-Erweiterung
- **Video abspielen** - Videos aus dem videos-Ordner
- **Warten auf Tastendruck** - Interaktive Schritte
- **Nachricht senden/empfangen** - Kommunikation zwischen Sprites

### MQTT-Erweiterung
- **MQTT verbinden** - Mit anderen Geräten kommunizieren
- **Nachrichten senden** - An Topics publishen
- **Nachrichten empfangen** - Topics abonnieren

### Zugriff
```
http://[PI-ADRESSE]:8601
```

---

## 🖥️ Kiosk-Modus

Der Kiosk-Modus zeigt Scratch-Projekte **im Vollbild** auf dem Pi-Display an.

### Aktivierung

Bei der Installation:
```bash
curl -fsSL https://...sidekick-setup.sh | bash -s -- --kiosk
```

Oder nachträglich:
```bash
~/Sidekick/sidekick-setup.sh --kiosk
```

### Funktionen
- Startet automatisch beim Booten
- Zeigt Stage im Vollbild
- Steuerbar über Dashboard (Start/Stop)
- Keine Maus/Tastatur am Pi nötig

---

## 📁 Ordnerstruktur

```
~/Sidekick/
├── sidekick/              # Scratch-Installation
│   ├── videos/            # Videos für Anleitungen
│   ├── projects/          # Gespeicherte .sb3 Projekte
│   └── ...
├── sidekick-setup.sh      # Setup-Script
└── logs/                  # Log-Dateien
```

### Videos hochladen

**Empfohlenes Format:**
- Codec: H.264 (AVC)
- Auflösung: max. 1920x1080
- Dateigröße: max. 50MB

**Nicht unterstützt:**
- HEVC / H.265 (Pi kann das nicht dekodieren)

Videos können über das Dashboard oder direkt in den Ordner kopiert werden.

---

## 🌐 Netzwerk

### Automatischer WLAN-Name

Der Pi erstellt automatisch einen Hotspot mit dem Namen:
```
sidekick-xxxxxx
```
Die 6 Zeichen (`xxxxxx`) sind die letzten 6 Zeichen der **Seriennummer** des Pi - diese steht auf dem Aufkleber auf dem Pi!

### Ports

| Port | Dienst |
|------|--------|
| 8601 | Scratch Editor |
| 5000 | Dashboard |
| 9001 | MQTT (WebSocket) |
| 1883 | MQTT (TCP) |

---

## ❓ FAQ

### Der Pi startet nicht
- SD-Karte richtig eingesteckt?
- Netzteil stark genug? (3A empfohlen)

### Ich finde den Pi nicht im Netzwerk
- Mit Pi-Hotspot (`sidekick-xxxxxx`) verbinden
- Dann: `http://10.42.0.1:8601`

### Videos spielen nicht ab
- Format prüfen (H.264, nicht HEVC)
- Mit ffmpeg konvertieren:
  ```bash
  ffmpeg -i video.mp4 -c:v libx264 -crf 23 output.mp4
  ```

### Wie aktualisiere ich SIDEKICK?
```bash
~/Sidekick/sidekick-setup.sh
```
Das Script erkennt automatisch, dass bereits installiert ist und macht ein Update.

---

## 📞 Support

Bei Fragen oder Problemen:
- GitHub Issues: [Repository-Link]
- Dokumentation: Dieses Dokument

---

*SIDEKICK - Einfache Assistenzsysteme für die Werkstatt*

*Version 1.0 | Dezember 2025*
