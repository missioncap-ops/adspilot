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
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<title>Mac Remote</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #000; color: #fff; font-family: -apple-system, sans-serif; height: 100vh; overflow: hidden; }

#toolbar {
    display: flex; gap: 6px; padding: 6px 8px; background: #1a1a1a;
    align-items: center; overflow-x: auto; white-space: nowrap; z-index: 10;
    -webkit-overflow-scrolling: touch;
}
#toolbar button {
    padding: 7px 10px; border: none; border-radius: 8px; flex-shrink: 0;
    background: #333; color: #fff; font-size: 13px; cursor: pointer;
}
#toolbar button:active { background: #555; }
#toolbar button.active { background: #0a84ff; }

#screen-container {
    position: relative; width: 100%; height: calc(100vh - 44px);
    overflow: auto; -webkit-overflow-scrolling: touch;
    background: #111;
}
#screen-wrapper {
    position: relative; transform-origin: 0 0;
    display: inline-block;
}
#screen {
    display: block; max-width: none;
}
#cursor {
    position: absolute; width: 16px; height: 16px;
    border: 2px solid #ff3b30; border-radius: 50%;
    background: rgba(255,59,48,0.3); pointer-events: none;
    transform: translate(-50%, -50%); display: none; z-index: 5;
    transition: left 0.1s, top 0.1s;
}
#click-indicator {
    position: absolute; width: 40px; height: 40px;
    border: 2px solid #0a84ff; border-radius: 50%;
    pointer-events: none; transform: translate(-50%, -50%);
    display: none; z-index: 6; animation: clickPulse 0.4s ease-out;
}
@keyframes clickPulse {
    0% { opacity: 1; transform: translate(-50%, -50%) scale(0.3); }
    100% { opacity: 0; transform: translate(-50%, -50%) scale(1.5); }
}

#status {
    position: fixed; bottom: 60px; left: 50%; transform: translateX(-50%);
    padding: 4px 12px; background: rgba(0,0,0,0.8); border-radius: 12px;
    font-size: 12px; color: #0a84ff; z-index: 20; white-space: nowrap;
}

#bottom-bar {
    position: fixed; bottom: 0; left: 0; right: 0;
    display: flex; gap: 6px; padding: 8px;
    background: #1a1a1a; border-top: 1px solid #333; z-index: 15;
}
#bottom-bar button {
    flex: 1; padding: 10px; border: none; border-radius: 8px;
    background: #333; color: #fff; font-size: 14px;
}
#bottom-bar button:active { background: #555; }
#bottom-bar button.active { background: #0a84ff; }

#keyboard-modal {
    display: none; position: fixed; bottom: 50px; left: 0; right: 0;
    background: #1a1a1a; padding: 12px; z-index: 20;
    border-top: 1px solid #333;
}
#keyboard-modal input {
    width: 100%; padding: 12px; font-size: 16px; background: #222;
    border: 1px solid #444; border-radius: 8px; color: #fff;
}
#keyboard-modal .actions { display: flex; gap: 6px; margin-top: 8px; flex-wrap: wrap; }
#keyboard-modal .actions button {
    flex: 1; min-width: 60px; padding: 10px; border: none; border-radius: 8px;
    background: #333; color: #fff; font-size: 13px;
}
#keyboard-modal .actions button:active { background: #555; }

#zoom-controls {
    position: fixed; right: 10px; top: 50px; display: flex;
    flex-direction: column; gap: 6px; z-index: 15;
}
#zoom-controls button {
    width: 40px; height: 40px; border: none; border-radius: 50%;
    background: rgba(50,50,50,0.8); color: #fff; font-size: 20px;
    cursor: pointer;
}
#zoom-controls button:active { background: rgba(100,100,100,0.8); }
#zoom-label {
    text-align: center; font-size: 11px; color: #aaa;
}
</style>
</head>
<body>

<div id="toolbar">
    <button onclick="sendKey('cmd+space')">Spotlight</button>
    <button onclick="sendKey('cmd+tab')">Switch</button>
    <button onclick="sendKey('cmd+c')">Copy</button>
    <button onclick="sendKey('cmd+v')">Paste</button>
    <button onclick="sendKey('cmd+z')">Undo</button>
    <button onclick="sendKey('cmd+a')">Sel All</button>
    <button onclick="sendKey('cmd+w')">Close</button>
    <button onclick="sendKey('cmd+q')">Quit</button>
    <button onclick="sendKey('cmd+t')">New Tab</button>
    <button onclick="sendKey('cmd+n')">New Win</button>
    <button onclick="sendKey('cmd+s')">Save</button>
    <button onclick="sendKey('escape')">Esc</button>
    <button onclick="sendKey('tab')">Tab</button>
    <button onclick="sendKey('up')">Up</button>
    <button onclick="sendKey('down')">Down</button>
    <button onclick="sendKey('left')">Left</button>
    <button onclick="sendKey('right')">Right</button>
