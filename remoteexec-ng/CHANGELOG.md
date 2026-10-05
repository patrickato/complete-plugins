# Changelog

## 0.1.0

First release. A token-gated **remote-exec agent** for Pwnagotchi plus a
**fleet controller** that drives it (and BadHID) across devices you own or are
authorized to test. Validated live on a Pi 4 (Model B Rev 1.5), Jayofelony
64-bit.

### What's in it

- **The agent (`remoteexec_ng.py`).** A small authenticated HTTP API that runs
  commands on the pwnagotchi it's installed on and returns JSON
  (`stdout`/`stderr`/`exit_code`/`duration`). Safe by default:
  - ships `enabled = false`; refuses to start without a real ≥12-char token;
  - **tasks mode** by default — only the named commands in the `tasks` table can
    run (the shipped set is read-only diagnostics: uptime/status/disk/temp/ip);
  - arbitrary shell needs **both** `command_mode="free"` and
    `allow_free_mode=true` — two switches, neither on by accident;
  - token auth on every request, `bind_scope` never opens the LAN by default,
    per-command timeout + output cap, and every run logged (optional JSON
    `audit_log`).
- **The controller (`fleetctl.py`).** A stdlib-only CLI: `enroll` an agent you
  own (stored 0600), `list --ping`, `tasks`, and `run <task> --all/--agents`
  (parallel fan-out, results collected). Plus the BadHID bridge:
  `badhid-stage` and `badhid-fire` to stage/remote-fire a payload on an agent's
  BadHID, with a loud "type yes" confirmation. Enrollment is explicit; nothing
  auto-joins.
- **Safe installer / uninstaller.** `install.sh` backs up, installs the agent +
  controller tools, adds the config block with a generated token
  (`enabled=false`, tasks-mode, scalars-then-`[.tasks]`), and validates with
  auto-rollback. `uninstall.sh --purge` removes the plugin, the home dir, and
  the whole config block *including its `.tasks` sub-table*.
- `remoteexecctl.sh` — friendly `status`/`tasks`/`run` without curl-by-hand;
  gives a clear "re-run with sudo" on the root-only token file.

### Hardware pass

On-Pi smoke test confirmed: agent up on `127.0.0.1:8084`, `tasks` gate live
(`mode=tasks`), `run uptime` returns clean JSON; the controller enrolls the
agent, fans a task out, and collects results (`done: 1/1 ok`); and a fleet
`badhid-fire` delivered real keystroke events through the agent's BadHID.
Multi-device over-network (widening `bind_scope` to Tailscale/LAN) is supported
and documented but exercised per-deployment.
