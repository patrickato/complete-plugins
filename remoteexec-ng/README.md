# RemoteExec NG + Fleet (`remoteexec_ng.py` + `fleetctl.py`)

Run commands you authorized on Pwnagotchis **you own**, over a token-gated API —
on one device, or fanned out across a fleet. Two cooperating pieces:

- **The agent** (`remoteexec_ng.py`) — a pwnagotchi plugin that exposes a small
  authenticated HTTP API on the device, returning each command's output as JSON.
- **The controller** (`fleetctl.py`) — a stdlib-only CLI you run from a box you
  control, that enrolls agents and drives them in parallel (and can stage/fire
  [BadHID NG](../badhid-ng) payloads across the fleet).

Functionally it's "SSH as a clean API, with an allowlist in front" — nothing
SSH doesn't already let you do, shaped so a script can call it and a controller
can coordinate it. **For devices you own or are authorized to test.**

---

## Safety model (read this)

The agent is **safe by default** and stays that way unless you deliberately open
it up:

- **Ships `enabled = false`.** Nothing runs until you turn it on.
- **No working default token.** A blank/placeholder/<12-char `auth_token` means
  the server refuses to start. The installer generates a strong one for you.
- **Tasks mode by default.** The API can **only** run the *named* commands in
  the `tasks` table — a caller asks for a task by name and cannot inject
  arbitrary shell. The shipped set is read-only: `uptime / status / disk / temp
  / ip`. An empty table = it runs nothing.
- **Free mode is double-gated.** Arbitrary commands need **both**
  `command_mode = "free"` **and** `allow_free_mode = true`. It can't turn on by
  accident.
- **Token auth on every request.** `bind_scope` never binds the open LAN by
  default (`auto` → Tailscale if present, else localhost). The exact bound URL
  is logged.
- **Timeout + output cap** on every command; **every run is logged** at WARNING,
  with an optional JSON `audit_log`.
- **The controller never auto-discovers.** You `enroll` each agent explicitly
  with its own token; tokens are stored `0600`.

---

## Install (on the Pi)

```bash
curl -fsSL https://raw.githubusercontent.com/patrickato/complete-plugins/main/remoteexec-ng/install.sh | sudo sh
```
(or clone this repo and `sudo sh remoteexec-ng/install.sh`). It installs the
agent, drops `fleetctl.py` + `remoteexecctl.sh` into
`/etc/pwnagotchi/remoteexec_ng/`, and adds a `[main.plugins.remoteexec_ng]`
block with a generated token, `enabled=false`, tasks-mode — then validates the
config (auto-rollback if it wouldn't parse). **Nothing runs yet.**

Turn the agent on (read-only tasks only), no nano:
```bash
sudo sed -i '/^\[main\.plugins\.remoteexec_ng\]/,/^\[/ s/^enabled = false/enabled = true/' /etc/pwnagotchi/config.toml
sudo systemctl restart pwnagotchi
```

---

## Use the agent (on the Pi)

`remoteexecctl.sh` wraps the API so you never type curl (run with `sudo` — the
token file is root-only):
```bash
sudo /etc/pwnagotchi/remoteexec_ng/remoteexecctl.sh status     # is it up?
sudo /etc/pwnagotchi/remoteexec_ng/remoteexecctl.sh tasks      # list allowed tasks
sudo /etc/pwnagotchi/remoteexec_ng/remoteexecctl.sh run uptime # run one -> JSON
```
A `run` returns e.g. `{"ok":true,"exit_code":0,"stdout":"…up…","truncated":false}`.

---

## Use the controller (fleet)

`fleetctl.py` is pure stdlib — run it wherever you coordinate from (a laptop,
another Pi, or the Pi itself). Enroll agents you own, then drive them:

```bash
# enroll (token stored 0600 in ~/.config/fleetctl/fleet.json)
python3 fleetctl.py enroll pi-a http://<pi-a>:8084 <token>
python3 fleetctl.py enroll pi-b http://<pi-b>:8084 <token>

python3 fleetctl.py list --ping          # who's enrolled, who answers
python3 fleetctl.py tasks pi-a            # one agent's allowed tasks
python3 fleetctl.py run uptime --all      # fan a task out, collect results
python3 fleetctl.py run disk --agents pi-a,pi-b
```

### Driving BadHID across the fleet (B3)

If an agent also runs [BadHID NG](../badhid-ng), enroll it with its BadHID
endpoint, then stage/fire payloads remotely:
```bash
python3 fleetctl.py enroll pi-a http://<pi-a>:8084 <exec-token> \
  --badhid-url http://<pi-a>:8083 --badhid-token <badhid-token>

python3 fleetctl.py badhid-stage pi-a ./mypayload.duck --as demo.duck
python3 fleetctl.py badhid-fire  pi-a hello_world.duck --target "my lab box"
```
`badhid-fire` prints a loud warning and requires you to type `yes` — a USB
keyboard can't verify which machine it's plugged into, and you're not standing
there, so only fire at hardware you've confirmed is yours.

---

## Reaching an agent from another machine

Out of the box the agent binds **localhost only** (`bind_scope = "auto"` with no
Tailscale), so a one-box test needs no exposure. To let a controller reach it
over the network, widen `bind_scope` in the agent's config — in order of
preference:

- **`tailscale`** (recommended): binds the Tailscale interface only — private,
  encrypted, not exposed to your LAN. Refuses to start if Tailscale isn't up.
- **`lan`**: binds `0.0.0.0` — reachable by anything on your LAN that has the
  token. Explicit, logged, broadest. Use only on a network you trust.

Then `sudo systemctl restart pwnagotchi`. The bound URL is always logged.

---

## Uninstall

```bash
sudo sh uninstall.sh           # remove plugin + controller tools (keep config/token)
sudo sh uninstall.sh --purge   # also remove the home dir + the whole config block
```

---

See **NOTES.md** for the full design/safety writeup, **CREDITS.md** for prior
art, and **CHANGELOG.md** for the release + hardware-pass record. The staging
history lives in `patrickato/plugins-wip` (`remoteexec-suite`, `fleet-suite`).
