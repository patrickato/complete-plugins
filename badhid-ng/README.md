# BadHID NG (`badhid_ng.py`)

Turn a gadget-capable Raspberry Pi into a **USB keyboard** that types a payload
*you* wrote — on demand, behind a token, with a loud log, a one-tap phone page,
and an on-screen status. A "BadUSB / BadHID" lab tool for Jayofelony Pwnagotchi,
for testing against **hardware you own or are authorized to test**.

New to this? Read **"How it works in one minute"**, then **Install**, then follow
the printed steps. `badhid_doctor.sh` holds your hand the whole way.

---

## How it works in one minute

- A Pi with a USB **device-capable** port can pretend to be a keyboard. When you
  plug that port into a computer, the computer thinks a keyboard was attached.
- This plugin reads a **payload** (a little script in DuckyScript syntax) and
  "types" it on that fake keyboard — into whatever window has focus.
- You control it from a **web page or a one-line command**, over your network
  (ethernet / Wi-Fi / Tailscale). So you can trigger it from your phone while
  the Pi is plugged into the target.
- It is **disarmed by default**. Nothing types until you **arm** it, and it
  re-locks itself after firing. Every arm and fire is logged.

Two honest limits up front (more in **Limitations**):
1. **Not every Pi can do this** — the USB port has to act as a *device*. Pi
   Zero/Zero 2 W, Pi 4, Pi 3A+ can; Pi 3B/3B+, Pi 400 can't. See
   **COMPATIBILITY.md**. `enable_dwc2.sh`/`badhid_doctor.sh` tell you which you
   have.
2. **A keyboard can't tell which computer it's plugged into.** The arm model and
   `authorized_targets` control *when* it fires and *log your intent*; they
   can't stop it typing into the wrong machine. The only real safeguard is
   **what you physically plug it into.**

It ships the framework + safety gates + **20 harmless demos** and **no** offensive
payloads. You write your own, for your own gear.

---

## Install

Everything runs on the Pi, and you stay reachable over ethernet/Wi-Fi the whole
time, so you can't lock yourself out.

**1. Install the files** (plugin + payloads + setup tools; adds a config block
with a random token and `enabled=false`; nothing runs yet):

```bash
curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/badhid-ng/install.sh | sudo sh
```
(or clone this repo and `sudo sh badhid-ng/install.sh`). The tools land in
`/etc/pwnagotchi/badhid_ng/`; your token is saved to
`/etc/pwnagotchi/badhid_ng/auth_token.txt`.

**2. One-time hardware setup** (the installer prints these too):
```bash
cd /etc/pwnagotchi/badhid_ng
sudo ./enable_dwc2.sh                      # put the USB port in gadget mode (board-aware)
sudo reboot                                # ethernet/wifi SSH survives it
# --- reconnect, then: ---
cd /etc/pwnagotchi/badhid_ng
sudo ./setup_composite_gadget.sh --hid-only   # creates /dev/hidg0
sudo ./badhid_doctor.sh                        # should be green except "enable the plugin"
```

**3. Enable the plugin:** open `/etc/pwnagotchi/config.toml`, find
`[main.plugins.badhid_ng]`, set `enabled = true`, then
`sudo systemctl restart pwnagotchi`.

**4. Fire a harmless demo** at the machine the Pi is plugged into:
```bash
sudo ./badhidctl.sh arm && sudo ./badhidctl.sh fire hello_world.duck
```

At any point, **`sudo ./badhid_doctor.sh`** prints exactly what to do next. To
update later, re-run the installer (or, from a clone, `sudo ./badhid_update.sh`).
Full undo: `sudo ./badhid_restore.sh` (or `sudo sh uninstall.sh --purge`).

> Not on a Pi 4? The same steps work on a Pi Zero/Zero 2 W or Pi 3A+ —
> `enable_dwc2.sh` auto-detects your board. On a Pi 3B/3B+/400 it tells you the
> board can't do HID and stops. See **COMPATIBILITY.md**.

---

## The helper scripts (what each one is for)

All live in `/etc/pwnagotchi/badhid_ng/` after install.

