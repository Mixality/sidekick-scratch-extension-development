#!/bin/bash
# =============================================================================
# SIDEKICK Desktop-Shortcuts installieren
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DESKTOP_DIR="$HOME/Desktop"

echo "Installiere SIDEKICK Desktop-Shortcuts..."

# Desktop-Ordner erstellen falls nicht vorhanden
mkdir -p "$DESKTOP_DIR"

# Alle .desktop Dateien kopieren
cp "$SCRIPT_DIR"/*.desktop "$DESKTOP_DIR/" 2>/dev/null || {
    echo "Keine .desktop Dateien gefunden in $SCRIPT_DIR"
    exit 1
}

# Ausfuehrbar machen
chmod +x "$DESKTOP_DIR"/sidekick-*.desktop

# Bei neueren RPi OS: "Trust" setzen (damit sie ohne Warnung starten)
if command -v gio &> /dev/null; then
    for f in "$DESKTOP_DIR"/sidekick-*.desktop; do
        gio set "$f" metadata::trusted true 2>/dev/null || true
    done
fi

echo ""
echo "Fertig! Folgende Shortcuts wurden installiert:"
ls -1 "$DESKTOP_DIR"/sidekick-*.desktop 2>/dev/null | while read f; do
    echo "  - $(basename "$f")"
done
echo ""
