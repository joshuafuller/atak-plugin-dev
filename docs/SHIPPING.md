# Shipping: getting a signed APK

Real users run the release ATAK, which will not load a plugin signed with the
SDK keystore (see [SIGNING.md](SIGNING.md)). TAK's **Third Party Pipeline**
builds and signs third-party plugins; you upload a zip at
<https://tak.gov/user_builds/agreement>. Plugins it signs are marked in the UI
as third-party-signed rather than TPC-built.

All of its requirements are checkable locally before you submit.

| Requirement | Check |
| --- | --- |
| Zip with a **single root folder**; that name becomes the APK name | `zip -r MyPlugin.zip MyPlugin` from the parent directory |
| Gradle build, scripts included | inherited from the template |
| **`assembleCivRelease` must exist and succeed** | `./gradlew assembleCivRelease` — the discriminating check; run it early |
| SDK referenced only through `atak-gradle-takdev` | the 5.8 template uses `takdevVersion = '3.+'`. Published guidance says `2.+` for ATAK 4.2+, but also states a recent template clone already satisfies the requirement — leave the template's value alone |
| `-repackageclasses` names your plugin | the template derives it from `rootProject.name`; just set that |
| `com.atakmap.app.component` activity in the manifest | present in the template — do not remove it |

Access to `artifacts.tak.gov` for a pre-submission verification build is
restricted to USG personnel. Without it, a clean local `assembleCivRelease` is
the best signal available.

## Verify the release variant on a device

The release variant is not the debug variant with a different name. Proguard
repackaging (`-repackageclasses`) changes class names, and anything reflective
— including Kotlin metadata — can behave differently. A plugin that works in
debug and fails after release is the worst shape a defect takes, because it
appears only once you have shipped.

Build the release variant, load it, and run the instrumented suite against it
before submitting.
