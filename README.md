# AdsPilot - iPhone Remote Control Setup

## Setup : Controle iPhone par Claude Code

Ce repo contient un script de setup automatique pour permettre a Claude Code
de voir et controler votre iPhone a distance.

### Architecture

```
[Claude Code (Linux)] --HTTP--> [Mac + MCP Server] --iPhone Mirroring--> [iPhone]
```

### Quick Start

Sur votre Mac, dans le Terminal :

```bash
bash setup-iphone-control.sh
```

Le script :
1. Verifie macOS, Node.js, Xcode
2. Detecte votre iPhone
3. Installe le serveur MCP adapte (mirroir-mcp ou iPhone-mcp)
4. Configure Claude Code
5. Lance le serveur en mode HTTP

### Pre-requis

- macOS 15+ (Sequoia) pour iPhone Mirroring, OU Xcode pour iPhone-mcp
- Node.js 18+
- iPhone connecte en USB ou Wi-Fi
- Permissions macOS : Enregistrement de l'ecran + Accessibilite

### Infos device

- **Device ID** : `00008150-001260D43688401C`
- **Team ID** : `VK6JCSNK68`
- **MCP Port** : `3001`

### Capacites Claude Code

Une fois configure, Claude Code peut :
- Voir l'ecran de l'iPhone en temps reel
- Taper (tap) a des coordonnees
- Swiper (haut, bas, gauche, droite)
- Ecrire du texte
- Ouvrir/fermer des apps
- Naviguer dans iOS
