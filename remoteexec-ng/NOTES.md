# RemoteExec NG + Fleet - design & safety notes

This bundle is two cooperating pieces: the **agent** (`remoteexec_ng.py`, a
pwnagotchi plugin) and the **controller** (`fleetctl.py`, a stdlib CLI). Below
are the design notes for each, as they graduated from the staging repo.

---

## Agent (remoteexec_ng.py)


Status: **new build**, B1 slice of `BADUSB_AND_REMOTE_EXEC_IDEAS`
(in `patrickato/test-plugins`). Sandbox-green; not hardware-tested yet, so it
does not graduate to `complete-plugins` until an on-device pass.

## What this is, and the line it holds

B1 is "remote admin of your own pwns": a hardened, authenticated command API.
It is deliberately **infrastructure for devices you own**, not an implant:

- You install it yourself, on your own Pi. It does not exploit anything,
  self-propagate, or persist beyond a normal plugin.
- It does nothing you can't already do over SSH — it just exposes it as a clean,
  token-gated API that a script or the B2 controller can call.

The repo already has `web2ssh_ng` (an interactive web shell) and `terminal` as
"seeds"; this is the **programmatic** sibling, designed as the **agent** the
fleet controller (B2) will drive. It's intentionally *more* restrictive than a
shell by default (named tasks only).

## The gates (why this stays safe)

1. **tasks mode by default.** `resolve_request()` (the single security choke
   point, unit-tested directly) only returns a command for a *named task* from
   the configured `tasks` table. An arbitrary `command` is refused in tasks
   mode — even if `allow_free_mode` is true. Empty table = nothing runs.
2. **free mode is double-gated.** Arbitrary commands require BOTH
   `command_mode="free"` AND `allow_free_mode=true`. One switch alone does
   nothing. This makes "oops, left it wide open" structurally hard.
3. **token auth** (≥12 chars, no placeholders), same gate as badhid/web2ssh.
4. **bind_scope** never `lan` by default; `auto` → tailscale/localhost, URL
   logged.
5. **timeout + output cap** per command; **loud WARNING log** on every
   run/refusal; optional JSON `audit_log`.

`resolve_request` is pure and isolated precisely so the gate logic can be
proven in tests without spawning anything — see `test_remoteexec_ng.py`
(`test_tasks_mode_gate`, `test_free_mode_double_gate`).

## Fork conventions followed

- Section `[main.plugins.remoteexec_ng]` = file basename; `DEFAULTS` + `_opt*`
  readers (no `__defaults__` merge); real hooks only (`on_loaded`, `on_unload`,
  `on_webhook`, `on_ui_setup/update`); server via `make_server` in a daemon
  thread so `on_loaded` never blocks; `bind_scope` with the URL logged — same as
  web2ssh_ng/handshaker/badhid_ng.
- `>>> USER INPUT REQUIRED <<<` on `auth_token`, which refuses placeholders.
- TOML gotcha documented: all scalar keys before the `[.tasks]` sub-table (can't
  re-open the parent table after a sub-table).

## Real-hardware pass checklist (before graduating)

1. Server binds at the expected `bind_scope` URL; token auth rejects a
   wrong/absent token.
2. `/tasks` lists the configured tasks; `/run` with `{"task":"uptime"}` returns
   real output + exit 0.
3. tasks mode refuses an arbitrary `{"command": ...}` on the real endpoint.
4. free mode runs an arbitrary command ONLY when both switches are set.
5. a command that exceeds `command_timeout_seconds` is killed and reported.

## Out of scope here (later slices)

- **B2** — the controller: enrollment (explicit shared key, no open
  registration), mutual auth, signed task messages, an allowlist of agents it
  will talk to, and task fan-out. Builds on this agent endpoint.
- **B3** — staging a BadHID payload to an agent to fire on plug-in.

---

## Controller (fleetctl.py)


