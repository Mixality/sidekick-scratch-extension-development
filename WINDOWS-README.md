# 🚀 Scratch Extension Development - Schnellübersicht

Alle PowerShell-Skripte für lokale Windows-Entwicklung! ✅

## 📋 Verfügbare Kommandos

```powershell
# 1. Einmaliges Setup (nur beim ersten Mal)
.\0-setup.ps1

# 2. Extension bearbeiten
# → Öffne: sidekick-scratch-extension\index.js

# 3. Builden (nach jeder Änderung)
.\2-build.ps1

# 4. Lokal testen
.\3-run-private.ps1
# → Browser: http://localhost:8000

# 5. Dependencies verwalten
.\1-add-dependency.ps1 <paket>           # Intelligent hinzufügen
.\1-2-add-thirdparty-library.ps1 <paket> # Browser-Version laden
.\1-3-remove-dependency.ps1 <paket>      # Entfernen

# 6. Auf GitHub Pages veröffentlichen
.\4-publish.ps1
```

## 🎯 Typischer Workflow

1. Code bearbeiten in `sidekick-scratch-extension\index.js`
2. `.\2-build.ps1` ausführen
3. `.\3-run-private.ps1` zum Testen (Ctrl+C zum Stoppen)
4. Zurück zu Schritt 1

## 📚 Ausführliche Anleitung

Siehe **[WINDOWS-ANLEITUNG.md](WINDOWS-ANLEITUNG.md)** für:
- Voraussetzungen
- Detaillierte Erklärungen
- Troubleshooting
- Unterschiede zu Codespaces

## 🔗 Links

- Original Template: https://github.com/dalelane/scratch-extension-development
- Deine Version: https://mixality.github.io/sidekick-scratch-extension-development/scratch/
