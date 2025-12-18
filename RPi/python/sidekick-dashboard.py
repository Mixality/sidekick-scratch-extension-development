#!/usr/bin/env python3
"""
SIDEKICK Dashboard Server

Ein einfacher Webserver für:
- Video-Upload
- Projekt-Upload (.sb3 Dateien)
- Übersicht aller Dateien
- Automatische video-list.json Generierung
- Display/Kiosk-Steuerung via MQTT

Startet auf Port 5000 (Scratch läuft auf 8601)

Verwendung:
    python3 sidekick-dashboard.py
"""

import os
import sys
import json
import html as html_module
import re
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import shutil
import io

# Importiere gemeinsame Funktionen
try:
    from sidekick_files import (
        setup_paths as _setup_paths, 
        update_video_list, 
        update_project_list,
        VIDEO_EXTENSIONS,
        PROJECT_EXTENSIONS
    )
except ImportError:
    # Fallback falls Import fehlschlägt
    VIDEO_EXTENSIONS = {'.mp4', '.webm', '.ogg', '.ogv', '.mov', '.avi', '.mkv'}
    PROJECT_EXTENSIONS = {'.sb3'}
    _setup_paths = None

# Konfiguration
DASHBOARD_PORT = 5000
SCRATCH_PORT = 8601
KIOSK_PORT = 8601  # Kiosk läuft auf dem gleichen Port wie Scratch

# Pfade (werden beim Start gesetzt)
SIDEKICK_DIR = None
VIDEOS_DIR = None
PROJECTS_DIR = None
SCRATCH_DIR = None


def setup_paths():
    """Initialisiert die Pfade basierend auf dem Home-Verzeichnis"""
    global SIDEKICK_DIR, VIDEOS_DIR, PROJECTS_DIR, SCRATCH_DIR
    
    # Nutze gemeinsame Funktion falls verfügbar
    if _setup_paths is not None:
        SIDEKICK_DIR, VIDEOS_DIR, PROJECTS_DIR, SCRATCH_DIR = _setup_paths()
    else:
        # Fallback
        home = Path.home()
        SIDEKICK_DIR = home / "Sidekick"
        SCRATCH_DIR = SIDEKICK_DIR / "sidekick"
        VIDEOS_DIR = SCRATCH_DIR / "videos"
        PROJECTS_DIR = SCRATCH_DIR / "projects"
        
        VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
        PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
    
    print(f"SIDEKICK Directory: {SIDEKICK_DIR}")
    print(f"Videos Directory: {VIDEOS_DIR}")
    print(f"Projects Directory: {PROJECTS_DIR}")


# Hinweis: update_video_list() und update_project_list() werden aus sidekick_files importiert
# Falls der Import fehlschlägt, sind hier Fallback-Implementierungen:
if _setup_paths is None:
    def update_video_list():
        """Fallback: Aktualisiert video-list.json"""
        video_files = []
        for f in sorted(VIDEOS_DIR.iterdir()):
            if f.suffix.lower() in VIDEO_EXTENSIONS:
                video_files.append(f.name)
        
        list_file = VIDEOS_DIR / "video-list.json"
        with open(list_file, 'w', encoding='utf-8') as f:
            json.dump(video_files, f, indent=2, ensure_ascii=False)
        
        return video_files


    def update_project_list():
        """Fallback: Aktualisiert project-list.json"""
        project_files = []
        for f in sorted(PROJECTS_DIR.iterdir()):
            if f.suffix.lower() in PROJECT_EXTENSIONS:
                project_files.append(f.name)
        
        list_file = PROJECTS_DIR / "project-list.json"
        with open(list_file, 'w', encoding='utf-8') as f:
            json.dump(project_files, f, indent=2, ensure_ascii=False)
        
        return project_files


def get_file_size_str(size_bytes):
    """Formatiert Dateigröße als lesbare Zeichenkette"""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.1f} GB"


