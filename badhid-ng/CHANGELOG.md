# Changelog

## 0.3.0

- **B3 complete: the `POST /stage` endpoint.** BadHID now accepts a
  token-authenticated payload upload from the fleet controller
  (`fleetctl.py badhid-stage`), so staging a payload on a remote enrolled device
  works end to end alongside the existing `/fire`. The upload is **path-safe**
  (stays inside `payloads_dir`, `.duck`/`.txt` only), **parse-validated** before
  it's written (a payload that won't parse is rejected, not saved), and gated by
  the new `allow_remote_stage` option (default `true`; set `false` to refuse all
  remote staging). Unit-tested: valid write, path-traversal rejected, wrong
  extension rejected, unparseable rejected, empty rejected, and
  `allow_remote_stage=false` → 403. The installer and `config.toml.example` now
  include the option. (This is the device-side piece of B3; the controller side
  — `badhid-stage`/`badhid-fire` — already shipped in RemoteExec NG.)

## 0.2.1

- **`badhid_phone.sh` QR always shows.** When no QR tool is present, the script
  now installs a real, tested encoder once (`qrencode` via apt, falling back to
  the `qrcode` Python package via pip) instead of just printing an install hint
  — so a fresh Pi still gets a scannable code with no manual step. Add
  `--no-install` to skip that and only print the URL. (Found when a fresh Pi
  showed the URL but no QR because `qrencode` wasn't installed yet.)

## 0.2.0

Ease-of-use pass — making it "just work" for someone brand new to it.

- **`badhid_setup.sh` — a guided wizard.** One command walks from nothing to a
  fireable setup: checks the board, turns on USB gadget mode, brings up the
  keyboard, enables the plugin, offers phone access, and prints how to fire — in
  plain language, asking before anything risky, and safe to re-run after the one
  reboot it needs. Non-interactive runs take the safe defaults (enable the
  plugin, but never expose the control page to the LAN without a yes).
- **`badhid_phone.sh` — phone access in one scan.** Prints the one-tap control
  URL (token already in it) and a scannable QR code (via `qrencode`, falling
  back to Python `qrcode`, then to the plain URL). `--fix` makes the page
  phone-reachable (`bind_scope=lan`) and restarts. Warns clearly when the
  current `bind_scope` isn't reachable from a phone.
- **`badhid_setopt.py` — no more hand-editing TOML.** Safely sets one option
  inside the `[main.plugins.badhid_ng]` block *only* (section-anchored so a
  neighbouring plugin's identically-named key is never touched, and a mention of
  the section in a comment is never mistaken for the block), and refuses to write
  if the result wouldn't parse. Used by the wizard; handy on its own.
- `badhid_doctor.sh` now points newcomers at the wizard.
- Tests: `tests/test_setup_helpers.py` covers the section-scoped setter
  (isolation, in-place update, append-when-missing, comment-mention guard) and
  shells out to the two scripts (URL building, reachability warning, and the
  wizard's safe non-interactive default).

No change to the plugin's firing behaviour, safety model, or payloads.

## 0.1.0

First release. A USB HID keystroke-injection ("BadUSB / BadHID") framework for
Pwnagotchi, for testing against hardware you own or are authorized to test.
Validated live on a Pi 4 (Model B Rev 1.5), Jayofelony 64-bit.

### What's in it

- **The plugin (`badhid_ng.py`).** A DuckyScript-subset interpreter + US HID
  keymap, an 8-byte boot-keyboard report emitter, an arm/disarm model (disarmed
  and manual-fire by default, auto-expiring arm window, one-shot budget), token
  auth, `bind_scope`, a mobile-friendly web control page with a one-tap FIRE
  button per payload, an on-screen `BadHID` status element for the TFT, and a
  loud audit log on every arm/disarm/fire.
- **Board-aware gadget setup.** `enable_dwc2.sh` auto-detects the board and
  enables USB gadget mode correctly (adds `dtoverlay=dwc2,dr_mode=otg` under
  `[all]`, leaving stock `[cm5]`/display overlays untouched), with `--revert`.
  `setup_composite_gadget.sh` brings up a HID-only (or composite ECM+HID) gadget
  and frees the UDC from a legacy `g_ether` if needed.
- **20 harmless demo payloads** (mild to spooky to sketchy-looking) — each only
  types text, opens an app, or runs a read-only command. No offensive payloads.
- **Operator tooling.** `badhid_doctor.sh` (health check + next step),
  `badhidctl.sh` (status/arm/disarm/fire), `badhid_backup.sh`/`badhid_restore.sh`
  (full undo), `badhid_sync.sh`/`badhid_update.sh` (apply a pull).
- **Docs.** README (install + full how-to + troubleshooting), COMPATIBILITY.md
  (per-board matrix + field power), PAYLOADS.md (annotated catalog), NOTES.md
  (design + safety + the hardware-pass record).
- **Tests.** Offline suite covering the parser, keymap, report emitter (incl.
  the stuck-modifier fix), token/bind logic, arm state machine, fire gate,
  payload-path safety, the web one-click flow, and that every shipped payload
  parses.

### Hardware pass (2026-10-04, Pi 4)

Gadget bringup (with `g_ether` auto-handoff), token-gated server, clean
multi-line typing (welcome text + the full ASCII skull rendered
character-perfect), Win+R app launch (Calculator) and URL/browser (rickroll) all
confirmed. The stuck-modifier bug found here was fixed on-device (leading/
trailing keys-up + `modifier_settle_ms`). Notepad-launch via Win+R fails on one
test laptop due to a Windows `notepad.exe` redirect quirk (documented), not a
BadHID issue — the typing those demos use is already confirmed.

### Safety line

Ships the framework + safety gates and harmless demos only — no shells,
credential grabbers, defender-disablers, persistence, or exfiltration. A USB
keyboard can't verify which host it's plugged into, so `authorized_targets` is
an advisory audit record, not a technical restriction: the real safeguard is
what you physically plug into.