| Script | What it does | Reversible? |
|---|---|---|
| `install.sh` / `uninstall.sh` | Install (plugin + payloads + tools + config) / remove (`--purge` also removes config + home dir) | `uninstall.sh` |
| `badhid_doctor.sh` | **Read-only** health check of the whole chain; prints the one next step | n/a |
| `badhid_update.sh` | From a clone, after a `git pull`: copy the updated plugin + payloads into place and restart | n/a |
| `enable_dwc2.sh` | Put the USB port in gadget mode (`dr_mode=otg`); board-aware; **needs reboot** | `enable_dwc2.sh --revert` |
| `setup_composite_gadget.sh` | Bring up the USB keyboard gadget (`/dev/hidg0`). `--hid-only` (keyboard only) or default (keyboard + USB net). Runtime only — a reboot clears it | `--teardown` |
| `badhidctl.sh` | Friendly control: `status / list / arm / disarm / fire` (reads your token automatically) | n/a |
| `badhid_backup.sh` | Snapshot config + plugins anytime | n/a |
| `badhid_restore.sh` | Full undo: remove plugin, restore config, tear gadget down (`--reboot` option) | n/a |

---

## The demo payloads (all harmless)

The suite ships a **catalog of 20 harmless payloads** — mild to spooky to
sketchy-*looking* — each of which only types text, opens an app, or runs a
**read-only** command. See **PAYLOADS.md** for the full annotated list. A taste:

| File | Tier | What it does |
|---|---|---|
| `hello_world.duck` | mild | Types one line — the quietest proof it works. |
| `keymap_test.duck` | utility | Types every key so you can confirm nothing's dropped. Run this first on a new target. |
| `rickroll.duck` | funny | Opens the classic video. |
| `capslock_prank.duck` | funny | Toggles Caps Lock 8× and leaves it as it started. |
| `spooky_skull.duck` | spooky | ASCII skull in Notepad — looks sinister, pure text. |
| `hacker_theater.duck` | spooky | Fake "hollywood hacking" log in Notepad. Theater only. |
| `shell_whoami.duck` | sketchy-looking | Opens cmd, runs `whoami`/`hostname`/`ver` — read-only, changes nothing. |

The Windows demos use **Win+R (Run)**; each file's header has the macOS/Linux
tweak. The plain ones work on any OS if you focus a text field first.

> **To update** to a newer release, re-run the one-line installer (it re-copies
> the plugin + payloads + tools and keeps your config). From a git clone instead,
> `sudo ./badhid_update.sh` copies the updated plugin + payloads into place and
> restarts.

---

## Controlling it

### Easiest: the CLI wrapper
```bash
sudo ./badhidctl.sh status            # arm state, HID device, bound URL
sudo ./badhidctl.sh list              # available payloads
sudo ./badhidctl.sh arm
sudo ./badhidctl.sh fire hello_world.duck   my-old-laptop   # (payload, optional label)
sudo ./badhidctl.sh disarm
```
It reads your token from `/etc/pwnagotchi/badhid_ng/auth_token.txt` automatically.

### Phone / web — one-tap fire (step by step)
The plugin serves a **mobile-friendly control page** with a **FIRE button per
payload** — one tap arms *and* fires (token-gated). Firing from your phone also
means you don't steal focus on the target, so plain-text payloads land where you
want them.

**1. Make the server reachable from your phone.** It defaults to the least-
exposed address, so pick one:
   - **Tailscale (most private, recommended):** set `bind_scope = "tailscale"`
     (or `"auto"`). The pwnagotchi log prints the exact URL,
     `http://100.x.y.z:8083/`. Your phone must be on the same tailnet.
   - **Plain LAN (quickest):** set `bind_scope = "lan"`. Reachable at
     `http://<pi-lan-ip>:8083/` from anything on your network.

   Then restart: `sudo systemctl restart pwnagotchi && sleep 20`

**2. Get the Pi's address and your token (on the Pi):**
   ```bash
   hostname -I | awk '{print $1}'                      # the LAN IP
   cat /etc/pwnagotchi/badhid_ng/auth_token.txt        # your token
   ```
   (For Tailscale, use the `100.x.y.z` URL from the log instead of the LAN IP.)

**3. Open this on your phone's browser:**
   ```
   http://<pi-address>:8083/?token=<your-token>
   ```
   You'll get the control page: arm state, ARM/DISARM, and a **FIRE** button for
   every payload. Tap one — that's the whole thing.

**4. Bookmark it** to your phone's home screen for a true one-tap launcher.

