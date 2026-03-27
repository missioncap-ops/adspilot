#!/usr/bin/env python3
"""
Mac Remote Control Server v2 - FAST edition
Uses pre-cached screenshots + non-blocking commands + low-res JPEG
"""

import http.server
import socketserver
import subprocess
import json
import os
import urllib.parse
import threading
import time
import io

PORT = 9090
SCREENSHOT_PATH = '/tmp/mac_remote_screen.jpg'
SCREENSHOT_SMALL = '/tmp/mac_remote_small.jpg'

# Capture screenshots in background, always ready
def screenshot_loop():
    while True:
        try:
            tmp = '/tmp/mac_remote_capture.jpg'
            # Capture to temp file first
            result = subprocess.run(
                ['screencapture', '-x', '-t', 'jpg', '-r', tmp],
                timeout=3, capture_output=True
            )
            if result.returncode == 0 and os.path.exists(tmp):
                # Then resize (waits for capture to fully complete)
                result2 = subprocess.run(
                    ['sips', '--resampleWidth', '700', '--setProperty', 'formatOptions', '20',
                     tmp, '--out', SCREENSHOT_SMALL],
                    timeout=3, capture_output=True
                )
                if result2.returncode != 0 or not os.path.exists(SCREENSHOT_SMALL):
                    # Fallback: copy original
                    subprocess.run(['cp', tmp, SCREENSHOT_SMALL], capture_output=True)
        except:
            pass
        time.sleep(0.3)
                timeout=2, capture_output=True, stderr=subprocess.DEVNULL
            )
        except:
            pass
        time.sleep(0.25)

threading.Thread(target=screenshot_loop, daemon=True).start()

