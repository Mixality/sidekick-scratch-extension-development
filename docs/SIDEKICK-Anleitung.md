# SIDEKICK Assistenzsystem

## Anleitung, Dokumentation

---

## Begriffe-Übersicht

| Begriff | Erklärung |
|---------|-----------|
| **Raspberry Pi (RPi)** | Kosteneffektiver, handlicher Einplatinencomputer. Führt SIDEKICK aus. |
| **Hostname** | Der Name des RPi im Netzwerk. Über diesen Namen ist der entprechende RPi von anderen Geräten aus erreichbar (Beispiel: `sidekick-rpi-ws1.local`). |
| **Dashboard** | Eine Webseite-Oberfläche zum Verwalten von Videos, Projekten und zum Steuern des Displays / der Darstellung im Kiosk-Modus. |
| **Scratch** | Die visuelle blockbasierte Programmiersprache und -umgebung |
| **Kiosk-Modus** | Darstellung eines Scratch-Projekts auf dem RPi im Vollbild (bspw. auf Displays in der Werkstatt). |
| **Hotspot** | Falls kein Firmennetzwerk verfügbar ist, kann der RPi somit ein eigenes WLAN aufmachen. |

---

## SIDEKICK?

Das SIDEKICK-Assisstenzsystem als Unterstützung für Menschen mit Einschränkungen bei prozeduralen Arbeitsabläufen, durch Anzeige von Anweisungen für einzelne Arbeitsschritte. Arbeitsabläufe sind über die Programmieroberfläche Scratch erstellbar.

SIDEKICK ist ein **RPi-basiertes Assistenzsystem**, das:

- **Interaktive Arbeitsanleitungen** auf einem Display anzeigt.
- Mit der visuellen, blockbasierten Programmiersprache **Scratch** erstellt wird.
  - Somit auch **ohne Programmierkenntnisse** bedienbar ist.
- **Multimedia** (Videos, Bilder etc.) unterstützt.
- Mit **Hardware** (Sensoren (Buttons, Ultraschall etc.), Aktuatoren (LED-Streifen etc.)) erweiterbar ist.

---

## Anwendungsfälle

### Arbeitsanleitungen
- Schritt-für-Schritt Montageanleitungen.
- Qualitätsprüfungen mit Checklisten.
- Sicherheitsunterweisungen.

### Assistenz am Arbeitsplatz
- Visuelle Hilfestellung für Mitarbeiter.
- Barrierefreie Darstellung (große Schrift, klare Bilder etc.).
- Mehrsprachige Anleitungen möglich.

### Interaktive Steuerung
- Weiterschalten per Tastendruck oder Sensor.
- Automatische Abläufe mit Zeitsteuerung.
- Feedback durch LEDs oder Töne.

---

## Systemübersicht

```
┌────────────────────────────────────────────────────────┐
│                    SIDEKICK-System                     │
├────────────────────────────────────────────────────────┤
│                                                        │
│   ┌─────────────┐         ┌─────────────┐              │
│   │     PC      │◄───────►│     RPi     │──► Display   │
│   │ (Front-End) │  WLAN   │ (Back-End)  │              │
│   └─────────────┘         └─────────────┘              │
│                                  │                     │
│                                  ▼                     │
│                      ┌──────────────────────┐          │
│                      │       Hardware       │          │
│                      │      (optional)      │          │
│                      │ Sensoren, Aktuatoren │          │
│                      └──────────────────────┘          │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### Komponenten

| Komponente | Funktion |
|------------|----------|
| **Raspberry Pi** | Hauptkomponente: Stellt Anwendungen bereit, führt Anleitungen aus etc. |
| **Display** | Zeigt die Arbeitsanleitung an (im „Kiosk-Modus“ des RPi). |
| **PC** | Zum Erstellen, Bearbeiten und Steuern der Assistenzanleitungen (durch Aufrufen Oberflächen der auf dem RPi bereitgestellten Anwendungen). |
| **WLAN** | Stellt Verbindung zwischen PC und RPi her. |

---

## Einrichtung

Es sind unterschiedliche Methoden zur Einrichtung von SIDEKICK bereitgestellt:

| Methode | Schwierigkeit | Display / Tastatur am Pi notwendig? |
|---------|---------------|-------------------------------|
| Setup-Datei | Einfach | Ja |
| Terminal-Befehl | Einfach | Ja |

> **Voraussetzung:** Display, Maus und Tastatur am RPi angeschlossen.

---

### Methode 1: Per Setup-Datei *(empfohlen)*

1. Die Setup-Datei auf den RPi herunterladen:
   - Download: [sidekick-setup.sh](https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh).
   - Oder per USB-Stick übertragen.

2. Die Datei ausführbar machen und starten:
   ```bash
   chmod +x sidekick-setup.sh
   sudo ./sidekick-setup.sh
   ```

3. Optional: Eigenen Hostname setzen (Beispiel-Hostname: „rpi-ws1“):
   ```bash
   sudo ./sidekick-setup.sh --hostname=rpi-ws1
   ```

4. Die Einrichtung wird automatisch durchgeführt.

---

### Methode 2: Per Terminal-Befehl

1. Ein Terminal-Fenster auf dem RPi öffnen:
   - Kann bspw. mit `Strg` + `Alt` + `T` oder über das Menü geöffnet werden.

2. Folgenden Befehl eingeben und mit `Enter` bestätigen:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh | sudo bash
   ```

