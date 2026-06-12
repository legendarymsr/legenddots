# IceCat Mobile (Fennec F-Droid rebrand)

Scripts and CI to produce a directly-installable, de-branded, and
privacy-hardened "IceCat for Android" APK by repackaging the official
prebuilt [Fennec F-Droid](https://f-droid.org/packages/org.mozilla.fennec_fdroid/)
APK — Mozilla's own de-Googled build of Firefox for Android (Fenix/GeckoView),
published on the official F-Droid repo — with a new app name/icon, an
Arkenfox/Mull/Tor-Browser-inspired set of hardened default preferences, and
re-signing for sideloading. No source build required.

This folder is self-contained: all paths below are relative to
`icecat-mobile/`.

## How this works

1. `scripts/download-apk.sh` looks up the latest Fennec F-Droid APK for
   `UPSTREAM_PACKAGE_ID`/`UPSTREAM_ABI` in the F-Droid repo
   (`UPSTREAM_FDROID_REPO`, see `config/branding.env`) and downloads it to
   `build/upstream.apk`.
2. `scripts/rebrand-apk.sh` decompiles it with `apktool`, then:
   - rewrites the `app_name` string to `APP_NAME` and replaces remaining
     "Fennec"/"Firefox" mentions across `res/values*/strings.xml` with
     `APP_NAME` (skipping the entries listed in
     `branding/strings/overrides.xml`, which name real external Mozilla
     services that keep their own name regardless of this rebrand);
   - sets the default search engine (`assets/search/list.json`) to
     `DEFAULT_SEARCH_ENGINE`;
   - recolors Fenix's primary accent color (`res/values/colors.xml`) to
     `ICECAT_ACCENT_COLOR`;
   - copies in custom launcher icons from `branding/icons/` if present;
   - applies the hardening prefs from `branding/hardening-prefs.js` to
     GeckoView's bundled default preferences (unless
     `ENABLE_HARDENING="false"`);

   then rebuilds everything to `build/icecat-unsigned.apk`.
3. `scripts/sign-apk.sh` runs `zipalign` and re-signs the APK with the
   throwaway keystore in `keystore/`, producing `dist/icecat.apk`.
4. `scripts/package.sh` runs the three steps above in order.
5. `.github/workflows/icecat-mobile.yml` (repo root) runs the same pipeline on
   every push to `master` that touches this folder (and on demand) and
   uploads `dist/icecat.apk` as a workflow artifact.

## Why repackaging instead of a source build

GNU IceCat's existing de-branding patches target the old Firefox/XUL desktop
codebase, which Firefox for Android no longer uses. Building Fenix-based apps
from source is possible but heavyweight (large source tree, Gradle/Android SDK
setup, multi-gigabyte caches). Repackaging Fennec F-Droid's already-built,
signed release APK gets the same de-Googled browser with a custom name/icon in
seconds, with nothing to compile.

### Why Fennec F-Droid (and not Mull)

DivestOS's Mull was the original target for this rebrand, but Mull was
deprecated and archived in early 2025 in favor of Fennec F-Droid, and is no
longer distributed as a downloadable APK. Fennec F-Droid is Mozilla's own
de-Googled Fenix build, actively maintained, and published on the official
F-Droid repo (`f-droid.org`) — a more reliable and directly reachable source
than DivestOS's third-party repo.

## Privacy & security hardening

In addition to renaming/re-iconing, `scripts/rebrand-apk.sh` patches
GeckoView's bundled default-preferences file
(`defaults/pref/<abi>/geckoview-prefs.js` inside `assets/omni.ja`) with an
Arkenfox/Mull/Tor-Browser-inspired preference set from
`branding/hardening-prefs.js`, layered on top of whatever Fennec F-Droid
already ships (telemetry off, EME/DRM off, crash reporting off, etc.). This
is a resource patch — no Gecko/Fenix source or code changes — but it's the
same mechanism ("ship different default prefs") Mull itself relied on for
most of its hardening.

Currently applied (see `branding/hardening-prefs.js` for the authoritative,
up-to-date list):

- Enhanced Tracking Protection set to "Strict" (blocks known trackers,
  cryptominers, fingerprinting scripts, and social trackers)
- `privacy.resistFingerprinting` — Tor Browser/Mull-style fingerprinting
  resistance (normalizes timezone, screen/window size, canvas/WebGL
  readback, etc.)
- HTTPS-Only mode
- Do Not Track and Global Privacy Control signals sent to sites
- Battery Status API, Beacon API, and `<a ping>` disabled
- Opt out of Mozilla's remote experiments (Nimbus/Shield studies) and extra
  data submission
