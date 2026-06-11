# IceCat Mobile (Mull rebrand scaffold)

Build scripts and CI to produce a de-Googled, de-branded "IceCat for Android"
APK by rebranding [Mull](https://divestos.org/) — DivestOS's privacy-hardened
fork of Firefox for Android (Fenix/GeckoView) — without vendoring its
multi-gigabyte source tree into this repo.

This folder is self-contained: all paths below are relative to
`icecat-mobile/`.

## How this works

1. `scripts/fetch-source.sh` clones Mull-Fenix's source into `src/` (gitignored).
2. `scripts/apply-branding.sh` rewrites `applicationId` and `app_name` to the
   values in `config/branding.env`, and copies in custom launcher icons from
   `branding/icons/` if present.
3. `scripts/build.sh` runs the two steps above, then `./gradlew $GRADLE_TASK`,
   and copies the resulting APK(s) to `dist/`.
4. `.github/workflows/icecat-mobile.yml` (repo root) runs the same pipeline on
   every push to `master` that touches this folder (and on demand) and
   uploads the APK as a build artifact.

## Why a Fenix-based fork instead of classic IceCat patches

GNU IceCat's existing de-branding patches target the old Firefox/XUL desktop
codebase, which Firefox for Android no longer uses. Modern Firefox for
Android is **Fenix**: a Kotlin app that depends on a *prebuilt* GeckoView
engine published to Mozilla's Maven repo. That means building it is "just" a
Gradle/Android build — not a multi-hour mozilla-central compile. Mull is the
most actively maintained de-Googled Fenix fork, so rebranding Mull is the
realistic path to an "IceCat for Android".

## Before you rely on this — things to verify/finish

- **`MULL_REPO_URL` / `MULL_REF`** in `config/branding.env` are best-effort —
  confirm the current Mull-Fenix repo location and pin `MULL_REF` to a
  release tag for reproducible builds (`main` moves).
- **`GRADLE_TASK`** is a placeholder (`assembleDebug`). After the first
  `scripts/fetch-source.sh`, run `cd src && ./gradlew tasks` to find the real
  flavor/buildType combo (Fenix-based projects typically expose names like
  `assembleFenixDebug`) and update `config/branding.env`.
- **Unsigned builds only** by default. A `release` build needs a signing
  keystore — add one via GitHub Actions secrets and a Gradle signing config
  before switching `GRADLE_TASK` to a release variant.
- **Disk space**: source + Gradle/Android SDK caches can approach the ~14GB
  free on GitHub-hosted runners. The workflow strips unused preinstalled SDKs
  first; if it still runs out, move to a larger or self-hosted runner.
- **Branding is best-effort**: `apply-branding.sh` only handles
  `applicationId`, `app_name`, and launcher icons. Mull's UI likely references
  its own name/links elsewhere (about screen, onboarding, update checker,
  crash reporter URLs) — after a build, run `git -C src diff` and grep
  `src/**/res/values*/strings.xml` for remaining "Mull"/"Fenix"/"Firefox"
  mentions (see `branding/strings/overrides.xml` for a starting checklist).
- **Licensing**: these scripts/config are covered by this repo's top-level
  GPL-3.0 `LICENSE`. The resulting app is a derivative of Mull/Fenix and stays
  under their licenses (MPL-2.0, with some AGPL-3.0 components) — keep source
  available and retain upstream license/copyright notices.

## Local usage

```bash
./scripts/build.sh
# APK(s) land in dist/
```

Run the steps individually for debugging:

```bash
./scripts/fetch-source.sh     # clone Mull into src/
./scripts/apply-branding.sh   # rewrite app name / package id / icons
cd src && ./gradlew tasks     # find the real assemble task name
```

## Customizing the rebrand

Edit `config/branding.env`:

```bash
APP_NAME="IceCat"
PACKAGE_ID="org.gnuzilla.icecat"
```

Drop launcher icon replacements into `branding/icons/<mipmap-density>/`,
mirroring Android's resource layout — see `branding/icons/README.md`.

## CI

`.github/workflows/icecat-mobile.yml` runs the full pipeline on
`ubuntu-latest` and uploads `dist/*.apk` as a workflow artifact named
`icecat-apk`. Trigger it manually from the Actions tab (`workflow_dispatch`)
or by pushing changes under `icecat-mobile/` to `master`.
