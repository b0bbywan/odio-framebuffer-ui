#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Build the fbrowser-kiosk .deb from an upstream Framebuffer-browser checkout.
# Runs INSIDE the builder image (docker/builder.Dockerfile), natively for the
# arch being packaged.
#
# Usage:
#   build-deb.sh --version <1.0.0+git20260211.4213a69> --commit <upstream sha>
#                [--src ./upstream] [--out ./dist]
#
# --commit is the upstream commit the tree was checked out at; the copyright
# file names it as the corresponding source.
#
# Upstream has no install rule and no usable Debian packaging (its debian/ holds
# prebuilt bullseye/bookworm .debs installing into /usr/local), so this stages
# the payload by hand and lets dpkg-shlibdeps write Depends from what the binary
# actually links.

set -euo pipefail

PKG="fbrowser-kiosk"
VERSION="" COMMIT="" SRC="./upstream" OUT="./dist"

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --commit)  COMMIT="$2"; shift 2 ;;
    --src)     SRC="$2"; shift 2 ;;
    --out)     OUT="$2"; shift 2 ;;
    -h|--help) sed -n '4,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[ -n "${VERSION}" ] || die "--version is required"
[ -n "${COMMIT}" ]  || die "--commit is required"
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

# LGPL-3 is a set of permissions on top of GPL-3, so both apply; base-files
# ships the two texts in /usr/share/common-licenses. The lineage is
# 44670/FBrowser → shownb/FBrowser → e1z0/Framebuffer-browser, LGPL-3 all the
# way. The compiled files (main.cpp, mainwindow.*) carry no headers. The
# BSD-licensed Qt simplebrowser example and data/3rdparty icons are
# FULLBROWSER-only and not in this binary. The exact commit is named so the
# corresponding source stays findable, as LGPL-3 §4 / GPL-3 §6 require.
install -d "${STAGE}/usr/share/doc/${PKG}"
cat > "${STAGE}/usr/share/doc/${PKG}/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Framebuffer-browser
Upstream-Contact: https://github.com/e1z0/Framebuffer-browser/issues
Source: https://github.com/e1z0/Framebuffer-browser/tree/${COMMIT}
Comment: Upstream also offers a commercial license; this package is
 distributed under the LGPL-3 terms only.

Files: *
Copyright: 2022 44670 <https://github.com/44670/FBrowser>
           2022 shownb <https://github.com/shownb/FBrowser>
           2022 e1z0 <e1z0@eofnet.lt>
License: LGPL-3
 This package is free software; you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License version 3 as
 published by the Free Software Foundation.
 .
 On Debian systems, the complete text of the GNU Lesser General Public
 License version 3 can be found in "/usr/share/common-licenses/LGPL-3", and
 the GNU General Public License version 3 it incorporates in
 "/usr/share/common-licenses/GPL-3".

Files: usr/lib/systemd/user/odio-screen.service
Copyright: 2026 Mathieu Réquillart <mathieu.requillart@gmail.com>
License: MIT
Comment: Packaging, from https://github.com/b0bbywan/odio-framebuffer-ui

License: MIT
$(sed 's/^$/./; s/^/ /' "${REPO_ROOT}/LICENSE")
EOF
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