Status: **new build**, B2 slice of `BADUSB_AND_REMOTE_EXEC_IDEAS`. Sandbox-green,
and the live B1↔B2 loop was exercised during development (real remoteexec_ng
agent + fleetctl over localhost HTTP). Not yet run across the real fleet, so it
doesn't graduate to `complete-plugins` until an on-fleet pass.

## What it is

B2 is the coordination layer: a controller (`fleetctl`) that drives the B1
agents (`remoteexec_ng`) on devices you own. Enroll agents explicitly, fan a
named task out, collect results. It's a standalone stdlib Python CLI (no deps)
so it runs on any controller box — a Pi, the Pi5, your laptop.

It is deliberately NOT a pwnagotchi plugin: a controller naturally runs from a
workstation or a designated master, not from inside the pwnagotchi engine. The
agents are the plugins; the controller is the conductor.

## The safety argument

The thing that separates "fleet management for your own kit" from "a botnet" is
**how agents join** and **who can command them**. This build draws the line hard:

1. **Explicit enrollment only.** `fleetctl enroll` is the only way an agent
   enters the controller's list. There is no discovery, no broadcast, no
   auto-registration, no "agent calls home and gets added." `select_agents()`
   (pure, tested) refuses any label that isn't already enrolled — so a `run`
   can only ever target agents you added by hand.
2. **The agent is the real authority.** The controller holds each agent's token
   and authenticates to it, but every request is still subject to the agent's
   own gates (B1: tasks-mode by default, token auth, timeout). The controller
   cannot make an agent exceed what the agent allows — proven in the integration
   check: the controller sends an arbitrary command and the agent refuses it
   (400), and a wrong token is 401.
3. **Secrets stay local.** Tokens live in a `0600` JSON config; traffic goes only
   to enrolled agents.

`select_agents()` and `fan_out()` are pure/orchestration with the network call
injected, so the allowlist property and the fan-out are unit-tested without a
network (`test_fleetctl.py`).

## Design points

- stdlib only (`urllib`, `concurrent.futures`) — runs anywhere, nothing to pip.
- parallel fan-out with a per-agent timeout; one agent being down never blocks
  or crashes the others (`test_fan_out_handles_agent_error`).
- non-JSON / error responses from an agent degrade to `ok:false`, never a crash.

## Roadmap (deliberately out of scope for v1)

- **Mutual auth / signed tasks.** Right now the controller authenticates to the
  agent (holds its token); the agent does not cryptographically verify the
  controller beyond that. A later slice: signed task messages + an enrollment
  shared-key handshake so an agent only accepts tasks from a controller it was
  enrolled with. The architecture (explicit enrollment both ways) is ready for
  it.
- Task templates with arguments; structured/full-JSON output; save-to-file.

## B3 — BadHID over the fleet (built, with the most care)

`badhid-stage` / `badhid-fire` let the controller push a payload to an agent's
BadHID and fire it. It is deliberately thin — it *composes* existing gated
pieces and adds nothing that bypasses them:

- **Staging** goes through BadHID's new `/stage` endpoint, which is token-gated,
  path-safe (writes only inside `payloads_dir`), **parse-validated**, and can be
  switched off per-agent (`allow_remote_stage=false`). No payloads are shipped;
  the operator authors them. (Verified live: a real agent accepts a valid stage,
  401s a wrong token, 400s a traversal attempt.)
- **Firing** goes through BadHID's existing `/quickfire` (token + arm model).
  The controller can't make BadHID do anything BadHID wouldn't do locally.
- **The extra caveat, made loud:** remote firing means the operator is *not*
  physically at the target, and a USB keyboard still cannot verify the host.
  `badhid-fire` therefore requires an interactive `yes` (or an explicit `--yes`
  in trusted scripts), and the docs state plainly that the physical
  responsibility — only plugging the agent into owned/authorized hardware — is
  entirely the operator's and cannot be enforced in software. This is the one
  piece to treat with the most care, and it's built to make the operator stop
  and confirm.
