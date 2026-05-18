# Maintainer: HWOS Team <dev@hwos.dev>
# GitHub: https://github.com/Anonim-IT/hacker-shell
pkgname=hacker-shell
pkgver=1.0.0
pkgrel=1
pkgdesc="Hacker Shell - Custom shell environment for Hacker Web OS"
arch=('any')
url="https://github.com/Anonim-IT/hacker-shell"
license=('GPL3')
depends=('bash' 'zsh' 'fastfetch' 'hwos-scripts' 'hwos-configs')
install=hacker-shell.install
source=("https://github.com/Anonim-IT/hacker-shell/archive/v${pkgver}.tar.gz")
sha256sums=('SKIP')

package() {
    cd "${srcdir}/hacker-shell-${pkgver}"

    install -Dm755 src/hacker "${pkgdir}/usr/bin/hacker"

    install -Dm644 configs/hwos-integration.sh \
        "${pkgdir}/usr/share/hacker-shell/hwos-integration.sh"

    install -Dm644 configs/hackerrc.default \
        "${pkgdir}/usr/share/hacker-shell/hackerrc.default"

    mkdir -p "${pkgdir}/etc/skel"
    cp configs/hackerrc.default "${pkgdir}/etc/skel/.hackerrc"

    if ! grep -q "^/usr/bin/hacker" "${pkgdir}/etc/shells" 2>/dev/null; then
        echo "/usr/bin/hacker" >> "${pkgdir}/etc/shells"
    fi
}
