# ATAK plugin dev container

A container with everything an ATAK 5.8 plugin build needs, so you are not
chasing JDK versions, Android SDK components and Gradle distributions on your
own machine. It builds the plugin, installs it to an emulator or device, and
gets it loaded into ATAK.

The ATAK SDK itself is **not** in the image. It is licensed material; you
download your own from [tak.gov](https://tak.gov) and mount it.

**Working with an AI agent?** Point it at [AGENTS.md](AGENTS.md). The container
is built so that everything after the SDK download — build, install, load,
drive the UI, run tests, read the result — can be done without a human in the
loop. Downloading the SDK is the one step that cannot: it is behind a
click-through licence.

**First command, always:** `docker compose exec atak-dev doctor`. It checks the
SDK layout, the toolchain, the adb bridge, the emulator image, and whether the
ATAK on the device will actually accept your plugin — and tells you what to do
about the first thing that is wrong.

---

## Read this first: the signing gate

This is the one thing that will cost you an afternoon if you skip it.

ATAK compares a plugin's signing certificate against its own. Your plugin is
signed with the SDK's `android_keystore` (`O=WinTec Arrowmaker`). The **release**
ATAK-CIV from tak.gov or the Play Store is signed with a different key, so it
refuses your plugin. What you see:

- the plugin manager lists it as **Incompatible**
- logcat says `AtakPluginRegistry: signature mismatch[your.package]`
  followed by `will NOT load`

The fix is not to re-sign anything. **Install the ATAK APK that ships inside the
SDK** — `atak.apk` at the SDK root. It is the same 5.8.0.1 build, signed with
the same key as your plugin, and it logs `SDK skipping signature check` instead.
You will see a red `DEVELOPER BUILD` watermark on the map; that is how you know
you are on the right one.

```bash
adb uninstall com.atakmap.app.civ          # release and dev builds cannot coexist
adb install -r "$ATAK_SDK_DIR/atak.apk"
```

Two consequences worth being deliberate about:

- **Uninstalling wipes app data.** Files under `/sdcard/atak` survive (it is a
  top-level directory), but ATAK's registrations and preferences do not — your
  imported maps will be on disk and not showing. If the previous install had
  encrypted databases, first launch will demand a passphrase you do not have;
  choose **Remove and Quit**, confirm, and relaunch.
- **The dev build skips a security check.** Anything you verify about plugin
  behaviour from here is verified on a permissive build. That is right for
  iterating and is not evidence about what real users on the release build get.

To ship to users on the release build you need a signed APK from TAK's
**Third Party Pipeline** — see [Shipping](#shipping-getting-a-signed-apk).

---

## Setup

You need Docker with Compose, and an emulator or device on the host.

```bash
git clone <this repo> && cd atak-plugin-dev
cp .env.example .env
$EDITOR .env                      # point ATAK_SDK_DIR at your unzipped SDK
docker compose up -d --build      # first build pulls ~2 GB of Android SDK
```

`.env` holds machine layout only — no secrets:

| Variable | What it is |
| --- | --- |
| `ATAK_SDK_DIR` | Folder that directly contains `atak.apk`, `android_keystore`, `atak-gradle-takdev.jar`. Mounted **writable** — the takdev gradle plugin writes `mapping.txt` into it. |
| `ANDROID_USER_HOME` | Your `~/.android`, so the emulator does not re-prompt to authorise adb. |
| `ADB_BRIDGE_TARGET` | Where the host's adb server is, for the port bridge. Defaults to `host.docker.internal:5037`. |

### adb

The container does not run its own adb server; it talks to the host's, so both
see the same device. adb only listens on a non-loopback interface when it is
started explicitly with `-a`, which means **you have to start it yourself** —
a client auto-spawning the server will not do it:

```bash
./bin/host-adb-server        # on the host, in its own terminal, leave running
```

Then, in the container:

```bash
docker compose exec atak-dev bash
adb devices                  # should list your emulator
```

The container forwards its own `127.0.0.1:5037` to that host server
(`workspace/bin/adb-bridge`, started automatically). `ADB_SERVER_SOCKET` is
deliberately **not** set, and setting it will cost you ten minutes per test
run: Gradle's device monitor ignores it, runs `adb start-server`, fails to bind
an address the container does not own, and then retries. The symptom is
`connectedAndroidTest` producing no output at all, and eventually
`[DeviceMonitor]: Cannot reach ADB server`.

If `adb devices` is empty: on native Linux Docker with `network_mode: host`,
`host.docker.internal` may not resolve even with the `extra_hosts` mapping. Set
`ADB_BRIDGE_TARGET=127.0.0.1:5037` in `.env` and recreate the container.

---

## The loop

Start from the SDK's template, which is the only shape the build system and the
signing pipeline both expect:

```bash
cp -r "$ATAK_SDK_DIR/samples/plugintemplate" workspace/MyPlugin
cd workspace/MyPlugin
cp template.local.properties local.properties
```

Edit `local.properties` — it is per-project, is not committed, and a fresh
clone fails confusingly without it:

```properties
sdk.dir=/opt/android-sdk
sdk.path=/opt/atak-sdk
takdev.plugin=/opt/atak-sdk/atak-gradle-takdev.jar
```

Then, from inside the container:

```bash
deploy MyPlugin
```

That assembles `CivDebug`, installs the APK, and stages a copy in
`/sdcard/atak/support/apks/sideloaded/` — which is the part that is not
obvious. **Installing the APK is not enough.** ATAK's plugin manager lists
products from its repositories, and a sideloaded plugin only becomes one of
them when a copy is in that folder and you sync:

> hamburger menu → **Tools** → **Plugins** → sync icon (top right) → **OK**
> → tap the plugin's row → **Load** → **OK**

Status goes `Not loaded` → `Loaded`, and the plugin appears in the Tools drawer.

The plugin manager after a sync — yours is listed alongside the products from
TAK's own repositories, and the sync control is the blue arrows, top right:

![Plugin manager listing a sideloaded plugin](docs/images/plugin-manager.png)

Tapping the row shows its state. `is loaded and current` is what you want; if
it says **Incompatible**, go back to
[the signing gate](#read-this-first-the-signing-gate):

![Plugin details showing loaded and current](docs/images/plugin-details.png)

Once loaded it appears in the Tools drawer and opens its own pane. Note the
red `DEVELOPER BUILD` watermark — that is how you know you are on the SDK's
ATAK and not the release one:

![The plugin's pane open in ATAK](docs/images/plugin-pane.png)

### Rename the template before you write any code

The template builds as `com.atakmap.android.plugintemplate.plugin` and displays
as "Plugin Template". Renaming later is worse than renaming now. Touch:

- `namespace` in `app/build.gradle`
- the java package directories, and the class implementing `IPlugin`
- `impl=` in `app/src/main/assets/plugin.xml`
- `app_name` and `app_desc` in `app/src/main/res/values/strings.xml`
- `rootProject.name` in `settings.gradle` — this drives the APK name **and**
  the proguard `-repackageclasses atakplugin.<name>` line the signing pipeline
  requires be specific to your plugin

Keep the `com.atakmap.app.component` activity in `AndroidManifest.xml`. It is
what makes the plugin discoverable; removing it makes it invisible with no
error. After renaming, uninstall the old package **and** delete its APK from
the sideload folder, or Sync Packages will show a phantom second product.

---

## Where plugins live

Each plugin is its own repository. `PLUGINS_DIR` in `.env` points at the
folder that holds them all, and that folder is mounted at `/work`.

```
PLUGINS_DIR=/home/you/development/tak
                    |
                    +-- atak-plugin-maproom      ->  /work/atak-plugin-maproom
                    +-- atak-plugin-weather      ->  /work/atak-plugin-weather
                    +-- my-plugin.worktrees/fix  ->  /work/my-plugin.worktrees/fix
```

Pointing at the parent rather than at one project is deliberate: several
people — or several agents — can then work on different plugins, or different
`git worktree`s of the same plugin, at once, each in its own directory, with
nothing shared but the Gradle cache, which locks correctly.

```bash
git clone <your-plugin-repo>
docker compose exec atak-dev deploy <plugin-dir>
```

The container's own helper scripts live in `workspace/bin`, are mounted
read-only at `/opt/tak-bin`, and are on `PATH`.

## Testing

`./gradlew testCivDebugUnitTest` runs local JVM tests — use these for anything
that does not touch the Android or ATAK API. They run in seconds.

For anything that does, the SDK ships an Espresso framework. Copy `espresso/`
from the SDK so it sits beside `app/`, then **rename
`ATAKPluginTests-debug.aar` to `atakplugintests-debug.aar`** — `testSetup.gradle`
resolves the lowercase name, and the flatDir lookup is case-sensitive on Linux.

Do **not** add `apply from: espresso/testSetup.gradle`. The takdev plugin
applies it as soon as the directory exists; a second apply fails the build with
`Cannot add task 'clearScreenshots' as a task with that name already exists`.

Derive test classes from `ATAKTestClass`, and in a `@BeforeClass` call
`helper.installPlugin("Your Plugin Name")` and
`ClassLoaderReplacer.fixClassLoaderForClass(...)` — plugins run inside ATAK's
process, so without the classloader fix you get `ClassDefNotFoundException` on
your own classes.

Run them with:

```bash
instrument MyPlugin
```

Not `./gradlew connectedCivDebugAndroidTest`. Gradle's Unified Test Platform
fails against the forwarded adb socket with `Failed to initialize
AndroidDebugBridge`. `instrument` does the parts that matter — assemble, the
`_modApk` step, install — and then drives the instrumentation over adb.

That `_modApk` step is easy to miss if you roll your own: `assembleAndroidTest`
does **not** run it, only `connectedAndroidTest` depends on it. It rewrites the
instrumentation manifest's `targetPackage` to `com.atakmap.app.civ` and
re-signs, which is what puts your tests inside ATAK's process. Without it every
test dies at startup with `NoClassDefFoundError` on ATAK's own classes.

Turn off animations or Espresso will be flaky:

```bash
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

**Debugging:** plugins have no activity of their own, so you attach to the
running ATAK process (`com.atakmap.app`) rather than launching. Breakpoints in
plugin source resolve once attached.

---

## Shipping: getting a signed APK

Real users run the release ATAK, which will not load an unsigned plugin. TAK's
Third Party Pipeline builds and signs third-party plugins; you upload a zip at
<https://tak.gov/user_builds/agreement>. Plugins it signs are marked in the UI
as third-party-signed rather than TPC-built.

All of its requirements are checkable locally before you submit:

| Requirement | Check |
| --- | --- |
| Zip with a **single root folder**; that name becomes the APK name | `zip -r MyPlugin.zip MyPlugin` from the parent directory |
| Gradle build, scripts included | inherited from the template |
| **`assembleCivRelease` must exist and succeed** | `./gradlew assembleCivRelease` — the discriminating check; run it early |
| SDK referenced only through `atak-gradle-takdev` | the 5.8 template uses `takdevVersion = '3.+'`. The published guidance says `2.+` for ATAK 4.2+, but also states a recent template clone already satisfies the requirement — leave the template's value alone |
| `-repackageclasses` names your plugin | the template derives it from `rootProject.name`; just set that |
| `com.atakmap.app.component` activity in the manifest | present in the template — do not remove it |

Access to `artifacts.tak.gov` for a pre-submission verification build is
restricted to USG personnel; without it, a clean local `assembleCivRelease` is
the best signal you can get.

---

## What is in the image

| | |
| --- | --- |
| JDK | Temurin 17 |
| Android | cmdline-tools, platforms 36 and 34, build-tools 36.0.0, platform-tools |
| Gradle | 8.14.3, pre-seeded so the first build does not download it |
| Also | git, curl, unzip, jq, python3, vim, nano, procps, net-tools |

Runs as `dev` (uid 1000) with passwordless sudo. It is a personal dev box, not
a hardened CI image — install what you need.

The NDK is **not** included. ATAK's own native libraries are built with NDK
12b, and plugins that link against them should match; add it via `sdkmanager`
or set `ndk.dir` if you need JNI.

---

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| Plugin manager says **Incompatible** | Release ATAK installed. Use the SDK's `atak.apk`. |
| `signature mismatch` in logcat | Same. |
| `will NOT load` but no signature error | Detected but not enabled — sync, tap the row, **Load**. |
| Plugin not listed at all after install | Not staged in `/sdcard/atak/support/apks/sideloaded/`, or you have not synced. |
| `adb devices` empty in the container | Host adb server not started with `-a` (`./bin/host-adb-server`), or `host.docker.internal` does not resolve. |
| `connectedAndroidTest` produces nothing for minutes | Gradle's device monitor cannot reach adb. Use `instrument`; never set `ADB_SERVER_SOCKET`. |
| `Failed to initialize AndroidDebugBridge` | Gradle's Unified Test Platform against the forwarded socket. Use `instrument`. |
| Instrumented tests die on `NoClassDefFoundError` for ATAK classes | The `_modApk` task did not run, so the tests target your plugin instead of ATAK. |
| Instrumented runs produce no output at all, `adb` exits 255 | A quiet adb connection was torn down. If you wrote your own port forwarder, clear the connect timeout after connecting — it otherwise applies to every read. |
| `adb install` fails with an empty message, or `Failure calling service package: Broken pipe` | The emulator's package service is wedged after many install cycles. `adb reboot`. |
| `Cannot add task 'clearScreenshots'` | `espresso/testSetup.gradle` applied twice — takdev already applies it. |
| Every XML document fails to parse on device but not in unit tests | Android's parser rejects `disallow-doctype-decl`. See the `atak-plugin` skill, `references/android-gotchas.md`. |
| `mapping.txt (Read-only file system)` | SDK mount is read-only; takdev writes into it. Drop any `:ro`. |
| Gradle fails offline | The gradle *distribution* is pre-seeded, dependencies are not. The first build needs network. |
| First launch demands an encryption passphrase | Left over from a previous install. **Remove and Quit**, confirm, relaunch. |
| Automated first-run walkthrough loops forever | ATAK's background-location prompt opens a settings sub-screen that re-presents itself. Grant with `adb shell pm grant <pkg> android.permission.…` and `adb shell appops set <pkg> MANAGE_EXTERNAL_STORAGE allow` instead of tapping through it. |

---

## Layout

```
.env.example          machine layout, copy to .env
AGENTS.md             how an agent runs all of this without a human
compose.yaml          the dev service
Dockerfile            the image
bin/host-adb-server   run on the HOST before using adb in the container
workspace/bin/        mounted read-only at /opt/tak-bin, on PATH
  doctor              check every assumption, in the order they break
  deploy              build + install + stage for sideload
  instrument          run instrumented tests inside ATAK
  adb-bridge          forwards 127.0.0.1:5037 to the host, started automatically
```
