# What ships, what does not, and how you close the gap

Three things this project needs cannot be shipped with it, all for licence
reasons. This page says exactly what is missing, why, what to run, and what to
do when the normal route is unavailable.

An agent should read the **Agent** column and the [air-gapped](#air-gapped-and-restricted-networks)
section. `doctor` checks every gap below and refuses to continue on the ones
that matter.

## The table

| Component | Ships? | Why | How the gap closes | Agent |
| --- | --- | --- | --- | --- |
| **Repo** — Dockerfiles, compose, `doctor` / `deploy` / `instrument` / `scan`, docs | **Yes**, MIT | Our own work | `git clone` | Automatic |
| **Base image** — JDK 17, Gradle, trivy, gitleaks, gh, shell tooling | **Yes**, `ghcr.io/joshuafuller/atak-plugin-dev-base` | All freely redistributable | Pulled by `docker compose build` | Automatic |
| **Android SDK** — cmdline-tools, platforms 34/36, build-tools, platform-tools | **No** | Google's Android SDK Terms 3.4 forbid redistribution | Installed by the final build stage, on your machine, under your acceptance | Automatic, needs network |
| **ATAK CIV SDK** — `atak.apk`, keystore, `main.jar`, espresso, samples | **No** | TAK licence forbids redistributing the SDK | **A person downloads it** from tak.gov and sets `ATAK_SDK_DIR` | **Must ask.** Cannot be automated |
| **ATAK developer APK** on the device | **No** | Part of the SDK | `adb install -r $ATAK_SDK/atak.apk` | Automatic once the SDK is present |
| **Emulator / AVD** | **No** | Machine-specific, and large | You create one; name it for the work | Automatic if the host SDK is present |
| **ATAK-CIV source** — for answering "how does ATAK actually behave" | **No** | Not ours to redistribute, and it is already public | `git clone https://github.com/TAK-Product-Center/atak-civ` | Automatic, optional but recommended |
| **The skill** — measured facts about ATAK | Separate repo | Different lifecycle | `git clone …/atak-plugin-skill ~/.claude/skills/atak-plugin` | Automatic |

## The one gap a human must close

**The ATAK CIV SDK.** It is behind a click-through licence at
<https://tak.gov> and cannot be fetched non-interactively. Everything else is
scriptable.

If `$ATAK_SDK` is empty, an agent should **stop and ask for the SDK zip**, not
hunt for a copy: a build from anywhere but tak.gov is both a licence problem
and probably the wrong version. `doctor` fails with that instruction.

```bash
cp .env.example .env
# set ATAK_SDK_DIR to the folder containing atak.apk, android_keystore
# and atak-gradle-takdev.jar
docker compose up -d --build
docker compose exec atak-dev doctor
```

## Why the Android SDK is not in the published image

Google's Android SDK Terms, clause 3.4:

> Except to the extent required by applicable third party licenses, you may not
> copy (except for backup purposes), modify, adapt, **redistribute**,
> decompile, reverse engineer, disassemble, or create derivative works of the
> SDK or any part of the SDK.

An image containing it is redistribution. Many public Android CI images do it
anyway; that does not change the text. So the build splits: the base image
carries everything redistributable and is published, and the final stage runs
`sdkmanager` **on your machine**, accepting Google's terms as you — which is
what `yes | sdkmanager --licenses` in `Dockerfile` is doing.

The cost of the split is one local build step of a few minutes, once.

## Air-gapped and restricted networks

The published base and the Android SDK both need network on first build. If the
target machine has none, build on a connected machine and move the image:

```bash
# connected machine
docker build -f Dockerfile.base -t atak-plugin-dev-base:local .
BASE=atak-plugin-dev-base:local docker compose build
docker save atak-plugin-dev-atak-dev:latest | zstd -o atak-dev.tar.zst

# air-gapped machine
zstd -d -c atak-dev.tar.zst | docker load
```

That is your own copy moving between your own machines, which the terms permit;
publishing that tarball to others is the thing that is not.

Two more things need carrying across by hand: the ATAK SDK directory, and the
Gradle dependency cache. The Gradle *distribution* is pre-seeded in the base,
but a plugin's dependencies are not — build once while connected so the
`gradle-cache` volume is warm.

## Versions and what a release means

`version.txt` and `CHANGELOG.md` are maintained by release-please from
Conventional Commits. A release tags the repo and publishes the base image with
matching tags:

| Tag | Use |
| --- | --- |
| `:0.2.0` | Immutable. Use this when a build must still work next year |
| `:0.2`, `:0` | Moves with patches, and with minors |
| `:latest` | Moves with everything. Fine for a workstation, wrong for CI |

The base image version tracks **this repository**, not ATAK. Which ATAK the
container targets is pinned by the SDK you mount, and by the Android platform
and build-tools versions in `Dockerfile`.

## If you change the base

The base is only rebuilt on release, so a change to `Dockerfile.base` does not
reach anyone until a release goes out. While iterating:

```bash
docker build -f Dockerfile.base -t atak-plugin-dev-base:local .
BASE=atak-plugin-dev-base:local docker compose build
```

CI builds both on every pull request, so a broken base fails before merge.
