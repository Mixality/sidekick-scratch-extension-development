# SIDEKICK - Installations-Anleitung

SIDEKICK ist ein Assistenzsystem, das Menschen bei prozeduralen Arbeitsabläufen unterstützt. Arbeitsabläufe werden mit Scratch erstellt und können auf einem Raspberry Pi ausgeführt werden.

---

## Was wird benötigt?

### Hardware
- **Raspberry Pi 4** (empfohlen: 4GB RAM oder mehr)
- **SD-Karte** (mind. 16 GB, empfohlen: 32 GB)
- **Netzteil** für den Raspberry Pi
- **Optional:** Display für Kiosk-Modus

### Software (wird automatisch installiert)
- MQTT Broker (Mosquitto)
- SIDEKICK Webapp (Scratch + Dashboard)
- Python-Pakete für Sensoren/LEDs

---

## Installation

### Schritt 1: Raspberry Pi OS installieren

1. **Raspberry Pi Imager** herunterladen und installieren:
   - https://www.raspberrypi.com/software/

2. **Im Imager:**
   - Gerät: Raspberry Pi 4
   - Betriebssystem: **Raspberry Pi OS (64-bit)** (mit Desktop)
   - SD-Karte auswählen

3. **Einstellungen anpassen** (Zahnrad-Symbol):
   - Hostname: `sidekick` (oder beliebig)
   - Benutzername: `sidekick`
   - Passwort: `sidekick`
   - WLAN konfigurieren (optional, für erste Verbindung hilfreich)
   - SSH aktivieren (empfohlen)

4. **Auf SD-Karte schreiben**

5. **SD-Karte in Pi einsetzen und starten**

---

### Schritt 2: SIDEKICK installieren

Sobald der Pi gestartet ist, ein Terminal öffnen (oder per SSH verbinden) und **einen** der folgenden Befehle eingeben:

#### Variante A: Standard-Installation
```bash
curl -fsSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh | sudo bash -s -- --kiosk
```

#### Variante B: Mit eigenem Namen
```bash
curl -fsSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh | sudo bash -s -- --kiosk --hostname=meinname
```
→ Erstellt Hostname `sidekick-meinname` und WLAN `SIDEKICK-MEINNAME`

#### Variante C: Update einer bestehenden Installation
```bash
curl -fsSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh | sudo bash -s -- --force --kiosk
```

---

### Schritt 3: Neustart

Nach der Installation:
```bash
sudo reboot
```

---

## Installations-Optionen

| Option | Beschreibung |
|--------|--------------|
| `--kiosk` | Aktiviert Kiosk-Modus (Vollbild-Browser beim Start) |
| `--hostname=NAME` | Eigener Hostname (max. 23 Zeichen, nur a-z, 0-9, -) |
| `--force` | Erzwingt Neuinstallation |
| `--pre` | Installiert auch Test-Versionen (Pre-Releases) |

**Beispiele:**
```bash
# Für Schule Raum 1:
--hostname=schule-raum1    → WLAN: SIDEKICK-SCHULE-RAUM1

# Für Werkstatt:
--hostname=werkstatt       → WLAN: SIDEKICK-WERKSTATT
```

---

## Verbinden & Nutzen

### WLAN-Name

Der WLAN-Name wird automatisch generiert:

| Installation | WLAN-Name |
|--------------|-----------|
| **Ohne `--hostname`** | `SIDEKICK-XXXXXX` (letzte 6 Zeichen der Pi-Seriennummer) |
| **Mit `--hostname=NAME`** | `SIDEKICK-NAME` |

**Beispiel (automatisch):**
```
Pi-Seriennummer: 100000005f7b6f00
                         └──────┘
WLAN-Name:       SIDEKICK-7B6F00
```

> 💡 **Tipp:** Die Seriennummer steht auf dem Aufkleber des Raspberry Pi. Die letzten 6 Zeichen ergeben den WLAN-Namen!

### Mit dem SIDEKICK-WLAN verbinden

1. Auf Tablet/Laptop nach WLAN suchen
2. Verbinden mit: **SIDEKICK-XXXXXX** (siehe oben)
3. Passwort: **sidekick**

### Webseiten öffnen

| Seite | URL | Beschreibung |
|-------|-----|--------------|
| **Scratch** | http://10.42.0.1:8601 | Scratch-Editor mit SIDEKICK-Extension |
| **Dashboard** | http://10.42.0.1:8080 | Projektverwaltung & Fernsteuerung |

**Über LAN (ohne Hotspot):**
- Scratch: `http://sidekick-xxx.local:8601`
- Dashboard: `http://sidekick-xxx.local:8080`

---

## Kiosk-Modus

Der Kiosk-Modus zeigt die Scratch-Bühne im Vollbild auf einem am Pi angeschlossenen Display.

```
┌────────────────────┐            ┌───────────────────┐
│      Tablet        │◄── WLAN ──►│   Raspberry Pi    │
│   (Dashboard)      │            │   + Display       │
│                    │            │                   │
│  • Projekt wählen  │            │  Zeigt Scratch-   │
│  • Start/Stop      │            │  Bühne (Vollbild) │
└────────────────────┘            └───────────────────┘
```

**So funktioniert's:**
1. Am Tablet: Dashboard öffnen (`http://10.42.0.1:8080`)
2. Projekt auswählen und "Auf Display laden" klicken
3. Mit "Start" die grüne Flagge auslösen

**Kiosk manuell steuern:**
```bash
# Beenden (falls nötig)
pkill -f 'chromium.*kiosk'

# Starten
systemctl start sidekick-kiosk
```

---

## Dienste verwalten

```bash
# Status aller SIDEKICK-Dienste anzeigen
systemctl status sidekick-*

# Einzelne Dienste starten/stoppen
sudo systemctl start sidekick-webapp
sudo systemctl stop sidekick-kiosk
sudo systemctl restart sidekick-dashboard

# Logs anzeigen
journalctl -u sidekick-webapp -f
```

---

## Fehlerbehebung

### WLAN-Hotspot erscheint nicht
```bash
# Hotspot-Status prüfen
nmcli connection show --active

# Hotspot manuell starten
nmcli connection up Hotspot
```

### Scratch lädt nicht
```bash
# Webapp-Service prüfen
sudo systemctl status sidekick-webapp
sudo systemctl restart sidekick-webapp
```

### Kiosk-Modus startet nicht nach Reboot
```bash
# Service aktivieren
sudo systemctl enable sidekick-kiosk
sudo reboot
```

### Verbindung über .local funktioniert nicht
Avahi/mDNS muss installiert sein:
```bash
sudo apt install avahi-daemon
sudo systemctl enable avahi-daemon
```

---

## Dateipfade

| Pfad | Inhalt |
|------|--------|
| `~/Sidekick/sidekick/` | Scratch Webapp |
| `~/Sidekick/dashboard/` | Dashboard |
| `~/Sidekick/python/` | Python-Skripte (Sensoren, LEDs) |
| `/etc/systemd/system/sidekick-*.service` | Systemd-Dienste |

---

## Updates

Für ein Update einfach das Setup-Script erneut ausführen:
```bash
curl -fsSL https://raw.githubusercontent.com/Mixality/sidekick-scratch-extension-development/master/RPi/sidekick-setup.sh | sudo bash -s -- --force --kiosk
```

---

## Support

Bei Problemen oder Fragen:
- GitHub Issues: https://github.com/Mixality/sidekick-scratch-extension-development/issues
