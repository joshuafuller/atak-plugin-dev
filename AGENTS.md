# Working in this container as an agent

You are expected to run this end to end without a human. This file tells you
how, and — more usefully — tells you which failures look like something they
are not.

Human-facing setup and background live in `README.md`. Read this one first.

**Install the companion skill before you start.** This repo gives you the
tools; the skill gives you the knowledge — the ATAK failures that present as
something else, what the licences allow, and the fact that ATAK's source is
published and usually answers a question faster than an experiment:

```bash
git clone https://github.com/joshuafuller/atak-plugin-skill \
    ~/.claude/skills/atak-plugin
```

## What you cannot do, and must ask for

One thing genuinely requires a person: **downloading the ATAK SDK.** It sits
behind a click-through licence at <https://tak.gov> and cannot be fetched
non-interactively. Everything after that point is yours.

If `$ATAK_SDK` is not populated, stop and ask for the SDK zip. Do not try to
find a copy elsewhere — it is licensed material, and a copy from anywhere but
tak.gov is both a licence problem and, quite likely, the wrong version.

## Bring the box up

```bash
cp .env.example .env
# edit ATAK_SDK_DIR and PLUGINS_DIR
docker compose up -d --build
docker compose exec atak-dev doctor        # verifies every assumption below
```

`doctor` is the first thing to run and the first thing to run again when
anything is strange. It checks the SDK layout, the Android SDK, the adb bridge,
the emulator, and whether the ATAK on the device is one that will accept your
plugin. It exits non-zero on the first genuine problem and prints what to do.

## The signing gate — read this before debugging anything else

**ATAK compares a plugin's signing certificate against its own.** A plugin
built here is signed with the SDK's `android_keystore`, and the release ATAK
from tak.gov or the Play Store will refuse to load it. The plugin manager says
*"Incompatible"*, which sounds like a version problem and is not.

Install `$ATAK_SDK/atak.apk` — the same version, signed with the matching key,
with a red `DEVELOPER BUILD` watermark. `doctor` checks this and will tell you
if the wrong ATAK is installed.

## The emulator is the point

Prefer the emulator over a physical device for everything. It is
scriptable, resettable, and lets you take the human out of the loop entirely:
you can install, grant permissions, drive the UI, screenshot, and read the
result without anyone touching a phone.

Use a **`google_apis`** image. Do not use `aosp_atd`: it renders a black
framebuffer while `uiautomator` still reports a complete view tree, so a UI
script will "tap" things successfully and change nothing, and you will believe
your test passed.

```bash
# On the HOST, not in the container — the emulator runs on the host.
adb -a -P 5037 server nodaemon &        # must listen on all interfaces
emulator -avd <name> -gpu swiftshader_indirect
```

The container reaches that server through `adb-bridge`, a forwarder on the
container's own `127.0.0.1:5037`. **Never set `ADB_SERVER_SOCKET`.** Gradle's
device monitor ignores it, runs `adb start-server`, fails to bind, and retries
for as long as you let it — which presents as a build that hangs for ten
minutes with no output rather than as an error.

### Taking the human out of the loop

ATAK's first run has a permission walkthrough that cannot be reliably tapped
through — it loops. Grant them directly instead:

```bash
adb shell pm grant com.atakmap.app.civ android.permission.ACCESS_FINE_LOCATION
adb shell appops set com.atakmap.app.civ MANAGE_EXTERNAL_STORAGE allow
```

For UI work, dump the view tree and act on nodes rather than coordinates —
ATAK's toolbar changes sides with layout, and a fixed tap lands on whatever
tool happens to be there.

## The loop

```bash
scan <plugin-dir>                    # seconds; run it unprompted
deploy <plugin-dir>                  # build, install, stage for sideload
instrument <plugin-dir> [Class#method]   # instrumented tests, bypassing UTP
```

All on `PATH`. `<plugin-dir>` is a directory under `/work`.

`scan` checks secrets in the tree *and* in history, dependency CVEs, licence
conflicts, SDK material, and manifest hygiene. It needs no configuration and
says nothing on a clean project, so there is no reason not to run it before a
commit. It exits non-zero only on a real failure; a check that cannot run
reports a warning, never a failure. `docs/SCANNING.md` covers what to install
when a project needs deeper analysis than the image carries.

**Installing a plugin is not enough to make it visible.** It becomes visible to
the plugin manager only when a copy is in
`/sdcard/atak/support/apks/sideloaded/` **and** you run Sync Packages. Loading
is then a third, separate action: the row will say `Not loaded`; tap it and
choose **Load**. `deploy` handles the staging; the sync and load happen on the
device.

## When something does not work, read the log, not the UI

```bash
adb logcat | rg "AtakPluginRegistry|PluginValidator"
```

| Log line | Meaning | Fix |
| --- | --- | --- |
| nothing for your package | not discovered | the manifest is missing the `com.atakmap.app.component` activity, or the `plugin-api` meta-data |
| `signature mismatch[pkg]` then `will NOT load` | cert does not match ATAK's | install `$ATAK_SDK/atak.apk` |
| `api matches` but `!should load` | discovered, compatible, not enabled | sync, tap the row, **Load** |
| `SDK skipping signature check[pkg]` | you are on the developer build | expected — this is the good path |
| `Loaded <class>` + `addPluginIcon` | fully live | — |

## Tests

`instrument` exists because Gradle's Unified Test Platform cannot initialise
`AndroidDebugBridge` through the forwarded socket. It also runs
`package<Variant>AndroidTest_modApk`, which `assembleAndroidTest` does not — skip
it and every ATAK class in your tests fails with `NoClassDefFoundError`.

`am instrument` **always exits 0**, including when tests fail. `instrument`
parses the output to decide. If you invoke `am instrument` yourself, do the
same, or you will report green on a red run.

Anything that only runs on device must be tested on device. Android's platform
classes differ from the JVM's in ways that fail silently rather than loudly.

## Several agents at once

`/work` is a directory of sibling repositories, not one project. Give each
agent its own directory — a separate repo, or a separate `git worktree` — and
they will not collide. The Gradle cache is shared and locks correctly.

Only one thing is genuinely exclusive: **the device.** Installing, running
instrumented tests, and driving the UI all contend for it. Serialise device
work between agents; parallelise everything else.

## Licence boundary

The SDK is mounted, never copied. Do not commit anything from `$ATAK_SDK` into
a plugin repository — not the AARs, not the keystore, not `atak.apk`, not the
espresso archives. The TAK licence permits deriving applications from the SDK
and forbids redistributing the SDK itself, and a public repo containing SDK
files breaches it. If a build wants an SDK file in the tree, copy it at build
time from `$ATAK_SDK` and gitignore it.
