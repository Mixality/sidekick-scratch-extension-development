#!/usr/bin/env python3
"""
SIDEKICK File Utilities

Gemeinsame Funktionen für Datei-Management:
- Video-Liste aktualisieren
- Projekt-Liste aktualisieren
- Pfad-Konfiguration

Wird verwendet von:
- sidekick-dashboard.py (Web-Upload)
- sidekick-usb-import.py (USB-Import)
"""

import json
from pathlib import Path

# Konfiguration
VIDEO_EXTENSIONS = {'.mp4', '.webm', '.ogg', '.ogv', '.mov', '.avi', '.mkv'}
PROJECT_EXTENSIONS = {'.sb3'}

# Pfade (werden durch setup_paths() gesetzt)
SIDEKICK_DIR = None
VIDEOS_DIR = None
PROJECTS_DIR = None
SCRATCH_DIR = None


def setup_paths():
    """Initialisiert die Pfade basierend auf dem Home-Verzeichnis"""
    global SIDEKICK_DIR, VIDEOS_DIR, PROJECTS_DIR, SCRATCH_DIR
    
    home = Path.home()
    SIDEKICK_DIR = home / "Sidekick"
    SCRATCH_DIR = SIDEKICK_DIR / "sidekick"
    VIDEOS_DIR = SCRATCH_DIR / "videos"
    PROJECTS_DIR = SCRATCH_DIR / "projects"
    
    # Erstelle Ordner falls nicht vorhanden
    VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
    PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
    
    return SIDEKICK_DIR, VIDEOS_DIR, PROJECTS_DIR, SCRATCH_DIR


def get_paths():
    """Gibt die aktuellen Pfade zurück, initialisiert falls nötig"""
    global SIDEKICK_DIR, VIDEOS_DIR, PROJECTS_DIR, SCRATCH_DIR
    
    if SIDEKICK_DIR is None:
        setup_paths()
    
    return SIDEKICK_DIR, VIDEOS_DIR, PROJECTS_DIR, SCRATCH_DIR


def update_video_list(videos_dir=None):
    """
    Aktualisiert video-list.json basierend auf den Dateien im Videos-Ordner
    
    Args:
        videos_dir: Optional - Pfad zum Videos-Ordner. Falls None, wird VIDEOS_DIR verwendet.
    
    Returns:
        Liste der Video-Dateinamen
    """
    if videos_dir is None:
        _, videos_dir, _, _ = get_paths()
    
    videos_dir = Path(videos_dir)
    
    video_files = []
    for f in sorted(videos_dir.iterdir()):
        if f.suffix.lower() in VIDEO_EXTENSIONS:
            video_files.append(f.name)
    
    list_file = videos_dir / "video-list.json"
    with open(list_file, 'w', encoding='utf-8') as f:
        json.dump(video_files, f, indent=2, ensure_ascii=False)
    
    return video_files


def update_project_list(projects_dir=None):
    """
    Aktualisiert project-list.json basierend auf den Dateien im Projects-Ordner
    
    Args:
        projects_dir: Optional - Pfad zum Projects-Ordner. Falls None, wird PROJECTS_DIR verwendet.
    
    Returns:
        Liste der Projekt-Dateinamen
    """
    if projects_dir is None:
        _, _, projects_dir, _ = get_paths()
    
    projects_dir = Path(projects_dir)
    
    project_files = []
    for f in sorted(projects_dir.iterdir()):
        if f.suffix.lower() in PROJECT_EXTENSIONS:
            project_files.append(f.name)
    
    list_file = projects_dir / "project-list.json"
    with open(list_file, 'w', encoding='utf-8') as f:
        json.dump(project_files, f, indent=2, ensure_ascii=False)
    
    return project_files


def update_all_lists():
    """Aktualisiert beide Listen (Videos und Projekte)"""
    videos = update_video_list()
    projects = update_project_list()
    return videos, projects


if __name__ == "__main__":
    # Test
    setup_paths()
    print(f"SIDEKICK_DIR: {SIDEKICK_DIR}")
    print(f"VIDEOS_DIR: {VIDEOS_DIR}")
    print(f"PROJECTS_DIR: {PROJECTS_DIR}")
    
    videos = update_video_list()
    projects = update_project_list()
    
    print(f"\nVideos: {videos}")
    print(f"Projects: {projects}")
