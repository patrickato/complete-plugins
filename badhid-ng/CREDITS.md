# Credits

BadHID NG is an independent, ground-up build for the Jayofelony Pwnagotchi fork.
It stands on the shoulders of the open tools and techniques that defined
USB-gadget keystroke injection:

## Prior art it studies

- **Hak5 Rubber Ducky / DuckyScript** — the keystroke-injection payload language
  this plugin implements a safe subset of (REM/STRING/STRINGLN/named keys/
  modifier combos/DELAY/DEFAULTDELAY/REPEAT).
- **P4wnP1 A.L.O.A. (MaMe82)** — the reference implementation for running a
  *composite* USB gadget (ethernet + HID together) on a Pi via `libcomposite`/
  configfs, which is what lets a Pwnagotchi keep its network link while also
  presenting an HID keyboard.
- **The Linux USB gadget / configfs HID documentation** — the boot-keyboard
  report descriptor and the `functions/hid.*` setup.

## This build

Written from scratch for this project's plugin line. It deliberately ships only
the framework, the safety gates, and harmless demo payloads — never turnkey
offensive payloads — so it stays a lab instrument rather than malware. The line
it holds, and the allowlist/arm/auth/logging discipline, mirror the same project's
`wifiJtest` deauth gate and `crack-pipeline` cracking gate.

Thanks to the Pwnagotchi and Jayofelony communities for the platform.
