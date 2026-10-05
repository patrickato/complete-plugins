# NetManager NG (`netmanager_ng.py`)

A phone-friendly **Network Manager** page for a pwnagotchi **you own** — the
"command center" for the 50+ networks/targets you work with. One token-gated page
(same pattern as [BadHID NG](../badhid-ng)'s control page), backing a
**searchable list that scales to 50+** with add / edit / delete, a **current /
selected** marker, a per-row **Fire Test**, one-tap **bulk import**, and an
**optional authorized-target capture backend**.

A *network* is any target you track, of three **kinds** — the store holds all
three the same way; each kind's Fire Test does the right thing:

| Kind | what it is | Fire Test does | transmits? |
|---|---|---|---|
| **wifi I join** | a WiFi the pi connects to | "am I on this SSID right now?" (read-only) | no |
| **fleet** | an agent you enrolled (url + token) | reachability + auth probe to *your* agent | small HTTP request to your own agent |
| **wifi target** | a WiFi SSID/BSSID you're **authorized** to test | the allowlist **GATE** → (optional) real capture | only if you enable the capture backend |

> **Fire Test is a safe check, not an attack.** By default no kind transmits
> attack frames — the page *enforces authorization* and *checks* things. The real
> capture backend is **off by default** and only ever acts on a target that has
> already cleared the allowlist gate (see below).

**For networks you OWN or are AUTHORIZED to test.**

---

## Safety model (read this)

- **Ships `enabled = false`.** Nothing serves until you turn it on.
- **No working default token.** A blank / placeholder / <12-char `auth_token`
  means the server refuses to start. The installer generates a strong one. Every
  request is token-authed (Bearer / `X-Auth-Token` / `?token=`).
- **`bind_scope` never binds the open LAN by default** (`auto` → Tailscale if
  present, else localhost). The exact bound URL is logged.
- **The store is `0600`** (it can hold fleet tokens), written atomically.
- **`authorized_targets` is the non-negotiable GATE** (empty by default): a
  `wifi_target` fire is refused unless the target is explicitly listed. The web
  page can **never** edit the allowlist — authorization is a deliberate `sudo`
  action on the pi.
- **The capture backend is double-gated.** Even for an authorized target, it runs
  only when **both** `capture_backend_enabled = true` **and** `capture_iface`
  names a **second** adapter (it refuses the pwnagotchi radio). Deauth is **off**
  unless you set `deauth_count > 0`, is **targeted** at the one BSSID, and is
  **hard-capped at 64 frames** (a capture nudge, never a flood). Every fire is
  logged.

---

## Install (on the Pi) — pick any method

**Users love options.** All of these end in the same safe state: files installed,
a generated token, `enabled = false`, the gate empty, the capture backend off.

### 1. One-line installer (recommended — plug-and-play)
```bash
curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/netmanager-ng/install.sh | sudo sh
```

### 2. `wget` instead of `curl`
```bash
wget -qO- https://raw.githubusercontent.com/patrickato/complete-plugins/main/netmanager-ng/install.sh | sudo sh
```

### 3. Clone the repo, then run the installer locally
```bash
git clone https://github.com/patrickato/complete-plugins.git
sudo sh complete-plugins/netmanager-ng/install.sh
```

### 4. Drop-in file (no installer)
Copy `netmanager_ng.py` into your plugin directory (the `main.custom_plugins`
path in your config, default `/etc/pwnagotchi/custom-plugins/`), copy the helper
scripts into `/etc/pwnagotchi/netmanager_ng/`, then add the config block from
[`config.toml.example`](config.toml.example) to your `config.toml` and set a
token.

### 5. Fully manual
Everything method 4 does, by hand — see [`config.toml.example`](config.toml.example),
which documents every option and marks exactly what needs your input.

### 6. Jayofelony `custom_plugin_repos` archive method
Add this repo to `main.custom_plugin_repos` in your config and let pwnagotchi
fetch it, then enable `[main.plugins.netmanager_ng]` as below.

---

## Turn it on + open it on your phone

After installing, turn it on and make it phone-reachable (no nano):
```bash
sudo sed -i '/^\[main\.plugins\.netmanager_ng\]/,/^\[/ s/^enabled = false/enabled = true/' /etc/pwnagotchi/config.toml
sudo sed -i '/^\[main\.plugins\.netmanager_ng\]/,/^\[/ s/^bind_scope = "auto"/bind_scope = "lan"/' /etc/pwnagotchi/config.toml
sudo systemctl restart pwnagotchi && sleep 12
```
Then get a **scannable QR** with the token already in it:
```bash
sudo /etc/pwnagotchi/netmanager_ng/netmanager_phone.sh
```
Scan it, and hit **Bulk import** on the page to pull your networks in one tap.

---

## The page

Built so a brand-new user can land on it and go:

- A **"New here?"** panel explains the page and the three kinds in plain language.
- A **first-run welcome**: when the list is empty, the two **Bulk import** buttons
  lead (handshakes + fleet.json), so the no-typing path is obvious. It disappears
  once you have networks.
- A sticky **search box** + **kind filter** — built for 50+ entries.
- A **floating toast** reports every action right where you are on screen (tap
  Fire on row 40, the result pops at the bottom and stays). Successes
  auto-dismiss; errors/refusals stay until you close them.
- Each row: name, kind badge, key fields, a **• here** marker when it matches the
  WiFi you're on, a **✓ selected** marker, and **Select / Fire Test / Edit /
  Delete**. **Edit** opens the form pre-filled (you can even change the kind) and
  saves in place.
- Dependency-free vanilla JS, so it works on an offline pi.

### Bulk import (never hand-type 50)
Two buttons pull your networks in, additive + deduped:
- **Import wifi targets from handshakes** — turns each capture in your handshakes
  dir into a `wifi_target` row (SSID + BSSID, deduped by BSSID).
- **Import agents from fleet.json** — reads your fleetctl store and adds each
  agent as a `fleet` row (url + token, plus its BadHID endpoint if set).

---

## Authorizing a wifi_target (why a Fire Test says "REFUSED")

Intentional — it's the safety gate. A `wifi_target` fire is refused until that
network is on the `authorized_targets` allowlist, **empty by default**. The
refused toast hands you the exact command. Do it the easy way:

```bash
sudo /etc/pwnagotchi/netmanager_ng/netmanagerctl.sh authorize 00:11:22:33:44:55 MyLabAP
sudo /etc/pwnagotchi/netmanager_ng/netmanagerctl.sh list
sudo /etc/pwnagotchi/netmanager_ng/netmanagerctl.sh deauthorize MyLabAP
```
It edits only the netmanager section, dedups (BSSIDs match colon/case-insensitive),
backs up + validates your config (auto-rollback), and restarts pwnagotchi
(`NO_RESTART=1` to skip). Authorization stays in config on purpose — the page
never edits it. **Only add networks you own or are explicitly authorized to test.**

---

## Optional: the real capture backend

Once a target is authorized, netmanager can run the real handshake capture — the
same thing your pwnagotchi already does via bettercap, pointed at that one
authorized BSSID. **Off by default**, and it needs a **second monitor-mode USB
adapter** (your built-in radio is busy with pwnagotchi, so `capture_iface` can
never be `wlan0`/`wlan0mon`).

1. Find a capture adapter (read-only; changes nothing):
   ```bash
   sudo /etc/pwnagotchi/netmanager_ng/netmanager_wifi_probe.sh
   ```
   It lists every adapter, its chipset/driver, and which do monitor mode, and
   recommends a `capture_iface`.
2. Set `capture_backend_enabled = true` and `capture_iface = "wlan1"` (or whatever
   the probe recommends) in your config, then `sudo systemctl restart pwnagotchi`.
3. Fire Test an authorized `wifi_target`: it locks `airodump-ng` to that one BSSID
   for `capture_seconds`, optionally sends a bounded `deauth_count` deauth, and
   drops the capture into your handshakes dir — where netmanager re-imports it and
   crack-house can crack it.

Start with `deauth_count = 0` (passive, sends nothing). Raise it only against
targets you're allowed to test.

---

## Requirements & dependencies

- **Platform:** Jayofelony Pwnagotchi (64-bit), Pi 4 + 3.5" TFT reference; any
  pwnagotchi on this fork should work. Validated on a Pi 4 (Model B Rev 1.5).
- **Python:** 3 (stdlib only for the plugin core). The web server uses
  **Flask + werkzeug**, which ship with pwnagotchi.
- **For bulk import:** nothing extra — it reads files already on the pi.
- **QR helper (`netmanager_phone.sh`):** `qrencode` for the scannable QR (it
  prints the URL plainly and offers to install qrencode if it's missing).
- **Capture backend only (optional):** a **second monitor-mode USB adapter** and
  **`aircrack-ng`** (`sudo apt install -y aircrack-ng`), plus `iw`. Handshake
  detection uses `hcxpcapngtool` if present, else `aircrack-ng`.
- **Installer:** `curl` or `wget` (or run from a local checkout); `python3` for
  the token + config validation.

---

## Troubleshooting

- **Page won't load / "unauthorized".** The token in your link must match the
  config. Re-open the QR with `netmanager_phone.sh`, or check
  `/etc/pwnagotchi/netmanager_ng/auth_token.txt`.
- **Server didn't start.** Check `/etc/pwnagotchi/log/pwnagotchi.log` for
  `[netmanager_ng]` — a blank/short token or a `bind_scope="tailscale"` with no
  Tailscale will refuse to start (by design). The bound URL is logged on success.
- **Import says "can't read …".** The handshakes dir is auto-detected, but if
  your path is unusual, set `handshakes_dir` in the config.
- **Fire Test on a wifi_target says REFUSED.** Working as intended — authorize it
  with `netmanagerctl.sh authorize <BSSID|SSID>` (only if it's yours to test).
- **Capture backend does nothing / "no capture_iface".** It needs a second
  monitor-mode adapter named in `capture_iface` and `capture_backend_enabled=true`.
  Run `netmanager_wifi_probe.sh`. Power-hungry AC adapters want a bare USB-3 port.
- **Captured file named oddly.** The backend normalizes airodump's `-NN.cap` to
  pwnagotchi-style `<ssid>_<bssid>.cap` so the rest of your tools recognize it.

---

## Uninstall

```bash
sudo sh uninstall.sh           # remove plugin + helper tools (keep config/token/list)
sudo sh uninstall.sh --purge   # also remove the home dir + the whole config block
```

---

See **NOTES.md** for the full design/safety writeup, **CREDITS.md** for prior
art, and **CHANGELOG.md** for the release + hardware-pass record. The staging
history lives in `patrickato/plugins-wip` (`netmanager-suite`).