3. Optional: Eigenen Hostname setzen (Beispiel-Hostname: „rpi-ws1“):
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh | sudo bash -s -- --hostname=rpi-ws1
   ```

4. Die Einrichtung wird automatisch durchgeführt.

---

### Einrichtung: Beispiel

**Szenario**: Einrichten eines RPis für „Workstation 1“.

- Gewählter Hostname: `rpi-ws1`.
- Nach der Installation:
  - Hotspot-Name: `sidekick-rpi-ws1`.
  - Hotspot-Passwort: `sidekick`.
  - Erreichbar unter:
    - SIDEKICK-Dashboard: `http://sidekick-rpi-ws1.local:5000`.
    - Scratch-Editor: `http://sidekick-rpi-ws1.local:8601`.

---

### Was wird installiert?

Das Setup-Script installiert automatisch:
- Scratch-Editor (angepasste Version mit SIDEKICK-Erweiterung).
- SIDEKICK-Dashboard für Dateiverwaltung, Display-Fernsteuerung etc.
- MQTT-Server für Kommunikation.
- WLAN-Hotspot (`sidekick-xxxxxx`).
- Notwendige Abhängigkeiten.

---

## Bedienung

### Aufrufen der SIDEKICK-Webseiten-Oberflächen

Es gibt zwei Webseiten die auf dem RPi laufen:

| Webseite | Funktion | Port |
|----------|----------|------|
| **SIDEKICK-Dashboard** | Videos / Projekte verwalten, Display steuern. | 5000 |
| **Scratch-Editor** | Assistenz-Anleitungen erstellen und bearbeiten. | 8601 |

---

### Verbindungsmöglichkeiten

**Option 1: Im gleichen Netzwerk wie der RPi**
> Z. B. am Office-PC, wenn der RPi mit dem gleichen (Firmen-)WLAN verbunden ist.

- **Dashboard**: `http://sidekick-HOSTNAME.local:5000`.
- **Scratch-Editor**: `http://sidekick-HOSTNAME.local:8601`.

**Option 2: Per Hotspot-Verbindung**
> Bspw. Laptop / Tablet direkt mit dem RPi (dem WLAN / Hotspot des RPis) verbinden.

1. Mit Hotspot verbinden:
   - WLAN-Name: `sidekick-HOSTNAME` (z. B. `sidekick-rpi-ws1`).
   - Passwort: `sidekick`.

2. Webseiten aufrufen:
   - **Dashboard**: `http://10.42.0.1:5000`.
   - **Scratch-Editor**: `http://10.42.0.1:8601`.

---

### Bedienung: Beispiel

**Szenario:** RPi mit Hostname `rpi-ws1` wurde eingerichtet.

**Am Office-PC (gleiches Netzwerk)**:
- Dashboard: `http://sidekick-rpi-ws1.local:5000`.
- Scratch-Editor: `http://sidekick-rpi-ws1.local:8601`.

**Per Hotspot**:
1. Mit WLAN `sidekick-rpi-ws1` verbinden (Passwort: `sidekick`).
2. Dashboard: `http://10.42.0.1:5000`.
3. Scratch-Editor: `http://10.42.0.1:8601`.

---

## Dashboard (1. SIDEKICK-Webseite-Oberfläche)

Das SIDEKICK-Dashboard (Port 5000) bietet:

### Dateiverwaltung
- **Videos hochladen** (verwendbar bei der Erstellung der Arbeitsanleitungen).
- **Projekte hochladen** (Scratch `.sb3`-Dateien).
- **Dateien umbenennen / löschen**.

### Kiosk-Steuerung
- **Projekt auf Display laden** (Projekt per Dropdown auswählbar).
- **Start / Stop** (grüne Flagge / Stop-Button).
- **Vollbild** (Stage- / Vollbild-Ansicht umschalten).

### Zugriff
```
http://[RPI-ADRESSE]:5000
```

---

## Scratch-Editor (2. SIDEKICK-Webseite-Oberfläche)

Der Scratch-Editor (Port 8601) ist eine **angepasste Version** von Scratch 3.0.

### SIDEKICK-Erweiterung
- **Button-Zustand abfragen** (interaktive Schritte, bspw. durch Reaktion auf Drücken eines Buttons).
- **Ultraschall-Sensoren abfragen** (bspw. für Erkennung eines Handeingriffs in einen Sichtlagerkasten).
- **LED-Streifen ansteuern** (interaktive Schritte, bspw. durch Pick-By-Light-System).
- **Videomaterial laden und steuern** (Nutzung der, über das SIDEKICK-Dashboard, hochgeladenen Videos, für Darstellung auf Display des SIDEKICK-Assistenzsystems).

