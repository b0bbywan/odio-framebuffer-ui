  <p align="center">
    <a href="https://odio.love">
      <img src="https://odio.love/logo.png" alt="odio" width="160" />
    </a>
  </p>
  <h1 align="center">odio-framebuffer-ui</h1>
  <p align="center"><em>A single-window browser drawing straight onto the Linux framebuffer.</em></p>
  <p align="center">
    <a href="https://github.com/b0bbywan/odio-framebuffer-ui/releases"><img src="https://img.shields.io/github/v/release/b0bbywan/odio-framebuffer-ui?include_prereleases" alt="Release" /></a>
    <a href="https://github.com/b0bbywan/odio-framebuffer-ui/blob/main/LICENSE"><img src="https://img.shields.io/github/license/b0bbywan/odio-framebuffer-ui" alt="License" /></a>
    <a href="https://github.com/b0bbywan/odio-framebuffer-ui/actions/workflows/build.yml"><img src="https://github.com/b0bbywan/odio-framebuffer-ui/actions/workflows/build.yml/badge.svg" alt="Build" /></a>
    <a href="https://github.com/sponsors/b0bbywan"><img src="https://img.shields.io/github/sponsors/b0bbywan?label=Sponsor&logo=GitHub" alt="GitHub Sponsors" /></a>
  </p>
  <p align="center">
    Part of the <a href="https://odio.love">odio</a> project — <a href="https://docs.odio.love/">Full documentation</a>.
  </p>
  <p align="center">
    <a href="https://www.qt.io/"><img src="https://img.shields.io/badge/Qt%206-41CD52?logo=qt&logoColor=white" alt="Qt 6" /></a>
    <a href="https://isocpp.org/"><img src="https://img.shields.io/badge/C%2B%2B-00599C?logo=cplusplus&logoColor=white" alt="C++" /></a>
    <a href="https://www.chromium.org/"><img src="https://img.shields.io/badge/Chromium-4285F4?logo=googlechrome&logoColor=white" alt="Chromium" /></a>
    <a href="https://www.debian.org/"><img src="https://img.shields.io/badge/Debian-A81D33?logo=debian&logoColor=white" alt="Debian" /></a>
    <a href="https://github.com/features/actions"><img src="https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white" alt="GitHub Actions" /></a>
  </p>

# odio-kiosk

A single-window QtWebEngine browser drawing straight onto `/dev/fb0`, with no
X server or Wayland compositor: one page, full screen, no chrome around it. It
is published as a Debian package to the [odio APT repository](https://apt.odio.love).

The source in [`src/`](src) derives from
[Framebuffer-browser](https://github.com/e1z0/Framebuffer-browser) at commit
`4213a69`, reduced to the kiosk window and ported to Qt 6. Upstream's full
browser — the Qt 5 simplebrowser example, with tabs, downloads, popups and
dialogs — is not carried here. What remains is `main.cpp` and `mainwindow.cpp`,
still LGPL-3; see [`debian/copyright`](debian/copyright).

## Why Qt 6

Qt 5.15 carries Chromium 87, from late 2020. It predates `:where()`,
`accent-color`, container queries, unprefixed `mask-*` and `Object.hasOwn`, and
the failures are quiet: an unknown pseudo-class invalidates the CSS rule that
contains it, and a missing built-in surfaces as a caught exception somewhere in
a library. Qt 6.8, the version Debian trixie ships, carries Chromium 122.

## Contents

- `/usr/bin/odio-kiosk`
- `/etc/default/odio-kiosk` — the node's Qt environment: the framebuffer every
  screen defaults to, the `QT_QPA_FB_*` settings and the Chromium flags.
- `/usr/lib/systemd/user/odio-kiosk@.service` — a template, one instance per
  screen. `~/.config/odio-kiosk/<instance>.conf` names the page that screen
  shows, and its framebuffer if it is not the first:

  ```
  URL=http://localhost:8018/ui
  FB=/dev/fb1
  ```

  No instance is enabled on install:

```bash
sudo usermod -aG tty,video,input $USER     # then log in again
sudo loginctl enable-linger $USER
mkdir -p ~/.config/odio-kiosk
printf 'URL=http://localhost:8018/ui\n' > ~/.config/odio-kiosk/main.conf
systemctl --user enable --now odio-kiosk@main.service
```

`/etc/default/odio-kiosk` sets the `QT_QPA_*` variables upstream's `fbrowser`
launcher would export, and the URL comes from the command line, so
`config.json` is not needed.

The unit names no server. Which one to wait for, and be restarted with, is
deployment configuration, so it goes in a drop-in:

```ini
# ~/.config/systemd/user/odio-kiosk@main.service.d/wait-for.conf
[Unit]
After=default.target my-server.service
PartOf=my-server.service
```

`After=default.target` belongs there too: without it the target orders itself
after the kiosk, and a server that is itself `After=default.target` closes a
cycle at boot.

## Architectures

- `amd64` (Debian trixie)
- `arm64` (Debian trixie / Raspberry Pi OS trixie)

No `armhf`. Raspberry Pi OS armhf is Raspbian, a separate rebuild of the
archive, and it publishes the `qt6-webengine` source and its `Architecture: all`
pieces but no armhf binary — exactly as it did for Qt 5. The Qt 6 move does not
bring armhf back; a 64-bit Pi OS install does.

## Building locally

```bash
docker build -t fbui-builder -f docker/builder.Dockerfile docker
docker run --rm -v "$PWD":/workspace \
  -e DEBEMAIL=you@example.com -e DEB_BUILD_OPTIONS=noddebs fbui-builder bash -c '
    mkdir -p /build/src && cp -a /workspace/. /build/src/ && cd /build/src &&
    dch --newversion 0.0.0+local -b --distribution trixie --force-distribution "Local build." &&
    dpkg-buildpackage -b -us -uc && cp /build/*.deb /workspace/dist/'
```

Or, against the system Qt 6:

```bash
cmake -B build && cmake --build build
./build/odio-kiosk http://localhost:8018/ui
```

## Releasing

[`debian/changelog`](debian/changelog) holds the version, and the tag has to
name it — a tag that does not match fails the build, so a stale tag cannot
publish something else:

```bash
git tag v2.0.0 && git push origin v2.0.0
```

A prerelease (routed to the `testing` channel of the APT repo) adds a suffix,
which becomes a `~` version so apt upgrades off it:

```bash
git tag v2.0.0-rc1 && git push origin v2.0.0-rc1
```

Branch pushes build but publish nothing; they are versioned `0.0.0+ci.<sha>`.

## Builder images

Pre-baked images on GHCR carry the Qt toolchain. They are rebuilt
automatically when `docker/builder.Dockerfile` changes, monthly, or on demand
— and must exist before the first build:

```bash
gh workflow run build-images.yml
```

## Packaging

Plain debhelper, in [`debian/`](debian), native format: the source and its
packaging live in the same repo, so the version carries no Debian revision.
`Depends` comes from `dh_shlibdeps`, and lintian gates every build.

## License

The build scripts, unit and Dockerfile are [MIT](LICENSE). The browser source
in `src/`, and the packages built from it, are
[LGPL-3.0](LICENSE.LGPLv3).
