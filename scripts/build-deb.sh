#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Build the fbrowser-kiosk .deb from an upstream Framebuffer-browser checkout.
# Runs INSIDE the builder image (docker/builder.Dockerfile), natively for the
# arch being packaged.
#
# Usage:
#   build-deb.sh --version <1.0.0+git20260211.4213a69> [--src ./upstream] [--out ./dist]
#
# Upstream has no install rule and no usable Debian packaging (its debian/ holds
# prebuilt bullseye/bookworm .debs installing into /usr/local), so this stages
# the payload by hand and lets dpkg-shlibdeps write Depends from what the binary
# actually links.

set -euo pipefail

PKG="fbrowser-kiosk"
VERSION="" SRC="./upstream" OUT="./dist"

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --src)     SRC="$2"; shift 2 ;;
    --out)     OUT="$2"; shift 2 ;;
    -h|--help) sed -n '4,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[ -n "${VERSION}" ] || die "--version is required"
[ -f "${SRC}/mainwindow.cpp" ] || die "no Framebuffer-browser tree at ${SRC}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$(cd "${SRC}" && pwd)"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"
ARCH="$(dpkg --print-architecture)"
BUILD="${REPO_ROOT}/build/${ARCH}"
STAGE="${REPO_ROOT}/stage/${ARCH}"

echo "=== ${PKG} ${VERSION} → ${ARCH} ==="

# FULLBROWSER stays OFF: the kiosk variant is the single-window browser odio's
# UI runs in. Upstream's own script names the two the other way round.
rm -rf "${BUILD}"
cmake -S "${SRC}" -B "${BUILD}" -DCMAKE_BUILD_TYPE=Release -DFULLBROWSER=OFF
cmake --build "${BUILD}" --parallel "$(nproc)"

rm -rf "${STAGE}"
install -Dm755 "${BUILD}/FBrowser" "${STAGE}/usr/bin/${PKG}"
strip --strip-unneeded "${STAGE}/usr/bin/${PKG}"
install -Dm644 "${REPO_ROOT}/packaging/odio-screen.service" \
               "${STAGE}/usr/lib/systemd/user/odio-screen.service"
install -Dm644 "${SRC}/README.md" "${STAGE}/usr/share/doc/${PKG}/README.md"
{
  echo "Upstream: https://github.com/e1z0/Framebuffer-browser"
  echo "License: LGPL-3.0"
  echo
  cat "${SRC}/LICENSE.LGPLv3"
} > "${STAGE}/usr/share/doc/${PKG}/copyright"
chmod 644 "${STAGE}/usr/share/doc/${PKG}/copyright"

echo "=== gate: every shared library resolves ==="
if ldd "${STAGE}/usr/bin/${PKG}" | grep 'not found'; then
  die "unresolved shared libraries"
fi
echo "=== shared libraries required ==="
objdump -p "${STAGE}/usr/bin/${PKG}" | sed -n 's/^ *NEEDED *//p' | sort

# dpkg-shlibdeps insists on a debian/control in its working directory.
SHLIBS="$(mktemp -d)"
mkdir -p "${SHLIBS}/debian"
echo "Source: ${PKG}" > "${SHLIBS}/debian/control"
DEPENDS="$(cd "${SHLIBS}" \
  && dpkg-shlibdeps -O -e"${STAGE}/usr/bin/${PKG}" 2>/dev/null \
  | sed -n 's/^shlibs:Depends=//p')"
rm -rf "${SHLIBS}"
[ -n "${DEPENDS}" ] || die "dpkg-shlibdeps produced no Depends"

mkdir -p "${STAGE}/DEBIAN"
cat > "${STAGE}/DEBIAN/control" <<EOF
Package: ${PKG}
Version: ${VERSION}
Architecture: ${ARCH}
Maintainer: Mathieu Réquillart <mathieu.requillart@gmail.com>
Installed-Size: $(du -sk --exclude=DEBIAN "${STAGE}" | cut -f1)
Depends: ${DEPENDS}
Section: web
Priority: optional
Homepage: https://github.com/e1z0/Framebuffer-browser
Description: QtWebEngine kiosk browser for the Linux framebuffer
 Single-window web browser drawing straight onto /dev/fb0, with no X server
 or Wayland compositor. Built from e1z0/Framebuffer-browser for odio, and
 ships a user unit, odio-screen.service (not enabled), that shows the odio
 embedded UI on a screen wired to the node.
EOF

DEB="${OUT}/${PKG}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group -Zxz "${STAGE}" "${DEB}"

echo "--- package"
dpkg-deb --info "${DEB}"
dpkg-deb --contents "${DEB}"
ls -lh "${DEB}"
echo "=== done: ${DEB} ==="