<!-- ### MQTT-Erweiterung
- **MQTT verbinden** - Mit anderen Geräten kommunizieren
- **Nachrichten senden** - An Topics publishen
- **Nachrichten empfangen** - Topics abonnieren -->

### Zugriff
```
http://[RPI-ADRESSE]:8601
```

---

## Kiosk-Modus

Der Kiosk-Modus zeigt Scratch-Projekte **im Vollbild** auf dem RPi-Display an.

### Aktivierung

Während der Installation:
```bash
curl -fsSL https://...sidekick-setup.sh | bash -s -- --kiosk
```

Oder nachträglich:
```bash
~/Sidekick/sidekick-setup.sh --kiosk
```

### Funktionen
- Startet automatisch beim Booten.
- Darstellung der Scratch-Stage (und deren visuelle Inhalte / Elemente) im Vollbild.
- Steuerbar über das SIDEKICK-Dashboard (Start / Stop / Vollbild umschalten).
  - Keine Maus / Tastatur am RPi notwendig.

---

## 📁 Ordnerstruktur

```
~/Sidekick/
├── sidekick/              # Scratch-Installation.
│   ├── videos/            # Hochgeladene Videos (für Anleitungen nutzbar).
│   ├── projects/          # Hochgeladene `.sb3`- / Scratch-Projekte (über SIDEKICK-Dashboard auf Display (Kiosk) ladbar). 
│   └── ...
├── sidekick-setup.sh      # Setup-Script
└── logs/                  # Log-Dateien
```

### Videos hochladen

**Empfohlenes Format:**
- Codec: H.264 (AVC).
- Auflösung: Maximal 1920 x 1080.
- Dateigröße: Maximal 50 MB.

**Nicht unterstützt:**
- HEVC / H.265 (nicht dekodierbar durch den RPi).

Videos können in den Ordner über das SIDEKICK-Dashboard (hoch)geladen oder direkt hereinkopiert werden.

---

## USB-Import

Videos und Projekte können auch per **USB-Stick** auf mehrere RPis verteilt werden.

### USB-Stick vorbereiten

```
USB-Stick/
├── rpi-ws1/              # Ordnername ≙ Hostname des entsprechenden Ziel-RPis.
│   ├── videos/
│   │   └── anleitung.mp4
│   └── projects/
│       └── projekt.sb3
├── rpi-ws2/              # Ordner für einen anderen RPi.
│   ├── videos/
│   └── projects/
└── ...
```

### Verwendung

1. USB-Stick in den RPi einstecken.
2. Der Import startet automatisch.
3. Dateien werden automatisch in die entsprechenden Ordner des entsprechenden RPis kopiert.
4. Ergebnis wird als `IMPORT-ERGEBNIS.txt` im Ordner gespeichert

> **Hinweis:** Dateien, die neuer sind als vorhandene, werden überschrieben.

---

## Netzwerk

### Automatischer WLAN-Name

Der RPi erstellt automatisch einen Hotspot mit dem Namen:
```
sidekick-xxxxxx
```
Die 6 Zeichen (`xxxxxx`) sind die letzten 6 Zeichen der **Seriennummer** des entsprechenden RPis (siehe evtl. Aufkleber auf dem entsprechenden RPi).

### Ports

| Port | Dienst |
|------|--------|
| 8601 | Scratch-Editor |
| 5000 | SIDEKICK-Dashboard |
| 9001 | MQTT (WebSocket) |
| 1883 | MQTT (TCP) |

---

## FAQ

### Der Pi startet nicht
- SD-Karte richtig eingesteckt?
- Netzteil stark genug? (Empfohlen: 3 A.)

### Ich finde den RPi nicht im Netzwerk
- Mit RPi-Hotspot (`sidekick-xxxxxx`, Passwort: `sidekick`) verbinden.
  - Danach: `http://10.42.0.1:8601` aufrufen.

### Videos werden nicht abgespielt
- Format prüfen (H.264, nicht HEVC).
  - Mit ffmpeg konvertieren:
   ```bash
   ffmpeg -i video.mp4 -c:v libx264 -crf 23 output.mp4
   ```

### Wie aktualisiere ich SIDEKICK?
```bash
~/Sidekick/sidekick-setup.sh
```
Das Script erkennt automatisch, wenn SIDEKICK bereits installiert ist und führt ein Update durch.

---

## Support

Bei Fragen oder Problemen:
- GitHub Issues: [Repository-Link].
- Dokumentation: Dieses Dokument.

---

*SIDEKICK − Einfaches Assistenzsystem für WfbM.*

*Version 1.0 | Dezember 2025*
