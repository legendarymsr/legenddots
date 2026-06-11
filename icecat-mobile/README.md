# IceCat Mobile (Mull rebrand)

Scripts and CI to produce a directly-installable, de-branded "IceCat for
Android" APK by repackaging the official prebuilt
[Mull](https://divestos.org/) APK — DivestOS's privacy-hardened fork of
Firefox for Android (Fenix/GeckoView) — with a new app name/icon, re-signed
for sideloading. No source build required.

This folder is self-contained: all paths below are relative to
`icecat-mobile/`.

## How this works

1. `scripts/download-apk.sh` downloads the prebuilt Mull APK from
   `MULL_APK_URL` (see `config/branding.env`) to `build/mull.apk`.
2. `scripts/rebrand-apk.sh` decompiles it with `apktool`, rewrites the
   `app_name` string to `APP_NAME`, copies in custom launcher icons from
   `branding/icons/` if present, and rebuilds it to `build/icecat-unsigned.apk`.
3. `scripts/sign-apk.sh` runs `zipalign` and re-signs the APK with the
   throwaway keystore in `keystore/`, producing `dist/icecat.apk`.
4. `scripts/package.sh` runs the three steps above in order.
5. `.github/workflows/icecat-mobile.yml` (repo root) runs the same pipeline on
   every push to `master` that touches this folder (and on demand) and
   uploads `dist/icecat.apk` as a workflow artifact.

## Why repackaging instead of a source build

GNU IceCat's existing de-branding patches target the old Firefox/XUL desktop
codebase, which Firefox for Android no longer uses. Building Mull's Fenix-based
app from source is possible but heavyweight (large source tree, Gradle/Android
SDK setup, multi-gigabyte caches). Repackaging Mull's already-built, signed
release APK gets the same de-Googled browser with a custom name/icon in
seconds, with nothing to compile.

## Getting the APK

- **Direct download (no build, no login)**: every push to `master` publishes
  `icecat.apk` to the
  [`icecat-latest` release](../../releases/tag/icecat-latest) as a release
  asset — grab it straight from the Releases page on your phone.
- **From CI**: open the "Build IceCat APK" workflow run in the Actions tab and
  download the `icecat-apk` artifact, which contains `icecat.apk`.
- **Locally**: run `./scripts/package.sh` (requires `apktool`, `zipalign`, and
  `apksigner` on `PATH`); the result is `dist/icecat.apk`.

### Installing

`icecat.apk` is signed with this repo's throwaway key, so it installs like any
sideloaded app: enable "Install unknown apps" for your file manager/browser,
then open the APK. Re-running the pipeline and reinstalling will update in
place (same signing key) without uninstalling first.

## Before you rely on this — things to verify/finish

- **`MULL_APK_URL`** in `config/branding.env` points at Mull's `latest`
  release asset for `arm64-v8a`. Check
  [Mull's releases](https://github.com/divested-mobile/Mull/releases) (or
  [DivestOS's F-Droid repo](https://fdroid.divestos.org/)) for the current
  build, pick the asset matching your device's ABI, and pin to a specific
  version/tag for reproducible builds.
- **Package ID/applicationId is unchanged** — this rebrand only changes the
  display name (and optionally the icon), not the Android package ID. It
  remains installable alongside or as an update path for upstream Mull only if
  signatures match (they won't, since this repo re-signs with its own key) —
  treat it as a separate app for update purposes.
- **Branding is best-effort**: only `app_name` and launcher icons are
  rewritten. Mull's UI likely references its own name/links elsewhere (about
  screen, onboarding, update checker, crash reporter URLs) — after a rebrand,
  grep `build/src/res/values*/strings.xml` for remaining "Mull"/"Fenix"
  mentions (see `branding/strings/overrides.xml` for a starting checklist).
- **Throwaway signing key**: `keystore/icecat-release.keystore` is committed
  to this repo specifically so sideloaded builds can be reinstalled/updated
  without uninstalling. It carries no trust beyond "built from this repo" —
  do not treat `icecat.apk` as officially signed by Mull/DivestOS.
- **Licensing**: these scripts/config are covered by this repo's top-level
  GPL-3.0 `LICENSE`. The resulting app is Mull/Fenix repackaged and stays under
  their licenses (MPL-2.0, with some AGPL-3.0 components) — keep source
  available and retain upstream license/copyright notices.

## Local usage

```bash
./scripts/package.sh
# Installable APK lands at dist/icecat.apk
```

Run the steps individually for debugging:

```bash
./scripts/download-apk.sh   # fetch the upstream Mull APK into build/
./scripts/rebrand-apk.sh    # decompile, rewrite app name/icons, rebuild
./scripts/sign-apk.sh       # zipalign + sign into dist/
```

## Customizing the rebrand

Edit `config/branding.env`:

```bash
APP_NAME="IceCat"
MULL_APK_URL="https://github.com/divested-mobile/Mull/releases/latest/download/Mull-FOSS-arm64-v8a.apk"
```

Drop launcher icon replacements into `branding/icons/<mipmap-density>/`,
mirroring Android's resource layout — see `branding/icons/README.md`.

## CI

`.github/workflows/icecat-mobile.yml` runs the full pipeline on
`ubuntu-latest` (installing JDK, Android build-tools, and `apktool`), uploads
`dist/icecat.apk` as a workflow artifact named `icecat-apk`, and publishes it
to the rolling `icecat-latest` GitHub release. Trigger it manually from the
Actions tab (`workflow_dispatch`) or by pushing changes under `icecat-mobile/`
to `master`.
