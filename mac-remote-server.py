#!/usr/bin/env python3
"""
Mac Remote Control Server
Access from iPhone browser to see and control your Mac.
Uses: screencapture, cliclick, osascript (all pre-installed on macOS)
"""

import http.server
import subprocess
import json
import base64
import os
import tempfile
import urllib.parse

PORT = 9090

HTML_PAGE = """<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<title>Mac Remote</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #000; color: #fff; font-family: -apple-system, sans-serif; overflow: hidden; height: 100vh; }
#toolbar {
    display: flex; gap: 8px; padding: 8px; background: #1a1a1a;
    align-items: center; flex-wrap: wrap; z-index: 10;
}
#toolbar button {
    padding: 8px 12px; border: none; border-radius: 8px;
    background: #333; color: #fff; font-size: 14px; cursor: pointer;
}
#toolbar button:active { background: #555; }
#toolbar button.active { background: #0a84ff; }
#toolbar input {
    flex: 1; min-width: 120px; padding: 8px; border: 1px solid #444;
    border-radius: 8px; background: #222; color: #fff; font-size: 14px;
}
#screen-container {
    position: relative; width: 100%; height: calc(100vh - 52px);
    overflow: hidden; touch-action: none;
}
#screen {
    width: 100%; height: 100%; object-fit: contain; display: block;
}
#status {
    position: fixed; bottom: 10px; right: 10px; padding: 4px 8px;
    background: rgba(0,0,0,0.7); border-radius: 4px; font-size: 11px;
    color: #0a84ff; z-index: 20;
}
#keyboard-modal {
    display: none; position: fixed; bottom: 0; left: 0; right: 0;
    background: #1a1a1a; padding: 12px; z-index: 20;
    border-top: 1px solid #333;
}
#keyboard-modal input {
    width: 100%; padding: 12px; font-size: 16px; background: #222;
    border: 1px solid #444; border-radius: 8px; color: #fff;
}
#keyboard-modal .actions { display: flex; gap: 8px; margin-top: 8px; }
#keyboard-modal .actions button { flex: 1; padding: 10px; }
</style>
</head>
<body>

<div id="toolbar">
    <button onclick="refresh()">Refresh</button>
    <button id="autoBtn" onclick="toggleAuto()">Auto: OFF</button>
    <button onclick="showKeyboard()">Keyboard</button>
    <button onclick="sendKey('cmd+space')">Spotlight</button>
    <button onclick="sendKey('cmd+tab')">Cmd+Tab</button>
    <button onclick="sendKey('cmd+w')">Close</button>
    <button onclick="sendKey('cmd+q')">Quit</button>
</div>

<div id="screen-container">
    <img id="screen" src="/screenshot" alt="Mac Screen">
</div>

<div id="status">Ready</div>

<div id="keyboard-modal">
    <input id="textInput" placeholder="Tapez du texte ici..." autocomplete="off" autocorrect="off">
    <div class="actions">
        <button onclick="sendText()">Envoyer</button>
        <button onclick="sendKey('return')">Enter</button>
        <button onclick="sendKey('delete')">Delete</button>
        <button onclick="hideKeyboard()">Fermer</button>
    </div>
</div>

<script>
const BASEURL = '';
let autoRefresh = false;
let autoInterval = null;
let imgNaturalW = 1, imgNaturalH = 1;

const screen = document.getElementById('screen');
const status = document.getElementById('status');

screen.onload = function() {
    imgNaturalW = screen.naturalWidth;
    imgNaturalH = screen.naturalHeight;
    setStatus('Screen loaded (' + imgNaturalW + 'x' + imgNaturalH + ')');
};

// Tap to click
screen.addEventListener('click', function(e) {
    const rect = screen.getBoundingClientRect();
    const scaleX = imgNaturalW / rect.width;
    const scaleY = imgNaturalH / rect.height;
    const x = Math.round((e.clientX - rect.left) * scaleX);
    const y = Math.round((e.clientY - rect.top) * scaleY);
    sendClick(x, y);
});

// Double tap
let lastTap = 0;
screen.addEventListener('touchend', function(e) {
    const now = Date.now();
    if (now - lastTap < 300) {
        const touch = e.changedTouches[0];
        const rect = screen.getBoundingClientRect();
        const scaleX = imgNaturalW / rect.width;
        const scaleY = imgNaturalH / rect.height;
        const x = Math.round((touch.clientX - rect.left) * scaleX);
        const y = Math.round((touch.clientY - rect.top) * scaleY);
        sendClick(x, y, true);
        e.preventDefault();
    }
    lastTap = now;
});

function sendClick(x, y, dbl) {
    setStatus('Click ' + x + ',' + y + (dbl ? ' (double)' : ''));
    fetch('/click', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({x: x, y: y, double: dbl || false})
    }).then(() => setTimeout(refresh, 300));
}

function sendKey(key) {
    setStatus('Key: ' + key);
    fetch('/key', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({key: key})
    }).then(() => setTimeout(refresh, 300));
}

function sendText() {
    const input = document.getElementById('textInput');
    const text = input.value;
    if (!text) return;
    setStatus('Type: ' + text.substring(0, 20));
    fetch('/type', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({text: text})
    }).then(() => { input.value = ''; setTimeout(refresh, 300); });
}

function refresh() {
    screen.src = '/screenshot?' + Date.now();
}

function toggleAuto() {
    autoRefresh = !autoRefresh;
    document.getElementById('autoBtn').textContent = 'Auto: ' + (autoRefresh ? 'ON' : 'OFF');
    document.getElementById('autoBtn').classList.toggle('active', autoRefresh);
    if (autoRefresh) {
        autoInterval = setInterval(refresh, 1000);
    } else {
        clearInterval(autoInterval);
    }
}

function showKeyboard() {
    document.getElementById('keyboard-modal').style.display = 'block';
    document.getElementById('textInput').focus();
}
function hideKeyboard() {
    document.getElementById('keyboard-modal').style.display = 'none';
}

function setStatus(msg) {
    status.textContent = msg;
}

document.getElementById('textInput').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') { sendText(); e.preventDefault(); }
});
</script>
</body>
</html>"""


