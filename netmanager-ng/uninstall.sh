#!/bin/sh
# NetManager NG - uninstaller. Run on your Pwnagotchi as root.
#
#   sudo sh uninstall.sh            # remove plugin + helper tools (keep config/token/list)
#   sudo sh uninstall.sh --purge    # also remove the home dir + the config block
#
# Removes the plugin file and the helper tools. With --purge it also removes
# /etc/pwnagotchi/netmanager_ng/ (token, your networks.json list, helpers) and
# the whole [main.plugins.netmanager_ng] config block.
set -eu

CONFIG="${CONFIG:-/etc/pwnagotchi/config.toml}"
HOME_DIR="/etc/pwnagotchi/netmanager_ng"
SECTION="main.plugins.netmanager_ng"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo sh uninstall.sh)"; exit 1; }

# find + remove the plugin file
PLUGDIR="$(sed -n 's/^[[:space:]]*main\.custom_plugins[[:space:]]*=[[:space:]]*"\{0,1\}\([^"#]*[^"# ]\)"\{0,1\}.*/\1/p' "$CONFIG" | head -1)"
[ -n "${PLUGDIR:-}" ] || PLUGDIR="/etc/pwnagotchi/custom-plugins/"
PLUGDIR="${PLUGDIR%/}"
rm -f "$PLUGDIR/netmanager_ng.py" && echo "removed $PLUGDIR/netmanager_ng.py"

if [ "$PURGE" = "1" ]; then
  # remove the config block up to the next [section]. netmanager_ng has no TOML
  # sub-tables, so a single flat block, but the awk is sub-table-safe anyway.
  if grep -q "^\[$SECTION\]" "$CONFIG"; then
    cp -a "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
    awk '
      /^\[main\.plugins\.netmanager_ng(\.|\])/ { skip=1; next }
      skip==1 && /^\[/ { skip=0 }
      skip!=1 { print }
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    echo "removed [$SECTION] from $CONFIG (backed up first)"
  fi
  rm -rf "$HOME_DIR" && echo "removed $HOME_DIR (token, networks.json, helpers)"
else
  # non-purge: drop the helper tools, keep config + token + networks.json
  rm -f "$HOME_DIR/netmanager_phone.sh" "$HOME_DIR/netmanagerctl.sh" "$HOME_DIR/netmanager_wifi_probe.sh" 2>/dev/null || true
  echo "removed helper tools from $HOME_DIR (config + token + networks.json kept; --purge to remove those too)"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl restart pwnagotchi 2>/dev/null && echo "restarted pwnagotchi" || true
fi
echo "Done."
