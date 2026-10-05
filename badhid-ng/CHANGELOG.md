# Changelog

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
