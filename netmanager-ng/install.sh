#!/bin/sh
# NetManager NG - installer for Pwnagotchi (Jayofelony 64-bit).
#
# A phone-friendly "Network Manager" page for a pwnagotchi you OWN: a searchable,
# 50+-scale list of the networks/targets you work with (wifi you join, fleet
# agents, wifi attack targets), with add / edit / delete, a current / selected
# marker, a per-row Fire Test, bulk import, and an OPTIONAL authorized-target
# capture backend. Run it on your Pwnagotchi, as root. Two ways:
#
#   One-liner:
#     curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/netmanager-ng/install.sh | sudo sh
#
#   From a local checkout of this folder:
#     sudo sh install.sh
#
# What it does (the SAFE part - nothing serves until you turn it on):
#   * installs netmanager_ng.py into your plugin directory,
#   * drops the helpers (netmanager_phone.sh = QR, netmanagerctl.sh = authorize,
#     netmanager_wifi_probe.sh = find a capture adapter) into
#     /etc/pwnagotchi/netmanager_ng/,
#   * adds a [main.plugins.netmanager_ng] section with a freshly generated random
#     auth_token, enabled=false, authorized_targets=[] (empty GATE), and the
#     capture backend OFF - never clobbering settings you've already set,
#   * validates config.toml still parses (auto-rollback if not).
# It does NOT enable the plugin, authorize any target, or turn on the capture
# backend. Out of the box it serves nothing. See README.md.
#
# Env overrides (optional):
#   RAW_BASE=<url>   where to download from (default: this plugin on GitHub 'main')
#   CONFIG=<path>    config.toml path (default: /etc/pwnagotchi/config.toml)
set -eu

RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/patrickato/complete-plugins/main/netmanager-ng}"
CONFIG="${CONFIG:-/etc/pwnagotchi/config.toml}"
PLUGIN="netmanager_ng.py"
SECTION="main.plugins.netmanager_ng"
HOME_DIR="/etc/pwnagotchi/netmanager_ng"
TOOLS="netmanager_phone.sh netmanagerctl.sh netmanager_wifi_probe.sh"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "please run as root (sudo sh install.sh, or pipe the one-liner to 'sudo sh')"
[ -f "$CONFIG" ] || die "config not found at $CONFIG (set CONFIG=/path/to/config.toml)"

HERE=""
if [ -n "${0:-}" ] && [ -f "$(dirname "$0")/$PLUGIN" ]; then HERE="$(cd "$(dirname "$0")" && pwd)"; fi

fetch() {  # fetch <relative-path> <dest>
  rel="$1"; dst="$2"
  if [ -n "$HERE" ] && [ -f "$HERE/$rel" ]; then
    cp "$HERE/$rel" "$dst"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dst" "$RAW_BASE/$rel" || die "download failed: $rel"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dst" "$RAW_BASE/$rel" || die "download failed: $rel"
  else
    die "need curl or wget to download (or run from a local checkout)"
  fi
}

gen_token() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets;print(secrets.token_urlsafe(24))" && return
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '/+=' | cut -c1-24 && return
  fi
  head -c 18 /dev/urandom | base64 | tr -d '/+=\n' | cut -c1-24
}