HTML_PAGE = r"""<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<title>Mac Remote</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#000;color:#fff;font-family:-apple-system,sans-serif;height:100vh;overflow:hidden;
  -webkit-user-select:none;user-select:none;-webkit-touch-callout:none}

#bar{display:flex;gap:4px;padding:4px;background:#111;overflow-x:auto;white-space:nowrap;z-index:10}
#bar button{padding:6px 8px;border:none;border-radius:6px;background:#333;color:#fff;font-size:12px;flex-shrink:0}
#bar button:active{background:#666}
#bar button.on{background:#07f}

#scr-box{width:100%;height:calc(100vh - 80px);overflow:scroll;-webkit-overflow-scrolling:touch;background:#000}
#scr{display:block;transform-origin:0 0}
#dot{position:absolute;width:14px;height:14px;border:2px solid red;border-radius:50%;
  background:rgba(255,0,0,.3);pointer-events:none;transform:translate(-50%,-50%);display:none;z-index:5}

#foot{position:fixed;bottom:0;left:0;right:0;display:flex;gap:4px;padding:6px;background:#111;z-index:10}
#foot button{flex:1;padding:8px;border:none;border-radius:6px;background:#333;color:#fff;font-size:13px}
#foot button:active{background:#666}
#foot button.on{background:#07f}

#kbd{display:none;position:fixed;bottom:42px;left:0;right:0;background:#111;padding:8px;z-index:20;border-top:1px solid #333}
#kbd input{width:100%;padding:10px;font-size:16px;background:#222;border:1px solid #444;border-radius:6px;color:#fff}
#kbd .row{display:flex;gap:4px;margin-top:6px}
#kbd .row button{flex:1;padding:8px;border:none;border-radius:6px;background:#333;color:#fff;font-size:12px}

#st{position:fixed;bottom:48px;left:50%;transform:translateX(-50%);padding:2px 8px;
  background:rgba(0,0,0,.7);border-radius:8px;font-size:11px;color:#07f;z-index:20}

#zc{position:fixed;right:6px;top:40px;display:flex;flex-direction:column;gap:4px;z-index:15}
#zc button{width:36px;height:36px;border:none;border-radius:50%;background:rgba(50,50,50,.8);color:#fff;font-size:18px}
#zl{text-align:center;font-size:10px;color:#888}
</style>
</head>
<body>
<div id="bar">
<button onclick="K('cmd+space')">Spotlight</button>
<button onclick="K('cmd+tab')">Switch</button>
<button onclick="K('cmd+c')">Copy</button>
<button onclick="K('cmd+v')">Paste</button>
<button onclick="K('cmd+z')">Undo</button>
<button onclick="K('cmd+a')">All</button>
<button onclick="K('cmd+w')">Close</button>
<button onclick="K('cmd+q')">Quit</button>
<button onclick="K('cmd+t')">Tab+</button>
<button onclick="K('cmd+n')">Win+</button>
<button onclick="K('cmd+s')">Save</button>
<button onclick="K('escape')">Esc</button>
<button onclick="K('up')">&#9650;</button>
<button onclick="K('down')">&#9660;</button>
<button onclick="K('left')">&#9664;</button>
<button onclick="K('right')">&#9654;</button>
</div>

<div id="zc">
<button onclick="Z(1)">+</button>
<div id="zl">Fit</div>
<button onclick="Z(-1)">-</button>
<button onclick="Z(0)">Fit</button>
</div>

<div id="scr-box">
<div style="position:relative;display:inline-block">
<img id="scr" src="/screenshot" draggable="false">
<div id="dot"></div>
</div>
</div>

<div id="st">Tap=Click</div>

<div id="kbd">
<input id="ti" placeholder="Type here..." autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false">
<div class="row">
<button onclick="ST()">Send</button>
<button onclick="K('return')">Enter</button>
<button onclick="K('delete')">Del</button>
<button onclick="K('space')">Space</button>
<button onclick="HK()">X</button>
</div>
</div>

<div id="foot">
<button onclick="R()">Refresh</button>
<button id="ab" onclick="TA()">Auto</button>
<button onclick="SK()">Kbd</button>
<button onclick="RC()">RClick</button>
<button id="mb" onclick="TM()">Move</button>
</div>

<script>
let z=1,nw=1,nh=1,ax=0,ay=0,mm=0,ar=0,ai=null,fl=1;
const s=document.getElementById('scr'),
  box=document.getElementById('scr-box'),
  dot=document.getElementById('dot'),
  st=document.getElementById('st');

s.onload=()=>{nw=s.naturalWidth;nh=s.naturalHeight;if(fl){fit();fl=0}else sz()};

// TOUCH -> CLICK
let tx,ty,tt,mv;
document.getElementById('scr-box').addEventListener('touchstart',e=>{
  if(e.touches.length===1){tx=e.touches[0].clientX;ty=e.touches[0].clientY;tt=Date.now();mv=0}
},{passive:true});
document.getElementById('scr-box').addEventListener('touchmove',e=>{
  if(e.touches.length===1){
    if(Math.abs(e.touches[0].clientX-tx)>8||Math.abs(e.touches[0].clientY-ty)>8)mv=1;
  }
},{passive:true});
document.getElementById('scr-box').addEventListener('touchend',e=>{
  if(mv||e.changedTouches.length!==1||Date.now()-tt>400)return;
  const t=e.changedTouches[0],r=s.getBoundingClientRect();
  const x=Math.round((t.clientX-r.left)/r.width*nw);
  const y=Math.round((t.clientY-r.top)/r.height*nh);
  if(x<0||y<0||x>nw||y>nh)return;
  if(mm){MV(x,y)}else{CL(x,y)}
  dot.style.left=(x/nw*100)+'%';dot.style.top=(y/nh*100)+'%';dot.style.display='block';
  ax=x;ay=y;
  st.textContent=(mm?'Move ':'Click ')+x+','+y;
});

function CL(x,y){fetch('/click',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({x,y})}).then(()=>R())}
function RC(){if(!ax)return;fetch('/rightclick',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({x:ax,y:ay})}).then(()=>R())}
function MV(x,y){fetch('/move',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({x,y})})}
function K(k){fetch('/key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({key:k})}).then(()=>R())}
function ST(){const i=document.getElementById('ti');if(!i.value)return;fetch('/type',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text:i.value})}).then(()=>{i.value='';R()})}

function R(){
  const sx=box.scrollLeft,sy=box.scrollTop;
  const img=new Image();
  img.onload=()=>{nw=img.naturalWidth;nh=img.naturalHeight;s.src=img.src;sz();
    requestAnimationFrame(()=>{box.scrollLeft=sx;box.scrollTop=sy})};
  img.src='/screenshot?'+Date.now();
}

function sz(){s.style.width=(nw*z)+'px';s.style.height=(nh*z)+'px';document.getElementById('zl').textContent=Math.round(z*100)+'%'}
function Z(d){if(d===0)fit();else{z=Math.max(.3,Math.min(4,z+(d>0?.2:-.2)));sz()}}
function fit(){z=Math.min(box.clientWidth/nw,(box.clientHeight-10)/nh);sz()}

function TA(){ar=!ar;document.getElementById('ab').classList.toggle('on',ar);if(ar)ai=setInterval(R,400);else clearInterval(ai)}
function TM(){mm=!mm;document.getElementById('mb').classList.toggle('on',mm);st.textContent=mm?'Mode: MOVE':'Mode: CLICK'}
function SK(){const k=document.getElementById('kbd');k.style.display=k.style.display==='none'?'block':'none';document.getElementById('ti').focus()}
function HK(){document.getElementById('kbd').style.display='none'}

document.getElementById('ti').addEventListener('keydown',e=>{if(e.key==='Enter'){ST();e.preventDefault()}});
TA(); // start auto-refresh
</script>
</body>
</html>"""