# HTML Templates
HTML_HEADER = """<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SIDEKICK-Dashboard</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            color: #eee;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 {
            color: #0E9D59;
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        h2 {
            color: #0E9D59;
            border-bottom: 2px solid #0E9D59;
            padding-bottom: 10px;
        }
        .card {
            background: rgba(255,255,255,0.1);
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 25px;
            backdrop-filter: blur(10px);
        }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .upload-form {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        input[type="file"] {
            padding: 15px;
            border: 2px dashed #0E9D59;
            border-radius: 10px;
            background: rgba(14, 157, 89, 0.1);
            color: #eee;
            cursor: pointer;
        }
        input[type="file"]:hover {
            background: rgba(14, 157, 89, 0.2);
        }
        button, .btn {
            background: #0E9D59;
            color: white;
            border: none;
            padding: 15px 25px;
            border-radius: 10px;
            cursor: pointer;
            font-size: 1em;
            font-weight: bold;
            text-decoration: none;
            display: inline-block;
            text-align: center;
            transition: all 0.3s;
        }
        button:hover, .btn:hover {
            background: #0c8a4e;
            transform: translateY(-2px);
        }
        .btn-danger { background: #e74c3c; }
        .btn-danger:hover { background: #c0392b; }
        .btn-secondary { background: #3498db; }
        .btn-secondary:hover { background: #2980b9; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        th { color: #0E9D59; font-weight: bold; }
        tr:hover { background: rgba(255,255,255,0.05); }
        .actions { display: flex; gap: 10px; }
        .status { padding: 15px; border-radius: 10px; margin-bottom: 20px; }
        .status-success { background: rgba(14, 157, 89, 0.3); border: 1px solid #0E9D59; }
        .status-error { background: rgba(231, 76, 60, 0.3); border: 1px solid #e74c3c; }
        .scratch-link {
            display: block;
            text-align: center;
            padding: 20px;
            background: linear-gradient(135deg, #0E9D59, #0c8a4e);
            border-radius: 15px;
            color: white;
            text-decoration: none;
            font-size: 1.3em;
            font-weight: bold;
            margin-bottom: 25px;
            transition: all 0.3s;
        }
        .scratch-link:hover {
            transform: scale(1.02);
            box-shadow: 0 10px 30px rgba(14, 157, 89, 0.4);
        }
        .empty-state {
            text-align: center;
            padding: 40px;
            color: #888;
        }
        /* Display Control Styles */
        .display-control {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        .display-status {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 15px;
            background: rgba(0,0,0,0.3);
            border-radius: 10px;
        }
        .status-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #888;
        }
        .status-dot.connected { background: #4CAF50; box-shadow: 0 0 10px #4CAF50; }
        .status-dot.disconnected { background: #ff9800; animation: pulse 1.5s infinite; }
        .control-buttons {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        .btn-start { background: #4CAF50; }
        .btn-start:hover { background: #45a049; }
        .btn-stop { background: #f44336; }
        .btn-stop:hover { background: #da190b; }
        .btn-display { background: #9c27b0; }
        .btn-display:hover { background: #7b1fa2; }
        .project-select {
            padding: 12px;
            border-radius: 10px;
            border: 2px solid #0E9D59;
            background: rgba(14, 157, 89, 0.1);
            color: #eee;
            font-size: 1em;
            cursor: pointer;
        }
        .project-select option { background: #1a1a2e; }
        /* Rename input styling */
        .rename-row {
            display: none;
            align-items: center;
            gap: 10px;
            margin-top: 10px;
            padding: 10px;
            background: rgba(14, 157, 89, 0.15);
            border-radius: 8px;
        }
        .rename-row.visible { display: flex; }
        .rename-row label { color: #0E9D59; font-weight: bold; white-space: nowrap; }
        .rename-input {
            flex: 1;
            padding: 10px;
            border: 2px solid #0E9D59;
            border-radius: 8px;
            background: rgba(0,0,0,0.3);
            color: #eee;
            font-size: 1em;
        }
        .rename-input:focus { outline: none; box-shadow: 0 0 10px rgba(14, 157, 89, 0.5); }
        .extension-label { color: #888; font-weight: bold; }
        .btn-rename {
            background: #f39c12;
            padding: 8px 12px !important;
            font-size: 0.9em;
        }
        .btn-rename:hover { background: #d68910; }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        @media (max-width: 600px) {
            .grid { grid-template-columns: 1fr; }
            h1 { font-size: 1.8em; }
        }
    </style>
</head>
<body>
<div class="container">
"""

HTML_FOOTER = """
</div>
</body>
</html>
"""


