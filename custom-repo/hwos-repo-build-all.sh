#!/usr/bin/env bash
# Build all HWOS custom packages and add to repository
set -euo pipefail

HWOS_ROOT="/home/hwos"
PACKAGES_DIR="${HWOS_ROOT}/packages"
REPO_DIR="/var/lib/hwos/repo/x86_64"
REPO_NAME="hwos"

echo "[*] HWOS Package Builder"
echo "[*] Building all custom packages..."

# List of packages to build (in dependency order)
PACKAGES=(
    "hwos-configs"
    "hwos-scripts"
    "hwos-theme"
    "hacker-shell"
    "hwins"
    "hwos-installer"
    "hackerrub"
    "hwos-kernel"
)

BUILD_DIR=$(mktemp -d)
trap "rm -rf ${BUILD_DIR}" EXIT

for pkg in "${PACKAGES[@]}"; do
    PKG_DIR="${PACKAGES_DIR}/${pkg}"
    if [[ ! -d "$PKG_DIR" ]]; then
        echo "[!] Package $pkg not found at $PKG_DIR, skipping..."
        continue
    fi

    echo ""
    echo "[*] Building: $pkg"
    cd "$PKG_DIR"

    # Build package
    makepkg -s --noconfirm 2>&1 | tail -5

    # Find built package
    PKG_FILE=$(ls -t *.pkg.tar.zst 2>/dev/null | head -1)
    if [[ -n "$PKG_FILE" ]]; then
        echo "[+] Built: $PKG_FILE"
        cp "$PKG_FILE" "${REPO_DIR}/"
        cd "$REPO_DIR"
        repo-add "${REPO_NAME}.db.tar.gz" "$PKG_FILE"
        cd "$PKG_DIR"
    else
        echo "[!] No package file generated for $pkg"
    fi
done

echo ""
echo "[+] All HWOS packages built and added to repository!"
echo "[*] Repository: ${REPO_DIR}/${REPO_NAME}.db.tar.gz"
echo "[*] To install: pacman -S <package-name>"
