# NetManager NG — design & safety notes

A ground-up build for the Jayofelony Pwnagotchi fork. One page, one store, three
kinds of "network," plus an optional authorized-path capture backend.

## Why one page, three kinds

The need: a phone-reachable place to see what networks you work with, switch
between them, add/delete, and fire a test — at 50+ scale. "Network" turned out to
mean three things at once (wifi you join, fleet agents, wifi attack targets), so
the design is **one store + one page** with a `kind` discriminator rather than
three plugins. See / switch / add-delete / fire are identical across kinds; only
the per-kind *fire* differs, and each bolts on without touching the backbone.

## Layering (what's testable without hardware)

- **Pure layer** (module-level, no flask/pwnagotchi): token/bind validation,
  CRUD, search, normalize, the import parsers, the three fire decisions, and
  `plan_capture` (the capture command-builder + gate). All unit-tested.
- **Plugin layer**: option readers, the file-backed store (atomic, 0600, locked),
  token auth, the Flask server + endpoints, the on-screen count, and the
  best-effort `current_ssid()`. Exercised by a live HTTP test.
- **Hardware layer** (`_execute_capture`): the real airodump/aireplay/monitor-mode
  work — can only be verified on a Pi with a second adapter.

Store shape: `{"version":1,"selected":<id|null>,"networks":{<id>:{name,kind,
notes,fields{…},added_at}}}`. `normalize_store` coerces anything on load so a
hand-edited or partial file never crashes the server.

## The three fires (none transmit attack frames by default)

1. **fleet** — a safe reachability+auth probe: POST a read-only task (`uptime`) to
   the agent's remoteexec `/run` with the stored token, report reachable/authed.
2. **wifi_join** — a read-only association check (`iwgetid`). Does not switch the
   radio (the built-in adapter is busy with pwnagotchi; switching needs a 2nd
   USB adapter, a documented hardware step).
3. **wifi_target** — the GATE. Refused unless the BSSID/SSID is on the explicit
   `authorized_targets` allowlist (empty by default). When authorized, it runs the
   capture backend only if that backend is explicitly enabled; otherwise it
   returns a gate-only "authorized ✓" result and sends nothing.

## The capture backend (authorized-path only)

`fire_wifi_target` stays a pure gate; `fire_dispatch` runs the backend **only
after** the gate passes **and** only when it's enabled + configured. Split for
testability:

- **`plan_capture(entry, cfg)`** — pure. Builds the exact commands or refuses, and
  a refusal sends nothing. Enforced, unit-tested properties: two switches on top
  of the allowlist (`capture_backend_enabled` **and** a set `capture_iface`);
  `capture_iface` must not be a `builtin_ifaces` entry (the pwnagotchi radio); a
  BSSID is required and `airodump-ng` is **locked to that one BSSID**; deauth is
  **off unless `deauth_count > 0`**, **targeted** at that BSSID (never a
  broadcast), and **hard-clamped to `MAX_DEAUTH` = 64**.
- **`run_capture_backend`** — fails safe: backend off / plan refusal → gate-only
  result; an executor exception is contained, never crashing the fire handler.
- **`_execute_capture`** — the tier-3 step: put the 2nd adapter in monitor mode
  via `iw` (keeps the interface name — `airmon-ng` would rename it), airodump
  locked to the BSSID for `capture_seconds`, optional bounded deauth, a best-effort
  handshake check (`hcxpcapngtool`/`aircrack-ng`), then **normalize the filename**
  (strip airodump's `-NN`, pwnagotchi-style `<ssid>_<bssid>.<ext>`) so the rest of
  the bus (netmanager re-import, crack-house) recognizes it.

This follows the project rule: keep the allowlist gate strict; make legitimate
use low-friction. netmanager owns the *gate* and the *orchestration*; the frames
go out via standard tools on the user's own authorized hardware.

## Safety posture

Disabled by default, no default token (refuses to start), `bind_scope` defaults
away from the open LAN, store 0600, every fire logged. The capture backend adds a
second independent switch and a hard deauth cap. The page is dependency-free so it
works offline and nothing phones home. The web layer can never edit the allowlist
— that's a deliberate `sudo` action via `netmanagerctl.sh`.

## Hardware pass (Pi 4, Jayofelony 64-bit)

Validated on-device 2026-10-05:
- Page serves over LAN to a phone; 42 `wifi_target` rows imported from real
  handshakes; `fleet` import from fleetctl (`{"agents":…}` unwrapped); search /
  select / edit / delete; the floating toast and refused-target command hint.
- The GATE: a `wifi_target` fire was correctly **refused** on the empty allowlist,
  then **authorized** via `netmanagerctl.sh authorize`, then passed.
- **The capture backend: operational.** On an Alfa AWUS036ACM (MT7612U / mt76x2u)
  as a second adapter on a USB-3 port, a Fire Test on an authorized target set
  monitor mode, ran airodump locked to the BSSID, **captured a real 4-way
  handshake**, and wrote it normalized into the handshakes dir.

The deauth-assisted path (`deauth_count > 0`) and multi-adapter field deployment
are supported and documented; injection quality depends on the adapter/driver
(AR9271/ath9k_htc and RTL8812AU/8811AU inject well; some others are capture-only).