**Use the dedicated server (port 8083), not the pwnagotchi web UI (8080).** The
plugin also appears under pwnagotchi's own web UI at
`http://<pi>:8080/plugins/badhid_ng/`, and the page will *load* there — but
pwnagotchi wraps that server in CSRF protection, so the ARM/FIRE **buttons**
fail there with `400 Bad Request: The CSRF token is missing`. The dedicated
control server on **port 8083** (`bind_scope`) has no CSRF wrapper and is what
the one-tap page is built for — set `bind_scope = "lan"` (or `tailscale`) and use
the `:8083` URL above. The `:8080` mount is fine for a quick read-only glance
only.

**Options & notes:**
   - `allow_quickfire = true` (default): one tap = arm **+** fire. Set it
     `false` to force the two-step (ARM first, then each FIRE needs you armed).
   - The token rides in a hidden field on every button, so no extra steps.
   - **Security:** `lan` means anyone on your network who *also* has the token
     can reach it, and the token sits in the URL/browser history. For a home lab
     that's a fair trade for one-tap; Tailscale keeps it off the LAN entirely.
     Don't share the `?token=` link.

### On the Pi's screen
With `ui_enabled = true` a small **`BadHID`** indicator shows on the TFT:
`off` → `ready` (gadget up) → `ARMED` (live) → `no-dev` (gadget not up).

---

## Ways to run it (pick what fits)

- **Tethered to a laptop (simplest first test):** the Pi is powered + plugged
  into the laptop you're at. That laptop is the target — fire a demo into a
  Notepad window on it.
- **Field rig, no laptop:** power the Pi from a **UPS HAT or power bank** and run
  a single **data cable** from the Pi's device port to the target. See
  **"Powering it in the field"** below. Trigger from your phone.
- **Gadget flavor:** `--hid-only` (target sees just a keyboard — best when you
  manage the Pi over ethernet/Wi-Fi) or the default composite (keyboard + a USB
  network link, if you want usb0 too).
- **Exposure:** `bind_scope = auto` (Tailscale if present, else localhost),
  `tailscale`, `localhost`, or `lan`. The URL is always logged.
- **Trigger model:** manual fire (default), a timed arm window
  (`arm_window_seconds`), one-shot vs repeat (`arm_one_shot`), or fire the moment
  a host enumerates (`fire_on_enumerate`, off by default).

### Powering it in the field (no laptop)
The gadget doesn't care how the Pi is powered — only that its **device port** is
cabled to the target:
- **Pi 4:** power via a GPIO **UPS HAT** (e.g. Waveshare UPS 3S) or 5V power bank
  → the USB-C port becomes a pure data link. Cable: USB-C (Pi) → USB-A (target).
- **Pi Zero:** power the **PWR** micro-USB; data via the **USB** (OTG) micro-USB.

Use a **data-only / charge-blocked cable** when you're also on a UPS so both
ends don't push 5V down the line. More in **COMPATIBILITY.md**.

---

## Writing your own payloads

Drop `*.duck` (or `*.txt`) files in `payloads_dir`
(`/etc/pwnagotchi/badhid_ng/payloads`). Supported commands:

| Command | Meaning |
|---|---|
| `REM ...` / `# ...` | comment |
| `STRING <text>` | type the literal text |
| `STRINGLN <text>` | type the text, then Enter |
| `ENTER`, `TAB`, `ESC`, `UP`, `DELETE`, `F5`, ... | a named key |
| `GUI r`, `CTRL ALT DELETE`, `CTRL c` | a modifier combo (GUI/CTRL/ALT/SHIFT) |
| `DELAY <ms>` | pause |
| `DEFAULTDELAY <ms>` | implicit pause between following lines |
| `REPEAT <n>` | repeat the previous line n times |

US keyboard layout for now. Keep payloads pointed at your own equipment.

---

## Configuration reference

Every option lives under `[main.plugins.badhid_ng]` (see `config.toml` for the
commented block). Highlights:

- `auth_token` — **required**, ≥12 chars, no placeholders, or the server refuses
  to start.
- `hid_device` (`/dev/hidg0`), `bind_scope`, `port` (8083).
- `payloads_dir`, `default_payload`.
- `arm_window_seconds` (120), `arm_one_shot` (true), `fire_on_enumerate` (false).
- `inter_key_delay_ms` (12) — raise if a fast host drops characters.
- `modifier_settle_ms` (40) — pause after a modifier combo so the host registers
  the release; raise if a Win+R / Ctrl combo "sticks".
