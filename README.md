# AdsPilot - Remote Control Setup (Mac + iPhone)

## Architecture

```
[Claude Code (Linux)] --HTTP--> [Mac + MCP Server] --iPhone Mirroring--> [iPhone]
                                      |
                                      +---> [ScreenPipe + cliclick] ---> [Mac Screen]
```

## Scripts

| Script | Quoi | Ou le lancer |
|---|---|---|
| `setup-mac-control.sh` | Setup complet Mac + iPhone | Sur le Mac |
| `setup-iphone-control.sh` | Setup iPhone uniquement | Sur le Mac |
| `connect-to-iphone.sh` | Connexion distante au Mac | Sur la machine Linux |

## Quick Start

### 1. Sur votre Mac

```bash
git clone https://github.com/missioncap-ops/adspilot.git
cd adspilot
git checkout claude/screen-sharing-setup-XIu7a

# Setup complet (Mac + iPhone)
bash setup-mac-control.sh

# OU juste iPhone
bash setup-iphone-control.sh
```

### 2. Lancer les services (sur le Mac)

```bash
# Ouvrir Recopie iPhone d'abord, puis :
npx -y mirroir-mcp --transport http --port 3001
```

### 3. Connexion distante (depuis Linux)

```bash
bash connect-to-iphone.sh <IP_DU_MAC> 3001
claude
```

## Pre-requis

- macOS 15+ (Sequoia) pour iPhone Mirroring
- Node.js 18+
- iPhone connecte (USB ou Wi-Fi)
- Permissions macOS : Enregistrement de l'ecran + Accessibilite

## Device Info

- **Device ID** : `00008150-001260D43688401C`
- **Team ID** : `VK6JCSNK68`

## Capacites

Claude Code peut :
- Voir l'ecran Mac en temps reel (ScreenPipe)
- Controler le Mac : cliquer, taper, scroller (computer-use MCP)
- Voir l'ecran iPhone (mirroir-mcp)
- Controler l'iPhone : tap, swipe, type, ouvrir apps (mirroir-mcp)