</div>

<div id="zoom-controls">
    <button onclick="zoomIn()">+</button>
    <div id="zoom-label">100%</div>
    <button onclick="zoomOut()">-</button>
    <button onclick="zoomFit()">Fit</button>
</div>

<div id="screen-container">
    <div id="screen-wrapper">
        <img id="screen" src="/screenshot" alt="Mac Screen" draggable="false">
        <div id="cursor"></div>
        <div id="click-indicator"></div>
    </div>
</div>

<div id="status">Tap = Click | Pinch = Zoom | Scroll = Pan</div>

<div id="keyboard-modal">
    <input id="textInput" placeholder="Tapez du texte..." autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false">
    <div class="actions">
        <button onclick="sendText()">Send</button>
        <button onclick="sendKey('return')">Enter</button>
        <button onclick="sendKey('delete')">Del</button>
        <button onclick="sendKey('space')">Space</button>
        <button onclick="hideKeyboard()">Close</button>
    </div>
</div>

<div id="bottom-bar">
    <button onclick="refresh()">Refresh</button>
    <button id="autoBtn" onclick="toggleAuto()">Auto</button>
    <button onclick="showKeyboard()">Keyboard</button>
    <button onclick="sendRightClick()">Right Click</button>
    <button onclick="moveMouse()">Move</button>
</div>

<script>
let autoRefresh = false, autoInterval = null;
let imgNaturalW = 1, imgNaturalH = 1;
let currentZoom = 1;
let lastClickX = 0, lastClickY = 0;
let moveMode = false;

const scr = document.getElementById('screen');
const wrapper = document.getElementById('screen-wrapper');
const container = document.getElementById('screen-container');
const cursorEl = document.getElementById('cursor');
const clickInd = document.getElementById('click-indicator');
const statusEl = document.getElementById('status');

scr.onload = function() {
    imgNaturalW = scr.naturalWidth;
    imgNaturalH = scr.naturalHeight;
    zoomFit();
    setStatus(imgNaturalW + 'x' + imgNaturalH);
};

// Touch handling for taps (not interfering with scroll)
let touchStartX, touchStartY, touchStartTime, touchMoved;

wrapper.addEventListener('touchstart', function(e) {
    if (e.touches.length === 1) {
        touchStartX = e.touches[0].clientX;
        touchStartY = e.touches[0].clientY;
        touchStartTime = Date.now();
        touchMoved = false;
    }
}, {passive: true});

wrapper.addEventListener('touchmove', function(e) {
    if (e.touches.length === 1) {
        const dx = e.touches[0].clientX - touchStartX;
        const dy = e.touches[0].clientY - touchStartY;
        if (Math.abs(dx) > 10 || Math.abs(dy) > 10) touchMoved = true;
    }
}, {passive: true});

wrapper.addEventListener('touchend', function(e) {
    if (touchMoved || e.changedTouches.length !== 1) return;
    const elapsed = Date.now() - touchStartTime;
    if (elapsed > 500) return; // ignore long press

    const touch = e.changedTouches[0];
    const rect = scr.getBoundingClientRect();
    const scaleX = imgNaturalW / rect.width;
    const scaleY = imgNaturalH / rect.height;
    const x = Math.round((touch.clientX - rect.left) * scaleX);
    const y = Math.round((touch.clientY - rect.top) * scaleY);

    if (x < 0 || y < 0 || x > imgNaturalW || y > imgNaturalH) return;

    if (moveMode) {
        moveTo(x, y);
    } else {
        sendClick(x, y);
    }
    showClickAt(touch.clientX - rect.left, touch.clientY - rect.top);
});

// Pinch zoom
let pinchStartDist = 0, pinchStartZoom = 1;
wrapper.addEventListener('touchstart', function(e) {
    if (e.touches.length === 2) {
        pinchStartDist = Math.hypot(
            e.touches[0].clientX - e.touches[1].clientX,
            e.touches[0].clientY - e.touches[1].clientY
        );
        pinchStartZoom = currentZoom;
    }
}, {passive: true});

