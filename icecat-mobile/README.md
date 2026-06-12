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
2. `scripts/download-extensions.sh` is a no-op unless `BUNDLE_EXTENSIONS="true"`
   (see "Bundled extensions (experimental)" below), in which case it
   downloads GNU LibreJS, uBlock Origin, Privacy Badger, and Dark Reader from
   addons.mozilla.org into `build/extensions/`.
3. `scripts/rebrand-apk.sh` decompiles `build/upstream.apk` with `apktool`,
   then:
   - rewrites the `app_name` string to `APP_NAME` and replaces remaining
     "Fennec"/"Firefox" mentions across `res/values*/strings.xml` with
     `APP_NAME` (skipping the entries listed in
     `branding/strings/overrides.xml`, which name real external Mozilla
     services that keep their own name regardless of this rebrand);
   - sets the default search engine (`assets/search/list.json`) to
     `DEFAULT_SEARCH_ENGINE`;
   - recolors Fenix's primary accent color (`res/values/colors.xml`) to
     `ICECAT_ACCENT_COLOR`;
   - points the **Settings → Add-ons → Recommended** list at
     `AMO_COLLECTION_USER`/`AMO_COLLECTION_NAME`, and unhides the
     **Settings → Advanced → Custom extension collection** option (normally
     Nightly/Beta-only) so users can also point it there themselves (see
     "Recommended add-ons" below);
   - copies in custom launcher icons from `branding/icons/` if present;
   - applies the hardening prefs from `branding/hardening-prefs.js` to
     GeckoView's bundled default preferences (unless
     `ENABLE_HARDENING="false"`);
   - if `BUNDLE_EXTENSIONS="true"`, bundles the extensions fetched in step 2
     as built-in WebExtensions (see "Bundled extensions (experimental)"
     below);

   then rebuilds everything to `build/icecat-unsigned.apk`.
4. `scripts/sign-apk.sh` runs `zipalign` and re-signs the APK with the
   throwaway keystore in `keystore/`, producing `dist/icecat.apk`.
5. `scripts/package.sh` runs the four steps above in order.
6. `.github/workflows/icecat-mobile.yml` (repo root) runs the same pipeline on
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
- DNS over HTTPS ("increased" mode, via Mullvad's base DoH endpoint), falling
  back to the system resolver only if DoH is unreachable
- Notification permission requests denied by default (sites can still be
  allowed individually from their site-permissions page)
- Credit card, address, and form-fill-history autofill disabled
- WebRTC local-network IP addresses hidden from peers (calls still work)
- Downloaded-file hashes no longer sent to Google Safe Browsing (URL-based
  phishing/malware blocklists stay on)
- Web content forced to `prefers-color-scheme: dark` — sites with a dark
  theme use it regardless of system theme (a built-in, prefs-only
  approximation of "Dark Reader" for sites that support it)

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
- DNS over HTTPS sends DNS lookups to Mullvad (`base.dns.mullvad.net`) instead
  of your network's configured resolver. Set `network.trr.mode=0` in
  `about:config` to disable, or change `network.trr.uri` to a different DoH
  resolver.
- Forcing `prefers-color-scheme: dark` for web content
  (`layout.css.prefers-color-scheme.content-override=0`) only affects sites
  that implement a dark theme via CSS — it doesn't recolor sites that don't.
  Set it to `3` in `about:config` to follow the browser theme instead, or
  install the Dark Reader extension (below) for force-dark on any site.
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

## Logo and wordmark

The Fennec fox-head icon and "Fennec F-Droid" wordmark (shown on the new-tab
homepage and the in-app About screen) are raster images, not strings, so the
string-based debranding below doesn't touch them. `branding/icons/` ships a
full replacement set — an original cat-head icon in `ICECAT_ACCENT_COLOR` and
an "IceCat" wordmark (IBM Plex Serif Bold) — covering every density and
light/dark ("normal"/"private") variant Fenix references:

- `drawable-{m,h,xh,xxh,xxx}hdpi/ic_logo_wordmark_{normal,private}.webp` —
  combined icon+wordmark shown on the About screen
- `drawable/ic_wordmark_logo.webp`,
  `ic_wordmark_text_{normal,private}.webp` — icon and wordmark text shown
  separately on the homepage header
- `drawable/ic_wordmark_sport_logo.webp` — seasonal/sport variant of the icon

These are deployed by the same `branding/icons/` copy mechanism as launcher
icons (see "Customizing the rebrand" below); regenerate or replace any of
these files to use different artwork. `drawable-night/ic_logo_wordmark_normal.xml`
just insets `ic_logo_wordmark_private`, so no XML changes are needed for dark
mode.

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
baked into images (besides the wordmark/logo replaced above), the update
checker, or crash-reporter URLs is unaffected.

## Bundled extensions (experimental)

**Status: experimental, opt-in, default off, untested on a real device.**
Set `BUNDLE_EXTENSIONS="true"` in `config/branding.env` to have
`scripts/package.sh` pre-install GNU LibreJS, uBlock Origin, Privacy Badger,
and Dark Reader as **built-in, auto-enabled WebExtensions** — no taps, no
visit to Settings → Add-ons required. The published `icecat-latest` release
is built with `BUNDLE_EXTENSIONS="false"` (the default); this is something
you opt into for your own sideloaded build.

### How it works

Fenix ships a handful of "built-in" extensions of its own (reader view,
favicon fetching, web-compat shims, etc.) as unpacked extension folders under
`assets/extensions/`, registered at startup with a single call —
`WebExtensionRuntime.installBuiltInWebExtension(id, "resource://android/assets/extensions/<name>/", onSuccess, onError)`
— from compiled app code (`org.mozilla.fenix.components.Core`'s
`BrowserStore` initializer). There's no resource file or config flag driving
this list, so extending it means patching that compiled code.

When `BUNDLE_EXTENSIONS="true"`, `scripts/rebrand-apk.sh`:

1. Unpacks the four extensions' XPIs (fetched by the new
   `scripts/download-extensions.sh` from addons.mozilla.org) into
   `assets/extensions/<name>/`, alongside Fenix's own built-ins.
