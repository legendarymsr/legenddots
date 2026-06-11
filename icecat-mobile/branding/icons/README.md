# Custom launcher icons

Drop replacement launcher icons here, mirroring Android's resource layout
under `mipmap-*dpi/`. `scripts/rebrand-apk.sh` copies any file placed here onto
a same-named, same-relative-path file under `build/src/**/res/` (the
apktool-decompiled APK).

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

Nothing is bundled here yet — until you add IceCat-branded icons, the build
keeps Fennec F-Droid's stock icons.
