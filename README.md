# ocs

**English** · [Українська](README.uk.md)

Run several `opencode web` instances on different ports and publish them
inside your own Tailscale tailnet. One script, no dependencies.

```
ocs                   pick a project folder and a port, start it
ocs ls                what is running right now
ocs stop <port|all>   stop an instance
ocs term [font]       ttyd web terminal (font 25, port 7681 by default)
ocs expose <port>     publish any local port to the tailnet
ocs off <port>        remove a published port
ocs reset             drop ALL tailscale serve rules and clear the registry
ocs help              this help
```

```bash
ocs                   # start a dashboard for a project
ocs term 30           # a terminal alongside, font size 30
ocs term 30 7690      # same, on a port of your choice
ocs expose 8080       # publish a third-party service
ocs stop all          # shut down everything ocs started
```

## Requirements

- [opencode](https://opencode.ai) in `PATH`
- [Tailscale](https://tailscale.com) with MagicDNS and HTTPS enabled
  (admin console → DNS → **Enable HTTPS**)

## Install

### Option 1 — symlink (recommended)

The repository stays the source of truth, so `git pull` updates the command.

```bash
git clone <URL> ~/Documents/pet_project/ocs
chmod +x ~/Documents/pet_project/ocs/ocs
sudo ln -sf ~/Documents/pet_project/ocs/ocs /usr/local/bin/ocs
```

### Option 2 — your own bin directory, no sudo

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

Two environment variables, no config file:

| Variable | Default | What it does |
|---|---|---|
| `OCS_ROOT` | `~/Documents` | where to look for project folders |
| `OCS_PASS` | empty | password for the opencode web UI |

Worth pinning in `~/.zshrc`:

```bash
export OCS_ROOT=~/Documents/pet_project
export OCS_PASS='...'
```

## How it works

1. `HOME` for the opencode process is replaced with the project folder. The
   "Open project" picker in the web UI is anchored to `$HOME`, so it stops
   exposing the rest of your disk. `XDG_CONFIG_HOME` and `XDG_DATA_HOME` stay
   real, so opencode keeps its config and sessions.
2. The server listens on `127.0.0.1` only — nothing is exposed to the LAN.
3. `tailscale serve --bg --https=<port> localhost:<port>` publishes it inside
   the tailnet with a valid TLS certificate.
4. The registry of running instances lives in `~/.ocs`; logs go to `.ocs.log`
   inside each project folder.

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
