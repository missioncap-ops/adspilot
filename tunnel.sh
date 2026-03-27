#!/bin/bash
# =============================================================
# Tunnel automatique iPhone -> Internet -> Claude Code
# Lance le tunnel et affiche l'URL publique
# Usage: bash tunnel.sh
# =============================================================

IPHONE_IP="192.168.1.104"
IPHONE_PORT="8085"

echo ""
echo "============================================="
echo "  Tunnel iPhone -> Internet"
echo "============================================="
echo ""

# Test connexion locale d'abord
echo "Test connexion a l'iPhone..."
if curl -s --connect-timeout 3 "http://$IPHONE_IP:$IPHONE_PORT/info" >/dev/null 2>&1; then
    echo "OK - iPhone accessible sur le reseau local"
else
    echo "WARN - iPhone non joignable sur $IPHONE_IP:$IPHONE_PORT"
    echo "Verifiez que l'app AdsPilot Remote est ouverte sur l'iPhone"
    echo ""
fi

echo ""
echo "Lancement du tunnel..."
echo "(L'URL publique va s'afficher ci-dessous)"
echo "Copiez-la et donnez-la a Claude Code"
echo ""
echo "============================================="
echo ""

# Methode 1: ssh tunnel via localhost.run (pas d'install)
ssh -o StrictHostKeyChecking=no -R 80:$IPHONE_IP:$IPHONE_PORT localhost.run 2>/dev/null

# Si echec, essayer pinggy
if [ $? -ne 0 ]; then
    echo "localhost.run echoue, essai avec pinggy..."
    ssh -o StrictHostKeyChecking=no -p 443 -R0:$IPHONE_IP:$IPHONE_PORT a.pinggy.io
fi
