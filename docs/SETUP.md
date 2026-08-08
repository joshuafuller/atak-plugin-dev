# Setup

You need Docker with Compose, an emulator or device on the host, and the ATAK
CIV SDK unzipped somewhere.

```bash
cp .env.example .env
$EDITOR .env
docker compose up -d --build      # first build pulls ~2 GB of Android SDK
docker compose exec atak-dev doctor
```

## Configuration

`.env` holds machine layout only — no secrets.

| Variable | What it is |
| --- | --- |
| `ATAK_SDK_DIR` | Folder that directly contains `atak.apk`, `android_keystore` and `atak-gradle-takdev.jar`. Mounted **writable** — the takdev gradle plugin writes `mapping.txt` into it. |
| `PLUGINS_DIR` | The folder holding your plugin repositories, mounted at `/work`. Point it at the parent, not at one project. |
| `ANDROID_USER_HOME` | Your `~/.android`, so the emulator does not re-prompt to authorise adb. |
| `ADB_BRIDGE_TARGET` | Where the host's adb server is. Defaults to `host.docker.internal:5037`. |
| `GH_TOKEN` | Optional, passed through so `gh` works inside the container. |

## Where plugins live

`PLUGINS_DIR` points at the folder that holds them all:

```
PLUGINS_DIR=/home/you/development/tak
                    |
                    +-- atak-plugin-alpha        ->  /work/atak-plugin-alpha
                    +-- atak-plugin-beta         ->  /work/atak-plugin-beta
                    +-- alpha.worktrees/a-branch ->  /work/alpha.worktrees/a-branch
```

Pointing at the parent rather than at one project is deliberate: several
people — or several agents — can then work on different plugins, or different
`git worktree`s of the same plugin, at once, each in its own directory, with
nothing shared but the Gradle cache, which locks correctly.

The container's helper scripts live in `workspace/bin`, are mounted read-only
at `/opt/tak-bin`, and are on `PATH`.

## adb

The container does not run its own adb server; it talks to the host's, so both
see the same device. adb only listens on a non-loopback interface when started
explicitly with `-a`, which means **you have to start it yourself** — a client
auto-spawning the server will not do it:

```bash
./bin/host-adb-server        # on the host, in its own terminal, leave running
```

Then, in the container:

```bash
docker compose exec atak-dev bash
adb devices                  # should list your emulator
```

The container forwards its own `127.0.0.1:5037` to that host server
(`workspace/bin/adb-bridge`, started automatically).

**`ADB_SERVER_SOCKET` is deliberately not set, and setting it will cost you ten
minutes per test run.** Gradle's device monitor ignores it, runs `adb
start-server`, fails to bind an address the container does not own, and then
retries. The symptom is `connectedAndroidTest` producing no output at all, and
eventually `[DeviceMonitor]: Cannot reach ADB server`.

If `adb devices` is empty: on native Linux Docker with `network_mode: host`,
`host.docker.internal` may not resolve even with the `extra_hosts` mapping. Set
`ADB_BRIDGE_TARGET=127.0.0.1:5037` in `.env` and recreate the container.

## Choose the right emulator image

Use a **`google_apis`** image. Do not use `aosp_atd`: it renders a black
framebuffer while `uiautomator` still reports a complete view tree, so UI
automation appears to work and changes nothing. `doctor` warns when it sees
one.

```bash
emulator -avd <name> -gpu swiftshader_indirect
```

## What is in the image

| | |
| --- | --- |
| JDK | Temurin 17 |
| Android | cmdline-tools, platforms 36 and 34, build-tools 36.0.0, platform-tools |
| Gradle | 8.14.3, pre-seeded so the first build does not download it |
| Tooling | git, gh, curl, unzip, jq, python3, ripgrep, fd, sqlite3, vim, nano |

Runs as `dev` (uid 1000) with passwordless sudo. It is a personal dev box, not
a hardened CI image — install what you need.

The NDK is **not** included. ATAK's own native libraries are built with NDK
12b, and plugins linking against them should match; add it via `sdkmanager` or
set `ndk.dir` if you need JNI.
