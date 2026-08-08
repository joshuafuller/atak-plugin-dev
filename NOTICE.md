# What is and is not in this repository

This repository is MIT licensed. It contains **no ATAK SDK material**, and that
is deliberate rather than incidental.

## The boundary

The TAK Software License Agreement grants a perpetual, royalty-free right to
use the SDK and to *derive new works or applications* from it, and it withholds
the right to **copy, publish, distribute or sublicense the SDK itself**.

So:

| Thing | Where it lives | Why |
| --- | --- | --- |
| `atak.apk`, `android_keystore`, `atak-gradle-takdev.jar`, `main.jar`, the espresso archives, the plugin template | your own SDK download, mounted at `/opt/atak-sdk` | SDK material — redistributing it is not permitted |
| This container, its scripts, its documentation | here, MIT | our own work |
| A plugin's own source | that plugin's own repository | a derived application, which the licence permits |

Get the SDK yourself from <https://tak.gov>. It is free of charge and requires
accepting the licence.

## If you are adding to this repository

Do not commit anything that came out of the SDK, including files a build step
copied into a working tree. If a build needs an SDK file present, copy it from
`$ATAK_SDK` at build time and add it to `.gitignore`. This applies to a private
repository as much as a public one: history is what gets published later, and
scrubbing it afterwards means rewriting every commit.

## Third-party components

The image installs the Android SDK command-line tools, Android platform and
build-tools, a Gradle distribution, and standard Debian packages, each under
its own licence, at build time. None are redistributed by this repository.
