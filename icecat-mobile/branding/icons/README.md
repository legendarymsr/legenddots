# Custom launcher icons & wordmark

Drop replacement icons/images here, mirroring Android's resource layout
under `mipmap-*dpi/` (launcher icons) or `drawable*/` (homepage/About
logo and wordmark). `scripts/rebrand-apk.sh` copies any `.png`/`.webp` file
placed here onto a same-named, same-relative-path file under
`build/src/**/res/` (the apktool-decompiled APK).

## Launcher icons

Expected sizes (legacy + adaptive icon foreground/background layers):

| Density | Launcher (px) | Adaptive layer (px) |
|---------|---------------|----------------------|
| mdpi    | 48x48         | 108x108              |
| hdpi    | 72x72         | 162x162              |
| xhdpi   | 96x96         | 216x216              |
| xxhdpi  | 144x144       | 324x324              |
| xxxhdpi | 192x192       | 432x432              |

Play Store listing icon: 512x512 PNG (store metadata only, not part of the
APK).

Layout example:

```
branding/icons/
├── mipmap-mdpi/ic_launcher.png
├── mipmap-hdpi/ic_launcher.png
├── mipmap-xhdpi/ic_launcher.png
├── mipmap-xxhdpi/ic_launcher.png
└── mipmap-xxxhdpi/ic_launcher.png
```

Nothing is bundled here yet — until you add IceCat-branded launcher icons,
the build keeps Fennec F-Droid's stock app icon.

## Homepage/About logo & wordmark

Replaces the Fennec fox-head icon and "Fennec F-Droid" wordmark shown on the
new-tab homepage and the in-app About screen with an IceCat cat-head icon
(in `ICECAT_ACCENT_COLOR`) and "IceCat" wordmark text:

```
branding/icons/
├── drawable-nodpi/ic_wordmark_logo.webp                 # homepage icon (160x160)
├── drawable-nodpi/ic_wordmark_text_{normal,private}.webp # homepage wordmark text (661x70)
├── drawable-mdpi/ic_logo_wordmark_{normal,private}.webp # About-screen combined icon+wordmark
├── drawable-hdpi/ic_logo_wordmark_{normal,private}.webp
├── drawable-xhdpi/ic_logo_wordmark_{normal,private}.webp
├── drawable-xxhdpi/ic_logo_wordmark_{normal,private}.webp
└── drawable-xxxhdpi/ic_logo_wordmark_{normal,private}.webp
```

Each file must sit in the SAME `res/` folder Fenix serves that resource from,
or `rebrand-apk.sh`'s path-exact copy silently skips it and the upstream
"Fennec F-Droid" art survives. In current Fennec F-Droid the split homepage
wordmark (icon + text, shown side-by-side on the new-tab page) lives in
`drawable-nodpi/`, while the combined About-screen wordmark is a density raster
set (`drawable-mdpi`..`drawable-xxxhdpi`). Match those exactly.

`normal`/`private` are Fenix's light/dark-theme variants. Fenix ALSO ships
vector (`.xml`) variants of some of these resources — `drawable/ic_wordmark_text_*.xml`
and a `drawable-night/ic_logo_wordmark_normal.xml` inset — that can override a
raster on some densities or in dark mode; `rebrand-apk.sh` deletes every upstream
`.xml` variant of any wordmark resource we ship a raster for, so ours is the
sole representation.

The shipped set is an original cat-head icon (flat shapes, no third-party
artwork) in `ICECAT_ACCENT_COLOR` paired with "IceCat" rendered in IBM Plex
Serif Bold; hand-edit or regenerate these `.webp` files (e.g. with Pillow) to
use different artwork or colors — they're static images, so changing
`ICECAT_ACCENT_COLOR` alone won't update them. Keep the pixel dimensions equal
to the upstream file you're replacing (see the tree above) so it renders at the
right size.