class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        p=urllib.parse.urlparse(self.path).path
        if p=='/' or p=='':
            d=HTML_PAGE.encode()
            self.send_response(200);self.send_header('Content-Type','text/html');self.send_header('Content-Length',str(len(d)));self.end_headers();self.wfile.write(d)
        elif p=='/screenshot':
            f=SCREENSHOT_SMALL if os.path.exists(SCREENSHOT_SMALL) else SCREENSHOT_PATH
            try:
                with open(f,'rb') as fh:d=fh.read()
            except:d=b''
            self.send_response(200);self.send_header('Content-Type','image/jpeg');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(d)));self.end_headers();self.wfile.write(d)
        elif p=='/info':
            self.j({'host':subprocess.getoutput('hostname'),'user':subprocess.getoutput('whoami')})
        else:self.j({'error':'not found'},404)

    def do_POST(self):
        p=urllib.parse.urlparse(self.path).path
        l=int(self.headers.get('Content-Length',0))
        b=self.rfile.read(l).decode() if l>0 else '{}'
        try:d=json.loads(b)
        except:d={}
        if p=='/click':
            x,y=d.get('x',0),d.get('y',0)
            subprocess.Popen(['cliclick',f'c:{x},{y}'])
            self.j({'ok':1})
        elif p=='/rightclick':
            subprocess.Popen(['cliclick',f'rc:{d.get("x",0)},{d.get("y",0)}'])
            self.j({'ok':1})
        elif p=='/move':
            subprocess.Popen(['cliclick',f'm:{d.get("x",0)},{d.get("y",0)}'])
            self.j({'ok':1})
        elif p=='/key':
            km={'return':'kp:return','delete':'kp:delete','escape':'kp:escape','tab':'kp:tab','space':'kp:space',
                'up':'kp:arrow-up','down':'kp:arrow-down','left':'kp:arrow-left','right':'kp:arrow-right',
                'cmd+space':'kd:cmd kp:space ku:cmd','cmd+tab':'kd:cmd kp:tab ku:cmd',
                'cmd+w':'kd:cmd t:w ku:cmd','cmd+q':'kd:cmd t:q ku:cmd','cmd+a':'kd:cmd t:a ku:cmd',
                'cmd+c':'kd:cmd t:c ku:cmd','cmd+v':'kd:cmd t:v ku:cmd','cmd+z':'kd:cmd t:z ku:cmd',
                'cmd+t':'kd:cmd t:t ku:cmd','cmd+n':'kd:cmd t:n ku:cmd','cmd+s':'kd:cmd t:s ku:cmd'}
            c=km.get(d.get('key',''),f'kp:{d.get("key","")}')
            subprocess.Popen(['cliclick']+c.split(' '))
            self.j({'ok':1})
        elif p=='/type':
            subprocess.Popen(['cliclick',f't:{d.get("text","")}'])
            self.j({'ok':1})
        elif p=='/open':
            a,u=d.get('app',''),d.get('url','')
            if a:subprocess.Popen(['open','-a',a])
            elif u:subprocess.Popen(['open',u])
            self.j({'ok':1})
        else:self.j({'error':'not found'},404)

    def do_OPTIONS(self):
        self.send_response(200);self.send_header('Access-Control-Allow-Origin','*');self.send_header('Access-Control-Allow-Methods','GET,POST');self.send_header('Access-Control-Allow-Headers','Content-Type');self.end_headers()

    def j(self,o,c=200):
        d=json.dumps(o).encode()
        self.send_response(c);self.send_header('Content-Type','application/json');self.send_header('Access-Control-Allow-Origin','*');self.send_header('Content-Length',str(len(d)));self.end_headers();self.wfile.write(d)

    def log_message(self,f,*a):pass  # silent

class S(socketserver.ThreadingMixIn,http.server.HTTPServer):
    daemon_threads=True

if __name__=='__main__':
    print(f"Mac Remote v2 | http://0.0.0.0:{PORT}")
    print("Screenshots: background capture every 250ms, resized to 900px")
    print("All commands non-blocking. Auto-refresh 400ms.")
    S(('0.0.0.0',PORT),H).serve_forever()
