# ATAK plugin dev container

[![build](https://github.com/joshuafuller/atak-plugin-dev/actions/workflows/build.yml/badge.svg)](https://github.com/joshuafuller/atak-plugin-dev/actions/workflows/build.yml)

A ready-made build environment for [ATAK](https://tak.gov) plugins. It builds
your plugin, installs it to an emulator or device, gets it loaded into ATAK,
and runs instrumented tests inside ATAK's own process — without you installing
a JDK, Android SDK components or Gradle on your machine.

Measured against **ATAK-CIV 5.8.0.1** on an Android 14 emulator.

## Why

Getting a first ATAK plugin to load is mostly not a coding problem. It is a
handful of environment facts that each fail in a way that looks like something
else — a plugin reported as "Incompatible" when the real cause is a signing
certificate, a test run that hangs for ten minutes instead of saying it cannot
reach adb, an emulator that renders nothing while UI automation reports
success.

This container encodes those facts so they cost you nothing. `doctor` checks
each one and tells you what to do about the first that is wrong.

## What you get

- **Pinned toolchain** — Temurin 17, Android platforms 36 and 34, build-tools
  36.0.0, Gradle 8.14.3 pre-seeded so the first build does not download it.
- **`doctor`** — verifies the SDK layout, toolchain, adb bridge, emulator image,
  and whether the ATAK on your device will actually accept your plugin.
- **`deploy`** — build, install, and stage for sideload in one command.
- **`instrument`** — instrumented tests inside ATAK, avoiding the Gradle test
  platform that cannot reach a forwarded adb socket.
- **Multi-project by default** — every plugin repo side by side, so several
  people or agents can work at once without sharing a checkout.

The ATAK SDK is **not** in the image. It is licensed material: download your
own from [tak.gov](https://tak.gov) and mount it. See [NOTICE.md](NOTICE.md).

## Requirements

Docker with Compose, an Android emulator or device on the host, and the ATAK
CIV SDK.

## Start

```bash
git clone https://github.com/joshuafuller/atak-plugin-dev
cd atak-plugin-dev
cp .env.example .env
$EDITOR .env                       # ATAK_SDK_DIR and PLUGINS_DIR

./bin/host-adb-server &            # on the HOST, leave running
docker compose up -d --build       # first build pulls ~2 GB

docker compose exec atak-dev doctor
```

`doctor` passing means the environment is sound. Then:

```bash
docker compose exec atak-dev deploy <plugin-dir>
```

and on the device: **Tools → Plugins → sync → tap the row → Load**.

## The one thing to know before you start

ATAK compares a plugin's signing certificate against its own, so the
**release** ATAK from tak.gov or the Play Store will refuse a plugin you built
here — reporting it as "Incompatible", which sounds like a version problem and
is not. Install the `atak.apk` that ships inside the SDK instead.

`doctor` checks this. [docs/SIGNING.md](docs/SIGNING.md) explains it.

## Working with an AI agent

Point it at **[AGENTS.md](AGENTS.md)**. Everything after the SDK download —
build, install, load, drive the UI, run tests, read the result — is designed to
run without a human. Downloading the SDK is the one step that cannot be
automated: it is behind a click-through licence.

## Documentation

| | |
| --- | --- |
| [docs/SETUP.md](docs/SETUP.md) | Configuration, how adb reaches the host, what to do when `adb devices` is empty |
| [docs/WORKFLOW.md](docs/WORKFLOW.md) | Scaffolding a plugin, renaming the template, the build-load loop, testing and debugging |
| [docs/SIGNING.md](docs/SIGNING.md) | The signing gate, and what the developer build changes |
| [docs/SHIPPING.md](docs/SHIPPING.md) | Getting a signed APK through TAK's Third Party Pipeline |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Symptom-to-cause table |
| [AGENTS.md](AGENTS.md) | Running the whole loop unattended |

There is also a [Claude skill](https://github.com/joshuafuller/atak-plugin-skill)
carrying the same measured facts, for agent-assisted work.

## Licence and attribution

MIT — see [LICENSE](LICENSE).

ATAK and TAK are products of the TAK Product Center and the U.S. Government.
This is an independent, unofficial development tool and is **not affiliated
with or endorsed by** them.

No ATAK SDK material is included or redistributed. [NOTICE.md](NOTICE.md)
covers that boundary, the third-party components the image installs and their
licences, the fact that building the image accepts Google's Android SDK terms
on your behalf, and the licensing of contributions.
