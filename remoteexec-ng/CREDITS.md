# Credits

RemoteExec NG (the agent) and the fleet controller are an independent, ground-up
build for the Jayofelony Pwnagotchi fork. They implement, in a deliberately
narrow and auditable way, ideas that are old and well understood:

## Prior art it studies

- **SSH / remote administration.** The agent is functionally "SSH as a small
  JSON API": run a command you authorized on a device you own, get its output
  back. It adds nothing SSH doesn't already allow — it just exposes it as a
  clean endpoint a script or a controller can call, with a named-command
  allowlist in front of it.
- **Configuration-management & orchestration tools** (Ansible, Fabric, pssh,
  Salt). The controller's model — a declared inventory of hosts you own, a
  command fanned out in parallel, results collected — is the same pattern those
  tools pioneered, shrunk to a single stdlib file with no agents to install
  beyond the one plugin.
- **Hak5 / DuckyScript** lineage, via the sibling BadHID NG plugin that this
  controller can drive (B3). See that plugin's CREDITS.

## What it deliberately is not

It is not a C2 framework, an implant, or anything that self-propagates, hides,
persists beyond a normal pwnagotchi plugin, or reaches a device you have not
explicitly enrolled with its own token. Enrollment is manual, every agent is
token-gated, the default mode runs only a fixed read-only command list, and
every run is logged. The whole point of the narrow design is that it is easy to
read and verify, and hard to misuse by accident.

For devices you own or are authorized to test.