2. Adds one new decompiled-bytecode (smali) class,
   `org.mozilla.fenix.icecat.IcecatExtensions`
   (`branding/smali/IcecatExtensions.smali`), whose `installAll()` method
   calls `installBuiltInWebExtension()` once per bundled extension — reusing
   the same no-op success/error callback classes
   (`BuiltInWebExtensionController$$ExternalSyntheticLambda2`/`Lambda3`) Fenix
   already ships for this purpose.
3. Finds the line where Fenix registers its own `icons@mozac.org` built-in
   and inserts one call to `IcecatExtensions.installAll()` immediately after
   it, passing along the same live `WebExtensionRuntime` reference.

This bytecode patch is the *only* way to get zero-tap, auto-enabled, unsigned
extensions out of a repackaging-only pipeline — everything else this pipeline
does is a resource/string/asset rewrite, but this one step edits compiled app
code.

### Why this is risky

- **Not verified on a real device.** This has been confirmed to produce a
  syntactically valid patch that survives `apktool b`'s rebuild (and a
  round-trip re-decompile with the patch intact) and yields an
  installable-sized APK — but it has *not* been launched on an Android
  device or emulator. If the patched initializer doesn't behave as expected
  at runtime, the app could crash on startup.
- **Fragile across Fennec F-Droid updates.** The insertion point is found by
  searching the decompiled smali for the literal string
  `resource://android/assets/extensions/browser-icons/` (Fenix's own
  `icons@mozac.org` registration) and patching that line. If a future Fenix
  release restructures this initializer so that string/line no longer exists
  in this form, `rebrand-apk.sh` fails loudly (`ERROR: could not locate
  Core's built-in-extension installer`) instead of silently producing a
  broken APK — but the patch will then need re-checking against the new
  Fenix internals.
- **LibreJS isn't in Fenix's curated extension collection** at all (the other
  three are — see below), so its Android compatibility is less battle-tested.
  It's bundled using its declared extension ID, `jid1-KtlZuoiikVfFew@jetpack`.

### Enabling and verifying

1. Set `BUNDLE_EXTENSIONS="true"` in `config/branding.env`.
2. Run `./scripts/package.sh` (the new `scripts/download-extensions.sh` step
   runs automatically between `download-apk.sh` and `rebrand-apk.sh`, and is
   a no-op when `BUNDLE_EXTENSIONS="false"`).
3. Install `dist/icecat.apk` on a device and open the app.

**Known issue**: the app launches normally (no crash), but the four
extensions do **not** appear in **Settings → Add-ons**. `WebExtensionRuntime.
installBuiltInWebExtension()` registers them directly with GeckoView, which is
how Fenix's own hidden built-ins (e.g. `icons@mozac.org`) work — but Fenix's
Add-ons screen is populated separately, by `WebExtensionSupport`/`AddonManager`
correlating AMO collection metadata with extensions installed through Fenix's
normal install flow. Extensions added via `installBuiltInWebExtension` outside
that flow aren't picked up by the screen, even if GeckoView has loaded them.
Whether they're nonetheless functionally active (e.g. uBlock0 actually
blocking requests) hasn't been verified. Making them appear/manageable in
**Settings → Add-ons** would need additional changes to register them with
`WebExtensionSupport` too — not yet implemented.

### Recovery if it breaks

The repo's throwaway signing key (see "Throwaway signing key" below) means a
new build can always be installed *over* a broken one — APK installation
doesn't require the currently-installed app to run. If a
`BUNDLE_EXTENSIONS="true"` build crashes on launch:

1. Set `BUNDLE_EXTENSIONS="false"` (or just leave it unset — that's the
   default).
2. Re-run `./scripts/package.sh`.
3. Install the resulting `dist/icecat.apk` over the broken one — same signing
   key, no uninstall needed.

## Recommended add-ons (default build)

