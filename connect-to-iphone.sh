#!/bin/bash
# =============================================================
# Connexion depuis Linux vers le Mac (pont MCP)
# =============================================================
# Usage : bash connect-to-iphone.sh <IP_DU_MAC> [PORT]
# Ex:     bash connect-to-iphone.sh 192.168.1.42 3001
# =============================================================

MAC_IP="${1:-}"
MAC_PORT="${2:-3001}"

if [ -z "$MAC_IP" ]; then
    echo "Usage: bash connect-to-iphone.sh <IP_DU_MAC> [PORT]"
    echo "Ex:    bash connect-to-iphone.sh 192.168.1.42 3001"
    exit 1
fi

echo ""
echo "=== Connexion au serveur MCP ==="
echo "Mac IP   : $MAC_IP"
echo "Port     : $MAC_PORT"
echo ""

# Test de connectivite
echo "Test de connexion..."
if curl -s --connect-timeout 5 "http://$MAC_IP:$MAC_PORT" >/dev/null 2>&1; then
    echo "OK - Serveur MCP accessible"
else
    echo "WARN - Serveur non joignable. Verifiez que :"
    echo "  1. Le serveur MCP tourne sur votre Mac"
    echo "  2. Le pare-feu autorise le port $MAC_PORT"
    echo "  3. Les deux machines sont sur le meme reseau"
    echo ""
    echo "Sur votre Mac, lancez :"
    echo "  npx -y mirroir-mcp --transport http --port $MAC_PORT"
    exit 1
fi

# Configurer Claude Code pour utiliser le serveur distant
CLAUDE_MCP_DIR="$HOME/.claude"
CLAUDE_MCP_FILE="$CLAUDE_MCP_DIR/mcp_servers.json"
mkdir -p "$CLAUDE_MCP_DIR"

cat > "$CLAUDE_MCP_FILE" <<MCPEOF
{
  "iphone-remote": {
    "type": "http",
    "url": "http://$MAC_IP:$MAC_PORT"
  }
}
MCPEOF

echo ""
echo "Configuration MCP ecrite dans $CLAUDE_MCP_FILE"
echo ""
echo "=== PRET ==="
echo "Relancez Claude Code pour controler l'iPhone :"
echo "  claude"
echo ""
