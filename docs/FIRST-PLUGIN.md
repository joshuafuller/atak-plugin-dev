# Your first ATAK plugin, start to finish

From nothing to a plugin you wrote, running inside ATAK on an emulator. Around
an hour, most of it downloads.

Every command is labelled **HOST** or **CONTAINER**. Getting that wrong is the
most common way this goes sideways, because the two see different paths and
different variables.

## What you are building, and why it is odd

ATAK is a mapping application used by search and rescue, fire, law enforcement
and military teams. A **plugin** is a separate Android APK that ATAK loads into
its own process at runtime — it is not an app you launch, and it has no
activity of its own.

Three consequences that explain most of the strangeness below:

- Your plugin runs **inside ATAK's process**, so tests must run there too.
- ATAK **checks who signed your plugin** and refuses anything signed with a
  different key than its own. This is the single biggest source of lost
  afternoons.
- The SDK is licensed and cannot be redistributed, so **you download it
  yourself** and it is mounted rather than shipped.

## 0. What you need on the HOST

| | Why | Check |
| --- | --- | --- |
| Docker with Compose | Runs the build environment | `docker compose version` |
| Android **platform-tools** (`adb`) | The container talks to your emulator through the host's adb | `adb version` |
| Android **emulator** + **cmdline-tools** | To create and run a virtual device | `emulator -version` |
| The **ATAK CIV SDK** | Licensed; you must fetch it | see step 1 |
| ~20 GB disk, ~8 GB RAM | Emulator plus images | |

If the Android tools are missing, install **Android Studio** (simplest) or the
command-line tools alone. They usually land in `~/Android/Sdk`, and the
binaries are not on `PATH` by default:

```bash
# HOST — add to your shell profile
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
```

## 1. Get the ATAK SDK — the one manual step

Sign in at <https://tak.gov>, accept the licence, and download the **ATAK CIV
SDK**. Unzip it. You want the folder that *directly* contains `atak.apk`,
`android_keystore` and `atak-gradle-takdev.jar` — often one level below where
the zip unpacked.

Nothing else in this guide needs a human. An agent that finds `$ATAK_SDK`
empty should stop and ask for this zip rather than looking for a copy
elsewhere: a build from anywhere but tak.gov is both a licence problem and
probably the wrong version.

## 2. Create and start an emulator

Use a **`google_apis`** image. Do not use `aosp_atd`: it renders a black screen
while still reporting a full view tree, so UI automation appears to work and
changes nothing.

```bash
# HOST
sdkmanager "system-images;android-34;google_apis;x86_64"

# Name it after the work, not the hardware. If two people or two agents share
# this machine, the name is how you tell whose device is whose.
avdmanager create avd --name atak_dev \
    --package 'system-images;android-34;google_apis;x86_64' --device medium_phone

emulator -avd atak_dev -port 5554 -gpu swiftshader_indirect &
```

Then start the adb server so the container can reach it. It must be started
explicitly with `-a`; a server auto-spawned by a client will not listen where
the container can see it:

```bash
# HOST — leave this running in its own terminal
./bin/host-adb-server
```

## 3. Bring up the container

```bash
# HOST
git clone https://github.com/joshuafuller/atak-plugin-dev
cd atak-plugin-dev
cp .env.example .env
```

Edit `.env`:

```bash
ATAK_SDK_DIR=/absolute/path/to/ATAK-CIV-5.8.0.1-SDK   # from step 1
PLUGINS_DIR=/absolute/path/to/where/your/plugins/live # a folder, not one project
```

```bash
# HOST
docker compose up -d --build          # first run pulls the base and the Android SDK
docker compose exec atak-dev doctor
```

`doctor` is the gate. It checks the SDK layout, the toolchain, the adb bridge,
the emulator image and — the check that saves the most time — whether the ATAK
on your device will actually accept plugins you build. **Do not continue past a
failure**; each one prints what to do.

## 4. Install the developer ATAK

This is the signing gate, and skipping it costs an afternoon.

Your plugin is signed with the SDK's keystore. The **release** ATAK from
tak.gov or the Play Store is signed with a different key and will refuse it,
reporting *"Incompatible"* — which sounds like a version problem and is not.

```bash
# HOST
adb install -r "$ATAK_SDK_DIR/atak.apk"
```

Launch ATAK, accept its prompts, and confirm a red **DEVELOPER BUILD**
watermark on the map. That watermark is how you know you are on the right one.
Re-run `doctor`; it compares the installed certificate against the SDK's.

## 5. Scaffold your plugin

```bash
# HOST — $PLUGINS_DIR is the folder from your .env
cp -r "$ATAK_SDK_DIR/samples/plugintemplate" "$PLUGINS_DIR/MyPlugin"
cd "$PLUGINS_DIR/MyPlugin"
cp template.local.properties local.properties
```

Edit `local.properties`. These are **container** paths, even though you are
editing on the host, because the build runs inside the container:

```properties
sdk.dir=/opt/android-sdk
sdk.path=/opt/atak-sdk
takdev.plugin=/opt/atak-sdk/atak-gradle-takdev.jar
```

**Rename the template before writing any code.** Renaming later is strictly
worse — see [WORKFLOW.md](WORKFLOW.md) for the five places that must change
together, and the one activity you must not remove.

## 6. Build, install, load

```bash
# CONTAINER
docker compose exec atak-dev deploy MyPlugin
```

That builds, installs, and stages a copy in
`/sdcard/atak/support/apks/sideloaded/`. Installing alone is not enough — ATAK
only lists plugins from that folder, and only after a sync.

On the device: **hamburger menu → Tools → Plugins → sync (top right) → OK →
tap your plugin's row → Load → OK**.

The row goes `Not loaded` → `Loaded`, and your plugin appears in the Tools
drawer.

## 7. Confirm it, and check yourself

```bash
# CONTAINER
docker compose exec atak-dev bash -lc 'adb logcat -d | rg "AtakPluginRegistry" | tail -5'
```

You want `SDK skipping signature check` and `Loaded <your class>`. If you see
`signature mismatch`, go back to step 4.

```bash
# CONTAINER — before your first commit
docker compose exec atak-dev scan MyPlugin
```

Scaffolding from the template copies SDK files into your tree, and committing
them breaches the licence. `scan` catches that, along with secrets and
dependency CVEs. Run it before the first commit, not before the first push:
history is what gets published, so removing a file later means rewriting
history.

## When it goes wrong

Read the log, not the UI. Almost every failure has a specific line:

```bash
adb logcat | rg "AtakPluginRegistry|PluginValidator"
```

| You see | It means |
| --- | --- |
| "Incompatible" in the plugin manager | Release ATAK installed. Step 4 |
| `signature mismatch` | Same |
| Plugin not listed at all | Not staged, or not synced. Step 6 |
| `adb devices` empty in the container | Host adb server not started with `-a`. Step 2 |
| Tests hang for ten minutes | Never set `ADB_SERVER_SOCKET`; use `instrument` |
| UI automation "works" but nothing changes | `aosp_atd` image. Step 2 |

[TROUBLESHOOTING.md](TROUBLESHOOTING.md) has the full table.

## Next

- [WORKFLOW.md](WORKFLOW.md) — renaming, the build-load loop, testing inside ATAK
- [SIGNING.md](SIGNING.md) — why the signing gate exists and what the dev build changes
- [SHIPPING.md](SHIPPING.md) — getting a signed APK for real users
- [The skill](https://github.com/joshuafuller/atak-plugin-skill) — measured facts
  about ATAK's behaviour, for you or your agent