class MacRemoteHandler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path

        if path == '/' or path == '':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode())

        elif path == '/screenshot':
            tmp = tempfile.NamedTemporaryFile(suffix='.jpg', delete=False)
            tmp.close()
            subprocess.run(['screencapture', '-x', '-t', 'jpg', '-r', tmp.name], timeout=5)
            with open(tmp.name, 'rb') as f:
                data = f.read()
            os.unlink(tmp.name)
            self.send_response(200)
            self.send_header('Content-Type', 'image/jpeg')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(data)

        elif path == '/info':
            info = {
                'hostname': subprocess.getoutput('hostname'),
                'user': subprocess.getoutput('whoami'),
                'uptime': subprocess.getoutput('uptime'),
                'resolution': subprocess.getoutput("system_profiler SPDisplaysDataType | grep Resolution | head -1").strip(),
            }
            self.send_json(info)

        else:
            self.send_json({'error': 'not found'}, 404)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length).decode() if length > 0 else '{}'
        try:
            data = json.loads(body)
        except:
            data = {}

        if path == '/click':
            x = data.get('x', 0)
            y = data.get('y', 0)
            double = data.get('double', False)
            if double:
                subprocess.run(['cliclick', f'dc:{x},{y}'], timeout=5)
            else:
                subprocess.run(['cliclick', f'c:{x},{y}'], timeout=5)
            self.send_json({'status': 'ok', 'x': x, 'y': y, 'double': double})

        elif path == '/key':
            key = data.get('key', '')
            key_map = {
                'return': 'kp:return',
                'delete': 'kp:delete',
                'escape': 'kp:escape',
                'tab': 'kp:tab',
                'space': 'kp:space',
                'up': 'kp:arrow-up',
                'down': 'kp:arrow-down',
                'left': 'kp:arrow-left',
                'right': 'kp:arrow-right',
                'cmd+space': 'kd:cmd kp:space ku:cmd',
                'cmd+tab': 'kd:cmd kp:tab ku:cmd',
                'cmd+w': 'kd:cmd t:w ku:cmd',
                'cmd+q': 'kd:cmd t:q ku:cmd',
                'cmd+a': 'kd:cmd t:a ku:cmd',
                'cmd+c': 'kd:cmd t:c ku:cmd',
                'cmd+v': 'kd:cmd t:v ku:cmd',
                'cmd+z': 'kd:cmd t:z ku:cmd',
                'cmd+t': 'kd:cmd t:t ku:cmd',
                'cmd+n': 'kd:cmd t:n ku:cmd',
                'cmd+s': 'kd:cmd t:s ku:cmd',
            }
            cliclick_cmd = key_map.get(key, f'kp:{key}')
            args = ['cliclick'] + cliclick_cmd.split(' ')
            subprocess.run(args, timeout=5)
            self.send_json({'status': 'ok', 'key': key})

        elif path == '/type':
            text = data.get('text', '')
            subprocess.run(['cliclick', f't:{text}'], timeout=5)
            self.send_json({'status': 'ok', 'text': text})

        elif path == '/scroll':
            x = data.get('x', 0)
            y = data.get('y', 0)
            amount = data.get('amount', -3)
            subprocess.run(['cliclick', f'm:{x},{y}'], timeout=5)
            script = f'tell application "System Events" to scroll area 1 by {amount}'
            # Use AppleScript for scrolling
            subprocess.run(['osascript', '-e',
                f'tell application "System Events" to key code 125 using {{}}'],
                timeout=5)
            self.send_json({'status': 'ok', 'amount': amount})

        elif path == '/open':
            app = data.get('app', '')
            url = data.get('url', '')
            if app:
                subprocess.run(['open', '-a', app], timeout=5)
                self.send_json({'status': 'ok', 'app': app})
            elif url:
                subprocess.run(['open', url], timeout=5)
                self.send_json({'status': 'ok', 'url': url})
            else:
                self.send_json({'error': 'provide app or url'})

        elif path == '/applescript':
            script = data.get('script', '')
            result = subprocess.getoutput(f"osascript -e '{script}'")
            self.send_json({'status': 'ok', 'result': result})

        else:
            self.send_json({'error': 'not found'}, 404)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def send_json(self, obj, code=200):
        data = json.dumps(obj, indent=2).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {args[0]}")


if __name__ == '__main__':
    print(f"""
=============================================
  Mac Remote Control Server
=============================================
  Port: {PORT}

  Depuis l'iPhone, ouvrez Safari :
  http://<IP_MAC>:{PORT}

  Controles:
  - Tap sur l'ecran = clic
  - Double tap = double clic
  - Bouton Keyboard = taper du texte
  - Spotlight, Cmd+Tab, etc.

  Endpoints API:
  GET  /           - Interface web
  GET  /screenshot - Capture ecran
  GET  /info       - Infos Mac
  POST /click      - Clic souris
  POST /key        - Touche clavier
  POST /type       - Taper du texte
  POST /open       - Ouvrir app/URL
  POST /applescript - Executer AppleScript
=============================================
""")
    server = http.server.HTTPServer(('0.0.0.0', PORT), MacRemoteHandler)
    server.serve_forever()
