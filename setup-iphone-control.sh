#!/bin/bash
# =============================================================
# 🎮 Setup complet : Contrôle iPhone par Claude Code
# =============================================================
# Ce script installe et configure tout automatiquement sur votre Mac
# pour permettre a Claude Code de controler votre iPhone a distance.
#
# Usage : copier-coller cette commande dans le Terminal de votre Mac :
#   curl -sL <URL_DU_SCRIPT> | bash
#   OU
#   bash setup-iphone-control.sh
# =============================================================

set -e

DEVICE_ID="00008150-001260D43688401C"
TEAM_ID="VK6JCSNK68"
MCP_PORT=3001

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}[$1/$TOTAL_STEPS]${NC} $2"; }
print_ok() { echo -e "  ${GREEN}OK${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}WARN${NC} $1"; }
print_fail() { echo -e "  ${RED}FAIL${NC} $1"; }

TOTAL_STEPS=7

echo ""
echo "============================================="
echo "  iPhone Remote Control Setup for Claude Code"
echo "============================================="
echo ""
echo "Device ID : $DEVICE_ID"
echo "Team ID   : $TEAM_ID"
echo "MCP Port  : $MCP_PORT"
echo ""

# -----------------------------------------------------------
# Step 1 : Verifier macOS
# -----------------------------------------------------------
print_step 1 "Verification macOS..."

OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
MAJOR_VERSION=$(echo "$OS_VERSION" | cut -d. -f1)

if [ "$MAJOR_VERSION" -ge 15 ] 2>/dev/null; then
    print_ok "macOS $OS_VERSION (Sequoia+)"
    HAS_SEQUOIA=true
else
    print_warn "macOS $OS_VERSION — iPhone Mirroring non disponible, on utilisera iPhone-MCP"
    HAS_SEQUOIA=false
fi

# -----------------------------------------------------------
# Step 2 : Verifier Node.js
# -----------------------------------------------------------
print_step 2 "Verification Node.js..."

if command -v node &>/dev/null; then
    NODE_VERSION=$(node -v)
    print_ok "Node.js $NODE_VERSION"
else
    print_warn "Node.js non trouve, installation via Homebrew..."
    if command -v brew &>/dev/null; then
        brew install node
        print_ok "Node.js installe"
    else
        print_fail "Homebrew non trouve. Installez Node.js : https://nodejs.org"
        exit 1
    fi
fi

# -----------------------------------------------------------
# Step 3 : Verifier Xcode
# -----------------------------------------------------------
print_step 3 "Verification Xcode..."

if command -v xcodebuild &>/dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -1)
    print_ok "$XCODE_VERSION"
else
    print_fail "Xcode non trouve. Installez-le depuis l'App Store."
    exit 1
fi

# Verifier le SDK iOS
if xcodebuild -showsdks 2>/dev/null | grep -qi ios; then
    print_ok "iOS SDK disponible"
else
    print_warn "iOS SDK non trouve, telechargement..."
    xcodebuild -downloadPlatform iOS
fi

# -----------------------------------------------------------
# Step 4 : Verifier iPhone connecte
# -----------------------------------------------------------
print_step 4 "Detection de l'iPhone..."

if xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICE_ID"; then
    print_ok "iPhone detecte ($DEVICE_ID)"
else
    print_warn "iPhone non detecte avec l'ID $DEVICE_ID"
    echo "  Appareils disponibles :"
    xcrun devicectl list devices 2>/dev/null || echo "  (impossible de lister)"
    echo ""
    echo "  Assurez-vous que :"
    echo "  - L'iPhone est branche en USB"
    echo "  - L'iPhone est deverrouille"
    echo "  - Vous avez fait 'Faire confiance' sur l'iPhone"
fi

# -----------------------------------------------------------
# Step 5 : Installer le serveur MCP
# -----------------------------------------------------------
print_step 5 "Installation du serveur MCP..."

if [ "$HAS_SEQUOIA" = true ]; then
    echo "  -> Installation de mirroir-mcp (methode iPhone Mirroring)"
    npm install -g mirroir-mcp 2>/dev/null || npm install -g mirroir-mcp
    print_ok "mirroir-mcp installe"
    MCP_CMD="mirroir-mcp"
else
    echo "  -> Installation de @blitzdev/iphone-mcp"
    npm install -g @blitzdev/iphone-mcp 2>/dev/null || npm install -g @blitzdev/iphone-mcp
    print_ok "iPhone-mcp installe"
    MCP_CMD="iphone-mcp"
fi

# -----------------------------------------------------------
# Step 6 : Configurer Claude Code MCP
# -----------------------------------------------------------
print_step 6 "Configuration Claude Code MCP..."

CLAUDE_MCP_DIR="$HOME/.claude"
CLAUDE_MCP_FILE="$CLAUDE_MCP_DIR/mcp_servers.json"

mkdir -p "$CLAUDE_MCP_DIR"

if [ "$HAS_SEQUOIA" = true ]; then
    MCP_CONFIG='{
  "mirroir": {
    "command": "npx",
    "args": ["-y", "mirroir-mcp"]
  }
}'
else
    MCP_CONFIG='{
  "iphone-mcp": {
    "command": "npx",
    "args": ["-y", "@blitzdev/iphone-mcp"]
  }
}'
fi

# Merge avec config existante ou creer
if [ -f "$CLAUDE_MCP_FILE" ]; then
    print_warn "Fichier MCP existant detecte, ajout de la config iPhone..."
    # Backup
    cp "$CLAUDE_MCP_FILE" "$CLAUDE_MCP_FILE.bak"
    # Merge avec node
    node -e "
        const fs = require('fs');
        const existing = JSON.parse(fs.readFileSync('$CLAUDE_MCP_FILE', 'utf8'));
        const newConfig = $MCP_CONFIG;
        const merged = { ...existing, ...newConfig };
        fs.writeFileSync('$CLAUDE_MCP_FILE', JSON.stringify(merged, null, 2));
    "
    print_ok "Config MCP mise a jour"
else
    echo "$MCP_CONFIG" > "$CLAUDE_MCP_FILE"
    print_ok "Config MCP creee"
fi

echo "  Fichier : $CLAUDE_MCP_FILE"

# -----------------------------------------------------------
# Step 7 : Lancer le serveur HTTP (pour acces distant)
# -----------------------------------------------------------
print_step 7 "Lancement du serveur MCP en mode HTTP..."

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "IP_NON_TROUVEE")

echo ""
echo "============================================="
echo "  SETUP TERMINE !"
echo "============================================="
echo ""
echo "  IP de votre Mac  : $LOCAL_IP"
echo "  Port MCP         : $MCP_PORT"
echo ""

if [ "$HAS_SEQUOIA" = true ]; then
    echo "  IMPORTANT : Ouvrez 'Recopie iPhone' (iPhone Mirroring)"
    echo "  avant de lancer le serveur."
    echo ""
    echo "  Pour lancer le serveur :"
    echo "    npx -y mirroir-mcp --transport http --port $MCP_PORT"
else
    echo "  Pour lancer le serveur :"
    echo "    npx -y @blitzdev/iphone-mcp --port $MCP_PORT"
fi

echo ""
echo "  Puis donnez a Claude Code :"
echo "    IP   = $LOCAL_IP"
echo "    Port = $MCP_PORT"
echo ""
echo "  Permissions requises (Reglages Systeme > Confidentialite) :"
echo "    - Enregistrement de l'ecran -> Terminal"
echo "    - Accessibilite -> Terminal"
echo ""
echo "============================================="
