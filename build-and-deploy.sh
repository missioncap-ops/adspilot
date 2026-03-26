#!/bin/bash
# =============================================================
# Build & Deploy AdsPilot Remote sur iPhone
# =============================================================
# Usage: bash build-and-deploy.sh
# =============================================================

set -e

DEVICE_ID="00008150-001260D43688401C"
TEAM_ID="VK6JCSNK68"
PROJECT_DIR="$(cd "$(dirname "$0")/ios" && pwd)"
PROJECT_PATH="$PROJECT_DIR/AdsPilotRemote.xcodeproj"
SCHEME="AdsPilotRemote"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "============================================="
echo "  Build & Deploy AdsPilot Remote"
echo "============================================="
echo ""
echo "  Device : $DEVICE_ID"
echo "  Team   : $TEAM_ID"
echo "  Project: $PROJECT_PATH"
echo ""

# -----------------------------------------------------------
# Step 1 : Verifier l'iPhone
# -----------------------------------------------------------
echo -e "${BLUE}[1/3]${NC} Verification iPhone..."

if xcrun devicectl list devices 2>/dev/null | grep -q "$DEVICE_ID"; then
    echo -e "  ${GREEN}OK${NC} iPhone connecte"
else
    echo -e "  ${RED}WARN${NC} iPhone non detecte. Verifiez USB + deverrouillage."
    echo "  Appareils disponibles :"
    xcrun devicectl list devices 2>/dev/null | head -20
    echo ""
    echo "  Continuer quand meme ? (Ctrl+C pour annuler)"
    read -r
fi

# -----------------------------------------------------------
# Step 2 : Build
# -----------------------------------------------------------
echo -e "${BLUE}[2/3]${NC} Build de l'app..."

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_IDENTITY="Apple Development" \
    CODE_SIGN_STYLE=Automatic \
    PROVISIONING_PROFILE_SPECIFIER="" \
    build 2>&1 | tail -20

# Trouver le .app dans DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "AdsPilotRemote.app" -path "*/Debug-iphoneos/*" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo -e "  ${RED}FAIL${NC} Build echoue — .app non trouve"
    echo "  Relancez le build manuellement pour voir les erreurs :"
    echo "  xcodebuild -project $PROJECT_PATH -scheme $SCHEME -destination \"id=$DEVICE_ID\" build"
    exit 1
fi

echo -e "  ${GREEN}OK${NC} Build reussi: $APP_PATH"

# -----------------------------------------------------------
# Step 3 : Install sur iPhone
# -----------------------------------------------------------
echo -e "${BLUE}[3/3]${NC} Installation sur iPhone..."

xcrun devicectl device install app \
    --device "$DEVICE_ID" \
    "$APP_PATH"

echo ""
echo "============================================="
echo -e "  ${GREEN}DEPLOYE !${NC}"
echo "============================================="
echo ""
echo "  1. Ouvrez 'AdsPilot Remote' sur votre iPhone"
echo ""
echo "  2. Si 'Developpeur non fiable' :"
echo "     Reglages > General > VPN et gestion des appareils"
echo "     > Faire confiance"
echo ""
echo "  3. L'app affiche son IP et port (8085)"
echo "     Testez: curl http://<IP_IPHONE>:8085/info"
echo ""
echo "  Endpoints disponibles :"
echo "    GET  /info       - Infos device"
echo "    GET  /battery    - Batterie"
echo "    GET  /network    - Reseau"
echo "    GET  /screenshot - Capture ecran (base64)"
echo "    GET  /clipboard  - Lire presse-papier"
echo "    POST /clipboard  - Ecrire presse-papier"
echo "    POST /open       - Ouvrir URL/app"
echo "    POST /notify     - Notification locale"
echo "    POST /vibrate    - Vibrer"
echo "    GET  /brightness - Luminosite"
echo "    POST /brightness - Changer luminosite"
echo "    GET  /volume     - Volume"
echo ""
echo "============================================="
