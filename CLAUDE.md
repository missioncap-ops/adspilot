# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A remote-control bridge that lets Claude Code (running on Linux) drive a Mac and an iPhone over HTTP. Three pieces, each on a different machine:

```
[Linux: Claude Code] --HTTP--> [Mac: mac-remote-server.py + cliclick]   --> Mac screen
                          \--> [Mac: mirroir-mcp + iPhone Mirroring]    --> iPhone
[iPhone: AdsPilotRemote.app (HTTPServer.swift)] <-- HTTP --              <-- Linux/Mac
```

The iOS app is **bidirectional**: it exposes its own HTTP server on port 8085 (so Linux/Mac can poll the iPhone for screenshots, clipboard, battery, etc.) and it embeds a UI that talks to the Mac's Python server on port 9090 to view/click the Mac screen from the iPhone.

There is no test suite, no linter, and no package manager root — each piece is built/run with its own native toolchain.

## Components

### `mac-remote-server.py` (runs on the Mac)
- Stdlib-only Python HTTP server on port **9090**.
- Background thread captures the screen every 300 ms via `screencapture` → resizes to 1200 px width with `sips` → writes JPEG to `/tmp/mac_remote_small.jpg`. `GET /screenshot` serves the cached file (never blocks on a fresh capture).
- POST endpoints (`/click`, `/rightclick`, `/move`, `/key`, `/type`, `/open`) shell out to `cliclick` via `subprocess.Popen` — **fire-and-forget, never `wait()`** (intentional, keeps the HTTP handler fast).
- Click coordinates from the client are in *image pixel* space (width = `IMG_WIDTH` = 1200). The server scales them to *logical screen points* using `logical_width / IMG_WIDTH`. `logical_width`/`logical_height` are detected at startup via `osascript`'s Finder desktop bounds. If you change `IMG_WIDTH`, the JS embedded in `HTML_PAGE` keeps using the image's natural dimensions, so coords stay consistent — but the scale factor in the POST handlers must match what `sips --resampleWidth` produces.
- The big `HTML_PAGE` string is a mobile-optimized touch UI served at `/`. It and the iOS `MacRemoteView` are two independent clients of the same JSON API.

### `ios/AdsPilotRemote/` (SwiftUI iOS app, deployment target 16.0)
- Bundle ID `com.adspilot.remote`, Team `VK6JCSNK68`.
- Entry point `AdsPilotRemoteApp.swift` instantiates one `HTTPServer` and one `MainTabView` (tabs: Mac remote / iPhone server status / Settings).
- `HTTPServer.swift` — raw `NWListener` on port **8085**, hand-parses HTTP, routes to `CommandHandler`. Adding an endpoint = a new `case` in the `switch (method, path)` block plus a method on `CommandHandler`. Responses always include CORS headers and `Connection: close`.
- `CommandHandler.swift` — all UIKit work goes through `DispatchQueue.main` (`.async` for fire-and-forget, `.sync` for synchronous reads like clipboard/brightness). The screenshot path renders the key window via `UIGraphicsImageRenderer` and base64-encodes JPEG into the JSON body.
- `MacRemoteView.swift` is the iPhone-side client of `mac-remote-server.py` (port 9090). It auto-refreshes the screenshot every 0.5 s and translates SwiftUI tap locations to image-pixel coords before POSTing.
- The Info.plist sets `NSAllowsArbitraryLoads=true` and `NSLocalNetworkUsageDescription` — required because the app talks plain HTTP to LAN IPs.

### Setup / deploy scripts
- `setup-mac-control.sh` — installs Homebrew, Node, ScreenPipe, `cliclick`, then `npm install -g mirroir-mcp computer-use-mcp-server`, and writes `~/.claude/mcp_servers.json` with three MCP entries. Run on the Mac.
- `setup-iphone-control.sh` — narrower variant that picks `mirroir-mcp` on macOS 15+ (Sequoia, for iPhone Mirroring) or `@blitzdev/iphone-mcp` on older macOS. Merges into existing `mcp_servers.json` via an inline `node -e` script if one is present.
- `connect-to-iphone.sh <MAC_IP> [PORT]` — run on the **Linux** side. Curls the Mac to confirm reachability, then overwrites `~/.claude/mcp_servers.json` with a single HTTP-transport MCP entry pointing at the Mac.
- `build-and-deploy.sh` — builds the Xcode project for a real device and installs it via `xcrun devicectl`. The device UDID is hard-coded as `DEVICE_ID="85F14EFB-5D2C-57CB-BE72-013772898AB5"` here, while `setup-iphone-control.sh` and `README.md` reference a different ID (`00008150-001260D43688401C`). When working on device-deploy code, confirm which ID is the live target before editing.
- `tunnel.sh` — `ssh -R 80:<iPhone>:8085 localhost.run` (falls back to `a.pinggy.io`) to expose the iPhone's server publicly. iPhone IP is hard-coded (`192.168.1.104`).

## Commands

All commands assume the indicated host. There is no CI and no test suite — verification is manual (`curl` the endpoints, watch the iOS app's request log, click around in the embedded web UI).

```bash
# Mac: run the screen-control server (foreground; needs Screen Recording + Accessibility perms on Terminal)
python3 mac-remote-server.py

# Mac: build & deploy the iOS app to a connected iPhone
bash build-and-deploy.sh

# Mac: build only, against a specific device (useful when iterating)
xcodebuild -project ios/AdsPilotRemote.xcodeproj -scheme AdsPilotRemote \
  -destination "id=<DEVICE_UDID>" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=VK6JCSNK68 build

# Linux: point Claude Code's MCP at a Mac running mirroir-mcp in HTTP mode
bash connect-to-iphone.sh <MAC_IP> 3001

# Quick smoke tests once servers are up
curl http://<MAC_IP>:9090/info
curl http://<IPHONE_IP>:8085/info
curl http://<IPHONE_IP>:8085/screenshot   # returns base64 in JSON
```

## Conventions & gotchas

- **Coordinate scaling.** Both the Python server and the iOS Mac-remote view convert between image-pixel coords (what the client sends) and logical screen points (what `cliclick` accepts). When changing screenshot resolution, update *both* the resize step and the scale math, and verify a corner-of-screen click still lands in the corner.
- **Non-blocking subprocess calls.** `mac-remote-server.py` uses `subprocess.Popen` without `.wait()` on every cliclick/open call. Don't "fix" this to `subprocess.run` — the snappy feel depends on it.
- **Main-thread UIKit.** Every method on `CommandHandler` that touches UIKit/AVFoundation hops to `DispatchQueue.main`. Keep that pattern when adding endpoints; the `NWListener` callback runs on a background queue.
- **HTTP parsing is naive.** `HTTPServer.processHTTPRequest` splits on `\r\n\r\n` for the body and assumes a single-read request — fine for JSON bodies under 64 KB but don't add streaming/multipart endpoints without rewriting that path.
- **Hard-coded identifiers.** Device UDIDs, team ID, IP addresses, and ports appear in multiple files (`build-and-deploy.sh`, `setup-iphone-control.sh`, `tunnel.sh`, `README.md`). If you change one, grep for the value and update all sites — there is no shared config.
- **Language mix.** Scripts and user-facing strings are in French (no accents — the codebase uses ASCII-only French like "demarre", "ecran"). Keep that style when editing existing strings; English is fine for new code identifiers and comments.
- **No `.gitignore` discipline beyond `__pycache__`.** The Xcode project is committed; build artifacts under `~/Library/Developer/Xcode/DerivedData` are not in the tree.
