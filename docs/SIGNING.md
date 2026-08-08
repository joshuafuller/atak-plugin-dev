# The signing gate

The one thing that will cost you an afternoon if you skip it.

ATAK compares a plugin's signing certificate against its own. Your plugin is
signed with the SDK's `android_keystore` (`O=WinTec Arrowmaker`). The
**release** ATAK-CIV from tak.gov or the Play Store is signed with a different
key, so it refuses your plugin. What you see:

- the plugin manager lists it as **Incompatible**
- logcat says `AtakPluginRegistry: signature mismatch[your.package]`
  followed by `will NOT load`

The dialog mentions software versions, which sends people looking at API
levels. It is almost never that.

## The fix

Not re-signing anything. **Install the ATAK APK that ships inside the SDK** —
`atak.apk` at the SDK root. It is the same 5.8.0.1 build, signed with the same
key as your plugin, and it logs `SDK skipping signature check` instead. A red
`DEVELOPER BUILD` watermark on the map is how you know you are on the right
one.

```bash
adb uninstall com.atakmap.app.civ          # release and dev builds cannot coexist
adb install -r "$ATAK_SDK_DIR/atak.apk"
```

`doctor` verifies this by pulling the installed APK and comparing its
certificate against the SDK's, so you do not have to remember which build is on
the device.

## Two consequences worth being deliberate about

**Uninstalling wipes app data.** Files under `/sdcard/atak` survive — it is a
top-level directory — but ATAK's registrations and preferences do not. Your
imported maps will be on disk and not showing. If the previous install had
encrypted databases, first launch will demand a passphrase you do not have:
choose **Remove and Quit**, confirm, and relaunch.

**The dev build skips a security check.** Anything you verify about plugin
behaviour from here is verified on a permissive build. That is the right trade
for iterating, and it is not evidence about what a user on the release build
gets.

## Shipping to real users

Real users run the release ATAK, which will not load a plugin signed with the
SDK keystore. You need a signed APK from TAK's Third Party Pipeline — see
[SHIPPING.md](SHIPPING.md).
