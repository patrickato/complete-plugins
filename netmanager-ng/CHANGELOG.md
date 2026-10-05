# Changelog

## 0.4.0

First release. A phone-friendly **Network Manager** page for a pwnagotchi you
own, plus an optional authorized-target **capture backend**. Validated live on a
Pi 4 (Model B Rev 1.5), Jayofelony 64-bit.

### What's in it

- **The page (`netmanager_ng.py`).** A token-gated Flask page backing a searchable
  50+-scale store of your networks/targets, three kinds (wifi I join / fleet /
  wifi target), with add / edit-in-place / delete, a current+selected marker, a
  per-row Fire Test, and bulk import (handshakes → wifi_target rows; fleetctl
  `fleet.json` → fleet rows, additive + deduped). Safe by default: ships
  `enabled=false`, refuses to start without a real ≥12-char token, `bind_scope`
  never opens the LAN by default, store 0600, every fire logged.
- **The three fires.** fleet = reachability+auth probe; wifi_join = read-only
  association check; wifi_target = the **authorized-target allowlist GATE**
  (empty by default), which the web page can never edit.
- **New-user UX.** A "New here?" help panel, a first-run welcome/empty-state that
  leads with bulk import, a floating toast that reports every action on-screen,
  and a refused-target message that hands you the exact authorize command.
- **The capture backend (optional, off by default).** A second switch on top of
  the allowlist: with `capture_backend_enabled=true` + a `capture_iface` second
  adapter, an authorized `wifi_target` Fire Test runs `airodump-ng` locked to the
  one BSSID (+ an optional bounded, targeted `aireplay-ng` deauth, hard-capped at
  64) and drops the handshake into your handshakes dir, normalized to
  pwnagotchi-style naming. Refuses the pwnagotchi radio; fails safe.
- **Helper scripts.**
  - `netmanager_phone.sh` — scannable QR with the token baked in.
  - `netmanagerctl.sh` — one-command `authorize`/`deauthorize`/`list` for the
    allowlist (section-scoped, deduped, config backed-up + validated with
    auto-rollback, restarts pwnagotchi). No TOML editing.
  - `netmanager_wifi_probe.sh` — read-only inventory of USB wifi adapters (driver,
    chipset, monitor capability) that recommends a `capture_iface` and excludes
    the pwnagotchi radio's chip.
- **Safe installer / uninstaller.** `install.sh` backs up, installs the plugin +
  helpers, adds the config block with a generated token (`enabled=false`, gate
  empty, backend off), and validates with auto-rollback. `uninstall.sh --purge`
  removes the plugin, the home dir, and the config block.

### Hardware pass

On-Pi: page served to a phone over LAN; 42 real `wifi_target` imports + fleet
import; search/select/edit/delete; the GATE refused then (after authorize)
passed. **Capture backend confirmed operational** on an Alfa AWUS036ACM
(MT7612U/mt76x2u) second adapter — set monitor mode, airodump locked to the
BSSID, captured a real 4-way handshake, wrote it normalized into the handshakes
dir. Deauth-assisted capture and multi-adapter field layout are supported and
documented; exercised per-deployment.
