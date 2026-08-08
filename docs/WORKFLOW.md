# The build-load loop

## Scaffold

Start from the SDK's template, which is the only shape the build system and the
signing pipeline both expect.

**On the host**, where `$ATAK_SDK_DIR` and `$PLUGINS_DIR` come from your
`.env`. Neither variable exists inside the container, where the same paths are
`/opt/atak-sdk` and `/work`:

```bash
# HOST
cp -r "$ATAK_SDK_DIR/samples/plugintemplate" "$PLUGINS_DIR/MyPlugin"
cd "$PLUGINS_DIR/MyPlugin"
cp template.local.properties local.properties
```

Edit `local.properties` — it is per-project, is not committed, and a fresh
clone fails confusingly without it. The paths are **container** paths even
though you are editing on the host, because the build runs in the container:

```properties
sdk.dir=/opt/android-sdk
sdk.path=/opt/atak-sdk
takdev.plugin=/opt/atak-sdk/atak-gradle-takdev.jar
```

### Rename the template before you write any code

The template builds as `com.atakmap.android.plugintemplate.plugin` and displays
as "Plugin Template". Renaming later is strictly worse. Touch, together:

- `namespace` in `app/build.gradle`
- the java package directories, and the class implementing `IPlugin`
- `impl=` in `app/src/main/assets/plugin.xml`
- `app_name` and `app_desc` in `app/src/main/res/values/strings.xml`
- `rootProject.name` in `settings.gradle` — this drives the APK name **and**
  the proguard `-repackageclasses atakplugin.<name>` line the signing pipeline
  requires be specific to your plugin

Keep the `com.atakmap.app.component` activity in `AndroidManifest.xml`. It is
what makes the plugin discoverable; removing it makes it invisible with no
error.

After renaming, uninstall the old package **and** delete its APK from the
sideload folder, or Sync Packages shows a phantom second product and ATAK
reports a signature failure for a package that no longer exists.

### Do not commit SDK files

Scaffolding from the template copies SDK material into your tree. The TAK
licence permits deriving applications from the SDK and forbids redistributing
it, and history is what gets published later — so a private repo does not
protect you. Check before your first commit:

```bash
for f in $(git ls-files); do
  m=$(find "$ATAK_SDK" -name "$(basename "$f")" -type f | head -1)
  [ -n "$m" ] && cmp -s "$f" "$m" && echo "SDK material: $f"
done
```

Gitignore what matches and copy it from `$ATAK_SDK` at build time.

## Build and load

```bash
# CONTAINER
deploy MyPlugin
```

That assembles `CivDebug`, installs the APK, and stages a copy in
`/sdcard/atak/support/apks/sideloaded/` — which is the part that is not
obvious. **Installing the APK is not enough.** ATAK's plugin manager lists
products from its repositories, and a sideloaded plugin only becomes one of
them when a copy is in that folder and you sync:

> hamburger menu → **Tools** → **Plugins** → sync icon (top right) → **OK**
> → tap the plugin's row → **Load** → **OK**

Status goes `Not loaded` → `Loaded`, and the plugin appears in the Tools
drawer.

The plugin manager after a sync — yours is listed alongside the products from
TAK's own repositories, and the sync control is the blue arrows, top right:

![Plugin manager listing a sideloaded plugin](images/plugin-manager.png)

Tapping the row shows its state. `is loaded and current` is what you want; if
it says **Incompatible**, see [SIGNING.md](SIGNING.md):

![Plugin details showing loaded and current](images/plugin-details.png)

Once loaded it appears in the Tools drawer and opens its own pane. Note the red
`DEVELOPER BUILD` watermark — that is how you know you are on the SDK's ATAK
and not the release one:

![The plugin's pane open in ATAK](images/plugin-pane.png)

## Testing

`./gradlew testCivDebugUnitTest` runs local JVM tests — use these for anything
that does not touch the Android or ATAK API. They run in seconds.

For anything that does, the SDK ships an Espresso framework. Copy `espresso/`
from the SDK so it sits beside `app/`, then **rename
`ATAKPluginTests-debug.aar` to `atakplugintests-debug.aar`** —
`testSetup.gradle` resolves the lowercase name, and the flatDir lookup is
case-sensitive on Linux.

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

`am instrument` **always exits 0**, including when tests fail. `instrument`
parses the output to decide pass or fail; if you invoke it yourself, do the
same.

Turn off animations or Espresso will be flaky:

```bash
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

## Debugging

Plugins have no activity of their own, so you attach to the running ATAK
process (`com.atakmap.app`) rather than launching it. Breakpoints in plugin
source resolve once attached.
