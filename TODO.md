# SIDEKICK TODO Liste

## ✅ Erledigt (v1.0.1-test3)

- [x] GitHub Actions CI/CD eingerichtet
- [x] Pre-Release System (Tags mit `test`, `dev`, `beta`, `alpha`)
- [x] Install-Script: Dashboard-Service hinzugefügt
- [x] Install-Script: Kiosk-Modus mit Abfrage
- [x] Install-Script: Reboot-Abfrage am Ende
- [x] Hotspot-Name gekürzt (`SIDEKICK-RPi-XXXXXXXX`)
- [x] Patches aktualisiert (extension-manager.js, index.jsx, player.jsx)
- [x] Extension-Icons in patches/ kopiert

---

## 🔧 Offen

### Priorität 1 (Wichtig)

- [ ] **Update-Script: Service-Pfade prüfen/aktualisieren**
  - Problem: Wenn alte Services noch auf alte Pfade zeigen, funktioniert Update nicht richtig
  - Lösung: Im Update-Script prüfen ob Services aktualisiert werden müssen

- [ ] **Kiosk: Keyring-Dialog deaktivieren**
  - Chromium fragt beim Start nach Keyring-Passwort
  - Lösung: `--password-store=basic` Flag hinzufügen

- [ ] **Kiosk: Translate-Dialog deaktivieren**
  - Chromium zeigt Übersetzungs-Popup
  - Lösung: `--disable-translate` Flag hinzufügen

### Priorität 2 (Nice-to-have)

- [ ] **curl stderr unterdrücken**
  - Kosmetisch: `curl: (23) Failure writing...` Meldung verstecken
  - Lösung: `2>/dev/null` nach curl-Befehl

### Priorität 3 (Später)

- [ ] **Extensions in Unterordner verschieben (Refactoring)**
  - `sidekick-scratch-extension/` → `extensions/sidekick/`
  - `sidekick-scratch-mqtt-extension/` → `extensions/sidekickmqtt/`
  - Dann auch Workflow und Setup-Scripts anpassen

---

## 🚀 Meilensteine

- [ ] **Stabiles Release v1.0.1 erstellen**
  - Wenn alle Priorität-1 Punkte erledigt sind
  - `git tag v1.0.1 && git push origin v1.0.1`

---

## 💡 Ideen für später

- USB-Stick Auto-Import verbessern
- Mehrsprachigkeit (i18n) für Kiosk-Oberfläche
- Automatische Updates (Cronjob?)

---

*Zuletzt aktualisiert: 12. Dezember 2025*
