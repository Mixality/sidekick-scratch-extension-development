#!/usr/bin/env python3
"""
SIDEKICK USB Import Service

Importiert Videos und Projekte von USB-Sticks automatisch.

Funktionsweise:
1. Wird durch udev bei USB-Einstecken getriggert
2. Sucht auf dem Stick nach Ordner mit eigenem Hostname
3. Kopiert videos/ und projects/ in die SIDEKICK-Ordner
4. Aktualisiert die JSON-Listen

USB-Stick Struktur:
    USB-Stick/
    ├── rpi-ws1/           (Hostname des Ziel-Pi)
    │   ├── videos/
    │   │   └── anleitung.mp4
    │   └── projects/
    │       └── projekt.sb3
    ├── rpi-ws2/
    │   └── ...

Verwendung:
    python3 sidekick-usb-import.py /media/pi/USB-STICK
    
    Oder automatisch via udev/systemd.
"""

import os
import sys
import socket
import shutil
import logging
from pathlib import Path
from datetime import datetime

# Importiere gemeinsame Funktionen
try:
    from sidekick_files import (
        setup_paths,
        update_video_list,
        update_project_list,
        VIDEO_EXTENSIONS,
        PROJECT_EXTENSIONS
    )
except ImportError:
    print("FEHLER: sidekick_files.py nicht gefunden!")
    print("Stelle sicher, dass das Script im gleichen Ordner liegt.")
    sys.exit(1)

# Logging einrichten
LOG_FILE = Path.home() / "Sidekick" / "logs" / "usb-import.log"
LOG_FILE.parent.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


def get_hostname():
    """Ermittelt den Hostnamen des Pi"""
    hostname = socket.gethostname()
    # Entferne 'sidekick-' Prefix falls vorhanden
    if hostname.startswith('sidekick-'):
        return hostname[9:]  # Ohne Prefix
    return hostname


def get_all_possible_hostnames():
    """
    Gibt alle möglichen Hostnamen zurück, die auf dem USB-Stick
    gesucht werden sollen.
    """
    hostname = socket.gethostname()
    hostnames = [hostname]
    
    # Mit und ohne 'sidekick-' Prefix
    if hostname.startswith('sidekick-'):
        hostnames.append(hostname[9:])
    else:
        hostnames.append(f'sidekick-{hostname}')
    
    # Hostname-Datei prüfen
    hostname_file = Path.home() / "Sidekick" / "HOSTNAME"
    if hostname_file.exists():
        saved_hostname = hostname_file.read_text().strip()
        if saved_hostname and saved_hostname not in hostnames:
            hostnames.append(saved_hostname)
    
    return hostnames


def find_usb_folder(usb_mount_path):
    """
    Sucht auf dem USB-Stick nach einem Ordner, der zum Hostnamen passt.
    
    Returns:
        Path zum gefundenen Ordner oder None
    """
    usb_path = Path(usb_mount_path)
    
    if not usb_path.exists():
        logger.error(f"USB-Pfad existiert nicht: {usb_path}")
        return None
    
    hostnames = get_all_possible_hostnames()
    logger.info(f"Suche nach Ordnern: {hostnames}")
    
    for hostname in hostnames:
        folder = usb_path / hostname
        if folder.exists() and folder.is_dir():
            logger.info(f"Gefunden: {folder}")
            return folder
    
    logger.info("Kein passender Ordner gefunden.")
    return None


