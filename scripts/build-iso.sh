#!/usr/bin/env bash
# HWOS ISO Builder
# Builds the Hacker Web OS Live ISO using archiso
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

HWOS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO_DIR="${HWOS_ROOT}/archiso/releng"
OUTPUT_DIR="${HWOS_ROOT}/out"
WORK_DIR="/tmp/archiso-tmp"

check_deps() {
    echo -e "${CYAN}[*] Checking dependencies...${NC}"
    local deps=("archiso" "make" "mkarchiso")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            if pacman -Qi "$dep" &>/dev/null; then
                echo -e "${GREEN}[+] $dep found${NC}"
            else
                echo -e "${RED}[!] Missing: $dep${NC}"
                echo -e "${YELLOW}[*] Install with: sudo pacman -S archiso${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}[+] $dep found${NC}"
        fi
    done
}

build_packages() {
    echo -e "${CYAN}[*] Building HWOS custom packages...${NC}"
    bash "${HWOS_ROOT}/custom-repo/hwos-repo-build-all.sh"
}

prepare_airootfs() {
    echo -e "${CYAN}[*] Preparing airootfs...${NC}"

    # Copy custom packages to airootfs
    mkdir -p "${ISO_DIR}/airootfs/root/packages"
    cp -r "${HWOS_ROOT}/packages"/* "${ISO_DIR}/airootfs/root/packages/" 2>/dev/null || true
}

build_iso() {
    echo -e "${CYAN}[*] Building HWOS ISO...${NC}"

    export HWOS_BUILD=1
    export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"

    mkdir -p "$OUTPUT_DIR"
    cd "$ISO_DIR"

    mkarchiso -v -w "$WORK_DIR" -o "$OUTPUT_DIR" .

    echo -e "${GREEN}[+] ISO build complete!${NC}"
    echo -e "${GREEN}[+] Output: ${OUTPUT_DIR}/hwos-*.iso${NC}"
}

clean() {
    echo -e "${YELLOW}[*] Cleaning build artifacts...${NC}"
    rm -rf "$WORK_DIR"
    rm -f "${ISO_DIR}/airootfs/root/packages" 2>/dev/null || true
    echo -e "${GREEN}[+] Cleaned${NC}"
}

usage() {
    echo "Usage: $0 {build|clean|full}"
    echo ""
    echo "  build   - Build HWOS ISO"
    echo "  clean   - Clean build artifacts"
    echo "  full    - Build packages + ISO (full build)"
}

case "${1:-build}" in
    build)
        check_deps
        prepare_airootfs
        build_iso
        ;;
    clean)
        clean
        ;;
    full)
        check_deps
        build_packages
        prepare_airootfs
        build_iso
        ;;
    help|--help)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac
