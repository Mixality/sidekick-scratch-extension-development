#!/bin/bash
# =============================================================================
# SIDEKICK USB-Import Wrapper
# =============================================================================
# Wird von udev aufgerufen wenn ein USB-Stick eingesteckt wird.
# Wartet kurz bis der Stick gemountet ist, dann startet den Import.
# =============================================================================

LOG_FILE="/var/log/sidekick-usb-import.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== USB-Event erkannt ==="
log "DEVNAME: ${DEVNAME:-unbekannt}"

# Warte bis das Gerät gemountet ist
sleep 3

# Finde Mount-Punkt
MOUNT_POINT=""

# Prüfe typische Mount-Punkte
for base in /media /mnt /run/media; do
    if [ -d "$base" ]; then
        # Suche nach kürzlich gemounteten Verzeichnissen
        for dir in "$base"/*/*/ "$base"/*/ 2>/dev/null; do
            if [ -d "$dir" ] && [ "$(stat -c %Y "$dir" 2>/dev/null)" ]; then
                # Prüfe ob es ein USB-Gerät ist (hat Dateien)
                if [ "$(ls -A "$dir" 2>/dev/null)" ]; then
                    MOUNT_POINT="$dir"
                    log "Mount-Punkt gefunden: $MOUNT_POINT"
                    break 2
                fi
            fi
        done
    fi
done

# Alternative: Nutze findmnt
if [ -z "$MOUNT_POINT" ]; then
    # Suche nach vfat/exfat/ntfs Mounts (typisch für USB-Sticks)
    MOUNT_POINT=$(findmnt -rno TARGET -t vfat,exfat,ntfs 2>/dev/null | head -1)
    if [ -n "$MOUNT_POINT" ]; then
        log "Mount-Punkt via findmnt: $MOUNT_POINT"
    fi
fi

if [ -z "$MOUNT_POINT" ]; then
    log "Kein Mount-Punkt gefunden, breche ab."
    exit 0
fi

# Führe Python-Import aus
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PYTHON_SCRIPT="$SCRIPT_DIR/sidekick-usb-import.py"

# Alternativ: Fester Pfad
if [ ! -f "$PYTHON_SCRIPT" ]; then
    PYTHON_SCRIPT="/home/*/Sidekick/python/sidekick-usb-import.py"
    PYTHON_SCRIPT=$(ls $PYTHON_SCRIPT 2>/dev/null | head -1)
fi

if [ -f "$PYTHON_SCRIPT" ]; then
    log "Starte Import: $PYTHON_SCRIPT $MOUNT_POINT"
    /usr/bin/python3 "$PYTHON_SCRIPT" "$MOUNT_POINT" >> "$LOG_FILE" 2>&1
    log "Import beendet mit Exit-Code: $?"
else
    log "FEHLER: Python-Script nicht gefunden: $PYTHON_SCRIPT"
fi

log "=== USB-Event abgeschlossen ==="
