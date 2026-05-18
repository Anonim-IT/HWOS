# Maintainer: HWOS Team <dev@hwos.dev>
# GitHub: https://github.com/hwos/hacker-shell
pkgname=hacker-shell
pkgver=1.0.0
pkgrel=1
pkgdesc="Hacker Shell - Custom shell environment for Hacker Web OS"
arch=('any')
url="https://hwos.dev"
license=('GPL3')
depends=('bash' 'zsh' 'fastfetch' 'hwos-scripts' 'hwos-configs')
install=hacker-shell.install
source=(
  "src/hacker"
  "configs/hwos-integration.sh"
  "configs/hackerrc.default"
)
sha256sums=('SKIP' 'SKIP' 'SKIP')

package() {
    install -Dm755 src/hacker "${pkgdir}/usr/bin/hacker"

    install -Dm644 configs/hwos-integration.sh \
        "${pkgdir}/usr/share/hacker-shell/hwos-integration.sh"

    install -Dm644 configs/hackerrc.default \
        "${pkgdir}/usr/share/hacker-shell/hackerrc.default"

    mkdir -p "${pkgdir}/etc/skel"
    cp configs/hackerrc.default "${pkgdir}/etc/skel/.hackerrc"

    # Only add to shells if not already present
    if ! grep -q "^/usr/bin/hacker" "${pkgdir}/etc/shells" 2>/dev/null; then
        echo "/usr/bin/hacker" >> "${pkgdir}/etc/shells"
    fi
}
