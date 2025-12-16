# SIDEKICK M5StickC Firmware

Diese Firmware verbindet den M5StickC mit SIDEKICK über MQTT.

## Funktionsweise

| Button | Position | Funktion |
|--------|----------|----------|
| **A** | Großer Button (vorne) | **Event senden** (pressed/released) |
| **B kurz** | Seitlicher Button | Nummer hoch (1→2→3→4→1...) |
| **B lang** | Seitlicher Button (>0.5s) | Nummer runter |

### Display zeigt:
- Aktuelle Button-Nummer (1-4) groß
- Verbindungsstatus (grün/rot)
- Aktuelles MQTT Topic

## MQTT Topics

Die Firmware sendet an das Topic der gewählten Nummer:

```
sidekick/button/1/state → "pressed" / "released"
sidekick/button/2/state → "pressed" / "released"
sidekick/button/3/state → "pressed" / "released"
sidekick/button/4/state → "pressed" / "released"
```

## Installation

### 1. Arduino IDE vorbereiten

1. Arduino IDE installieren: https://www.arduino.cc/en/software
2. ESP32 Board Support hinzufügen:
   - Datei → Einstellungen → Zusätzliche Boardverwalter-URLs:
   - `https://dl.espressif.com/dl/package_esp32_index.json`
3. Werkzeuge → Board → Boardverwalter → "esp32" suchen → Installieren

### 2. Libraries installieren

Sketch → Bibliothek einbinden → Bibliotheken verwalten:
- **M5StickC** (von M5Stack)
- **PubSubClient** (von Nick O'Leary)

### 3. Board auswählen

- Werkzeuge → Board → ESP32 Arduino → **M5Stick-C**
- Port auswählen (COM-Port des M5StickC)

### 4. Konfiguration anpassen (falls nötig)

In `sidekick-m5stickc.ino`:

```cpp
// WLAN Zugangsdaten (SIDEKICK Hotspot)
const char* WIFI_SSID = "SIDEKICK-RPI";      // Anpassen falls anders benannt
const char* WIFI_PASSWORD = "sidekick";
```

### 5. Hochladen

- Sketch → Hochladen
- Warten bis "Done uploading" erscheint

## Verwendung

1. M5StickC einschalten
2. Verbindet sich automatisch mit dem SIDEKICK Hotspot
3. Display zeigt Nummer "1" wenn verbunden
4. **Button B** kurz drücken um Nummer zu wechseln
5. **Button A** drücken um Event zu senden!

## In Scratch verwenden

```
┌─────────────────────────────────────┐
│ Wenn Button [1 ▼] [gedrückt ▼] wird │
├─────────────────────────────────────┤
│   sage "Button wurde gedrückt!"     │
└─────────────────────────────────────┘
```

**Wichtig:** Die Nummer am M5StickC und in Scratch müssen übereinstimmen!

## LED/Feedback

- **Grüner Blitz**: Button A gedrückt, gesendet
- **Blauer Blitz**: Button B gedrückt, gesendet
- **Roter Blitz**: Nicht verbunden

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| WiFi verbindet nicht | Hotspot-Name prüfen (SIDEKICK-RPI vs SIDEKICK-RPI-2) |
| MQTT Fehler | Pi muss laufen, Mosquitto aktiv |
| Kein Upload möglich | Richtigen COM-Port auswählen, Treiber installieren |

## Erweiterungsmöglichkeiten

- Accelerometer auslesen (Schütteln erkennen)
- LED-Farbe über MQTT steuern
- Mehrere M5StickC mit unterschiedlichen IDs
