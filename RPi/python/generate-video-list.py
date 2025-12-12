#!/usr/bin/env python3
"""
SIDEKICK Video-Liste Generator

Dieses Skript scannt den Videos-Ordner und erstellt/aktualisiert die video-list.json Datei.
Kann manuell oder als Teil eines automatischen Prozesses ausgeführt werden.

Verwendung:
    python3 generate-video-list.py

Oder mit benutzerdefiniertem Pfad:
    python3 generate-video-list.py /pfad/zum/videos/ordner
"""

import os
import json
import sys

# Standard Video-Ordner Pfade
DEFAULT_PATHS = [
    os.path.expanduser("~/Sidekick/videos"),
    os.path.expanduser("~/Sidekick/sidekick/videos"),
    "/home/sidekick/Sidekick/videos"
]

# Unterstützte Video-Formate
VIDEO_EXTENSIONS = {'.mp4', '.webm', '.ogg', '.ogv', '.mov', '.avi', '.mkv'}

def find_videos_folder():
    """Findet den Videos-Ordner"""
    for path in DEFAULT_PATHS:
        if os.path.isdir(path):
            return path
    return None

def generate_video_list(videos_dir):
    """Generiert die video-list.json aus den Dateien im Ordner"""
    if not os.path.isdir(videos_dir):
        print(f"Fehler: Ordner existiert nicht: {videos_dir}")
        return False
    
    # Finde alle Video-Dateien
    video_files = []
    for filename in sorted(os.listdir(videos_dir)):
        ext = os.path.splitext(filename)[1].lower()
        if ext in VIDEO_EXTENSIONS:
            video_files.append(filename)
    
    # Schreibe video-list.json
    list_file = os.path.join(videos_dir, "video-list.json")
    with open(list_file, 'w', encoding='utf-8') as f:
        json.dump(video_files, f, indent=2, ensure_ascii=False)
    
    print(f"✓ video-list.json erstellt in: {videos_dir}")
    print(f"  Gefundene Videos: {len(video_files)}")
    for vf in video_files:
        print(f"    - {vf}")
    
    return True

def main():
    # Bestimme den Videos-Ordner
    if len(sys.argv) > 1:
        videos_dir = sys.argv[1]
    else:
        videos_dir = find_videos_folder()
        if not videos_dir:
            print("Fehler: Kein Videos-Ordner gefunden.")
            print("Bitte erstelle einen der folgenden Ordner:")
            for path in DEFAULT_PATHS:
                print(f"  - {path}")
            print("\nOder gib den Pfad als Argument an:")
            print("  python3 generate-video-list.py /pfad/zum/ordner")
            sys.exit(1)
    
    print(f"Videos-Ordner: {videos_dir}")
    
    # Erstelle Ordner falls nicht vorhanden
    if not os.path.exists(videos_dir):
        os.makedirs(videos_dir)
        print(f"Ordner erstellt: {videos_dir}")
    
    # Generiere die Liste
    success = generate_video_list(videos_dir)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
