# AGENTS.md

Bash + PowerShell CLI that serves the opencode web UI on several ports and
publishes them in a Tailscale tailnet. No build system, no tests, no CI, no
package manifests — the two scripts *are* the product, and changes are pushed
straight to `origin/main`. Docs: `README.md` (EN, primary) and `README.uk.md`.

## Entry points

- `ocs` — Bash, Unix/macOS. The canonical implementation.
- `ocs.ps1` — PowerShell 7, Windows. Port of the same commands but **lags behind
  the Bash script**. When changing one, mirror in the other unless it is a
  deliberate platform difference (e.g. Windows ttyd can't bind loopback).

Known divergences (do not "fix" one side to match blindly — the READMEs treat
them as features):

| Feature | `ocs` (bash) | `ocs.ps1` (pwsh) |
|---|---|---|
| opencode launch command | `opencode serve` | `opencode web` |
| instance log | `<project>/.ocs.log` | `~/.ocs-logs/<name>-<port>.log` |
| `off <port>` for an unpublished port | prints "not published" | blindly removes / prints success |
| `help` without tailscale installed | fails (see below) | works |

## Conventions

- User-facing output, usage text, and code comments are in **Ukrainian**;
  READMEs are bilingual (EN primary). Follow this when adding messages.
- Command dispatch is `case "${1:-start}"` in `ocs` — the first arg is either a
  command or a project directory/path. Unknown commands fall through to
  "start a project". `start` is an explicit no-op alias.
- `stop`, `off`, `reset` mutate live Tailscale state and the registry. Avoid
  running them while testing unless intended.
- Registry `~/.ocs` is tab-separated plain text, one line per instance, fields
  `port`, `pid`, `dir`. `ls` filters dead PIDs; entries are removed only by
  `stop`/`reset`.

## How the server is isolated (don't regress)

- `HOME` (and `USERPROFILE` on Windows) is overridden to the project dir so the
  web UI project picker can't see the rest of the disk; `XDG_CONFIG_HOME` /
  `XDG_DATA_HOME` are pinned to the real values so opencode keeps its config.
- opencode binds `127.0.0.1` only; exposure is exclusively via
  `tailscale serve --bg --https=<port> localhost:<port>`.
- opencode v2 always generates a server password — it **cannot be disabled**
  (empty env just triggers a fresh random one). `ocs` reads the
  `server password …` line from the instance log (retry up to 5 s) and prints
  `код: …`, plus a one-click login link `…/connect#<payload>` where `<payload>`
  is unpadded base64url of `{"urls":["https://host:port"],"username":"opencode","password":"…"}`
  — the exact format the web UI and `opencode pair` use. The QR codes that
  `start`, `expose`, and `term` print encode that link (`start`) or the plain
  URL (`expose`/`term` — no auth there). Don't "simplify" the payload shape;
  it was reverse-engineered from the web bundle.
- ttyd (`ocs term`) is deliberately password-less: `-c user:pass` breaks the
  WebSocket upgrade (browsers don't send Basic Auth on WS handshake). On
  macOS/BSD `-i lo0` is required to avoid colliding with tailscaled on an
  already-published port; Windows serves on a different port instead.
- These are guardrails, not a sandbox — see "Limitations" in the READMEs.

## Verifying changes

- `bash -n ocs` for syntax (shellcheck is not installed here).
- `pwsh` is also not installed here — `ocs.ps1` edits cannot be syntax-checked
  locally; keep them minimal and test on Windows.
- The Bash script runs `command -v tailscale` *before* dispatch, so even
  `ocs help` requires `tailscale` on PATH; `stop` additionally uses `lsof`.
- Functional testing needs `tailscale` (logged into a tailnet with HTTPS
  enabled) and `opencode` installed; `ocs term` also needs `ttyd`. The scripts
  print install instructions for missing deps instead of failing bare.
- `qrencode` (optional) turns on QR output. Bash prints an install hint when
  it is missing; pwsh silently skips — that asymmetry is deliberate, not a bug.
- README command lists (both languages) must stay in sync with `usage()` /
  `Show-Usage` — the "full command list" in the README header is a maintained
  feature.
