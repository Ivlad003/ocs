# ocs

**English** · [Українська](README.uk.md)

Run several `opencode web` instances on different ports and publish them
inside your own Tailscale tailnet. One script, no dependencies.

```
ocs [dir]             run the current folder (or the given one), pick a port
ocs pick              browse from the current folder, pick a port
ocs ls                what is running right now
ocs stop <port|all>   stop an instance
ocs term [font]       ttyd web terminal (font 25, port 7681 by default)
ocs expose <port>     publish any local port to the tailnet
ocs funnel <port>     publish a local port to the internet (Funnel)
ocs off <port>        remove a published port
ocs reset             stop EVERYTHING, drop tailscale serve rules, clear the registry
ocs help              this help
```

```bash
ocs                   # dashboard for the current folder — no picker
ocs ~/projects/demo   # dashboard for the given folder
ocs pick              # browse from the current folder: numbers go deeper, . selects, .. goes up
ocs term 30           # a terminal alongside, font size 30 — URL + QR
ocs term 30 7690      # same, on a port of your choice
ocs expose 8080       # publish a third-party service — prints URL + QR
ocs funnel 4096       # publish port 4096 to the whole internet
ocs stop all          # shut down everything ocs started
```

What a start looks like:

```
$ ocs
Тека: /home/kosmodev/Documents/pet_project
Порт [4096]: ⏎
→ https://machine.tailnet.ts.net:4096
  код: Xj3kqPZtLm…
  лінк: https://machine.tailnet.ts.net:4096/connect#eyJ1cmxzIjpb…
  █▀▀▀▀▀█ ▀█▀█ █▀▀▀▀▀█ …   ← QR of the same link (with qrencode)
```

The `лінк:` line opens the dashboard already logged in — opencode v2 always
generates a server password, and `ocs` embeds it into a `/connect#…` link
(the same format `opencode pair` uses). The QR code encodes that link.

## Requirements

