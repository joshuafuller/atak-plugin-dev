# Security

## Reporting

Report a vulnerability privately through GitHub's
[security advisories](https://github.com/joshuafuller/atak-plugin-dev/security/advisories/new)
rather than a public issue. Expect an acknowledgement within a few days.

## What this is

A development container. It is a personal dev box by design, not a hardened CI
image: it runs as a user with passwordless sudo, and it exists so that a
developer can install what they need while debugging at one in the morning.
Do not use it as a base for anything exposed.

Two properties are deliberate and worth knowing:

**It talks to the host's adb server.** `adb-bridge` forwards the container's
`127.0.0.1:5037` to a server you start on the host with `-a`, which makes that
server reachable on a non-loopback interface. Anyone who can reach that port
can control the attached device. Run it on a trusted network, and stop it when
you are done.

**The SDK is mounted writable.** The takdev gradle plugin writes `mapping.txt`
into the SDK directory, so a read-only mount breaks the build. The container
can therefore modify files in your SDK folder.

## The developer ATAK build skips a signature check

`atak.apk` from the SDK is a developer build. It loads plugins without
verifying their signing certificate against its own — which is what makes local
development possible, and means it is not representative of what a user on a
release build gets. Do not treat behaviour verified against it as evidence
about the release build, and do not put it on a device used operationally.

## No secrets, no SDK material

There are no repository secrets. Workflows run with read-only permissions and
do not run on `pull_request_target`.

No ATAK SDK material is included or redistributed — see
[NOTICE.md](NOTICE.md). Please do not open a pull request that adds any.
