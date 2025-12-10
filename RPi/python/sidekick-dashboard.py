#!/usr/bin/env python3
"""
SIDEKICK Dashboard Server

Ein einfacher Webserver für:
- Video-Upload
- Projekt-Upload (.sb3 Dateien)
- Übersicht aller Dateien
- Automatische video-list.json Generierung

Startet auf Port 8080 (Scratch läuft auf 8000)

Verwendung:
    python3 sidekick-dashboard.py
"""

import os
import sys
import json
import cgi
import html
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
import shutil

# Konfiguration
DASHBOARD_PORT = 8080
SCRATCH_PORT = 8000

# Pfade (werden beim Start gesetzt)
SIDEKICK_DIR = None
VIDEOS_DIR = None
PROJECTS_DIR = None
SCRATCH_DIR = None

# Unterstützte Dateitypen
VIDEO_EXTENSIONS = {'.mp4', '.webm', '.ogg', '.ogv', '.mov', '.avi', '.mkv'}
PROJECT_EXTENSIONS = {'.sb3'}


def setup_paths():
    """Initialisiert die Pfade basierend auf dem Home-Verzeichnis"""
    global SIDEKICK_DIR, VIDEOS_DIR, PROJECTS_DIR, SCRATCH_DIR
    
    home = Path.home()
    SIDEKICK_DIR = home / "Sidekick"
    SCRATCH_DIR = SIDEKICK_DIR / "sidekick-scratch-extension-development-gh-pages" / "scratch"
    VIDEOS_DIR = SCRATCH_DIR / "videos"
    PROJECTS_DIR = SIDEKICK_DIR / "projects"
    
    # Erstelle Ordner falls nicht vorhanden
    VIDEOS_DIR.mkdir(parents=True, exist_ok=True)
    PROJECTS_DIR.mkdir(parents=True, exist_ok=True)
    
    print(f"SIDEKICK Directory: {SIDEKICK_DIR}")
    print(f"Videos Directory: {VIDEOS_DIR}")
    print(f"Projects Directory: {PROJECTS_DIR}")


