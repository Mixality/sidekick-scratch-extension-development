# SIDEKICK M5GO Firmware

Firmware für den **M5Stack M5GO IoT Starter Kit V2.7** zur Integration mit SIDEKICK.

## Funktionsweise

Das M5GO hat 3 Buttons - wir nutzen sie so:

| Button | Position | Funktion |
|--------|----------|----------|
| **A** | Links | Nummer runter (4 → 3 → 2 → 1 → 4...) |
| **B** | Mitte | **Event senden** (pressed/released) |
| **C** | Rechts | Nummer hoch (1 → 2 → 3 → 4 → 1...) |

### Display zeigt:
- Aktuelle Button-Nummer (1-4) groß in der Mitte
- Verbindungsstatus (WiFi/MQTT)
- Aktuelles MQTT Topic

## MQTT Topics

Die Firmware sendet an das Topic der gewählten Nummer:

```
sidekick/button/1/state → "pressed" / "released"
sidekick/button/2/state → "pressed" / "released"
sidekick/button/3/state → "pressed" / "released"
sidekick/button/4/state → "pressed" / "released"
```

## Installation mit PlatformIO

### 1. PlatformIO installieren

- VS Code Extension: "PlatformIO IDE" installieren
- Oder: `pip install platformio`

### 2. Projekt öffnen

```bash
cd m5go
pio run  # Kompilieren
```

### 3. Hochladen

```bash
pio run -t upload
```

Oder in VS Code: PlatformIO Icon → Upload

### 4. Serial Monitor

```bash
pio device monitor
```

## Konfiguration

In `src/main.cpp` bei Bedarf anpassen:

```cpp
// WLAN Zugangsdaten (SIDEKICK Hotspot)
const char* WIFI_SSID = "SIDEKICK-RPI";
const char* WIFI_PASSWORD = "sidekick";

// MQTT Broker
const char* MQTT_SERVER = "10.42.0.1";

// Button-Nummern Bereich (Standard: 1-4)
const int MIN_BUTTON = 1;
const int MAX_BUTTON = 4;
```

## Verwendung

1. **M5GO einschalten** - verbindet automatisch mit SIDEKICK Hotspot
2. **Nummer wählen** mit Button A/C (links/rechts)
3. **Button B drücken** - sendet Event für gewählte Nummer

## In Scratch verwenden

```
┌─────────────────────────────────────┐
│ Wenn Button [1 ▼] [gedrückt ▼] wird │
├─────────────────────────────────────┤
│   sage "Button 1 wurde gedrückt!"   │
└─────────────────────────────────────┘
```

Das M5GO und Scratch müssen die **gleiche Nummer** verwenden!

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| "WiFi getrennt" | SIDEKICK Hotspot aktiv? Richtige SSID? |
| "MQTT getrennt" | SIDEKICK Services gestartet? |
| Event kommt nicht an | Gleiche Button-Nummer in Scratch? |

## Unterschied zum M5StickC

Die [M5StickC-Firmware](../m5stickc/) ist für das kleinere M5StickC mit nur 2 Buttons gedacht und nutzt feste Topics (A/B). Diese M5GO-Firmware ist flexibler und lässt dich die Button-Nummer am Gerät wählen.