| Tool | Needed for | Site |
|---|---|---|
| Tailscale | everything | [tailscale.com](https://tailscale.com) |
| opencode | `ocs` (dashboards) | [opencode.ai](https://opencode.ai) |
| ttyd | `ocs term` only | [ttyd docs](https://tsl0922.github.io/ttyd/) |
| qrencode | QR code on start (optional) | [libqrencode](https://fukuchi.org/works/qrencode/) |

If something is missing, the script prints the install commands for your OS
instead of a bare `command not found`.

### macOS

```bash
brew install --cask tailscale
brew install ttyd                              # only for `ocs term`
brew install qrencode                          # optional — QR code on start
curl -fsSL https://opencode.ai/install | bash  # or: npm i -g opencode-ai
tailscale up
```

### Linux

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo apt install ttyd                          # only for `ocs term`
sudo apt install qrencode                      # optional — QR code on start
curl -fsSL https://opencode.ai/install | bash
sudo tailscale up
```

### Windows

Run PowerShell **as Administrator** — `tailscale serve` will not work
otherwise.

```powershell
winget install tailscale.tailscale
winget install OpenJS.NodeJS.LTS
npm install -g opencode-ai
tailscale up

# only for `ocs term` — scoop first, if you don't have it
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
irm get.scoop.sh | iex
scoop install ttyd
scoop install qrencode                         # optional — QR code on start
```

Global npm packages land in `%APPDATA%\npm`, so restart the terminal if
`opencode` is not found. If `tailscale` is not on `PATH`, it lives at
`C:\Program Files\Tailscale\tailscale.exe`.

### One-off step for every platform

Enable HTTPS for the tailnet, otherwise `tailscale serve --https` accepts the
config but no certificate is issued:

[login.tailscale.com/admin/dns](https://login.tailscale.com/admin/dns) →
MagicDNS on → **Enable HTTPS**

The scripts use the Tailscale 1.52+ CLI syntax (`tailscale serve` /
`tailscale funnel`), so keep the client up to date. `ocs funnel` has one more
one-off requirement — the `funnel` node attribute, see
[Publishing to the internet](#publishing-to-the-internet-funnel).

## Install

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/Ivlad003/ocs/main/install.sh | sh
```

Drops `ocs` into `~/.local/bin` (override with `OCS_INSTALL_DIR`, pick a
branch/tag with `OCS_REF`) and tells you if that directory is missing from
`PATH`. Re-run it to update. Windows (PowerShell 7):

```powershell
irm https://raw.githubusercontent.com/Ivlad003/ocs/main/install.ps1 | iex
```

This puts `ocs.ps1` into `~\.ocs-bin` and adds it to the user `PATH`.

### From a clone — symlink


The repository stays the source of truth, so `git pull` updates the command.

```bash
git clone <URL> ~/Documents/pet_project/ocs
chmod +x ~/Documents/pet_project/ocs/ocs
sudo ln -sf ~/Documents/pet_project/ocs/ocs /usr/local/bin/ocs
```

### From a clone — your own bin directory, no sudo

```bash
mkdir -p ~/bin
ln -sf ~/Documents/pet_project/ocs/ocs ~/bin/ocs
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Verify

```bash
which ocs
ocs help
```

## Configuration

Environment variables, no config file:

| Variable | Default | What it does |
|---|---|---|
| `OCS_ROOT` | `~/Documents` | navigation boundary for `ocs pick` when launched inside it; `ocs <name>` looks up folders here |
| `OCS_AUTO` | `1` | autonomous mode: the agent doesn't ask for permissions (`0` — ask as usual) |

Autonomous mode is the server-side equivalent of `opencode --auto` (`serve` /
`web` have no such flag): ocs sets `OPENCODE_PERMISSION='{"*":"allow","external_directory":"ask"}'`,
so everything is allowed except what your config explicitly denies, and
touching files outside the project folder still asks. `OCS_AUTO=0 ocs` keeps
your own permission config.

Worth pinning in `~/.zshrc`:

```bash
export OCS_ROOT=~/Documents/pet_project
```

## How it works

1. `HOME` for the opencode process is replaced with the project folder. The
   "Open project" picker in the web UI is anchored to `$HOME`, so it stops
   exposing the rest of your disk. `XDG_CONFIG_HOME` and `XDG_DATA_HOME` stay
   real, so opencode keeps its config and sessions.
2. The server listens on `127.0.0.1` only — nothing is exposed to the LAN.
3. `tailscale serve --bg --https=<port> localhost:<port>` publishes it inside
   the tailnet with a valid TLS certificate; public exposure is deliberate and
   only via `ocs funnel` (`tailscale funnel`, see below).
4. The registry of running instances lives in `~/.ocs`; logs go to `.ocs.log`
   inside each project folder.
5. opencode v2 always generates a server password. `ocs` prints it at startup
   as `код: …`, plus a one-click link (`/connect#…`, the same format as
   `opencode pair`) that logs the browser in automatically — and a QR code of
   it, if `qrencode` is installed. The password is also in the project's
   `.ocs.log`.

## Publishing to the internet (funnel)

`tailscale serve` publishes inside the tailnet; `ocs funnel` publishes to the
whole internet through
[Tailscale Funnel](https://tailscale.com/docs/reference/tailscale-cli/funnel):

```bash
ocs funnel 4096      # asks for a funnel port, defaults to 443
```

- Funnel ports are limited to **443, 8443 and 10000** — `ocs` asks which one
  to use (default `443`). On port 443 the URL has no port part.
- One-off: the tailnet must grant the `funnel` node attribute
  ([login.tailscale.com/admin/acls](https://login.tailscale.com/admin/acls) →
  `nodeAttrs: [{"target": ["*"], "attr": ["funnel"]}]`) and have HTTPS
  enabled. `ocs funnel` checks both and prints instructions instead of
  hanging in the interactive `tailscale funnel` flow.
- Remove a publication with `ocs off <funnel-port>` (e.g. `ocs off 443`).
  Funnel publishes are not tracked in the registry — same as `expose`.
- opencode instances keep their server password, but anything you funnel is
  reachable by the entire internet: only funnel services you would publish
  publicly anyway.

## Web terminal alongside

For a plain shell in the browser:

```bash
brew install ttyd
ocs term        # font 25, port 7681
ocs term 30     # font 30
ocs stop 7681   # stop it
```

Under the hood:

```bash
ttyd -i lo0 -p 7681 -W -t fontSize=25 -t lineHeight=1.2 -t scrollback=5000 \
  tmux new -A -s term
tailscale serve --bg --https=7681 localhost:7681
```

`-W` is required (without it the terminal is read-only), and so is `-i lo0`
when the port is already published — otherwise ttyd collides with tailscaled
over the same port.

No password on purpose: `-c user:pass` breaks the websocket upgrade, because
browsers do not send Basic Auth credentials in a WebSocket handshake. The
tailnet is the perimeter here.

## Windows

`ocs.ps1` is the PowerShell port, same commands:

```powershell
.\ocs.ps1 term 30
.\ocs.ps1 ls
```

Make it a global command by adding a function to your profile
(`notepad $PROFILE`):

```powershell
function ocs { & "$HOME\Documents\pet_project\ocs\ocs.ps1" @args }
```

Windows specifics:

- PowerShell 7 (`pwsh`) is required; if scripts are blocked, run
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
- `tailscale serve` needs an **elevated** shell — run PowerShell as
  Administrator, otherwise publishing fails
- `HOME` and `USERPROFILE` are both overridden, since that is what the
  project picker follows on Windows
- `ocs term` works: ttyd has had native Windows support since 1.7.0 (ConPTY,
  Windows 10+). Install it with `scoop install ttyd`. It runs `pwsh` instead
  of `tmux`, so the session does not survive a browser reload — run long jobs
  as detached processes (`Start-Process -WindowStyle Hidden`) or a Scheduled
  Task instead of keeping them in the shell
- on Windows ttyd binds `0.0.0.0` and has no `-i lo0` equivalent, so `ocs
  term` publishes the terminal on a **different** port than ttyd listens on

## Minimal alternative

If the script feels like too much, two shell functions do the same job:

```bash
oc() {
  local p=${1:-4096}
  tailscale serve --bg --https=$p localhost:$p
  HOME=$PWD XDG_CONFIG_HOME=~/.config XDG_DATA_HOME=~/.local/share \
    opencode web --hostname 127.0.0.1 --port $p
}
ocoff() { tailscale serve --https=${1:-4096} off; }
```

## Limitations

Replacing `HOME` and the `permission` rules in `opencode.json` are
**guardrails, not a sandbox**. The agent's `bash` tool can still step outside
the project. If you need real isolation, run opencode in a container with only
the project folder mounted.
