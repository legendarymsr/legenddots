# EXPERIMENTAL (see config/branding.env's BUNDLE_EXTENSIONS and README's
# "Bundled extensions (experimental)" section).
#
# scripts/rebrand-apk.sh copies this class verbatim into the decompiled
# Fenix smali tree and adds one call to IcecatExtensions->installAll() from
# Core's BrowserStore initializer (where Fenix itself installs its own
# built-in extensions, e.g. "icons@mozac.org"). installAll() registers
# GNU LibreJS, uBlock Origin, Privacy Badger, and Dark Reader as built-in
# WebExtensions the same way, via
# WebExtensionRuntime->installBuiltInWebExtension(), using their unpacked
# XPIs under assets/extensions/ (placed there by the same script from
# scripts/download-extensions.sh's output) and their real AMO extension IDs.
#
# The no-op success/error callbacks
# (BuiltInWebExtensionController$$ExternalSyntheticLambda2 / Lambda3) are
# reused from mozilla.components.support.webextensions, which Fenix already
# ships and uses for the same purpose.
.class public final Lorg/mozilla/fenix/icecat/IcecatExtensions;
.super Ljava/lang/Object;
.source "IcecatExtensions.smali"


# direct methods
.method public static final installAll(Lmozilla/components/concept/engine/webextension/WebExtensionRuntime;)V
    .locals 4

    new-instance v0, Lmozilla/components/support/webextensions/BuiltInWebExtensionController$$ExternalSyntheticLambda2;

    invoke-direct {v0}, Ljava/lang/Object;-><init>()V

    new-instance v1, Lmozilla/components/support/webextensions/BuiltInWebExtensionController$$ExternalSyntheticLambda3;

    invoke-direct {v1}, Ljava/lang/Object;-><init>()V

    const-string v2, "uBlock0@raymondhill.net"

    const-string v3, "resource://android/assets/extensions/ublock0/"

    invoke-interface {p0, v2, v3, v0, v1}, Lmozilla/components/concept/engine/webextension/WebExtensionRuntime;->installBuiltInWebExtension(Ljava/lang/String;Ljava/lang/String;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function1;)V

    new-instance v0, Lmozilla/components/support/webextensions/BuiltInWebExtensionController$$ExternalSyntheticLambda2;

    invoke-direct {v0}, Ljava/lang/Object;-><init>()V

    new-instance v1, Lmozilla/components/support/webextensions/BuiltInWebExtensionController$$ExternalSyntheticLambda3;

    invoke-direct {v1}, Ljava/lang/Object;-><init>()V

    const-string v2, "jid1-MnnxcxisBPnSXQ@jetpack"

    const-string v3, "resource://android/assets/extensions/privacy-badger/"

    invoke-interface {p0, v2, v3, v0, v1}, Lmozilla/components/concept/engine/webextension/WebExtensionRuntime;->installBuiltInWebExtension(Ljava/lang/String;Ljava/lang/String;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function1;)V

    new-instance v0, Lmozilla/components/support/webextensions/BuiltInWebExtensionController$$ExternalSyntheticLambda2;

    invoke-direct {v0}, Ljava/lang/Object;-><init>()V

    new-instance v1, Lmozilla/components/support/webextensions/BuiltInWebExtensionController$$ExternalSyntheticLambda3;

    invoke-direct {v1}, Ljava/lang/Object;-><init>()V

    const-string v2, "addon@darkreader.org"

    const-string v3, "resource://android/assets/extensions/darkreader/"

    invoke-interface {p0, v2, v3, v0, v1}, Lmozilla/components/concept/engine/webextension/WebExtensionRuntime;->installBuiltInWebExtension(Ljava/lang/String;Ljava/lang/String;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function1;)V

    new-instance v0, Lmozilla/components/support/webextensions/BuiltInWebExtensionController$$ExternalSyntheticLambda2;

    invoke-direct {v0}, Ljava/lang/Object;-><init>()V

    new-instance v1, Lmozilla/components/support/webextensions/BuiltInWebExtensionController$$ExternalSyntheticLambda3;

    invoke-direct {v1}, Ljava/lang/Object;-><init>()V

    const-string v2, "jid1-KtlZuoiikVfFew@jetpack"

    const-string v3, "resource://android/assets/extensions/librejs/"

    invoke-interface {p0, v2, v3, v0, v1}, Lmozilla/components/concept/engine/webextension/WebExtensionRuntime;->installBuiltInWebExtension(Ljava/lang/String;Ljava/lang/String;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function1;)V

    return-void
.end method
