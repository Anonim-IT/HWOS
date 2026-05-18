#!/usr/bin/env bash
# HWOS Custom Repository Setup Script
set -euo pipefail

REPO_DIR="/var/lib/hwos/repo"
REPO_NAME="hwos"
ARCH="x86_64"
PACMAN_CONF="/etc/pacman.conf"

echo "[*] Setting up HWOS custom repository..."

# Create repo directory
mkdir -p "${REPO_DIR}/${ARCH}"

# Add repo to pacman.conf if not already present
if ! grep -q "\[${REPO_NAME}\]" "$PACMAN_CONF"; then
    cat >> "$PACMAN_CONF" <<EOF

[${REPO_NAME}]
SigLevel = Optional TrustAll
Server = file://${REPO_DIR}/\$arch
EOF
    echo "[+] Repository added to pacman.conf"
fi

echo "[*] HWOS repository initialized at ${REPO_DIR}"
echo "[*] To add packages, run:"
echo "    cd ${REPO_DIR}/${ARCH}"
echo "    repo-add ${REPO_NAME}.db.tar.gz <package>.pkg.tar.zst"
echo ""
echo "[*] To build and add all HWOS packages:"
echo "    hwos-repo-build-all"
