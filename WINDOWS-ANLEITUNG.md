# Scratch Extension Development - Lokale Windows-Anleitung

Dieses Projekt ist für die lokale Entwicklung von Scratch-Extensions auf Windows angepasst.

## Voraussetzungen

- **Node.js** (Version 18 oder höher) - [Download](https://nodejs.org/)
- **Git** - [Download](https://git-scm.com/)
- **Python 3** (optional, für Test-Server) - [Download](https://www.python.org/)

Du hast bereits Node.js v24 installiert, das ist perfekt! ✓

## Schnellstart

### 1. Einmaliges Setup

Führe das Setup-Skript **einmal** aus:

```powershell
.\0-setup.ps1
```

Dies wird:
- Die Scratch-Source-Code-Repositories herunterladen (`scratch-vm` und `scratch-gui`)
- Alle npm-Dependencies installieren
- Patches anwenden, um deine Extension zu integrieren
- **Die lokale scratch-vm Version mit der GUI verlinken** (npm link)

**Wichtig:** Beim Erstellen von symbolischen Links benötigt PowerShell evtl. Administrator-Rechte. Falls Fehler auftreten:
- Rechtsklick auf PowerShell → "Als Administrator ausführen"
- Oder aktiviere den Developer Mode: Windows-Einstellungen → Update & Sicherheit → Für Entwickler → Developer Mode

### 2. Extension bearbeiten

Deine Extension-Code ist hier:
```
sidekick-scratch-extension\index.js
```

Bearbeite diese Datei, um neue Blöcke hinzuzufügen oder das Verhalten zu ändern.

**Wichtig:** Das Build-Skript synchronisiert automatisch deine Änderungen in den `scratch-vm` Ordner!

### 3. Builden

Nach jeder Änderung musst du neu builden:

```powershell
.\2-build.ps1
```

Dies:
1. Synchronisiert deine Extension-Dateien automatisch
2. Kompiliert den Scratch-Code mit deiner Extension

### 4. Lokal testen

Starte einen Test-Server:

```powershell
.\3-run-private.ps1
```

Öffne dann im Browser: **http://localhost:8000**

Zum Stoppen: `Ctrl+C` im Terminal

## Workflow während der Entwicklung

1. **Code bearbeiten** → `sidekick-scratch-extension\index.js`
2. **Builden** → `.\2-build.ps1`
3. **Testen** → `.\3-run-private.ps1`
4. Wenn Server läuft: `Ctrl+C` drücken, dann zurück zu Schritt 1

## Dependencies hinzufügen

Du hast ein **intelligentes Dependency-System** mit drei Skripten:

### 1. Automatisches Hinzufügen (empfohlen)

```powershell
.\1-add-dependency.ps1 <paket-name>
```

**Was passiert:**
- Versucht zuerst `npm install`
- Prüft automatisch, ob das Paket Node.js-spezifische Module braucht
- **Wenn ja:** Lädt automatisch die Browser-Version herunter
- **Wenn nein:** Bleibt als npm-Dependency

**Beispiele:**
```powershell
.\1-add-dependency.ps1 syllable  # → npm dependency (browser-kompatibel)
.\1-add-dependency.ps1 mqtt      # → Browser-Version (hat Node.js-Module)
```

### 2. Manuell Browser-Version herunterladen

Falls du explizit die Browser-Version willst:

```powershell
.\1-2-add-thirdparty-library.ps1 mqtt
```

Lädt minifizierte Browser-Version von unpkg.com herunter nach:
`sidekick-thirdparty-libraries/mqtt/mqtt.min.js`

### 3. Dependencies entfernen

```powershell
.\1-3-remove-dependency.ps1 <paket-name>
```

Entfernt npm-Dependencies ODER Third-Party-Libraries automatisch.

## Publish (GitHub Pages veröffentlichen)

Um deine Extension öffentlich auf GitHub Pages zu veröffentlichen:

```powershell
.\4-publish.ps1
```

**Was passiert:**
- Committed deine Änderungen
- Baut deine Extension
- Erstellt/aktualisiert den `gh-pages` Branch
- Pusht zu GitHub

Deine Extension wird dann verfügbar unter:
```
https://<dein-github-username>.github.io/<dein-repo-name>/scratch/
```

**Hinweis:** Beim ersten Mal musst du GitHub Pages in den Repository-Einstellungen aktivieren:
- Gehe zu deinem Repo auf GitHub
- Settings → Pages
- Source: Deploy from branch
- Branch: `gh-pages` / `root`
- Save

## Unterschiede zu Codespaces

- **Codespaces** läuft in einem Docker-Container mit vorinstallierter Umgebung
- **Lokal** musst du Node.js, Git und Python selbst installieren
- Die `.sh` Bash-Skripte wurden zu `.ps1` PowerShell-Skripten umgewandelt
- Keine zeitliche Begrenzung wie bei Codespaces!

## Troubleshooting

### "Cannot create symbolic link" Fehler
→ PowerShell als Administrator ausführen oder Developer Mode aktivieren

### Build-Fehler mit OpenSSL
→ Wird automatisch mit `NODE_OPTIONS=--openssl-legacy-provider` gehandhabt

### Port 8000 bereits belegt
→ Ändere den Port in `3-run-private.ps1` (Zeile `$port = 8000`)

### Python nicht gefunden
→ Das Skript verwendet automatisch `http-server` (Node.js) als Fallback

## Nützliche Links

- Original Repository: https://github.com/dalelane/scratch-extension-development
- Original Instructions: https://github.com/dalelane/scratch-extension-development/blob/master/INSTRUCTIONS.md
- Deine publizierte Version: https://mixality.github.io/sidekick-scratch-extension-development/scratch/

## Projektstruktur

```
sidekick-scratch-extension-development/
├── 0-setup.ps1                    # Einmaliges Setup ✅
├── 1-add-dependency.ps1           # Dependency hinzufügen (intelligent) ✅
├── 1-2-add-thirdparty-library.ps1 # Browser-Library herunterladen ✅
├── 1-3-remove-dependency.ps1      # Dependency entfernen ✅
├── 2-build.ps1                    # Build-Skript ✅
├── 3-run-private.ps1              # Test-Server ✅
├── 4-publish.ps1                  # GitHub Pages Publish ✅
├── sidekick-scratch-extension/    # Deine Extension
│   └── index.js                   # Hauptdatei für deine Blöcke
├── sidekick-thirdparty-libraries/ # Third-party JS libraries (Browser-Versionen)
│   └── mqtt/                      # Beispiel: mqtt.min.js
├── patches/                       # Git-Patches für Scratch
├── dependencies/                  # npm dependencies
├── scratch-vm/                    # Scratch VM (nach Setup)
└── scratch-gui/                   # Scratch GUI (nach Setup)
```

## Fragen?

Bei Problemen kannst du:
1. Die Original-Anleitung durchlesen (auf Englisch)
2. In den Issues des Original-Repos nachschauen
3. Die Scratch-Extension-Dokumentation ansehen