wrapper.addEventListener('touchmove', function(e) {
    if (e.touches.length === 2) {
        const dist = Math.hypot(
            e.touches[0].clientX - e.touches[1].clientX,
            e.touches[0].clientY - e.touches[1].clientY
        );
        const scale = dist / pinchStartDist;
        setZoom(Math.max(0.2, Math.min(3, pinchStartZoom * scale)));
        e.preventDefault();
    }
}, {passive: false});

function showClickAt(x, y) {
    clickInd.style.left = x + 'px';
    clickInd.style.top = y + 'px';
    clickInd.style.display = 'block';
    clickInd.style.animation = 'none';
    clickInd.offsetHeight;
    clickInd.style.animation = 'clickPulse 0.4s ease-out';
    setTimeout(() => clickInd.style.display = 'none', 400);
}

function showCursorAt(x, y) {
    cursorEl.style.left = (x / imgNaturalW * 100) + '%';
    cursorEl.style.top = (y / imgNaturalH * 100) + '%';
    cursorEl.style.display = 'block';
    lastClickX = x; lastClickY = y;
}

function sendClick(x, y, dbl) {
    setStatus('Click ' + x + ',' + y);
    showCursorAt(x, y);
    fetch('/click', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({x: x, y: y, double: dbl || false})
    }).then(() => setTimeout(refresh, 200));
}

function sendRightClick() {
    if (!lastClickX) { setStatus('Tap ecran d\\'abord'); return; }
    setStatus('Right click ' + lastClickX + ',' + lastClickY);
    fetch('/rightclick', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({x: lastClickX, y: lastClickY})
    }).then(() => setTimeout(refresh, 200));
}

function moveTo(x, y) {
    setStatus('Move -> ' + x + ',' + y);
    showCursorAt(x, y);
    fetch('/move', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({x: x, y: y})
    });
}

function moveMouse() {
    moveMode = !moveMode;
    document.querySelector('#bottom-bar button:last-child').classList.toggle('active', moveMode);
    setStatus(moveMode ? 'Mode: MOVE (tap = deplace souris)' : 'Mode: CLICK (tap = clic)');
}

function sendKey(key) {
    setStatus('Key: ' + key);
    fetch('/key', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({key: key})
    }).then(() => setTimeout(refresh, 200));
}

function sendText() {
    const input = document.getElementById('textInput');
    if (!input.value) return;
    setStatus('Type: ' + input.value.substring(0, 20));
    fetch('/type', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({text: input.value})
    }).then(() => { input.value = ''; setTimeout(refresh, 200); });
}

function refresh() {
    scr.src = '/screenshot?' + Date.now();
}

function setZoom(z) {
    currentZoom = z;
    scr.style.width = (imgNaturalW * z) + 'px';
    scr.style.height = (imgNaturalH * z) + 'px';
    document.getElementById('zoom-label').textContent = Math.round(z * 100) + '%';
}

function zoomIn() { setZoom(Math.min(3, currentZoom + 0.25)); }
function zoomOut() { setZoom(Math.max(0.2, currentZoom - 0.25)); }
function zoomFit() {
    const cw = container.clientWidth;
    const ch = container.clientHeight - 50;
    const fit = Math.min(cw / imgNaturalW, ch / imgNaturalH);
    setZoom(fit);
}

function toggleAuto() {
    autoRefresh = !autoRefresh;
    document.getElementById('autoBtn').classList.toggle('active', autoRefresh);
    if (autoRefresh) autoInterval = setInterval(refresh, 800);
    else clearInterval(autoInterval);
}

function showKeyboard() {
    document.getElementById('keyboard-modal').style.display = 'block';
    document.getElementById('textInput').focus();
}
function hideKeyboard() {
    document.getElementById('keyboard-modal').style.display = 'none';
}
function setStatus(msg) { statusEl.textContent = msg; }

document.getElementById('textInput').addEventListener('keydown', function(e) {
    if (e.key === 'Enter') { sendText(); e.preventDefault(); }
});

// Auto-refresh on start
toggleAuto();
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

        elif path == '/rightclick':
            x = data.get('x', 0)
            y = data.get('y', 0)
            subprocess.run(['cliclick', f'rc:{x},{y}'], timeout=5)
            self.send_json({'status': 'ok', 'x': x, 'y': y, 'action': 'rightclick'})

        elif path == '/move':
            x = data.get('x', 0)
            y = data.get('y', 0)
            subprocess.run(['cliclick', f'm:{x},{y}'], timeout=5)
            self.send_json({'status': 'ok', 'x': x, 'y': y, 'action': 'move'})

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