- `write_timeout_seconds` (10) — a fire aborts with a clear error if no host is
  reading (e.g. not plugged into a powered/awake target), instead of hanging.
- `authorized_targets` (advisory log only — see Limitations), `ui_*`.

---

## Limitations (read before sharing)

- **Board support is hardware-bound.** Pi Zero/Zero 2 W, Pi 4, Pi 3A+: yes. Pi 5:
  experimental. Pi 3B/3B+, Pi 400, Pi 1/2: no device port, so no HID. See
  **COMPATIBILITY.md**.
- **The allowlist is advisory, not a guard.** A USB keyboard can't verify the
  host, so `authorized_targets` is an audit/intent record only. Physical control
  of what you plug into is the real safeguard.
- **US keyboard layout only** right now. Non-US layouts can mistype symbols.
- **Focus matters.** It types into whatever window is focused. The Windows demos
  open their own window (Run → Notepad/browser); a bare `STRING` demo needs you
  to click into a text field first.
- **One payload at a time, synchronous.** A long payload (many DELAYs) holds the
  request until it finishes.
- **This is a lab tool.** It ships no offensive payloads and won't be extended
  into turnkey malware. Keep it to gear you own or are authorized to test.

---

## Troubleshooting

Run **`sudo ./badhid_doctor.sh`** first — it pinpoints the broken link. Common ones:

| Symptom | Cause | Fix |
|---|---|---|
| `no UDC found` from the gadget script | No `dwc2` overlay active for this board. On stock Raspberry Pi OS the only `dwc2` line is under `[cm5]` (Compute Module 5 only), so a Pi 4/Zero has none active | `sudo ./enable_dwc2.sh && sudo reboot` — it adds one under `[all]` and leaves the `[cm5]`/display/other lines untouched |
| gadget script: `/dev/hidg0 missing` after bind | legacy `g_ether` grabbed the controller | the script auto-unbinds it; re-run; or `sudo ./setup_composite_gadget.sh --hid-only` |
| server won't start, log: token refused | `auth_token` blank/placeholder/<12 chars | set a long random token in config, restart |
| fire error: "HID device not accepting input" | Pi isn't plugged into a powered, awake, enumerated target | plug into the target; wake it; check the cable |
| characters dropped/garbled on the target | host too slow for the type speed | raise `inter_key_delay_ms` (e.g. 15–25) |
| a modifier "sticks" (Win+R turns typing into Win+key shortcuts, Explorer opens, etc.) | host missed the modifier release | raise `modifier_settle_ms` (e.g. 60–80); streams already lead and end with a keys-up report |
| `Win+R → notepad` fails with a missing-DLL error (e.g. `Microsoft.UI.Windowing.Core.dll`) but Notepad opens fine from the Start menu | some Win11 installs have a broken `notepad.exe` redirect — launching the Store Notepad via its exe bypasses app activation, so it can't find its runtime DLLs | not a BadHID issue. On that PC: Settings → Apps → Advanced app settings → **App execution aliases** → toggle **Notepad** off then on. Or just open Notepad yourself and fire a type-only payload (open the editor, focus it, fire `hello_world.duck` from your phone so focus isn't stolen). Other PCs are unaffected. |
| wrong symbols typed | non-US keyboard layout on the target | US layout only for now |
| lost `usb0` after the gadget came up | expected if you used composite on an ethernet-managed Pi | you manage over ethernet; or `--teardown`, or reboot |
| the phone page loads but ARM/FIRE give `400 Bad Request: The CSRF token is missing` | you opened it via the pwnagotchi web UI (`:8080/plugins/badhid_ng/`), whose CSRF guard blocks the POSTs | use the dedicated control server instead: `bind_scope = "lan"` (or `tailscale`), restart, then open `http://<pi>:8083/?token=...`. The `:8080` mount is read-only. |
| want it all gone | — | `sudo ./badhid_restore.sh` (add `--reboot` to fully clear the gadget) |

---

## Tests

From a checkout of this folder:
```bash
python3 tests/test_badhid_ng.py
```
Offline tests cover the parser, keymap, report emitter (incl. the stuck-modifier
fix), token/bind logic, the arm state machine, the fire gate (device write
mocked), payload-path safety, the UI hooks, the web one-tap flow, and that every
shipped payload parses. The on-device behavior (gadget bringup, real `/dev/hidg0`
writes, modifier combos, app launch) was validated on a Pi 4 — see **NOTES.md**
for the hardware-pass record.
