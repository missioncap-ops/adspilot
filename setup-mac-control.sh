#!/bin/bash
# =============================================================
# Setup complet : Controle Mac + iPhone par Claude Code
# =============================================================
# Installe ScreenPipe (voir Mac) + mirroir-mcp (voir/controler iPhone)
# + computer-use MCP (controler Mac)
#
# Usage : bash setup-mac-control.sh
# =============================================================

set -e

MCP_PORT_IPHONE=3001
MCP_PORT_MAC=3002

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "\n${BLUE}[$1/$TOTAL_STEPS]${NC} $2"; }
print_ok() { echo -e "  ${GREEN}OK${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}WARN${NC} $1"; }

TOTAL_STEPS=6

echo ""
echo "============================================="
echo "  Mac + iPhone Control Setup for Claude Code"
echo "============================================="
echo ""

# -----------------------------------------------------------
# Step 1 : Homebrew
# -----------------------------------------------------------
print_step 1 "Verification Homebrew..."

if command -v brew &>/dev/null; then
    print_ok "Homebrew installe"
else
    print_warn "Installation de Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    print_ok "Homebrew installe"
fi

# -----------------------------------------------------------
# Step 2 : Node.js
# -----------------------------------------------------------
print_step 2 "Verification Node.js..."

if command -v node &>/dev/null; then
    print_ok "Node.js $(node -v)"
else
    brew install node
    print_ok "Node.js installe"
fi

# -----------------------------------------------------------
# Step 3 : ScreenPipe (voir l'ecran Mac)
# -----------------------------------------------------------
print_step 3 "Installation ScreenPipe..."

if command -v screenpipe &>/dev/null; then
    print_ok "ScreenPipe deja installe"
else
    brew tap mediar-ai/screenpipe 2>/dev/null || true
    brew install screenpipe
    print_ok "ScreenPipe installe"
fi

# -----------------------------------------------------------
# Step 4 : cliclick (controler souris/clavier Mac)
# -----------------------------------------------------------
print_step 4 "Installation cliclick..."

if command -v cliclick &>/dev/null; then
    print_ok "cliclick deja installe"
else
    brew install cliclick
    print_ok "cliclick installe"
fi

# -----------------------------------------------------------
# Step 5 : MCP servers (iPhone + Mac)
# -----------------------------------------------------------
print_step 5 "Installation des serveurs MCP..."

npm install -g mirroir-mcp 2>/dev/null || npm install -g mirroir-mcp
print_ok "mirroir-mcp (iPhone)"

npm install -g computer-use-mcp-server 2>/dev/null || npm install -g computer-use-mcp-server
print_ok "computer-use-mcp (Mac)"

# -----------------------------------------------------------
# Step 6 : Configuration Claude Code
# -----------------------------------------------------------
print_step 6 "Configuration Claude Code MCP..."

CLAUDE_MCP_DIR="$HOME/.claude"
CLAUDE_MCP_FILE="$CLAUDE_MCP_DIR/mcp_servers.json"
mkdir -p "$CLAUDE_MCP_DIR"

cat > "$CLAUDE_MCP_FILE" <<'MCPEOF'
{
  "screenpipe": {
    "command": "npx",
    "args": ["-y", "screenpipe-mcp"]
  },
  "computer-use": {
    "command": "npx",
    "args": ["-y", "computer-use-mcp-server"]
  },
  "mirroir": {
    "command": "npx",
    "args": ["-y", "mirroir-mcp"]
  }
}
MCPEOF

print_ok "Config MCP ecrite dans $CLAUDE_MCP_FILE"

# -----------------------------------------------------------
# Resultat
# -----------------------------------------------------------
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "IP_NON_TROUVEE")

echo ""
echo "============================================="
echo "  SETUP COMPLET !"
echo "============================================="
echo ""
echo "  IP Mac : $LOCAL_IP"
echo ""
echo "  --- Services a lancer ---"
echo ""
echo "  1. ScreenPipe (voir Mac) :"
echo "     screenpipe"
echo ""
echo "  2. Serveur iPhone (controler iPhone) :"
echo "     Ouvrez d'abord Recopie iPhone, puis :"
echo "     npx -y mirroir-mcp --transport http --port $MCP_PORT_IPHONE"
echo ""
echo "  3. Claude Code local (controle direct) :"
echo "     claude"
echo ""
echo "  --- Acces distant (depuis Linux) ---"
echo ""
echo "  Sur la machine Linux :"
echo "     bash connect-to-iphone.sh $LOCAL_IP $MCP_PORT_IPHONE"
echo ""
echo "  --- Permissions macOS requises ---"
echo ""
echo "  Reglages Systeme > Confidentialite & Securite :"
echo "    - Enregistrement de l'ecran -> Terminal"
echo "    - Accessibilite -> Terminal"
echo ""
echo "============================================="
