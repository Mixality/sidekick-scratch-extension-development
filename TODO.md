# SIDEKICK TODO Liste

## ✅ Erledigt (v1.0.1)

- [x] GitHub Actions CI/CD eingerichtet
- [x] Pre-Release System (Tags mit `test`, `dev`, `beta`, `alpha`)
- [x] Install-Script: Dashboard-Service hinzugefügt
- [x] Install-Script: Kiosk-Modus mit Abfrage
- [x] Install-Script: Reboot-Abfrage am Ende
- [x] Hotspot-Name gekürzt (`SIDEKICK-RPi-XXXXXXXX`)
- [x] Patches aktualisiert (extension-manager.js, index.jsx, player.jsx)
- [x] Extension-Icons in patches/ kopiert
- [x] **Unified Setup-Script** (`sidekick-setup.sh`) - ersetzt install + update
- [x] **Automatische Install/Update Erkennung**
- [x] **Hostname-System** - eindeutiger Name pro Pi (`sidekick-XXXXXX.local`)
- [x] **mDNS/Avahi** - Pi erreichbar via `.local` Domain
- [x] **QR-Code Ausgabe** im Terminal nach Setup
- [x] **Kiosk: Keyring-Dialog deaktiviert** (`--password-store=basic`)
- [x] **Kiosk: Translate-Dialog deaktiviert** (`--disable-translate`)
- [x] **curl stderr unterdrückt** (`2>/dev/null`)
- [x] **Port-Standardisierung**: 8601 (Scratch), 5000 (Dashboard)
- [x] **Cleanup-Step** im Setup: Stoppt alte Services, gibt alte Ports frei
- [x] **Chromium-Pfad Auto-Erkennung** (`chromium` vs `chromium-browser`)
- [x] **Dynamische URLs im Dashboard** - funktioniert mit LAN und Hotspot
- [x] **Video-Upload Warnung** - prüft Größe, Auflösung, zeigt ffmpeg-Tipp
- [x] **MQTT über LAN** - Kiosk-Fernsteuerung vom Büro-PC
- [x] **Service-Start Fix** - Services starten nach Update korrekt
- [x] **Alte Scripts entfernt** - nur noch `sidekick-setup.sh`

---

## 🔧 Offen

### Priorität 1 (Nice-to-have)

- [ ] **Video Auto-Konvertierung (Optional)**
  - Checkbox "Automatisch konvertieren" beim Upload
  - Hintergrund-Job mit ffmpeg
  - Fortschrittsanzeige
  - Konvertiert zu H.264, 1080p, optimierte Größe

### Phase 2: USB-Stick Datei-Import ✅

- [x] **USB-Import Service (udev)**
  - Erkennt USB-Stick beim Einstecken
  - Sucht Ordner mit eigenem Hostname (z.B. `rpi-ws1/`)
  - Kopiert `videos/*` → `~/Sidekick/sidekick/videos/`
  - Kopiert `projects/*` → `~/Sidekick/sidekick/projects/`
  - Aktualisiert JSON-Listen (wiederverwendet Dashboard-Funktionen)
  - Schreibt IMPORT-ERGEBNIS.txt auf USB

- [x] **USB-Stick Struktur**
  ```
  USB-Stick/
  ├── rpi-ws1/
  │   ├── videos/
  │   └── projects/
  ├── rpi-ws2/
  │   └── ...
  ```

### Phase 3: Dashboard Einstellungen

- [ ] **Einstellungen-Tab im Dashboard**
  - Hostname ändern
  - QR-Code anzeigen/drucken
  - Netzwerk-Info

### Priorität 3 (Später)

- [ ] **Extensions in Unterordner verschieben (Refactoring)**
  - `sidekick-scratch-extension/` → `extensions/sidekick/`
  - `sidekick-scratch-mqtt-extension/` → `extensions/sidekickmqtt/`

---

## 🚀 Meilensteine

- [x] **v1.0.1-test6**: Unified Setup, Cleanup, Chromium-Fix ✅
- [ ] **v1.0.1**: Stabiles Release (nach Video-Warnung)
- [ ] **v1.1.0**: Mit USB-Datei-Import und Dashboard-Einstellungen
- [ ] **v1.2.0**: Mit Auto-Video-Konvertierung

---

## 💡 Architektur-Entscheidung

**Netzwerk-Ansatz für Büro → Werkstatt Workflow:**
- Pi läuft im Firmennetzwerk
- Vom Büro-PC: `http://sidekick-XXXXXX.local:8601` für Scratch
- Vom Büro-PC: `http://sidekick-XXXXXX.local:5000` für Dashboard
- Videos auf dem Pi → erscheinen sofort im Scratch-Dropdown
- Kein Export/Import nötig!

**Video-Anforderungen:**
- Codec: H.264 (AVC), VP8, VP9 ✅ | HEVC (H.265) ❌
- Auflösung: max. 1920x1080 empfohlen
- Dateigröße: max. 50MB empfohlen

---

*Zuletzt aktualisiert: 17. Dezember 2025*