# --- plugin directory (from config custom_plugins, else Jayofelony default) ---
PLUGDIR="$(sed -n 's/^[[:space:]]*main\.custom_plugins[[:space:]]*=[[:space:]]*"\{0,1\}\([^"#]*[^"# ]\)"\{0,1\}.*/\1/p' "$CONFIG" | head -1)"
[ -n "${PLUGDIR:-}" ] || PLUGDIR="/etc/pwnagotchi/custom-plugins/"
PLUGDIR="${PLUGDIR%/}"
mkdir -p "$PLUGDIR" "$HOME_DIR"
say "plugin directory : $PLUGDIR"
say "netmanager home  : $HOME_DIR"

# --- install the plugin (syntax-checked, backed up) ---
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
fetch "$PLUGIN" "$TMP"
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$TMP" \
    || die "plugin failed a syntax check; not installing"
fi
grep -q "class NetManagerNG" "$TMP" || die "that doesn't look like the NetManager NG plugin; not installing"
if [ -f "$PLUGDIR/$PLUGIN" ]; then
  cp -a "$PLUGDIR/$PLUGIN" "$PLUGDIR/$PLUGIN.bak.$(date +%Y%m%d-%H%M%S)"
  say "backed up existing plugin"
fi
install -m 0644 "$TMP" "$PLUGDIR/$PLUGIN"
VER="$(sed -n 's/.*__version__ = "\([^"]*\)".*/\1/p' "$PLUGDIR/$PLUGIN" | head -1)"
say "installed $PLUGIN (version ${VER:-unknown})"

# --- helper tools ---
for t in $TOOLS; do fetch "$t" "$HOME_DIR/$t"; done
chmod +x "$HOME_DIR/netmanager_phone.sh" "$HOME_DIR/netmanagerctl.sh" "$HOME_DIR/netmanager_wifi_probe.sh" 2>/dev/null || true
say "installed helpers -> $HOME_DIR  (netmanager_phone.sh, netmanagerctl.sh, netmanager_wifi_probe.sh)"

# --- config section (only if not already present) ---
if grep -q "^\[$SECTION\]" "$CONFIG"; then
  say "config already has [$SECTION] - leaving your settings untouched"
else
  cp -a "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
  TOKEN="$(gen_token)"
  [ -n "$TOKEN" ] || die "couldn't generate a token"
  printf '%s\n' "$TOKEN" > "$HOME_DIR/auth_token.txt"; chmod 600 "$HOME_DIR/auth_token.txt"
  {
    printf '\n# NetManager NG (added by install.sh %s)\n' "$(date -Iseconds 2>/dev/null || date)"
    printf '[%s]\n' "$SECTION"
    printf 'enabled = false\n'
    printf 'auth_token = "%s"\n' "$TOKEN"
    printf 'bind_scope = "auto"\n'
    printf 'port = 8085\n'
    printf 'store_path = "%s/networks.json"\n' "$HOME_DIR"
    printf 'fire_timeout_seconds = 10\n'
    printf 'handshakes_dir = "/etc/pwnagotchi/handshakes"\n'
    printf 'fleet_json_path = "/home/pi/.config/fleetctl/fleet.json"\n'
    printf '# >>> THE GATE: empty = nothing can be fired at. Authorize with:\n'
    printf '#     sudo %s/netmanagerctl.sh authorize <BSSID|SSID>\n' "$HOME_DIR"
    printf 'authorized_targets = []\n'
    printf '# Optional capture backend - OFF. Needs a 2nd monitor-mode USB adapter.\n'
    printf '#   find one: sudo %s/netmanager_wifi_probe.sh\n' "$HOME_DIR"
    printf 'capture_backend_enabled = false\n'
    printf 'capture_iface = ""\n'
    printf 'capture_seconds = 25\n'
    printf 'deauth_count = 0\n'
    printf 'capture_out_dir = ""\n'
    printf 'builtin_ifaces = ["wlan0", "wlan0mon", "mon0"]\n'
    printf 'ui_enabled = true\n'
    printf 'ui_position_x = -40\n'
    printf 'ui_position_y = 30\n'
  } >> "$CONFIG"
  say "added [$SECTION] to $CONFIG (backed up first; token saved to $HOME_DIR/auth_token.txt)"
fi

# --- validate config parses; auto-rollback if we just appended and broke it ---
if command -v python3 >/dev/null 2>&1; then
  python3 - "$CONFIG" <<'PY' || { LASTBAK="$(ls -1t "$CONFIG".bak.* 2>/dev/null | head -1)"; [ -n "$LASTBAK" ] && cp -a "$LASTBAK" "$CONFIG" && echo "config did not parse - rolled back from $LASTBAK"; exit 1; }
import sys
try:
    import tomllib
    tomllib.load(open(sys.argv[1], "rb"))
except ModuleNotFoundError:
    sys.exit(0)
except Exception as e:
    print("parse error:", e); sys.exit(1)
print("config.toml parses OK")
PY
fi

BOARD="$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo 'your Pi')"
say ""
say "=============================================================="
say " FILES INSTALLED (safe state - the page is NOT serving yet)."
say " Board: $BOARD"
say ""
say " 1) Turn it on + make it phone-reachable, no nano:"
say "    sudo sed -i '/^\\[$SECTION\\]/,/^\\[/ s/^enabled = false/enabled = true/' $CONFIG"
say "    sudo sed -i '/^\\[$SECTION\\]/,/^\\[/ s/^bind_scope = \"auto\"/bind_scope = \"lan\"/' $CONFIG"
say "    sudo systemctl restart pwnagotchi && sleep 12"
say ""
say " 2) Open it on your phone (scannable QR, token baked in):"
say "    sudo $HOME_DIR/netmanager_phone.sh"
say ""
say " 3) In the page: tap 'Bulk import' to pull your networks in one tap."
say ""
say " Authorize a wifi_target to test (one command, no TOML editing):"
say "    sudo $HOME_DIR/netmanagerctl.sh authorize <BSSID|SSID>   # only networks you're allowed to test"
say "    sudo $HOME_DIR/netmanagerctl.sh list"
say ""
say " (Optional) real capture backend - needs a 2nd monitor-mode USB adapter:"
say "    sudo $HOME_DIR/netmanager_wifi_probe.sh    # find a capture_iface, then set it + capture_backend_enabled=true"
say ""
say " Full undo:  sudo sh uninstall.sh --purge"
say " NOTE: for networks you OWN or are AUTHORIZED to test. Every fire is logged."
say "=============================================================="
