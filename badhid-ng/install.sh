#!/bin/sh
# BadHID NG - installer for Pwnagotchi (Jayofelony 64-bit).
#
# Run it on your Pwnagotchi, as root. Two ways:
#
#   One-liner (downloads the plugin, payloads and setup tools):
#     curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/badhid-ng/install.sh | sudo sh
#
#   From a local checkout of this folder:
#     sudo sh install.sh
#
# What it does (the SAFE part - it does NOT touch your USB gadget or type
# anything): installs badhid_ng.py into your plugin directory, drops the 20
# demo payloads and the setup tools into /etc/pwnagotchi/badhid_ng/, adds a
# [main.plugins.badhid_ng] section with a freshly generated random auth_token
# and enabled=false (never clobbering settings you've set), and then prints the
# remaining one-time hardware steps (enable gadget mode, reboot, bring the
# keyboard gadget up, enable the plugin). Those can't be automated through a
# reboot, so they stay deliberate - see the printed steps and README.md.
#
# Env overrides (optional):
#   RAW_BASE=<url>   where to download from (default: this plugin on GitHub 'main')
#   CONFIG=<path>    config.toml path (default: /etc/pwnagotchi/config.toml)
set -eu

RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/patrickato/complete-plugins/main/badhid-ng}"
CONFIG="${CONFIG:-/etc/pwnagotchi/config.toml}"
PLUGIN="badhid_ng.py"
SECTION="main.plugins.badhid_ng"
HOME_DIR="/etc/pwnagotchi/badhid_ng"
PAYLOADS_DIR="$HOME_DIR/payloads"

PAYLOADS="ascii_cat.duck capslock_prank.duck fake_selfdestruct.duck fortune.duck ghost_typer.duck hacker_theater.duck haunted_browser.duck hello_world.duck i_see_you.duck keymap_test.duck loading_bar.duck open_calculator.duck redrum.duck rickroll.duck shell_netinfo.duck shell_whoami.duck shrug.duck spooky_skull.duck too_many_notepads.duck welcome.duck"
SCRIPTS="badhid_setup.sh badhid_phone.sh badhid_setopt.py enable_dwc2.sh setup_composite_gadget.sh badhid_doctor.sh badhidctl.sh badhid_sync.sh badhid_update.sh badhid_backup.sh badhid_restore.sh"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "please run as root (sudo sh install.sh, or pipe the one-liner to 'sudo sh')"
[ -f "$CONFIG" ] || die "config not found at $CONFIG (set CONFIG=/path/to/config.toml)"

# where this script lives, so a local checkout can copy instead of download
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
mkdir -p "$PLUGDIR" "$HOME_DIR" "$PAYLOADS_DIR"
say "plugin directory : $PLUGDIR"
say "badhid home      : $HOME_DIR"

# --- install the plugin (syntax-checked, backed up) ---
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
fetch "$PLUGIN" "$TMP"
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$TMP" \
    || die "plugin failed a syntax check; not installing"
fi
grep -q "class BadHIDNG" "$TMP" || die "that doesn't look like the BadHID NG plugin; not installing"
if [ -f "$PLUGDIR/$PLUGIN" ]; then
  cp -a "$PLUGDIR/$PLUGIN" "$PLUGDIR/$PLUGIN.bak.$(date +%Y%m%d-%H%M%S)"
  say "backed up existing plugin"
