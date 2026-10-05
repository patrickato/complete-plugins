#!/bin/sh
# RemoteExec NG - installer for Pwnagotchi (Jayofelony 64-bit).
#
# Installs the remote-exec AGENT (a token-gated command API, the agent side of
# the fleet layer) and the companion CONTROLLER tools (fleetctl.py +
# remoteexecctl.sh). Run it on your Pwnagotchi, as root. Two ways:
#
#   One-liner:
#     curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/remoteexec-ng/install.sh | sudo sh
#
#   From a local checkout of this folder:
#     sudo sh install.sh
#
# What it does (the SAFE part - nothing runs until you turn it on):
#   * installs remoteexec_ng.py into your plugin directory,
#   * drops fleetctl.py + remoteexecctl.sh into /etc/pwnagotchi/remoteexec_ng/,
#   * adds a [main.plugins.remoteexec_ng] section with a freshly generated
#     random auth_token, enabled=false, command_mode="tasks",
#     allow_free_mode=false (never clobbering settings you've set),
#   * validates config.toml still parses (auto-rollback if not).
# It does NOT enable the agent, open free mode, or widen bind_scope. Out of the
# box the agent runs NOTHING; once enabled it runs only the 5 read-only
# diagnostic tasks. See README.md.
#
# Env overrides (optional):
#   RAW_BASE=<url>   where to download from (default: this plugin on GitHub 'main')
#   CONFIG=<path>    config.toml path (default: /etc/pwnagotchi/config.toml)
set -eu

RAW_BASE="${RAW_BASE:-https://raw.githubusercontent.com/patrickato/complete-plugins/main/remoteexec-ng}"
CONFIG="${CONFIG:-/etc/pwnagotchi/config.toml}"
PLUGIN="remoteexec_ng.py"
SECTION="main.plugins.remoteexec_ng"
HOME_DIR="/etc/pwnagotchi/remoteexec_ng"
TOOLS="remoteexecctl.sh fleetctl.py fleet.json.example"

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
say "remoteexec home  : $HOME_DIR"

# --- install the plugin (syntax-checked, backed up) ---
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
fetch "$PLUGIN" "$TMP"
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$TMP" \
    || die "plugin failed a syntax check; not installing"
fi
grep -q "class RemoteExecNG" "$TMP" || die "that doesn't look like the RemoteExec NG plugin; not installing"
if [ -f "$PLUGDIR/$PLUGIN" ]; then
  cp -a "$PLUGDIR/$PLUGIN" "$PLUGDIR/$PLUGIN.bak.$(date +%Y%m%d-%H%M%S)"
  say "backed up existing plugin"
fi
install -m 0644 "$TMP" "$PLUGDIR/$PLUGIN"
VER="$(sed -n 's/.*__version__ = "\([^"]*\)".*/\1/p' "$PLUGDIR/$PLUGIN" | head -1)"
say "installed $PLUGIN (version ${VER:-unknown})"

# --- controller tools ---
for t in $TOOLS; do fetch "$t" "$HOME_DIR/$t"; done
chmod +x "$HOME_DIR/remoteexecctl.sh" "$HOME_DIR/fleetctl.py" 2>/dev/null || true
say "installed controller tools -> $HOME_DIR  (fleetctl.py, remoteexecctl.sh)"

# --- config section (only if not already present) ---
if grep -q "^\[$SECTION\]" "$CONFIG"; then
  say "config already has [$SECTION] - leaving your settings untouched"
else
  cp -a "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
  TOKEN="$(gen_token)"
  [ -n "$TOKEN" ] || die "couldn't generate a token"
  printf '%s\n' "$TOKEN" > "$HOME_DIR/auth_token.txt"; chmod 600 "$HOME_DIR/auth_token.txt"
  {
    printf '\n# RemoteExec NG (added by install.sh %s)\n' "$(date -Iseconds 2>/dev/null || date)"
    printf '# Scalars first, [.tasks] sub-table LAST (TOML requirement).\n'
    printf '[%s]\n' "$SECTION"
    printf 'enabled = false\n'
    printf 'auth_token = "%s"\n' "$TOKEN"
    printf 'bind_scope = "auto"\n'
    printf 'port = 8084\n'
    printf 'command_mode = "tasks"\n'
    printf 'allow_free_mode = false\n'
    printf 'command_timeout_seconds = 30\n'
    printf 'max_output_chars = 20000\n'
    printf 'audit_log = "%s/audit.log"\n' "$HOME_DIR"
    printf 'ui_enabled = true\n'
    printf 'ui_position_x = -40\n'
    printf 'ui_position_y = 20\n'
    printf '\n'
    printf '[%s.tasks]\n' "$SECTION"
    printf 'uptime = "uptime"\n'
    printf 'status = "systemctl is-active pwnagotchi"\n'
    printf 'disk = "df -h /"\n'
    printf 'temp = "vcgencmd measure_temp"\n'
    printf 'ip = "hostname -I"\n'
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
say " FILES INSTALLED (safe state - the agent is NOT running yet)."
say " Board: $BOARD"
say ""
say " Turn the agent on (read-only diagnostic tasks only), no nano:"
say "   sudo sed -i '/^\\[$SECTION\\]/,/^\\[/ s/^enabled = false/enabled = true/' $CONFIG"
say "   sudo systemctl restart pwnagotchi"
say ""
say " Smoke test from the pi:"
say "   sudo $HOME_DIR/remoteexecctl.sh tasks        # list the allowed tasks"
say "   sudo $HOME_DIR/remoteexecctl.sh run uptime   # run one"
say ""
say " Drive it (and BadHID) across a fleet with the controller:"
say "   python3 $HOME_DIR/fleetctl.py enroll <label> http://<pi>:8084 <token>"
say "   python3 $HOME_DIR/fleetctl.py run uptime --all"
say ""
say " It stays in tasks mode unless you set BOTH command_mode=\"free\" AND"
say " allow_free_mode=true. To reach it from another machine, widen bind_scope"
say " (Tailscale preferred). Full undo:  sudo sh uninstall.sh --purge"
say " NOTE: for devices you own or are authorized to test. Every run is logged."
say "=============================================================="
