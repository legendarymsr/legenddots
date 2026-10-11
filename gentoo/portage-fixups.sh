# shellcheck shell=bash
# Shared by setup (root = "") and resume.sh (root = /mnt/gentoo).
# Hand-applied fixes, kept idempotent for existing installs:
# VIDEO_CARDS "intel" only (Haswell uses crocus, not iris); dedupe the llvm
# package.use; pyqt6 webchannel in xlibs (never qtbase -opengl, qtwebengine
# needs opengl); overlay metadata so portage stops warning about masters.
portage_fixups() {
  local root="${1:-}" p="${1:-}/etc/portage" r d f
  if [[ -f $p/make.conf ]]; then
    if grep -q '^VIDEO_CARDS=' "$p/make.conf"; then
      sed -i 's/^VIDEO_CARDS=.*/VIDEO_CARDS="intel"/' "$p/make.conf"
    else
      echo 'VIDEO_CARDS="intel"' >> "$p/make.conf"
    fi
  fi
  if [[ -f $p/package.use/llvm ]]; then
    awk '/^[[:space:]]*(#|$)/ || !seen[$0]++' "$p/package.use/llvm" > "$p/package.use/llvm.new" \
      && mv "$p/package.use/llvm.new" "$p/package.use/llvm"
  fi
  if [[ -f $p/package.use/xlibs ]]; then
    sed -i '/^dev-qt\/qtbase .*-opengl/d' "$p/package.use/xlibs"
    grep -q '^dev-python/pyqt6 .*webchannel' "$p/package.use/xlibs" \
      || echo 'dev-python/pyqt6 webchannel' >> "$p/package.use/xlibs"
  fi
  for r in icecat parona-overlay; do
    d="$root/var/db/repos/$r"
    [[ -d $d ]] || continue
    mkdir -p "$d/metadata" "$d/profiles"
    f="$d/metadata/layout.conf"
    if ! grep -qx 'masters = gentoo' "$f" 2>/dev/null; then
      [[ -f $f ]] && sed -i '/^masters[[:space:]]*=/d' "$f"
      echo 'masters = gentoo' >> "$f"
    fi
    [[ -s $d/profiles/repo_name ]] || echo "$r" > "$d/profiles/repo_name"
    # Sync resets the checkout, so also pin masters in repos.conf (survives sync).
    # Only touch a repos.conf entry that already exists for this location.
    for f in "$p"/repos.conf "$p"/repos.conf/*.conf; do
      [[ -f $f ]] || continue
      grep -q "^location[[:space:]]*=[[:space:]]*/var/db/repos/$r/*$" "$f" || continue
      # Simple, idempotent: if that section lacks a masters line, add one after its location line.
      awk -v loc="/var/db/repos/$r" '
        /^\[/ { sec++ }
        { line[NR]=$0; s[NR]=sec
          if ($0 ~ "^location[[:space:]]*=[[:space:]]*" loc "/*$") { tgt=sec; at=NR }
          if ($0 ~ /^masters[[:space:]]*=/) hasm[sec]=1 }
        END { for (i=1;i<=NR;i++) { print line[i]; if (i==at && !hasm[tgt]) print "masters = gentoo" } }
      ' "$f" > "$f.new" && mv "$f.new" "$f"
    done
  done
}
