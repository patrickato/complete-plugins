#!/bin/sh
# BadHID NG - uninstaller. Run on your Pwnagotchi as root.
#
#   sudo sh uninstall.sh            # remove plugin + tools, tear gadget down
#   sudo sh uninstall.sh --purge    # also remove payloads + token + config block
#
# It removes the plugin file, tears down the runtime USB gadget, and (with
# --purge) removes the badhid home dir and the [main.plugins.badhid_ng] config
# block. It does NOT revert the dwc2 config.txt change - run
# /etc/pwnagotchi/badhid_ng/enable_dwc2.sh --revert && reboot for that (kept
# separate because other things could rely on gadget mode).
set -eu

CONFIG="${CONFIG:-/etc/pwnagotchi/config.toml}"
HOME_DIR="/etc/pwnagotchi/badhid_ng"
SECTION="main.plugins.badhid_ng"
PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo sh uninstall.sh)"; exit 1; }

# tear down the runtime gadget if the tool is present
if [ -x "$HOME_DIR/setup_composite_gadget.sh" ]; then
  "$HOME_DIR/setup_composite_gadget.sh" --teardown 2>/dev/null || true
fi

# find + remove the plugin file
PLUGDIR="$(sed -n 's/^[[:space:]]*main\.custom_plugins[[:space:]]*=[[:space:]]*"\{0,1\}\([^"#]*[^"# ]\)"\{0,1\}.*/\1/p' "$CONFIG" | head -1)"
[ -n "${PLUGDIR:-}" ] || PLUGDIR="/etc/pwnagotchi/custom-plugins/"
PLUGDIR="${PLUGDIR%/}"
rm -f "$PLUGDIR/badhid_ng.py" && echo "removed $PLUGDIR/badhid_ng.py"

if [ "$PURGE" = "1" ]; then
  # remove the config block (from the section header to the next blank line / section)
  if grep -q "^\[$SECTION\]" "$CONFIG"; then
    cp -a "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
    awk -v sec="[$SECTION]" '
      $0==sec {skip=1; next}
      skip==1 && (/^\[/ ) {skip=0}
      skip==1 && NF==0 {skip=0; next}
      skip!=1 {print}
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    echo "removed [$SECTION] from $CONFIG (backed up first)"
  fi
  rm -rf "$HOME_DIR" && echo "removed $HOME_DIR"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl restart pwnagotchi 2>/dev/null && echo "restarted pwnagotchi" || true
fi
echo "Done. (dwc2 gadget mode in config.txt is left as-is; a reboot clears the"
echo "runtime gadget, and enable_dwc2.sh --revert undoes the overlay if you want.)"
