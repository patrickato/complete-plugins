# Credits

NetManager NG is an independent, ground-up build for the Jayofelony Pwnagotchi
fork. It implements, in a deliberately narrow and auditable way, patterns that
are old and well understood.

## Prior art it studies

- **Pwnagotchi + bettercap.** Handshake capture is pwnagotchi's whole job; the
  optional capture backend does the same thing bettercap already does on the
  device, just pointed at one target you've explicitly authorized, on a second
  adapter, instead of at everything the radio hears.
- **The aircrack-ng suite** (`airodump-ng`, `aireplay-ng`) and `hcxpcapngtool`.
  The capture backend shells out to these standard tools rather than
  hand-rolling 802.11 injection; they do the capture, deauth and handshake
  extraction.
- **The authorized-target allowlist pattern** established earlier in this project
  for anything that can deauth/target a network (WifiJammerNG / the reference
  deauth work): an explicit BSSID/SSID allowlist, empty by default, gating the
  offensive action — never physical/signal-range assumptions. NetManager reuses
  that gate and keeps it strict while making legitimate use low-friction.
- **BadHID NG / RemoteExec NG** (sibling plugins). The token-gated page, the
  `bind_scope` exposure model, the generated-token installer and the QR phone
  helper all follow the pattern those plugins set.

## What it deliberately is not

It is not a mass-deauth tool, a wardriving autopilot, or anything that fires at
networks it hasn't been explicitly authorized for. The allowlist is empty by
default and the web page can never edit it; the capture backend is off by default
and double-gated; deauth is off unless you ask for it, targeted at one BSSID, and
hard-capped. Every fire is logged. The point of the narrow design is that it is
easy to read and verify, and hard to misuse by accident.

For networks you own or are authorized to test.