- Autoplaying media with sound blocked by default
- Internationalized domain names (IDNs) shown as punycode (`xn--...`) to
  resist script-mixing phishing/homograph attacks
- DNS over HTTPS ("increased" mode, via Mozilla's Cloudflare TRR endpoint),
  falling back to the system resolver only if DoH is unreachable
- Notification permission requests denied by default (sites can still be
  allowed individually from their site-permissions page)
- Credit card autofill/storage disabled

**Trade-offs to know about:**

- `privacy.resistFingerprinting` can break sites that depend on
  canvas/WebGL/timezone APIs, and spoofs `Accept-Language`/locale to en-US —
  some sites may show English instead of your language. Toggle it off
  per-site via the shield icon in the address bar, or set
  `privacy.resistFingerprinting=false` in `about:config` to disable it
  globally.
- `network.IDN_show_punycode` means legitimate non-Latin-script domains
  (e.g. your bank's site in a language using Cyrillic, CJK, etc.) will also
  display as `xn--...` punycode instead of native script.
- DNS over HTTPS sends DNS lookups to Cloudflare (`mozilla.cloudflare-dns.com`)
  instead of your network's configured resolver. Set
  `network.trr.mode=0` in `about:config` to disable, or change
  `network.trr.uri` to a different DoH resolver.
- None of these prefs are `locked` — anything here can be changed at runtime
  in `about:config` if it causes problems on a site.
- Set `ENABLE_HARDENING="false"` in `config/branding.env` for a pure rebrand
  with no behavior changes beyond the name/icon.

## Default search engine

`scripts/rebrand-apk.sh` sets `assets/search/list.json`'s
`default.searchDefault` to `DEFAULT_SEARCH_ENGINE` (`config/branding.env`,
default `"Brave"`). Brave Search is already bundled as a selectable engine in
Fennec F-Droid (`assets/searchplugins/brave.xml`); this just makes it the
default for new profiles instead of DuckDuckGo. Change it to any engine name
listed in `default.searchOrder`/`default.visibleDefaultEngines` in that file
(e.g. `"DuckDuckGo"`, `"Ecosia"`, `"Mojeek"`, `"Startpage"`).

## Theming

`scripts/rebrand-apk.sh` recolors Fenix's primary accent color
(`res/values/colors.xml`'s `photonInk20`/`photonInk20A20`, normally a
dark indigo/purple) to `ICECAT_ACCENT_COLOR` (`config/branding.env`, default
`0EA5E9`, an "ice" blue). This affects the address bar highlight, buttons,
links, and similar accented UI in both light and dark mode. Private
browsing's distinct purple accent (`photonViolet*`) is intentionally left
unchanged.

## Removing Firefox/Fennec branding

In addition to `app_name`, `scripts/rebrand-apk.sh` replaces remaining
"Fennec"/"Firefox" mentions in `res/values*/strings.xml` (onboarding,
Terms of Use, sync, profiler labels, etc.) with `APP_NAME`, across every
bundled locale. Entries listed by `name` in
`branding/strings/overrides.xml` are skipped — currently just
`firefox_relay` ("Firefox Relay"), Mozilla's email-masking service, which
keeps its own name since it's a real external service this app doesn't
provide. Add more `<string name="...">` entries to that file if a future
Fennec F-Droid release adds other strings that shouldn't be renamed.

This is a best-effort find/replace of UI text, not a rebuild — anything
baked into images, the update checker, or crash-reporter URLs is unaffected.

## Recommended add-ons (not pre-installed)

GNU LibreJS, uBlock Origin, and Privacy Badger can't be bundled as
pre-installed/auto-enabled extensions by this repackaging approach: Fenix's
"built-in" extensions (`assets/extensions/` — search, webcompat, etc.) are
registered by ID in compiled app code, not from a resource file this pipeline
can extend without a full source build.

All three are, however, available for Firefox for Android on
addons.mozilla.org and install in a couple of taps from **Settings → Add-ons**
in the app:

- [GNU LibreJS](https://addons.mozilla.org/en-US/android/addon/librejs/) —
  blocks nonfree/nontrivial JavaScript
- [uBlock Origin](https://addons.mozilla.org/en-US/android/addon/ublock-origin/)
  — wide-spectrum content/ad blocker
- [Privacy Badger](https://addons.mozilla.org/en-US/android/addon/privacy-badger17/)
  — learns to block hidden trackers

## Getting the APK

- **Direct download (no build, no login)**: every push to `master` publishes
  `icecat.apk` to the
  [`icecat-latest` release](../../releases/tag/icecat-latest) as a release
  asset — grab it straight from the Releases page on your phone.
- **From CI**: open the "Build IceCat APK" workflow run in the Actions tab and
  download the `icecat-apk` artifact, which contains `icecat.apk`.
- **Locally**: run `./scripts/package.sh` (requires `apktool`, `zipalign`,
  `apksigner`, `zip`, `unzip`, and `jq` on `PATH`); the result is
  `dist/icecat.apk`.

### Installing

`icecat.apk` is signed with this repo's throwaway key, so it installs like any
sideloaded app: enable "Install unknown apps" for your file manager/browser,
then open the APK. Re-running the pipeline and reinstalling will update in
place (same signing key) without uninstalling first.

## Before you rely on this — things to verify/finish

- **`UPSTREAM_ABI`** in `config/branding.env` defaults to `arm64-v8a` (most
  modern phones; Fennec F-Droid also ships `armeabi-v7a` and `x86_64`).
  `scripts/download-apk.sh` always pulls the latest build straight from the
  [F-Droid repo](https://f-droid.org/repo) (`UPSTREAM_FDROID_REPO`) for
  `UPSTREAM_PACKAGE_ID`/`UPSTREAM_ABI`, so no URL pinning is needed.
- **Package ID/applicationId is unchanged** — this rebrand only changes the
  display name (and optionally the icon), not the Android package ID. It
  remains installable alongside or as an update path for upstream Fennec
  F-Droid only if signatures match (they won't, since this repo re-signs with
  its own key) — treat it as a separate app for update purposes.
- **Branding is best-effort**: `app_name`, launcher icons, and
  "Fennec"/"Firefox" mentions in `res/values*/strings.xml` are rewritten (see
  "Removing Firefox/Fennec branding" above), but the update checker, crash
  reporter URLs, and anything baked into images are unaffected. After a
  rebrand, grep `build/src/res/values*/strings.xml` for any remaining
  "Fennec"/"Fenix"/"Firefox" mentions if you want to track down more.
- **Hardening is a default-prefs patch, not a source rebuild**:
  `branding/hardening-prefs.js` changes GeckoView's *default* `pref()`
  values — solid for the privacy/security toggles Firefox already exposes
  (tracking protection, fingerprinting resistance, HTTPS-Only, etc.), but it
  can't remove UI elements, add new features, or change anything that needs
  actual Fenix/Gecko code changes (that would need a full Mull-style source
  build).
- **Throwaway signing key**: `keystore/icecat-release.keystore` is committed
  to this repo specifically so sideloaded builds can be reinstalled/updated
  without uninstalling. It carries no trust beyond "built from this repo" —
  do not treat `icecat.apk` as officially signed by Mozilla/F-Droid.
- **Licensing**: these scripts/config are covered by this repo's top-level
  GPL-3.0 `LICENSE`. The resulting app is Fennec F-Droid/Fenix repackaged and
  stays under their licenses (MPL-2.0, with some AGPL-3.0 components) — keep
  source available and retain upstream license/copyright notices.

## Local usage

```bash
./scripts/package.sh
# Installable APK lands at dist/icecat.apk
```

Run the steps individually for debugging:

```bash
./scripts/download-apk.sh   # fetch the upstream Fennec F-Droid APK into build/
./scripts/rebrand-apk.sh    # decompile, rewrite app name/icons, rebuild
./scripts/sign-apk.sh       # zipalign + sign into dist/
```

## Customizing the rebrand

Edit `config/branding.env`:

```bash
APP_NAME="IceCat"
UPSTREAM_ABI="arm64-v8a"
ENABLE_HARDENING="true"
DEFAULT_SEARCH_ENGINE="Brave"
ICECAT_ACCENT_COLOR="0EA5E9"
```

Drop launcher icon replacements into `branding/icons/<mipmap-density>/`,
mirroring Android's resource layout — see `branding/icons/README.md`.

Edit `branding/hardening-prefs.js` to add, remove, or tune the hardening
preferences applied to GeckoView's defaults (see "Privacy & security
hardening" above).

Edit `branding/strings/overrides.xml` to exclude additional
`<string name="...">` entries from the "Fennec"/"Firefox" -> `APP_NAME`
rename (see "Removing Firefox/Fennec branding" above).

## CI

`.github/workflows/icecat-mobile.yml` runs the full pipeline on
`ubuntu-latest` (installing JDK, Android build-tools, and `apktool`), uploads
`dist/icecat.apk` as a workflow artifact named `icecat-apk`, and publishes it
to the rolling `icecat-latest` GitHub release. Trigger it manually from the
Actions tab (`workflow_dispatch`) or by pushing changes under `icecat-mobile/`
to `master`.