def copy_files(source_dir, target_dir, extensions):
    """
    Kopiert Dateien mit bestimmten Erweiterungen.
    
    Returns:
        Liste der kopierten Dateinamen
    """
    copied = []
    source_path = Path(source_dir)
    target_path = Path(target_dir)
    
    if not source_path.exists():
        return copied
    
    target_path.mkdir(parents=True, exist_ok=True)
    
    for file in source_path.iterdir():
        if file.is_file() and file.suffix.lower() in extensions:
            target_file = target_path / file.name
            
            # Prüfe ob Datei schon existiert
            if target_file.exists():
                # Überschreiben wenn neuer
                if file.stat().st_mtime > target_file.stat().st_mtime:
                    logger.info(f"Aktualisiere: {file.name}")
                    shutil.copy2(file, target_file)
                    copied.append(file.name)
                else:
                    logger.info(f"Überspringe (nicht neuer): {file.name}")
            else:
                logger.info(f"Kopiere: {file.name}")
                shutil.copy2(file, target_file)
                copied.append(file.name)
    
    return copied


def import_from_usb(usb_mount_path):
    """
    Hauptfunktion: Importiert Dateien vom USB-Stick.
    
    Args:
        usb_mount_path: Pfad zum gemounteten USB-Stick
        
    Returns:
        Tuple (videos_copied, projects_copied) oder (None, None) bei Fehler
    """
    logger.info(f"=== USB-Import gestartet: {usb_mount_path} ===")
    
    # Pfade initialisieren
    sidekick_dir, videos_dir, projects_dir, _ = setup_paths()
    
    # Passenden Ordner auf USB suchen
    usb_folder = find_usb_folder(usb_mount_path)
    
    if usb_folder is None:
        logger.info("Kein Import nötig - kein passender Ordner gefunden.")
        return None, None
    
    # Videos kopieren
    usb_videos = usb_folder / "videos"
    videos_copied = copy_files(usb_videos, videos_dir, VIDEO_EXTENSIONS)
    
    # Projekte kopieren
    usb_projects = usb_folder / "projects"
    projects_copied = copy_files(usb_projects, projects_dir, PROJECT_EXTENSIONS)
    
    # JSON-Listen aktualisieren
    if videos_copied:
        update_video_list()
        logger.info(f"video-list.json aktualisiert")
    
    if projects_copied:
        update_project_list()
        logger.info(f"project-list.json aktualisiert")
    
    # Zusammenfassung
    logger.info(f"=== Import abgeschlossen ===")
    logger.info(f"Videos kopiert: {len(videos_copied)}")
    logger.info(f"Projekte kopiert: {len(projects_copied)}")
    
    # Ergebnis-Datei auf USB schreiben (optional)
    try:
        result_file = usb_folder / "IMPORT-ERGEBNIS.txt"
        with open(result_file, 'w', encoding='utf-8') as f:
            f.write(f"SIDEKICK USB-Import\n")
            f.write(f"==================\n\n")
            f.write(f"Zeitpunkt: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Hostname: {socket.gethostname()}\n\n")
            f.write(f"Videos kopiert: {len(videos_copied)}\n")
            for v in videos_copied:
                f.write(f"  - {v}\n")
            f.write(f"\nProjekte kopiert: {len(projects_copied)}\n")
            for p in projects_copied:
                f.write(f"  - {p}\n")
        logger.info(f"Ergebnis gespeichert: {result_file}")
    except Exception as e:
        logger.warning(f"Konnte Ergebnis-Datei nicht schreiben: {e}")
    
    return videos_copied, projects_copied


def main():
    """Haupteinsprungpunkt"""
    if len(sys.argv) < 2:
        print("Verwendung: python3 sidekick-usb-import.py <USB-MOUNT-PFAD>")
        print("Beispiel:   python3 sidekick-usb-import.py /media/pi/USB-STICK")
        sys.exit(1)
    
    usb_path = sys.argv[1]
    videos, projects = import_from_usb(usb_path)
    
    if videos is None and projects is None:
        sys.exit(0)  # Kein Fehler, nur nichts zu tun
    
    total = len(videos or []) + len(projects or [])
    if total > 0:
        print(f"\n✅ Import erfolgreich: {len(videos or [])} Videos, {len(projects or [])} Projekte")
    else:
        print("\nKeine neuen Dateien zu importieren.")


if __name__ == "__main__":
    main()
