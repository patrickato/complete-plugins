# complete-plugins

Finished, hardware-validated plugins for **Jayofelony Pwnagotchi** (64-bit).

Each plugin lives in its own folder with its own README, installer and tests.

## Plugins

| Plugin | What it does | Status |
|---|---|---|
| [**tweak-view-ng**](tweak-view-ng/) | Safe, resolution-independent UI layout editor — drag, nudge, align and restyle your Pwnagotchi's screen from a browser, with named layout profiles. | 0.2.0-beta1 |
| [**badhid-ng**](badhid-ng/) | USB HID keystroke-injection ("BadUSB") lab tool for hardware you own — DuckyScript-subset runner, board-aware gadget setup, arm/auth/logging, one-tap phone page + QR (auto-shows on a fresh Pi), guided wizard, 20 harmless demos. | 0.2.1 |
| [**remoteexec-ng**](remoteexec-ng/) | Token-gated remote-exec agent (safe-by-default, tasks-mode) + a stdlib fleet controller that fans commands out across Pis you own and can stage/fire BadHID across the fleet. | 0.1.0 |

## Installing a plugin

Each plugin folder has a one-line installer.

Tweak View NG:
```bash
curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/tweak-view-ng/install.sh | sudo sh
```

BadHID NG (installs files + config; then a one-time gadget setup it prints):
```bash
curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/badhid-ng/install.sh | sudo sh
```

RemoteExec NG (installs the agent + fleet controller; safe-by-default, enabled=false):
```bash
curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/remoteexec-ng/install.sh | sudo sh
```

See that plugin's README for full details, manual install, configuration and
troubleshooting.

## License

GPL-3.0 (see [LICENSE](LICENSE)).