class DashboardHandler(BaseHTTPRequestHandler):
    """HTTP Request Handler für das SIDEKICK Dashboard"""
    
    def log_message(self, format, *args):
        """Überschreibt das Standard-Logging"""
        print(f"[Dashboard] {args[0]}")
    
    def send_html(self, content, status=200):
        """Sendet HTML-Antwort"""
        self.send_response(status)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(content.encode('utf-8'))
    
    def send_redirect(self, location):
        """Sendet Redirect"""
        self.send_response(302)
        self.send_header('Location', location)
        self.end_headers()
    
    def do_GET(self):
        """Handle GET requests"""
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)
        
        status_msg = query.get('status', [None])[0]
        
        if path == '/' or path == '/index.html':
            self.serve_dashboard(status_msg)
        elif path == '/delete-video':
            filename = query.get('file', [None])[0]
            if filename:
                self.delete_video(filename)
            else:
                self.send_redirect('/?status=error_no_file')
        elif path == '/delete-project':
            filename = query.get('file', [None])[0]
            if filename:
                self.delete_project(filename)
            else:
                self.send_redirect('/?status=error_no_file')
        elif path == '/rename-video':
            old_name = query.get('old', [None])[0]
            new_name = query.get('new', [None])[0]
            if old_name and new_name:
                self.rename_file(VIDEOS_DIR, old_name, new_name, 'video', VIDEO_EXTENSIONS)
            else:
                self.send_redirect('/?status=error_no_file')
        elif path == '/rename-project':
            old_name = query.get('old', [None])[0]
            new_name = query.get('new', [None])[0]
            if old_name and new_name:
                self.rename_file(PROJECTS_DIR, old_name, new_name, 'project', PROJECT_EXTENSIONS)
            else:
                self.send_redirect('/?status=error_no_file')
        else:
            self.send_error(404, 'Not Found')
    
    def do_POST(self):
        """Handle POST requests (file uploads)"""
        if self.path == '/upload-video':
            self.handle_upload(VIDEOS_DIR, 'video', VIDEO_EXTENSIONS)
        elif self.path == '/upload-project':
            self.handle_upload(PROJECTS_DIR, 'project', PROJECT_EXTENSIONS)
        else:
            self.send_error(404, 'Not Found')
    
    def handle_upload(self, target_dir, file_type, allowed_extensions):
        """Handles file upload - without deprecated cgi module"""
        try:
            content_type = self.headers.get('Content-Type', '')
            if not content_type or 'multipart/form-data' not in content_type:
                self.send_redirect(f'/?status=error_invalid_content')
                return
            
            # Extract boundary from content-type
            boundary_match = re.search(r'boundary=([^\s;]+)', content_type)
            if not boundary_match:
                self.send_redirect(f'/?status=error_invalid_content')
                return
            
            boundary = boundary_match.group(1).encode()
            
            # Read the entire body
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            # Parse multipart data manually
            filename, file_data, custom_name = self.parse_multipart(body, boundary)
            
            if not filename or not file_data:
                self.send_redirect(f'/?status=error_no_file')
                return
            
            filename = os.path.basename(filename)
            ext = os.path.splitext(filename)[1].lower()
            
            if ext not in allowed_extensions:
                self.send_redirect(f'/?status=error_invalid_type')
                return
            
            # Use custom name if provided
            if custom_name:
                # Sanitize custom name (remove path separators and dangerous chars)
                custom_name = re.sub(r'[<>:"/\\|?*]', '', custom_name)
                custom_name = custom_name.strip()
                if custom_name:
                    filename = custom_name + ext
            
            # Save file
            filepath = target_dir / filename
            with open(filepath, 'wb') as f:
                f.write(file_data)
            
            # Update list based on file type
            if file_type == 'video':
                update_video_list()
            elif file_type == 'project':
                update_project_list()
            
            self.send_redirect(f'/?status=success_{file_type}')
            
        except Exception as e:
            print(f"Upload error: {e}")
            import traceback
            traceback.print_exc()
            self.send_redirect(f'/?status=error_upload')
    
    def parse_multipart(self, body, boundary):
        """Parse multipart form data and extract file and custom name"""
        # Split by boundary
        parts = body.split(b'--' + boundary)
        
        filename = None
        file_data = None
        custom_name = None
        
        for part in parts:
            if b'Content-Disposition' not in part:
                continue
            
            # Check if this is the customName field
            if b'name="customName"' in part and b'filename=' not in part:
                header_end = part.find(b'\r\n\r\n')
                if header_end == -1:
                    header_end = part.find(b'\n\n')
                    if header_end == -1:
                        continue
                    content_start = header_end + 2
                else:
                    content_start = header_end + 4
                
                value = part[content_start:].strip()
                if value.endswith(b'\r\n'):
                    value = value[:-2]
                if value:
                    custom_name = value.decode('utf-8').strip()
                continue
            
            # Check if this part has a filename (it's a file upload)
            if b'filename="' not in part:
                continue
            
            # Extract filename
            filename_match = re.search(rb'filename="([^"]*)"', part)
            if not filename_match:
                continue
            
            filename = filename_match.group(1).decode('utf-8')
            if not filename:
                continue
            
            # Find where headers end and content begins (double newline)
            header_end = part.find(b'\r\n\r\n')
            if header_end == -1:
                header_end = part.find(b'\n\n')
                if header_end == -1:
                    continue
                content_start = header_end + 2
            else:
                content_start = header_end + 4
            
            # Extract file content (remove trailing boundary markers)
            file_data = part[content_start:]
            # Remove trailing \r\n or \n before next boundary
            if file_data.endswith(b'\r\n'):
                file_data = file_data[:-2]
            elif file_data.endswith(b'\n'):
                file_data = file_data[:-1]
            # Also handle the case where there's a trailing --
            if file_data.endswith(b'--'):
                file_data = file_data[:-2]
                if file_data.endswith(b'\r\n'):
                    file_data = file_data[:-2]
        
        return filename, file_data, custom_name
    
    def delete_video(self, filename):
        """Löscht ein Video"""
        try:
            filepath = VIDEOS_DIR / filename
            if filepath.exists() and filepath.suffix.lower() in VIDEO_EXTENSIONS:
                filepath.unlink()
                update_video_list()
                self.send_redirect('/?status=deleted_video')
            else:
                self.send_redirect('/?status=error_not_found')
        except Exception as e:
            print(f"Delete error: {e}")
            self.send_redirect('/?status=error_delete')
    
    def delete_project(self, filename):
        """Löscht ein Projekt"""
        try:
            filepath = PROJECTS_DIR / filename
            if filepath.exists() and filepath.suffix.lower() in PROJECT_EXTENSIONS:
                filepath.unlink()
                update_project_list()
                self.send_redirect('/?status=deleted_project')
            else:
                self.send_redirect('/?status=error_not_found')
        except Exception as e:
            print(f"Delete error: {e}")
            self.send_redirect('/?status=error_delete')
    
    def rename_file(self, target_dir, old_name, new_name, file_type, allowed_extensions):
        """Benennt eine Datei um"""
        try:
            old_path = target_dir / old_name
            new_path = target_dir / new_name
            
            # Validierung
            if not old_path.exists():
                self.send_redirect('/?status=error_not_found')
                return
            if old_path.suffix.lower() not in allowed_extensions:
                self.send_redirect('/?status=error_invalid_type')
                return
            if new_path.suffix.lower() not in allowed_extensions:
                self.send_redirect('/?status=error_invalid_type')
                return
            if new_path.exists() and new_path != old_path:
                self.send_redirect('/?status=error_exists')
                return
            
            # Umbenennen
            old_path.rename(new_path)
            
            # Listen aktualisieren
            if file_type == 'video':
                update_video_list()
            else:
                update_project_list()
            
            self.send_redirect(f'/?status=renamed_{file_type}')
        except Exception as e:
            print(f"Rename error: {e}")
            self.send_redirect('/?status=error_rename')
    
    def serve_dashboard(self, status_msg=None):
        """Rendert die Dashboard-Seite"""
        html = HTML_HEADER
        
        # SIDEKICK Logo als inline SVG (grüner Blitz)
        sidekick_logo_svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" style="height: 1.5em; vertical-align: middle; margin-right: 10px;"><g transform="matrix(1.163134, 0, 0, 1.163081, -9.026044, -35.353489)"><g transform="matrix(0.832517, 0, 0, 0.832517, 75.024178, 82.846268)"><path d="M 0 348.179 L 337.63 761.13 L 382.994 761.13 L 403.081 786.592 L 460.382 786.592 L 484.09 761.13 L 535.023 761.13 L 896 348.179 L 895.567 320.246 L -0.1 319.935 L 0 348.179 Z" style="stroke-linecap: round; stroke-linejoin: round; stroke-width: 30px; stroke: rgb(146, 170, 121); fill: rgb(182, 213, 151);"></path><path d="M 1.148 319.517 L 337.913 731.409 L 383.161 731.409 L 403.196 756.806 L 460.35 756.806 L 483.997 731.409 L 534.8 731.409 L 894.852 319.517 L 729.435 144.945 L 169.763 144.945 L 1.148 319.517 Z" style="stroke-linecap: round; stroke-linejoin: round; stroke-width: 30px; fill: rgb(182, 213, 151); stroke: rgb(197, 221, 172);"></path></g><g transform="matrix(0.931649, 0, 0, 0.931649, 246.421875, 139.795685)"><path d="M 213.06900024414062 205.85000610351562 L 165.85699462890625 323.68701171875 L 242.62399291992188 274.6409912109375 L 225.3730010986328 366.1409912109375 L 137.7790069580078 452.10400390625 L 129 504.6759948730469 L 142.96299743652344 456.16400146484375 L 240.5070037841797 385.26300048828125 L 297.4649963378906 208.58200073242188 L 208.36099243164062 273.3800048828125 L 231.46200561523438 216.98800659179688 L 318.29998779296875 133.9759979248047 Z" style="fill-rule: nonzero; paint-order: stroke; stroke: rgb(197, 221, 172); stroke-width: 150.381px; stroke-linejoin: round; fill: rgb(197, 221, 172);"></path><path d="M 213.06900024414062 205.85000610351562 L 165.85699462890625 323.68701171875 L 242.62399291992188 274.6409912109375 L 225.3730010986328 366.1409912109375 L 137.7790069580078 452.10400390625 L 129 504.6759948730469 L 142.96299743652344 456.16400146484375 L 240.5070037841797 385.26300048828125 L 297.4649963378906 208.58200073242188 L 208.36099243164062 273.3800048828125 L 231.46200561523438 216.98800659179688 L 318.29998779296875 133.9759979248047 Z" style="fill-rule: nonzero; paint-order: stroke; stroke: rgb(255, 255, 255); stroke-width: 75.1906px; stroke-linejoin: round; fill: rgb(255, 255, 255);"></path><polygon style="fill-rule: nonzero; paint-order: stroke; fill: rgb(182, 213, 151); stroke-width: 75.1906px; stroke-linejoin: round;" points="213.069 205.85 165.857 323.687 242.624 274.641 225.373 366.141 137.779 452.104 129 504.676 142.963 456.164 240.507 385.263 297.465 208.582 208.361 273.38 231.462 216.988 318.3 133.976"></polygon></g></g></svg>'''
        
        html += f'<h1>{sidekick_logo_svg}SIDEKICK Dashboard</h1>'
        
        # Scratch Link - dynamisch basierend auf aktuellem Host
        # Scratch Cat Emoji (einfach und funktioniert überall)
        scratch_icon = '🐱'
        
        html += f'''
        <script>
            // Scratch-Link und Kiosk-Link dynamisch setzen beim Laden
            document.addEventListener('DOMContentLoaded', function() {{
                const host = window.location.hostname;
                const scratchLink = document.getElementById('scratchLink');
                if (scratchLink) {{
                    scratchLink.href = 'http://' + host + ':{SCRATCH_PORT}/';
                }}
                const kioskLinkTop = document.getElementById('kioskLinkTop');
                if (kioskLinkTop) {{
                    kioskLinkTop.href = 'http://' + host + ':{KIOSK_PORT}/kiosk.html';
                }}
            }});
        </script>
        <a href="http://10.42.0.1:{SCRATCH_PORT}/" id="scratchLink" class="scratch-link" target="_blank">
            {scratch_icon} Scratch-Editor öffnen
        </a>
        <div style="text-align: center; margin-bottom: 20px;">
            <a href="#" id="kioskLinkTop" target="_blank" style="color: #888; text-decoration: none; font-size: 0.9em;">
                🖥️ Kiosk-Display öffnen <span style="color: #666; font-size: 0.85em;">(bspw. für 2. Monitor)</span>
            </a>
        </div>
        '''
        
        # Status Message
        if status_msg:
            status_class = 'status-success' if 'success' in status_msg or 'deleted' in status_msg else 'status-error'
            messages = {
                'success_video': '✅ Video erfolgreich hochgeladen!',
                'success_project': '✅ Projekt erfolgreich hochgeladen!',
                'deleted_video': '✅ Video gelöscht!',
                'deleted_project': '✅ Projekt gelöscht!',
                'error_no_file': '❌ Keine Datei ausgewählt!',
                'error_invalid_type': '❌ Ungültiger Dateityp!',
                'error_upload': '❌ Fehler beim Hochladen!',
                'error_delete': '❌ Fehler beim Löschen!',
                'error_not_found': '❌ Datei nicht gefunden!',
                'renamed_video': '✅ Video umbenannt!',
                'renamed_project': '✅ Projekt umbenannt!',
                'error_rename': '❌ Fehler beim Umbenennen!',
                'error_exists': '❌ Eine Datei mit diesem Namen existiert bereits!'
            }
            msg = messages.get(status_msg, status_msg)
            html += f'<div class="status {status_class}">{msg}</div>'
        
        # Display Control Card (Kiosk-Steuerung)
        projects = sorted([f.name for f in PROJECTS_DIR.iterdir() if f.suffix.lower() in PROJECT_EXTENSIONS])
        project_options = ''.join([f'<option value="{html_module.escape(p)}">{html_module.escape(p)}</option>' for p in projects])
        
        html += f'''
        <div class="card">
            <h2>🖥️ Display-Steuerung (Kiosk-Modus)</h2>
            <div class="display-control">
                <div class="display-status">
                    <div class="status-dot" id="mqttStatusDot"></div>
                    <span id="mqttStatusText">Verbinde...</span>
                </div>
                
                <div style="display: flex; gap: 15px; align-items: center; flex-wrap: wrap;">
                    <select class="project-select" id="projectSelect" style="flex: 1; min-width: 200px;">
                        <option value="">-- Projekt auswählen --</option>
                        {project_options}
                    </select>
                    <button class="btn btn-display" onclick="loadProjectOnDisplay()">📤 Auf Display laden</button>
                </div>
                
                <div class="control-buttons">
                    <button class="btn btn-start" onclick="startProject()">▶️ Start (Grüne Flagge)</button>
                    <button class="btn btn-stop" onclick="stopProject()">⏹️ Stop</button>
                    <button class="btn btn-secondary" onclick="toggleFullscreen()" title="Stage-Vollbild umschalten">⛶ Vollbild</button>
                </div>
                
                <div id="displayStatus" style="color: #888; font-size: 0.9em;">
                    Aktuelles Projekt: <span id="currentProject">-</span><br>
                    Status: <span id="projectStatus">-</span>
                </div>
            </div>
        </div>
        
        <!-- MQTT.js vom Scratch-Server laden (lokal, funktioniert offline!) -->
        <script>
            // Warte auf mqtt.js und initialisiere dann
            function loadMqttAndInit() {{
                const script = document.createElement('script');
                script.src = 'http://' + window.location.hostname + ':8601/sidekick-thirdparty-libraries/mqtt/mqtt.min.js';
                script.onload = function() {{
                    console.log('MQTT.js geladen');
                    initDashboard();
                }};
                script.onerror = function() {{
                    console.error('MQTT.js konnte nicht geladen werden');
                    document.getElementById('mqttStatusText').textContent = 'MQTT nicht verfügbar';
                }};
                document.head.appendChild(script);
            }}
            window.onload = loadMqttAndInit;
        </script>
        <script>
            // Dynamische Host-Erkennung - funktioniert mit LAN und Hotspot!
            const SIDEKICK_HOST = window.location.hostname;
            const SCRATCH_PORT = {SCRATCH_PORT};
            const KIOSK_PORT = {KIOSK_PORT};
            const MQTT_PORT = 9001;
            
            let mqttClient = null;
            
            // Kiosk-Link wird oben beim Scratch-Link gesetzt
            
            function initDashboard() {{
                connectMQTT();
            }}
            
            function connectMQTT() {{
                const statusDot = document.getElementById('mqttStatusDot');
                const statusText = document.getElementById('mqttStatusText');
                
                // Dynamische MQTT-URL basierend auf aktuellem Host
                const mqttUrl = 'ws://' + SIDEKICK_HOST + ':' + MQTT_PORT;
                console.log('MQTT verbinden zu:', mqttUrl);
                
                mqttClient = mqtt.connect(mqttUrl, {{
                    clientId: 'dashboard-' + Math.random().toString(16).substr(2, 8),
                    clean: true,
                    reconnectPeriod: 5000
                }});
                
                mqttClient.on('connect', function() {{
                    console.log('MQTT verbunden');
                    statusDot.className = 'status-dot connected';
                    statusText.textContent = 'Verbunden';
                    
                    // Status-Topic abonnieren
                    mqttClient.subscribe('sidekick/display/state');
                    
                    // Status anfragen
                    mqttClient.publish('sidekick/display/status', '');
                }});
                
                mqttClient.on('error', function(err) {{
                    console.error('MQTT Fehler:', err);
                    statusDot.className = 'status-dot disconnected';
                    statusText.textContent = 'Kein Kiosk-Display (MQTT nicht erreichbar)';
                }});
                
                mqttClient.on('close', function() {{
                    statusDot.className = 'status-dot disconnected';
                    statusText.textContent = 'Kein Kiosk-Display verbunden';
                }});
                
                mqttClient.on('message', function(topic, message) {{
                    if (topic === 'sidekick/display/state') {{
                        try {{
                            const state = JSON.parse(message.toString());
                            document.getElementById('currentProject').textContent = state.project || '-';
                            document.getElementById('projectStatus').textContent = state.status || '-';
                        }} catch(e) {{
                            console.error('Status parse error:', e);
                        }}
                    }}
                }});
            }}
            
            function loadProjectOnDisplay() {{
                const select = document.getElementById('projectSelect');
                const projectName = select.value;
                if (!projectName) {{
                    alert('Bitte wähle ein Projekt aus!');
                    return;
                }}
                if (mqttClient && mqttClient.connected) {{
                    mqttClient.publish('sidekick/display/load', projectName);
                    console.log('Lade Projekt:', projectName);
                }} else {{
                    alert('Nicht mit MQTT verbunden!');
                }}
            }}
            
            function startProject() {{
                if (mqttClient && mqttClient.connected) {{
                    mqttClient.publish('sidekick/display/start', '');
                    console.log('Start gesendet');
                }} else {{
                    alert('Nicht mit MQTT verbunden!');
                }}
            }}
            
            function stopProject() {{
                if (mqttClient && mqttClient.connected) {{
                    mqttClient.publish('sidekick/display/stop', '');
                    console.log('Stop gesendet');
                }} else {{
                    alert('Nicht mit MQTT verbunden!');
                }}
            }}
            
            function toggleFullscreen() {{
                if (mqttClient && mqttClient.connected) {{
                    mqttClient.publish('sidekick/display/fullscreen', 'toggle');
                    console.log('Fullscreen-Toggle gesendet');
                }} else {{
                    alert('Nicht mit MQTT verbunden!');
                }}
            }}
            
            // MQTT wird jetzt über initDashboard() gestartet (nach mqtt.js Laden)
            
            // Rename field functions
            function showRenameField(type) {{
                const fileInput = document.getElementById(type + 'FileInput');
                const renameRow = document.getElementById(type + 'RenameRow');
                const nameInput = document.getElementById(type + 'NameInput');
                
                if (fileInput.files.length > 0) {{
                    const fullName = fileInput.files[0].name;
                    const lastDot = fullName.lastIndexOf('.');
                    const baseName = lastDot > 0 ? fullName.substring(0, lastDot) : fullName;
                    const ext = lastDot > 0 ? fullName.substring(lastDot) : '';
                    
                    nameInput.value = baseName;
                    renameRow.classList.add('visible');
                    
                    // Update extension label for videos
                    if (type === 'video') {{
                        document.getElementById('videoExtLabel').textContent = ext;
                    }}
                }} else {{
                    renameRow.classList.remove('visible');
                }}
            }}
            
            // Rename existing file
            function renameFile(type, oldName) {{
                const lastDot = oldName.lastIndexOf('.');
                const baseName = lastDot > 0 ? oldName.substring(0, lastDot) : oldName;
                const ext = lastDot > 0 ? oldName.substring(lastDot) : '';
                
                const newBaseName = prompt('Neuer Name für "' + oldName + '":', baseName);
                if (newBaseName && newBaseName !== baseName) {{
                    const newName = newBaseName + ext;
                    window.location.href = '/rename-' + type + '?old=' + encodeURIComponent(oldName) + '&new=' + encodeURIComponent(newName);
                }}
            }}
        </script>
        '''
        
        html += '<div class="grid">'
        
        # Video Upload Card mit Codec-Warnung
        html += '''
        <div class="card">
            <h2>🎞️ Video hochladen</h2>
            <form class="upload-form" action="/upload-video" method="post" enctype="multipart/form-data" id="videoUploadForm">
                <input type="file" name="file" accept=".mp4,.webm,.ogg,.ogv,.mov,.avi,.mkv" required id="videoFileInput" onchange="checkVideoFile()">
                
                <!-- Video-Warnung (standardmäßig versteckt) -->
                <div id="videoWarning" class="video-warning" style="display: none;">
                    <div class="warning-icon">⚠️</div>
                    <div class="warning-text">
                        <strong>Video-Warnung</strong><br>
                        <span id="warningMessage"></span>
                    </div>
                </div>
                
                <!-- Video-Info (standardmäßig versteckt) -->
                <div id="videoInfo" class="video-info" style="display: none;">
                    <strong>Video-Details:</strong><br>
                    <span id="videoDetails"></span>
                </div>
                
                <div class="rename-row" id="videoRenameRow">
                    <label>Speichern als:</label>
                    <input type="text" class="rename-input" name="customName" id="videoNameInput" placeholder="Dateiname">
                    <span class="extension-label" id="videoExtLabel">.mp4</span>
                </div>
                <button type="submit" id="videoSubmitBtn">Video hochladen</button>
            </form>
            <p style="color: #888; font-size: 0.9em; margin-top: 10px;">
                <strong>Empfohlen:</strong> H.264 Codec, max. 1080p, max. 50MB<br>
                <span style="color: #e74c3c;">❌ HEVC/H.265 wird auf dem Pi nicht unterstützt!</span>
            </p>
        </div>
        
        <style>
            .video-warning {
                display: flex;
                gap: 15px;
                padding: 15px;
                background: rgba(231, 76, 60, 0.2);
                border: 2px solid #e74c3c;
                border-radius: 10px;
                color: #ff6b6b;
            }
            .video-warning .warning-icon { font-size: 2em; }
            .video-warning .warning-text { flex: 1; }
            .video-info {
                padding: 15px;
                background: rgba(52, 152, 219, 0.2);
                border: 1px solid #3498db;
                border-radius: 10px;
                color: #5dade2;
                font-size: 0.9em;
            }
            .video-ok {
                background: rgba(14, 157, 89, 0.2) !important;
                border-color: #0E9D59 !important;
                color: #0E9D59 !important;
            }
        </style>
        
        <script>
            async function checkVideoFile() {
                const fileInput = document.getElementById('videoFileInput');
                const warningDiv = document.getElementById('videoWarning');
                const warningMsg = document.getElementById('warningMessage');
                const infoDiv = document.getElementById('videoInfo');
                const detailsSpan = document.getElementById('videoDetails');
                const submitBtn = document.getElementById('videoSubmitBtn');
                
                // Reset
                warningDiv.style.display = 'none';
                infoDiv.style.display = 'none';
                submitBtn.textContent = 'Video hochladen';
                
                if (!fileInput.files.length) return;
                
                const file = fileInput.files[0];
                showRenameField('video');
                
                // Dateigroesse pruefen
                const sizeMB = file.size / (1024 * 1024);
                const warnings = [];
                const infos = [];
                
                infos.push('Datei: ' + file.name);
                infos.push('Größe: ' + sizeMB.toFixed(1) + ' MB');
                
                if (sizeMB > 100) {
                    warnings.push('⚠️ Datei ist sehr groß (' + sizeMB.toFixed(0) + ' MB). Empfohlen: max. 50MB');
                } else if (sizeMB > 50) {
                    warnings.push('⚠️ Datei ist relativ groß (' + sizeMB.toFixed(0) + ' MB). Empfohlen: max. 50MB');
                }
                
                // Video in temporaeres Element laden um Metadaten zu pruefen
                try {
                    const videoUrl = URL.createObjectURL(file);
                    const video = document.createElement('video');
                    video.preload = 'metadata';
                    
                    await new Promise((resolve, reject) => {
                        video.onloadedmetadata = resolve;
                        video.onerror = () => reject(new Error('Video konnte nicht geladen werden'));
                        setTimeout(() => reject(new Error('Timeout')), 10000);
                        video.src = videoUrl;
                    });
                    
                    const width = video.videoWidth;
                    const height = video.videoHeight;
                    const duration = video.duration;
                    
                    infos.push('Auflösung: ' + width + 'x' + height);
                    infos.push('Länge: ' + Math.floor(duration/60) + ':' + String(Math.floor(duration%60)).padStart(2,'0'));
                    
                    // Aufloesung pruefen
                    if (width > 1920 || height > 1080) {
                        warnings.push('⚠️ Auflösung (' + width + 'x' + height + ') ist höher als 1080p. Kann ruckeln!');
                    }
                    
                    // Codec-Erkennung (leider eingeschränkt in JavaScript)
                    // Wir können nur pruefen ob der Browser es abspielen kann
                    const canPlay = video.canPlayType(file.type);
                    
                    // HEVC-Warnung basierend auf Dateiendung und typischen Merkmalen
                    const ext = file.name.split('.').pop().toLowerCase();
                    if (ext === 'mkv' || ext === 'mov') {
                        warnings.push('⚠️ ' + ext.toUpperCase() + '-Dateien können HEVC-kodiert sein. Falls das Video nicht abspielt, bitte zu H.264 konvertieren.');
                    }
                    
                    URL.revokeObjectURL(videoUrl);
                    
                } catch (e) {
                    warnings.push('⚠️ Video-Metadaten konnten nicht gelesen werden. Möglicherweise inkompatibles Format!');
                    console.error('Video check error:', e);
                }
                
                // Info anzeigen
                if (infos.length > 0) {
                    detailsSpan.innerHTML = infos.join('<br>');
                    infoDiv.style.display = 'block';
                    if (warnings.length === 0) {
                        infoDiv.classList.add('video-ok');
                        detailsSpan.innerHTML += '<br>✅ Video sieht kompatibel aus!';
                    } else {
                        infoDiv.classList.remove('video-ok');
                    }
                }
                
                // Warnungen anzeigen
                if (warnings.length > 0) {
                    warningMsg.innerHTML = warnings.join('<br><br>');
                    warningDiv.style.display = 'flex';
                    submitBtn.textContent = '⚠️ Trotzdem hochladen';
                    
                    // HEVC-Konvertierungstipp hinzufuegen
                    warningMsg.innerHTML += '<br><br><small style="color: #aaa;">💡 Tipp: Mit ffmpeg konvertieren:<br><code style="background: rgba(0,0,0,0.3); padding: 5px; border-radius: 4px; font-size: 0.8em;">ffmpeg -i video.mp4 -c:v libx264 -crf 23 -vf "scale=1920:1080" video_h264.mp4</code></small>';
                }
            }
        </script>
        '''
        
        # Project Upload Card
        html += '''
        <div class="card">
            <h2>📁 Projekt hochladen</h2>
            <form class="upload-form" action="/upload-project" method="post" enctype="multipart/form-data" id="projectUploadForm">
                <input type="file" name="file" accept=".sb3" required id="projectFileInput" onchange="showRenameField('project')">
                <div class="rename-row" id="projectRenameRow">
                    <label>Speichern als:</label>
                    <input type="text" class="rename-input" name="customName" id="projectNameInput" placeholder="Dateiname">
                    <span class="extension-label">.sb3</span>
                </div>
                <button type="submit">Projekt hochladen</button>
            </form>
            <p style="color: #888; font-size: 0.9em; margin-top: 10px;">
                Unterstützte Formate: SB3 (Scratch 3.0 Projekte)
            </p>
        </div>
        '''
        
        html += '</div>'  # End grid
        
        # Videos List
        html += '<div class="card">'
        html += '<h2>🎞️ Video-Liste</h2>'
        
        videos = update_video_list()
        if videos:
            html += '<table><tr><th>Dateiname</th><th>Größe</th><th>Aktionen</th></tr>'
            for video in videos:
                filepath = VIDEOS_DIR / video
                size = get_file_size_str(filepath.stat().st_size) if filepath.exists() else '?'
                escaped_name = html_module.escape(video)
                url_name = urllib.parse.quote(video)
                # Verwende data-path für dynamische URL-Generierung
                html += f'''<tr>
                    <td>{escaped_name}</td>
                    <td>{size}</td>
                    <td class="actions">
                        <button class="btn btn-rename" onclick="renameFile('video', '{escaped_name}')" title="Umbenennen">✏️</button>
                        <a href="#" onclick="openVideoLink('{url_name}'); return false;" class="btn btn-secondary" style="padding: 8px 15px;">▶️ Abspielen</a>
                        <a href="/delete-video?file={url_name}" class="btn btn-danger" style="padding: 8px 15px;" onclick="return confirm('Wirklich löschen?')">🗑️ Löschen</a>
                    </td>
                </tr>'''
            html += '</table>'
            html += f'''
            <script>
                function openVideoLink(filename) {{
                    const url = 'http://' + window.location.hostname + ':{SCRATCH_PORT}/videos/' + filename;
                    window.open(url, '_blank');
                }}
            </script>
            '''
        else:
            html += '<div class="empty-state">Keine Videos vorhanden.<br>Lade ein Video hoch um zu beginnen!</div>'
        
        html += '</div>'
        
        # Projects List
        html += '<div class="card">'
        html += '<h2>📁 Projekt-Liste</h2>'
        
        projects = sorted([f.name for f in PROJECTS_DIR.iterdir() if f.suffix.lower() in PROJECT_EXTENSIONS])
        if projects:
            html += '<table><tr><th>Dateiname</th><th>Größe</th><th>Aktionen</th></tr>'
            for project in projects:
                filepath = PROJECTS_DIR / project
                size = get_file_size_str(filepath.stat().st_size) if filepath.exists() else '?'
                escaped_name = html_module.escape(project)
                url_name = urllib.parse.quote(project)
                # Verwende onclick für dynamische URL
                html += f'''<tr>
                    <td>{escaped_name}</td>
                    <td>{size}</td>
                    <td class="actions">
                        <button class="btn btn-rename" onclick="renameFile('project', '{escaped_name}')" title="Umbenennen">✏️</button>
                        <a href="#" onclick="downloadProject('{url_name}'); return false;" class="btn btn-secondary" style="padding: 8px 15px;">💾 Download</a>
                        <a href="/delete-project?file={url_name}" class="btn btn-danger" style="padding: 8px 15px;" onclick="return confirm('Wirklich löschen?')">🗑️ Löschen</a>
                    </td>
                </tr>'''
            html += '</table>'
            html += f'''
            <script>
                function downloadProject(filename) {{
                    const url = 'http://' + window.location.hostname + ':{SCRATCH_PORT}/projects/' + filename;
                    window.location.href = url;
                }}
            </script>
            '''
        else:
            html += '<div class="empty-state">Keine Projekte vorhanden.<br>Lade ein Scratch-Projekt (.sb3) hoch!</div>'
        
        html += '</div>'
        
        # Info Card - dynamisch
        html += f'''
        <div class="card">
            <h2>ℹ️ Verbindung</h2>
            <p style="color: #0E9D59; margin-bottom: 15px;">
                💡 Die nachfolgenden Links werden automatisch, je nach Verbindung(smethode) angepasst (LAN / Hotspot).
            </p>
            <table>
                <tr><td><strong>Aktueller Host:</strong></td><td><span id="currentHost">...</span></td></tr>
                <tr><td><strong>Scratch-Editor:</strong></td><td><a href="#" id="infoScratchLink" target="_blank">...</a></td></tr>
                <tr><td><strong>Kiosk-Display:</strong></td><td><a href="#" id="infoKioskLink" target="_blank">...</a></td></tr>
                <tr><td><strong>SIDEKICK-Dashboard:</strong></td><td><span id="infoDashboardLink">...</span></td></tr>
                <tr><td><strong>MQTT-Broker:</strong></td><td><span id="infoMqttLink">...</span></td></tr>
                <tr><td><strong>Videos-Ordner:</strong></td><td>{VIDEOS_DIR}</td></tr>
                <tr><td><strong>Projekte-Ordner:</strong></td><td>{PROJECTS_DIR}</td></tr>
            </table>
        </div>
        
        <script>
            // Info-Card Links dynamisch setzen
            document.addEventListener('DOMContentLoaded', function() {{
                const host = window.location.hostname;
                document.getElementById('currentHost').textContent = host;
                
                const scratchUrl = 'http://' + host + ':{SCRATCH_PORT}/';
                document.getElementById('infoScratchLink').href = scratchUrl;
                document.getElementById('infoScratchLink').textContent = scratchUrl;
                
                const kioskUrl = 'http://' + host + ':{KIOSK_PORT}/kiosk.html';
                document.getElementById('infoKioskLink').href = kioskUrl;
                document.getElementById('infoKioskLink').textContent = kioskUrl;
                
                document.getElementById('infoDashboardLink').textContent = 'http://' + host + ':{DASHBOARD_PORT}/';
                document.getElementById('infoMqttLink').textContent = 'ws://' + host + ':9001';
            }});
        </script>
        '''
        
        html += HTML_FOOTER
        self.send_html(html)


def main():
    setup_paths()
    
    print(f"\n{'='*50}")
    print(f"  SIDEKICK Dashboard")
    print(f"{'='*50}")
    print(f"\n  Dashboard: http://0.0.0.0:{DASHBOARD_PORT}/")
    print(f"  (Im Hotspot: http://10.42.0.1:{DASHBOARD_PORT}/)")
    print(f"\n  Scratch: http://0.0.0.0:{SCRATCH_PORT}/")
    print(f"  (Im Hotspot: http://10.42.0.1:{SCRATCH_PORT}/)")
    print(f"\n{'='*50}\n")
    
    server = HTTPServer(('0.0.0.0', DASHBOARD_PORT), DashboardHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nDashboard beendet.")
        server.server_close()


if __name__ == "__main__":
    main()
