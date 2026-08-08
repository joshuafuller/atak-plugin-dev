# Troubleshooting

Run `doctor` first. It checks the SDK layout, toolchain, adb bridge, emulator
image and installed ATAK certificate, and reports the first genuine problem
with what to do about it. Most of the table below is what `doctor` exists to
pre-empt.

## Read the log, not the UI

```bash
adb logcat | rg "AtakPluginRegistry|PluginValidator"
```

| Log line | Meaning | Fix |
| --- | --- | --- |
| nothing for your package | not discovered | missing `com.atakmap.app.component` activity or `plugin-api` meta-data |
| `signature mismatch[pkg]` then `will NOT load` | cert does not match ATAK's | install the SDK's `atak.apk` — see [SIGNING.md](SIGNING.md) |
| `api matches` but `!should load` | discovered and compatible, not enabled | sync, tap the row, **Load** |
| `SDK skipping signature check[pkg]` | on the developer build | expected; the good path |
| `Successfully loaded plugin descriptor` | `plugin.xml` parsed, `impl=` resolved | — |
| `Loaded <class>` + `addPluginIcon` | fully live | — |

## Symptom to cause

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
| UI automation "succeeds" but nothing changes | An `aosp_atd` emulator image: black framebuffer, full view tree. Use `google_apis`. |
| Every XML document fails to parse on device but not in unit tests | Android's parser rejects `disallow-doctype-decl`. |
| `mapping.txt (Read-only file system)` | SDK mount is read-only; takdev writes into it. Drop any `:ro`. |
| Gradle fails offline | The gradle *distribution* is pre-seeded, dependencies are not. The first build needs network. |
| First launch demands an encryption passphrase | Left over from a previous install. **Remove and Quit**, confirm, relaunch. |
| Automated first-run walkthrough loops forever | ATAK's background-location prompt opens a settings sub-screen that re-presents itself. Grant with `adb shell pm grant …` and `adb shell appops set <pkg> MANAGE_EXTERNAL_STORAGE allow` instead of tapping through it. |
| Toolbar moved to the other side of the screen | The Espresso harness sets `nav_orientation_right`, and it persists after tests. |
