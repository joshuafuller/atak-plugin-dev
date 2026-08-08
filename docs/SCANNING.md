# Scanning a project

```bash
scan <plugin-dir>          # seconds
scan <plugin-dir> --deep   # adds Android Lint; minutes
```

Run it unprompted. It needs no configuration, needs no network for the checks
that matter most, and says nothing on a clean project.

## What it checks, and why these

Aiming for the 80% that is cheap and catches real problems, rather than a
security programme nobody runs twice.

| Check | Catches | Tool |
| --- | --- | --- |
| **SDK material** — working tree, git history, and byte-for-byte against `$ATAK_SDK` | Licence breach. History is what gets published, so a file deleted later is still there | ours |
| **Manifest** | A missing `com.atakmap.app.component` (invisible plugin, no error), forced debuggable, blanket cleartext | ours |
| **Secrets** | Credentials in the tree and in **history** | trivy + gitleaks |
| **Dependency CVEs** | Known-vulnerable libraries, HIGH and CRITICAL | trivy |
| **Licence conflicts** | Dependencies whose terms fight your distribution | trivy |
| **Android Lint** (`--deep`) | The platform's own correctness and security rules | the project's gradle |

Two tools, both single binaries, roughly 200 MB together. `build/` and
`.gradle/` are skipped: they are generated and full of third-party jars the
project never ships, so scanning them reports other people's problems as yours.

## What it deliberately does not do

Deeper analysis is real work and belongs to whoever needs it, not in every
image. Install these in the container when a project warrants it — it has
`pip`, `apt` and passwordless sudo:

| Want | Install | Cost |
| --- | --- | --- |
| Dataflow and taint analysis of Java/Kotlin | `pip install semgrep`, then `semgrep --config p/java --config p/mobsfscan` | ~200 MB, minutes per run |
| Mobile-specific rules (crypto misuse, insecure storage, exported components) | `pip install mobsfscan` | ~100 MB |
| Full APK analysis of a built artifact | MobSF, in its own container | large |
| SBOM for a submission | `trivy fs --format cyclonedx --output sbom.json .` | already installed |
| Dependency freshness | `./gradlew dependencyUpdates` with the versions plugin | build change |

The container stays small so that starting is free. Going deeper is a decision
with a cost, and should be taken deliberately.

## Reading the result

Three verdicts, and the exit code follows them:

- **ok** — checked and clean.
- **warn** — worth a human's attention, not blocking. Cleartext traffic is a
  warning because a loopback tile server legitimately needs it.
- **FAIL** — exit code 1. Fix it or decide, explicitly, that it is acceptable.

A check that cannot run reports **warn**, never FAIL. Reporting a missing tool
or a bad flag as a security finding trains people to ignore the output, which
costs more than the check was worth.

## Wiring it into the loop

The point is that findings reach you without being asked for. See
[the agent SDLC reference](https://github.com/joshuafuller/atak-plugin-skill/blob/main/references/agent-sdlc.md)
in the skill for the full pattern; the short version:

```bash
# .git/hooks/pre-commit — refuse to commit SDK material or a secret
#!/usr/bin/env bash
exec docker compose -f /path/to/atak-plugin-dev/compose.yaml \
    exec -T atak-dev scan "$(basename "$PWD")"
```

Cheap checks belong in `pre-commit`, slow ones in `pre-push` or CI. A hook that
takes a minute gets bypassed with `--no-verify` within a day, and then it is
protecting nothing.