With `BUNDLE_EXTENSIONS="false"` (the default), GNU LibreJS, uBlock Origin,
Privacy Badger, and Dark Reader are not pre-installed, but each is a couple of
taps away — open the link on the device (it'll launch IceCat) and tap
"Add to Firefox":

- [GNU LibreJS](https://addons.mozilla.org/en-US/android/addon/librejs/) —
  blocks nonfree/nontrivial JavaScript
- [uBlock Origin](https://addons.mozilla.org/en-US/android/addon/ublock-origin/)
  — wide-spectrum content/ad blocker
- [Privacy Badger](https://addons.mozilla.org/en-US/android/addon/privacy-badger17/)
  — learns to block hidden trackers
- [Dark Reader](https://addons.mozilla.org/en-US/android/addon/darkreader/) —
  force-dark for sites without a native dark theme (the hardening prefs above
  already force `prefers-color-scheme: dark` for sites that *do* have one)

**GNU LibreJS note**: AMO doesn't list LibreJS as Android-compatible, so its
page shows "This add-on is not available on your platform" instead of an
install button. Request the desktop site first — IceCat will still install it
normally:

```
┌────────────────────────────────────┐
│ addons.mozilla.org/.../librejs/  ⋮ │
├────────────────────────────────────┤
│                                      │
│  GNU LibreJS                        │
│  by Ruben Rodriguez                 │
│                                      │
│  ⚠ This add-on is not available     │
│    on your platform.                │
│                                      │
└────────────────────────────────────┘
        1. tap ⋮ (top-right menu)
                  │
                  ▼
┌────────────────────────────────────┐
│  ↻  Reload                          │
│  ☆  Add to bookmarks                │
│  ⬇  Downloads                       │
│  ▢  Desktop site            ◄── tap │
│  ⚙  Settings                        │
└────────────────────────────────────┘
        2. enable "Desktop site" (page reloads)
                  │
                  ▼
┌────────────────────────────────────┐
│ addons.mozilla.org/.../librejs/  ⋮ │
├────────────────────────────────────┤
│                                      │
│  To use Android extensions, you'll  │
│  need Firefox for Android. To       │
│  explore Firefox for desktop        │
│  add-ons, please visit our          │
│  ┌────────────────────────┐        │
│  │ visit our desktop site  │◄── tap │
│  └────────────────────────┘        │
└────────────────────────────────────┘
        3. tap "visit our desktop site"
                  │
                  ▼
┌────────────────────────────────────┐
│ addons.mozilla.org/.../librejs/  ⋮ │
├────────────────────────────────────┤
│                                      │
│  GNU LibreJS                        │
│  by Ruben Rodriguez                 │
│                                      │
│  [ + Add to Firefox ]        ◄── tap│
│                                      │
└────────────────────────────────────┘
        4. tap "Add to Firefox" → "Add"
```

uBlock Origin, Privacy Badger, and Dark Reader also show up directly under
**Settings → Add-ons → Recommended** (Mozilla's default
"Extensions-for-Android" AMO collection); LibreJS isn't in that collection, so
grab it via the link above or "Find more add-ons" on the same screen.

Advanced: `AMO_COLLECTION_USER`/`AMO_COLLECTION_NAME` in
`config/branding.env`, plus the unhidden **Settings → Advanced → Custom
extension collection** setting, let you point the Recommended tab at your own
AMO collection if you'd rather have all four show up there too.

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
- **Branding is best-effort**: `app_name`, launcher icons, the homepage/About
  logo and wordmark, and "Fennec"/"Firefox" mentions in
  `res/values*/strings.xml` are rewritten (see "Logo and wordmark" and
  "Removing Firefox/Fennec branding" above), but the update checker, crash
  reporter URLs, and anything else baked into images are unaffected. After a
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
- **`BUNDLE_EXTENSIONS` (default `"false"`) is experimental and untested on a
  real device** — it patches compiled app bytecode to pre-install four
  extensions, rather than just rewriting resources/strings like everything
  else here. See "Bundled extensions (experimental)" above before enabling
  it. The published `icecat-latest` release always has this off.
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
./scripts/download-apk.sh        # fetch the upstream Fennec F-Droid APK into build/
./scripts/download-extensions.sh # fetch bundled extensions into build/ (no-op unless BUNDLE_EXTENSIONS=true)
./scripts/rebrand-apk.sh         # decompile, rewrite app name/icons, rebuild
./scripts/sign-apk.sh            # zipalign + sign into dist/
```

## Customizing the rebrand

Edit `config/branding.env`:

```bash
APP_NAME="IceCat"
UPSTREAM_ABI="arm64-v8a"
ENABLE_HARDENING="true"
DEFAULT_SEARCH_ENGINE="Brave"
ICECAT_ACCENT_COLOR="0EA5E9"
AMO_COLLECTION_USER="mozilla"
AMO_COLLECTION_NAME="Extensions-for-Android"
BUNDLE_EXTENSIONS="false"
```

Drop launcher icon replacements into `branding/icons/<mipmap-density>/`, and
logo/wordmark replacements into `branding/icons/drawable*/`, mirroring
Android's resource layout — see `branding/icons/README.md`.

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
