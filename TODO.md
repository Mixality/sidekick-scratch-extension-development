# SIDEKICK TODO Liste

## ✅ Erledigt (v1.0.1-test4)

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

---

## 🔧 Offen

### Phase 2: USB-Stick Auto-Setup

- [ ] **Service für USB-Erkennung**
  - udev-Regel die auf USB-Stick mit `sidekick-setup.sh` wartet
  - Führt Setup automatisch aus
  - Schreibt ERGEBNIS.txt auf den Stick

- [ ] **QR-Code als PNG auf Stick speichern**
  - Für Sticker-Druck

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

- [ ] **v1.0.1-test4**: Unified Setup-Script testen
- [ ] **v1.0.1**: Stabiles Release (nach erfolgreichem Test)
- [ ] **v1.1.0**: Mit USB-Auto-Setup und Dashboard-Einstellungen

---

## 💡 Architektur-Entscheidung

**Netzwerk-Ansatz für Büro → Werkstatt Workflow:**
- Pi läuft im Firmennetzwerk
- Vom Büro-PC: `http://sidekick-XXXXXX.local:8601` für Scratch
- Vom Büro-PC: `http://sidekick-XXXXXX.local:5000` für Dashboard
- Videos auf dem Pi → erscheinen sofort im Scratch-Dropdown
- Kein Export/Import nötig!

---

*Zuletzt aktualisiert: 14. Dezember 2024*
