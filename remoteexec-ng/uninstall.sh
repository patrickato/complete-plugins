#!/bin/sh
# RemoteExec NG - uninstaller. Run on your Pwnagotchi as root.
#
#   sudo sh uninstall.sh            # remove plugin + controller tools
#   sudo sh uninstall.sh --purge    # also remove the home dir + config block
#
# Removes the plugin file and the controller tools. With --purge it also removes
# /etc/pwnagotchi/remoteexec_ng/ (token, audit log, fleetctl) and the whole
# [main.plugins.remoteexec_ng] config block INCLUDING its .tasks sub-table.
set -eu

CONFIG="${CONFIG:-/etc/pwnagotchi/config.toml}"
HOME_DIR="/etc/pwnagotchi/remoteexec_ng"
SECTION="main.plugins.remoteexec_ng"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo sh uninstall.sh)"; exit 1; }

# find + remove the plugin file
PLUGDIR="$(sed -n 's/^[[:space:]]*main\.custom_plugins[[:space:]]*=[[:space:]]*"\{0,1\}\([^"#]*[^"# ]\)"\{0,1\}.*/\1/p' "$CONFIG" | head -1)"
[ -n "${PLUGDIR:-}" ] || PLUGDIR="/etc/pwnagotchi/custom-plugins/"
PLUGDIR="${PLUGDIR%/}"
rm -f "$PLUGDIR/remoteexec_ng.py" && echo "removed $PLUGDIR/remoteexec_ng.py"

if [ "$PURGE" = "1" ]; then
  # remove the config block AND its .tasks sub-table (anything whose header
  # starts with [main.plugins.remoteexec_ng] or [main.plugins.remoteexec_ng.*),
  # up to the next unrelated [section]. Does not stop at blank lines.
  if grep -q "^\[$SECTION\]" "$CONFIG"; then
    cp -a "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
    awk '
      /^\[main\.plugins\.remoteexec_ng(\.|\])/ { skip=1; next }
      skip==1 && /^\[/ { skip=0 }
      skip!=1 { print }
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    echo "removed [$SECTION] (and its .tasks sub-table) from $CONFIG (backed up first)"
  fi
  rm -rf "$HOME_DIR" && echo "removed $HOME_DIR"
else
  # non-purge: just drop the controller tools, keep config + token
  rm -f "$HOME_DIR/fleetctl.py" "$HOME_DIR/remoteexecctl.sh" "$HOME_DIR/fleet.json.example" 2>/dev/null || true
  echo "removed controller tools from $HOME_DIR (config + token kept; --purge to remove those too)"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl restart pwnagotchi 2>/dev/null && echo "restarted pwnagotchi" || true
fi
echo "Done."
