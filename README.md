# ATAK plugin dev container

[![build](https://github.com/joshuafuller/atak-plugin-dev/actions/workflows/build.yml/badge.svg)](https://github.com/joshuafuller/atak-plugin-dev/actions/workflows/build.yml)

A ready-made build environment for [ATAK](https://tak.gov) plugins. It builds
your plugin, installs it to an emulator or device, gets it loaded into ATAK,
and runs instrumented tests inside ATAK's own process — without you installing
a JDK, Android SDK components or Gradle on your machine.

Measured against **ATAK-CIV 5.8.0.1** on an Android 14 emulator.

## Start here

**New to ATAK plugins? → [docs/FIRST-PLUGIN.md](docs/FIRST-PLUGIN.md).** From
nothing to a plugin running inside ATAK, in about an hour. Every command is
labelled HOST or CONTAINER, with what you should see at each step.

**An AI agent? → [AGENTS.md](AGENTS.md)**, plus the
[companion skill](https://github.com/joshuafuller/atak-plugin-skill). Every
step but one runs unattended.

**Set up already?**

```bash
docker compose exec atak-dev doctor            # always first
docker compose exec atak-dev deploy MyPlugin
```

## What an ATAK plugin is

ATAK is a mapping application used by search and rescue, fire, law enforcement
and military teams. A plugin is a separate Android APK that ATAK loads **into
its own process** at runtime. It has no activity of its own, and you never
launch it directly.

That explains most of what looks strange here: tests run inside ATAK, ATAK
checks who signed your plugin before loading it, and the SDK is licensed so you
fetch it yourself.

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
- **`scan`** — secrets (tree *and* history), dependency CVEs, licence
  conflicts, SDK material, manifest hygiene. Seconds, no configuration. See
  [docs/SCANNING.md](docs/SCANNING.md).
- **Multi-project by default** — every plugin repo side by side, so several
  people or agents can work at once without sharing a checkout.

The ATAK SDK is **not** in the image. It is licensed material: download your
own from [tak.gov](https://tak.gov) and mount it. See [NOTICE.md](NOTICE.md).

## Requirements

On the **host**: Docker with Compose, Android **platform-tools** (`adb`) and
the **emulator** with `cmdline-tools`, and the **ATAK CIV SDK** from
[tak.gov](https://tak.gov). Roughly 20 GB of disk.

The ATAK SDK is the only thing that cannot be automated — it is behind a
click-through licence.
[docs/FIRST-PLUGIN.md](docs/FIRST-PLUGIN.md) walks through installing the
Android tools and creating an emulator if you do not have them.

The build pulls a published base image
(`ghcr.io/joshuafuller/atak-plugin-dev-base`) and adds the Android SDK locally.
That split is deliberate: Google's terms forbid redistributing the Android SDK,
so it is installed on your machine under your own acceptance rather than shipped
in a shared image. See [NOTICE.md](NOTICE.md). To build the base yourself:

```bash
docker build -f Dockerfile.base -t atak-plugin-dev-base:local .
BASE=atak-plugin-dev-base:local docker compose build
```

## The short version

Assumes you already have an emulator and the SDK; if not, use
[docs/FIRST-PLUGIN.md](docs/FIRST-PLUGIN.md).

```bash
# HOST
git clone https://github.com/joshuafuller/atak-plugin-dev
cd atak-plugin-dev
cp .env.example .env
$EDITOR .env                       # ATAK_SDK_DIR and PLUGINS_DIR

./bin/host-adb-server &            # leave running
docker compose up -d --build       # first build pulls ~2 GB

docker compose exec atak-dev doctor
docker compose exec atak-dev deploy <plugin-dir>
```

Then on the device: **Tools → Plugins → sync → tap the row → Load**.

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

Pair it with the
**[atak-plugin skill](https://github.com/joshuafuller/atak-plugin-skill)**.
The split is deliberate: **this repo carries the tools, the skill carries the
knowledge** — which ATAK failures look like something else, what the licences
permit, and where ATAK's own source answers the question faster than an
experiment will.

```bash
git clone https://github.com/joshuafuller/atak-plugin-skill \
    ~/.claude/skills/atak-plugin
```

## Documentation

| | |
| --- | --- |
| [docs/FIRST-PLUGIN.md](docs/FIRST-PLUGIN.md) | **Start here.** Nothing to a running plugin, end to end |
| [docs/SETUP.md](docs/SETUP.md) | Configuration, how adb reaches the host, what to do when `adb devices` is empty |
| [docs/WORKFLOW.md](docs/WORKFLOW.md) | Scaffolding a plugin, renaming the template, the build-load loop, testing and debugging |
| [docs/SIGNING.md](docs/SIGNING.md) | The signing gate, and what the developer build changes |
| [docs/SHIPPING.md](docs/SHIPPING.md) | Getting a signed APK through TAK's Third Party Pipeline |
| [docs/WHAT-SHIPS.md](docs/WHAT-SHIPS.md) | What ships, what cannot, and how to close each gap — including air-gapped |
| [docs/SCANNING.md](docs/SCANNING.md) | What `scan` checks, and what to install when a project needs more |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Symptom-to-cause table |
| [AGENTS.md](AGENTS.md) | Running the whole loop unattended |

## Licence and attribution

MIT — see [LICENSE](LICENSE).

ATAK and TAK are products of the TAK Product Center and the U.S. Government.
This is an independent, unofficial development tool and is **not affiliated
with or endorsed by** them.

No ATAK SDK material is included or redistributed. [NOTICE.md](NOTICE.md)
covers that boundary, the third-party components the image installs and their
licences, the fact that building the image accepts Google's Android SDK terms
on your behalf, and the licensing of contributions.
