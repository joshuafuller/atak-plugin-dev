# Licensing and attribution

This repository is MIT licensed (see [LICENSE](LICENSE)). It contains our own
work only: the Dockerfile, the compose file, the helper scripts and the
documentation.

## Not affiliated with the TAK Product Center

ATAK, TAK, and the Android Team Awareness Kit are products of the TAK Product
Center and the U.S. Government, and those names are their marks. This project
is an independent, unofficial development tool. It is **not affiliated with,
endorsed, sponsored or approved by** the TAK Product Center, the U.S. Army
Combat Capabilities Development Command, or any part of the U.S. Government.
Those names are used only to describe what this tool works with.

## No ATAK SDK material is included

The TAK Software License Agreement grants a perpetual, royalty-free right to
use the SDK and to *derive new works or applications* from it, and withholds
the right to **copy, publish, distribute or sublicense the SDK itself**.

So the SDK is mounted at runtime, never copied into the image or this
repository:

| Thing | Where it lives | Why |
| --- | --- | --- |
| `atak.apk`, `android_keystore`, `atak-gradle-takdev.jar`, `main.jar`, the espresso archives, the plugin template | your own SDK download, mounted at `/opt/atak-sdk` | SDK material — redistributing it is not permitted |
| This container, its scripts and documentation | here, MIT | our own work |
| A plugin's own source | that plugin's own repository | a derived application, which the licence permits |

Get the SDK yourself from <https://tak.gov>. It is free of charge and requires
accepting the licence.

CI helps, but does not prove this. The workflow rejects committed binaries and
archives (`.aar`, `.apk`, `.jar`, `.zip`, `.aab`, `.keystore`, `.so`) and a
list of known SDK filenames. It cannot recognise an SDK text file that has been
renamed, so it is a backstop against the common mistake, not a guarantee. The
reliable check is comparing your tree against the SDK, which
[docs/WORKFLOW.md](docs/WORKFLOW.md) shows how to do.

## Third-party components the image installs

None of these are redistributed by this repository — the image is built on your
machine, and we publish no image. They are listed so you know what you are
running, and because **if you publish a built image, their obligations become
yours.**

| Component | Licence |
| --- | --- |
| Eclipse Temurin JDK 17 (base image) | GPL-2.0 with Classpath Exception |
| Android SDK command-line tools, platforms 34 and 36, build-tools, platform-tools | Android Software Development Kit License Agreement |
| Gradle 8.14.3 | Apache-2.0 |
| GitHub CLI (`gh`) | MIT |
| ripgrep | MIT / Unlicense |
| fd | MIT / Apache-2.0 |
| SQLite (`sqlite3`) | public domain |
| Ubuntu base packages (git, curl, jq, python3, vim, and the rest) | various, per Debian/Ubuntu packaging |
| shellcheck (CI only) | GPL-3.0 |

### The image accepts the Android SDK licence on your behalf

The Dockerfile runs `yes | sdkmanager --licenses`. That is an automated
acceptance of Google's Android SDK terms, made when you build the image. If you
are not in a position to accept those terms, do not build it.

## Documentation

The behaviour documented here was measured against ATAK-CIV 5.8.0.1. Where it
restates a requirement published by the TAK Product Center — the Third Party
Pipeline rules in [docs/SHIPPING.md](docs/SHIPPING.md), for instance — that is
a description of their process, not a reproduction of their material, and
tak.gov is authoritative.

## Contributions

By opening a pull request you agree that your contribution is licensed under
the same MIT licence as this project, and that you have the right to submit it.
