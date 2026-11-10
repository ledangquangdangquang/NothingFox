#!/usr/bin/env bash
# ============================================================
#  NothingFirefoxCss - Linux / macOS installer
#
#  Usage:
#    ./install.sh                     interactive: choose a profile
#    ./install.sh --all               install into every profile found
#    ./install.sh /path/to/profile    install into a specific profile
#    ./install.sh --uninstall [--all | /path/to/profile]
#
#  Supported Firefox locations:
#    ~/.mozilla/firefox                               (deb / rpm / tarball)
#    ~/.config/mozilla/firefox                        (XDG layout, newer Firefox)
#    ~/snap/firefox/common/.mozilla/firefox           (Snap)
#    ~/.var/app/org.mozilla.firefox/.mozilla/firefox  (Flatpak)
#    ~/Library/Application Support/Firefox            (macOS)
# ============================================================
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="install"
ALL=0
TARGET=""

if [ -t 1 ]; then
  C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_DIM=$'\e[2m'; C_RST=$'\e[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_RST=""
fi

die()  { echo "${C_ERR}[ERROR]${C_RST} $*" >&2; exit 1; }
warn() { echo "${C_WARN}[!]${C_RST} $*"; }

usage() {
  sed -n '4,10p' "$0" | sed 's/^#  \{0,1\}//'
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    -u|--uninstall) MODE="uninstall" ;;
    -a|--all)       ALL=1 ;;
    -h|--help)      usage ;;
    -*)             die "Unknown option: $1" ;;
    *)              TARGET="$1" ;;
  esac
  shift
done

echo
echo " ============================================="
echo "    NothingFirefoxCss - $MODE"
echo " ============================================="
echo

[ "$MODE" = "install" ] && [ ! -f "$SRC/userChrome.css" ] && die "userChrome.css not found in $SRC"

# ---------- warn if Firefox is running ----------
RESTART=0
if pgrep -x firefox >/dev/null 2>&1 || pgrep -x firefox-bin >/dev/null 2>&1 || pgrep -f 'firefox/firefox' >/dev/null 2>&1; then
  warn "Firefox is running. Changes only take effect after a restart."
  if [ -t 0 ]; then
    read -r -p "    Close Firefox now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      pkill -x firefox 2>/dev/null || true
      pkill -x firefox-bin 2>/dev/null || true
      sleep 2
      RESTART=1
    fi
  fi
  echo
fi

# ---------- helpers ----------
# set_pref <profile> <name> <js value>
set_pref() {
  local ujs="$1/user.js" name="$2" value="$3" tmp
  tmp="$(mktemp)"
  if [ -f "$ujs" ]; then
    grep -v -F "user_pref(\"$name\"" "$ujs" > "$tmp" || true
  fi
  printf 'user_pref("%s", %s);\n' "$name" "$value" >> "$tmp"
  cat "$tmp" > "$ujs"
  rm -f "$tmp"
}

do_install() {
  local p="$1" chrome="$1/chrome"
  echo " -> Installing into: $p"
  if [ -f "$chrome/userChrome.css" ]; then
    local backup="$p/chrome.backup-$(date +%Y%m%d-%H%M%S)"
    cp -r "$chrome" "$backup"
    echo "    Backed up existing chrome folder to: $backup"
  fi
  mkdir -p "$chrome"
  cp -f "$SRC/userChrome.css" "$chrome/userChrome.css"
  [ -f "$SRC/userContent.css" ] && cp -f "$SRC/userContent.css" "$chrome/userContent.css"
  echo "    Copied userChrome.css, userContent.css"
  set_pref "$p" "toolkit.legacyUserProfileCustomizations.stylesheets" "true"
  set_pref "$p" "browser.toolbars.bookmarks.visibility" '"always"'
  echo "    user.js prefs set"
  echo
}

do_uninstall() {
  local p="$1"
  echo " -> Uninstalling from: $p"
  rm -f "$p/chrome/userChrome.css" "$p/chrome/userContent.css"
  echo "    Removed userChrome.css, userContent.css"
  echo "    ${C_DIM}(Backups chrome.backup-* are kept; copy one back into \"chrome\" to restore.)${C_RST}"
  echo
}

finish() {
  echo "${C_OK}[OK]${C_RST} Done."
  if [ "$RESTART" = "1" ] && command -v firefox >/dev/null 2>&1; then
    nohup firefox >/dev/null 2>&1 &
  else
    echo "Restart Firefox to see the changes."
  fi
  echo
  exit 0
}

# ---------- explicit profile ----------
if [ -n "$TARGET" ]; then
  TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || die "Directory not found"
  [ -f "$TARGET/prefs.js" ] || [ -f "$TARGET/times.json" ] || die "\"$TARGET\" does not look like a Firefox profile."
  "do_$MODE" "$TARGET"
  finish
fi

# ---------- discover profiles ----------
ROOTS=(
  "$HOME/.mozilla/firefox"
  "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"
  "$HOME/snap/firefox/common/.mozilla/firefox"
  "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
  "$HOME/Library/Application Support/Firefox"
)

PROFILES=()
DEFAULTS=()
for root in "${ROOTS[@]}"; do
  [ -f "$root/profiles.ini" ] || continue
  # default profile of the current install (installs.ini / [Install...] section)
  def=""
  for ini in "$root/installs.ini" "$root/profiles.ini"; do
    [ -f "$ini" ] || continue
    def="$(awk -F= '/^\[Install/{f=1;next} /^\[/{f=0} f&&$1=="Default"{print $2; exit}' "$ini")"
    [ -n "$def" ] && break
  done
  # every Path= in profiles.ini
  while IFS='|' read -r rel path; do
    [ -n "$path" ] || continue
    if [ "$rel" = "0" ]; then full="$path"; else full="$root/$path"; fi
    [ -d "$full" ] || continue
    [ -f "$full/prefs.js" ] || [ -f "$full/times.json" ] || continue
    PROFILES+=("$full")
    if [ -n "$def" ] && [ "$path" = "$def" ]; then DEFAULTS+=(1); else DEFAULTS+=(0); fi
  done < <(awk -F= '
      /^\[Profile/ { if (p!="") print r "|" p; p=""; r="1"; inprof=1; next }
      /^\[/        { if (p!="") print r "|" p; p=""; inprof=0; next }
      inprof && $1=="Path"       { p=substr($0, index($0,"=")+1) }
      inprof && $1=="IsRelative" { r=$2 }
      END { if (p!="") print r "|" p }' "$root/profiles.ini")
done

[ ${#PROFILES[@]} -gt 0 ] || die "No Firefox profile found. Start Firefox once, or pass the profile path explicitly."

default_index=1
for i in "${!PROFILES[@]}"; do
  mark=""
  if [ "${DEFAULTS[$i]}" = "1" ]; then mark="  (default)"; default_index=$((i+1)); fi
  echo "  [$((i+1))] ${PROFILES[$i]}${mark}"
done

if [ "$ALL" = "1" ]; then
  echo
  for p in "${PROFILES[@]}"; do "do_$MODE" "$p"; done
  finish
fi

echo "  [A] All profiles"
echo
read -r -p "Choose a profile [default: $default_index]: " choice || true
choice="${choice:-$default_index}"
echo

if [[ "$choice" =~ ^[Aa]$ ]]; then
  for p in "${PROFILES[@]}"; do "do_$MODE" "$p"; done
elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#PROFILES[@]} ]; then
  "do_$MODE" "${PROFILES[$((choice-1))]}"
else
  die "Invalid choice: $choice"
fi
finish
