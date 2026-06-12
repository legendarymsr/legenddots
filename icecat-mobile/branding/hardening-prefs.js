// IceCat hardening prefs (Arkenfox/Mull/Tor-Browser inspired).
//
// scripts/rebrand-apk.sh appends this file to GeckoView's bundled
// defaults/pref/<abi>/geckoview-prefs.js inside assets/omni.ja when
// ENABLE_HARDENING=true (config/branding.env). These only change *default*
// values on top of Fennec F-Droid's own defaults (telemetry already off,
// EME/DRM off, crash reporting off, etc.) — every pref below is unlocked,
// so it can still be flipped at runtime via about:config if it causes
// trouble on a particular site.

// --- Tracking protection: Firefox's strictest built-in tier ------------
pref("browser.contentblocking.category", "strict");
pref("privacy.trackingprotection.enabled", true);
pref("privacy.trackingprotection.socialtracking.enabled", true);
pref("privacy.trackingprotection.cryptomining.enabled", true);
pref("privacy.trackingprotection.fingerprinting.enabled", true);

// --- Fingerprinting resistance (Tor Browser/Mull style) ------------------
// Normalizes timezone, screen/window size, canvas/WebGL readback, fonts,
// hardware concurrency, etc. Can break some sites, and spoofs
// Accept-Language/UI strings to en-US for non-English locales. Disable
// per-site via the shield icon, or set to false in about:config to turn
// off globally.
pref("privacy.resistFingerprinting", true);

// --- Opt-out signals sent to sites ----------------------------------------
pref("privacy.donottrackheader.enabled", true);
pref("privacy.globalprivacycontrol.enabled", true);

// --- Trim remaining fingerprinting/tracking surface -----------------------
pref("dom.battery.enabled", false);
pref("beacon.enabled", false);
pref("browser.send_pings", false);

// --- Transport security ----------------------------------------------------
pref("dom.security.https_only_mode", true);

// --- Reduce remote experiments/telemetry beyond Fennec F-Droid's defaults --
pref("app.shield.optoutstudies.enabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);

// --- Sane default: block autoplaying media with sound -----------------------
pref("media.autoplay.default", 1);

// --- Anti-phishing: show IDNs as punycode (xn--...) ------------------------
// Stops a domain that mixes scripts to imitate a trusted site (e.g.
// Cyrillic "а" for Latin "a") from hiding behind a convincing native-script
// label in the address bar. Trade-off: legitimate non-Latin domains will
// also display as punycode.
pref("network.IDN_show_punycode", true);

// --- DNS over HTTPS ----------------------------------------------------------
// "Increased" mode: try DoH first, fall back to the system resolver only if
// DoH fails or is unavailable, so DNS lookups aren't plaintext on the
// network path.
pref("network.trr.mode", 2);
pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");

// --- Reduce notification-permission prompts ---------------------------------
// New sites are denied notification permission by default instead of
// prompting; users can still allow individual sites from their
// site-permissions page.
pref("permissions.default.desktop-notification", 2);

// --- Don't offer to save/autofill payment card details ----------------------
pref("extensions.formautofill.creditCards.enabled", false);

// --- Don't store form-fill history or autofill addresses ---------------------
// Pairs with the credit-card setting above: nothing typed into forms (search
// boxes, signup fields, shipping addresses, etc.) is remembered for autofill
// suggestions.
pref("browser.formfill.enable", false);
pref("extensions.formautofill.addresses.enabled", false);

// --- WebRTC: hide local network IPs from peers -------------------------------
// Keeps WebRTC working for video/voice calls, but stops it from leaking
// local-network IP addresses (and host candidates) to remote peers via ICE.
pref("media.peerconnection.ice.default_address_only", true);
pref("media.peerconnection.ice.no_host", true);

// --- De-Google the downloads Safe Browsing check ------------------------------
// Stops Firefox from sending hashes of downloaded files to Google Safe
// Browsing. URL-based phishing/malware blocklists (privacy-preserving local
// hash-prefix lookups) are left enabled.
pref("browser.safebrowsing.downloads.remote.enabled", false);

// --- Force dark color scheme for web content ----------------------------------
// Tells every site `prefers-color-scheme: dark`, so sites with a dark theme
// use it regardless of system theme. Sites without a dark theme are
// unaffected (full force-dark recoloring of any page needs an extension like
// Dark Reader - see README's "Recommended add-ons"). Set to 3 in about:config
// to follow the browser theme instead, or 1 to force light.
pref("layout.css.prefers-color-scheme.content-override", 0);
