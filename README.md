# odio-framebuffer-ui

Build pipeline that produces multi-arch Debian packages of
[Framebuffer-browser](https://github.com/e1z0/Framebuffer-browser) for the
[Odio APT repository](https://apt.odio.love).

This is **not a fork** — no source code is vendored here. The CI clones
upstream at a pinned commit, builds it inside per-arch builder images, and
publishes `.deb` artifacts as a GitHub Release.

## What is packaged

`fbrowser-kiosk`: the single-window QtWebEngine browser (upstream's default
cmake build, Qt 5), drawing straight onto `/dev/fb0` with no X server.

- `/usr/bin/fbrowser-kiosk`
- `/usr/lib/systemd/user/odio-screen.service` — shows the odio embedded UI
  (`http://localhost:8018/ui`) on a screen wired to the node. Not enabled:

```bash
sudo usermod -aG tty,video,input $USER     # then log in again
sudo loginctl enable-linger $USER
systemctl --user enable --now odio-screen.service
```

Upstream's interactive `fbrowser` launcher is gone with the rest: the unit
sets the `QT_QPA_*` variables it would export, and the URL comes from the
command line, so `config.json` is not needed either.

## Architectures

- `amd64` (Debian trixie)
- `arm64` (Debian trixie / Raspberry Pi OS trixie)

No `armhf`: Raspberry Pi OS armhf ships no QtWebEngine binaries.

## Releasing

Upstream has no tags, so the commit to build is pinned in
`.github/workflows/build.yml` (`UPSTREAM_COMMIT`). The package version is
derived from it — upstream's `1.0.0`, the commit date and short sha — and the
tag must match it:

```bash
git tag v1.0.0+git20260210.4213a69 && git push origin v1.0.0+git20260210.4213a69
```

A prerelease (routed to the `testing` channel of the APT repo) adds a suffix:

```bash
git tag v1.0.0+git20260210.4213a69-rc1 && git push origin v1.0.0+git20260210.4213a69-rc1
```

A tag that does not name the pinned commit fails the build. To follow upstream,
bump `UPSTREAM_COMMIT`, push, then tag.

## Builder images

Pre-baked images on GHCR carry the Qt toolchain. They are rebuilt
automatically when `docker/builder.Dockerfile` changes, monthly, or on demand
— and must exist before the first build:

```bash
gh workflow run build-images.yml
```

## Packaging

Plain debhelper, in [`debian/`](debian). Upstream carries no usable Debian
packaging, so the CI replaces upstream's `debian/` with this one, writes the
changelog for the version being built with `dch`, runs
`dpkg-buildpackage -b` and gates the result with lintian. `Depends` comes from
`dh_shlibdeps`.

To build locally, mirroring the `Build .deb` step of the workflow:

```bash
git clone https://github.com/e1z0/Framebuffer-browser upstream
docker build -t fbui-builder -f docker/builder.Dockerfile docker
docker run --rm -v "$PWD":/workspace -w /workspace \
  -e DEBEMAIL=you@example.com -e DEB_BUILD_OPTIONS=noddebs fbui-builder bash -c '
    rm -rf upstream/debian && cp -r debian upstream/debian && cd upstream &&
    dch --create --package fbrowser-kiosk --newversion 0.0.0+local \
      --distribution trixie --force-distribution "Local build." &&
    dpkg-buildpackage -b -us -uc'
```

## License

The build scripts, unit and Dockerfile in this repo are licensed under the
[MIT License](LICENSE). The produced packages contain compiled
Framebuffer-browser, which is licensed
[LGPL-3.0](https://github.com/e1z0/Framebuffer-browser/blob/main/LICENSE.LGPLv3).