def update_video_list():
    """Aktualisiert video-list.json basierend auf den Dateien im Videos-Ordner"""
    video_files = []
    for f in sorted(VIDEOS_DIR.iterdir()):
        if f.suffix.lower() in VIDEO_EXTENSIONS:
            video_files.append(f.name)
    
    list_file = VIDEOS_DIR / "video-list.json"
    with open(list_file, 'w', encoding='utf-8') as f:
        json.dump(video_files, f, indent=2, ensure_ascii=False)
    
    return video_files


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
    <title>SIDEKICK Dashboard</title>
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
        """Handles file upload"""
        try:
            content_type = self.headers.get('Content-Type')
            if not content_type or 'multipart/form-data' not in content_type:
                self.send_redirect(f'/?status=error_invalid_content')
                return
            
            # Parse multipart form data
            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={
                    'REQUEST_METHOD': 'POST',
                    'CONTENT_TYPE': content_type
                }
            )
            
            file_item = form['file'] if 'file' in form else None
            
            if not file_item or not file_item.filename:
                self.send_redirect(f'/?status=error_no_file')
                return
            
            filename = os.path.basename(file_item.filename)
            ext = os.path.splitext(filename)[1].lower()
            
            if ext not in allowed_extensions:
                self.send_redirect(f'/?status=error_invalid_type')
                return
            
            # Save file
            filepath = target_dir / filename
            with open(filepath, 'wb') as f:
                shutil.copyfileobj(file_item.file, f)
            
            # Update video list if it was a video
            if file_type == 'video':
                update_video_list()
            
            self.send_redirect(f'/?status=success_{file_type}')
            
        except Exception as e:
            print(f"Upload error: {e}")
            self.send_redirect(f'/?status=error_upload')
    
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
                self.send_redirect('/?status=deleted_project')
            else:
                self.send_redirect('/?status=error_not_found')
        except Exception as e:
            print(f"Delete error: {e}")
            self.send_redirect('/?status=error_delete')
    
    def serve_dashboard(self, status_msg=None):
        """Rendert die Dashboard-Seite"""
        html = HTML_HEADER
        
        html += '<h1>🤖 SIDEKICK Dashboard</h1>'
        
        # Scratch Link
        html += f'<a href="http://10.42.0.1:{SCRATCH_PORT}/" class="scratch-link" target="_blank">🎮 Scratch Editor öffnen</a>'
        
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
                'error_not_found': '❌ Datei nicht gefunden!'
            }
            msg = messages.get(status_msg, status_msg)
            html += f'<div class="status {status_class}">{msg}</div>'
        
        html += '<div class="grid">'
        
        # Video Upload Card
        html += '''
        <div class="card">
            <h2>📹 Video hochladen</h2>
            <form class="upload-form" action="/upload-video" method="post" enctype="multipart/form-data">
                <input type="file" name="file" accept=".mp4,.webm,.ogg,.ogv,.mov,.avi,.mkv" required>
                <button type="submit">Video hochladen</button>
            </form>
            <p style="color: #888; font-size: 0.9em; margin-top: 10px;">
                Unterstützte Formate: MP4, WebM, OGG, MOV, AVI, MKV
            </p>
        </div>
        '''
        
        # Project Upload Card
        html += '''
        <div class="card">
            <h2>📁 Projekt hochladen</h2>
            <form class="upload-form" action="/upload-project" method="post" enctype="multipart/form-data">
                <input type="file" name="file" accept=".sb3" required>
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
        html += '<h2>📹 Verfügbare Videos</h2>'
        
        videos = update_video_list()
        if videos:
            html += '<table><tr><th>Dateiname</th><th>Größe</th><th>Aktionen</th></tr>'
            for video in videos:
                filepath = VIDEOS_DIR / video
                size = get_file_size_str(filepath.stat().st_size) if filepath.exists() else '?'
                escaped_name = html.escape(video)
                url_name = urllib.parse.quote(video)
                html += f'''<tr>
                    <td>{escaped_name}</td>
                    <td>{size}</td>
                    <td class="actions">
                        <a href="/videos/{url_name}" target="_blank" class="btn btn-secondary" style="padding: 8px 15px;">▶️ Abspielen</a>
                        <a href="/delete-video?file={url_name}" class="btn btn-danger" style="padding: 8px 15px;" onclick="return confirm('Wirklich löschen?')">🗑️ Löschen</a>
                    </td>
                </tr>'''
            html += '</table>'
        else:
            html += '<div class="empty-state">Keine Videos vorhanden.<br>Lade ein Video hoch um zu beginnen!</div>'
        
        html += '</div>'
        
        # Projects List
        html += '<div class="card">'
        html += '<h2>📁 Gespeicherte Projekte</h2>'
        
        projects = sorted([f.name for f in PROJECTS_DIR.iterdir() if f.suffix.lower() in PROJECT_EXTENSIONS])
        if projects:
            html += '<table><tr><th>Dateiname</th><th>Größe</th><th>Aktionen</th></tr>'
            for project in projects:
                filepath = PROJECTS_DIR / project
                size = get_file_size_str(filepath.stat().st_size) if filepath.exists() else '?'
                escaped_name = html.escape(project)
                url_name = urllib.parse.quote(project)
                html += f'''<tr>
                    <td>{escaped_name}</td>
                    <td>{size}</td>
                    <td class="actions">
                        <a href="/projects/{url_name}" download class="btn btn-secondary" style="padding: 8px 15px;">💾 Download</a>
                        <a href="/delete-project?file={url_name}" class="btn btn-danger" style="padding: 8px 15px;" onclick="return confirm('Wirklich löschen?')">🗑️ Löschen</a>
                    </td>
                </tr>'''
            html += '</table>'
        else:
            html += '<div class="empty-state">Keine Projekte vorhanden.<br>Lade ein Scratch-Projekt (.sb3) hoch!</div>'
        
        html += '</div>'
        
        # Info Card
        html += f'''
        <div class="card">
            <h2>ℹ️ Verbindung</h2>
            <table>
                <tr><td><strong>Scratch Editor:</strong></td><td><a href="http://10.42.0.1:{SCRATCH_PORT}/" target="_blank">http://10.42.0.1:{SCRATCH_PORT}/</a></td></tr>
                <tr><td><strong>Dashboard:</strong></td><td>http://10.42.0.1:{DASHBOARD_PORT}/</td></tr>
                <tr><td><strong>MQTT Broker:</strong></td><td>ws://10.42.0.1:9001</td></tr>
                <tr><td><strong>Videos Ordner:</strong></td><td>{VIDEOS_DIR}</td></tr>
                <tr><td><strong>Projekte Ordner:</strong></td><td>{PROJECTS_DIR}</td></tr>
            </table>
        </div>
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