fi
install -m 0644 "$TMP" "$PLUGDIR/$PLUGIN"
VER="$(sed -n 's/.*__version__ = "\([^"]*\)".*/\1/p' "$PLUGDIR/$PLUGIN" | head -1)"
say "installed $PLUGIN (version ${VER:-unknown})"

# --- payloads ---
for p in $PAYLOADS; do fetch "payloads/$p" "$PAYLOADS_DIR/$p"; done
say "installed $(echo "$PAYLOADS" | wc -w) demo payloads -> $PAYLOADS_DIR"

# --- setup tools ---
for s in $SCRIPTS; do fetch "$s" "$HOME_DIR/$s"; chmod +x "$HOME_DIR/$s"; done
say "installed setup tools -> $HOME_DIR"

# --- config section (only if not already present) ---
if grep -q "^\[$SECTION\]" "$CONFIG" || grep -q "^[[:space:]]*$SECTION\.enabled" "$CONFIG"; then
  say "config already has [$SECTION] - leaving your settings untouched"
else
  cp -a "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
  TOKEN="$(gen_token)"
  [ -n "$TOKEN" ] || die "couldn't generate a token"
  printf '%s\n' "$TOKEN" > "$HOME_DIR/auth_token.txt"; chmod 600 "$HOME_DIR/auth_token.txt"
  {
    printf '\n# BadHID NG (added by install.sh %s)\n' "$(date -Iseconds 2>/dev/null || date)"
    printf '[%s]\n' "$SECTION"
    printf 'enabled = false\n'
    printf 'auth_token = "%s"\n' "$TOKEN"
    printf 'hid_device = "/dev/hidg0"\n'
    printf 'manage_gadget = false\n'
    printf 'bind_scope = "auto"\n'
    printf 'port = 8083\n'
    printf 'payloads_dir = "%s"\n' "$PAYLOADS_DIR"
    printf 'default_payload = "hello_world.duck"\n'
    printf 'authorized_targets = []\n'
    printf 'arm_window_seconds = 120\n'
    printf 'arm_one_shot = true\n'
    printf 'fire_on_enumerate = false\n'
    printf 'inter_key_delay_ms = 12\n'
    printf 'default_delay_ms = 0\n'
    printf 'modifier_settle_ms = 40\n'
    printf 'max_actions = 20000\n'
    printf 'write_timeout_seconds = 10\n'
    printf 'allow_quickfire = true\n'
    printf '# B3: let the fleet controller stage payloads here (path-safe, parse-validated).\n'
    printf 'allow_remote_stage = true\n'
    printf 'ui_enabled = true\n'
    printf 'ui_position_x = -55\n'
    printf 'ui_position_y = 10\n'
  } >> "$CONFIG"
  say "added [$SECTION] to $CONFIG (backed up first; token saved to $HOME_DIR/auth_token.txt)"
fi

BOARD="$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo 'your Pi')"
say ""
say "=============================================================="
say " FILES INSTALLED (nothing is running yet; gadget is NOT up)."
say " Board: $BOARD"
say ""
say " EASIEST: let the guided wizard finish the setup for you -"
say "   sudo $HOME_DIR/badhid_setup.sh"
say " It enables gadget mode, brings up the keyboard, turns the plugin on,"
say " offers phone access, and shows how to fire. It needs ONE reboot in the"
say " middle and is safe to re-run afterward."
say ""
say " ---- or do the one-time hardware setup by hand (see README.md) ----"
say "   1) sudo $HOME_DIR/enable_dwc2.sh      # put the USB port in gadget mode"
say "   2) sudo reboot                        # ethernet/wifi SSH survives"
say "   3) sudo $HOME_DIR/setup_composite_gadget.sh --hid-only   # make /dev/hidg0"
say "   4) sudo python3 $HOME_DIR/badhid_setopt.py $CONFIG enabled true"
say "      then: sudo systemctl restart pwnagotchi"
say ""
say " Then check everything and fire a demo:"
say "   sudo $HOME_DIR/badhid_doctor.sh"
say "   sudo $HOME_DIR/badhidctl.sh arm && sudo $HOME_DIR/badhidctl.sh fire hello_world.duck"
say ""
say " Fire from your phone (QR code):  sudo $HOME_DIR/badhid_phone.sh"
say " Full undo any time:             sudo $HOME_DIR/badhid_restore.sh"
say " NOTE: this is a lab tool for hardware you own or are authorized to test."
say "=============================================================="
