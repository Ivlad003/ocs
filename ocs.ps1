#!/usr/bin/env pwsh
# ocs — кілька opencode web на різних портах + публікація в tailnet (Windows)
# Потрібен PowerShell 7 (pwsh). tailscale serve на Windows вимагає
# запуску від імені адміністратора.

param(
  [Parameter(Position = 0)][string]$Cmd = 'start',
  [Parameter(Position = 1)][string]$A1,
  [Parameter(Position = 2)][string]$A2
)

$ErrorActionPreference = 'Stop'

$RealHome = $HOME
$Root = if ($env:OCS_ROOT) { $env:OCS_ROOT } else { Join-Path $RealHome 'Documents' }
$Pass = if ($env:OCS_PASS) { $env:OCS_PASS } else { '' }
$Reg  = Join-Path $RealHome '.ocs'
$LogDir = Join-Path $RealHome '.ocs-logs'

if (-not (Test-Path $Reg))    { New-Item -ItemType File      -Path $Reg    -Force | Out-Null }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Get-Ts {
  $exe = Get-Command tailscale -ErrorAction SilentlyContinue
  if ($exe) { return $exe.Source }
  $fallback = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
  if (Test-Path $fallback) { return $fallback }
  throw 'tailscale не знайдено — встанови з tailscale.com або додай у PATH'
}

function Get-TsHost {
  try {
    $json = & (Get-Ts) status --json | ConvertFrom-Json
    return $json.Self.DNSName.TrimEnd('.')
  } catch { return 'localhost' }
}

function Test-PortFree([int]$Port) {
  -not (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Get-FreePort([int]$From) {
  $p = $From
  while (-not (Test-PortFree $p)) { $p++ }
  return $p
}

function Read-Registry {
  Get-Content $Reg | Where-Object { $_ -match '\S' } | ForEach-Object {
    $f = $_ -split "`t"
    [pscustomobject]@{ Port = [int]$f[0]; Pid = [int]$f[1]; Dir = $f[2] }
  }
}

function Show-Usage {
  @'
ocs — кілька opencode web на різних портах + публікація в tailnet

  ocs                   вибрати теку зі списку, вибрати порт, запустити
  ocs ls                що працює зараз
  ocs stop <порт|all>   зупинити інстанс
  ocs term [шрифт]      веб-термінал ttyd (типово 25, порт 7681)
  ocs expose <порт>     прокинути будь-який локальний порт у tailnet
  ocs off <порт>        прибрати прокинутий порт
  ocs reset             зняти ВСІ правила tailscale serve і очистити реєстр
  ocs help              ця довідка

Змінні оточення:
  OCS_ROOT   де шукати проєкти            (типово ~\Documents)
  OCS_PASS   пароль на веб-інтерфейс      (типово без пароля)

Приклад:
  $env:OCS_ROOT = "$HOME\projects"; ocs
  ocs term 30
  ocs stop all
'@
}

function Start-Instance {
  $dirs = @(Get-ChildItem -Path $Root -Directory | Sort-Object Name)
  if ($dirs.Count -eq 0) { throw "Порожньо в $Root" }
  for ($i = 0; $i -lt $dirs.Count; $i++) { "  $($i + 1)) $($dirs[$i].Name)" }
  $n = Read-Host 'Тека'
  $dir = $dirs[[int]$n - 1].FullName

  $suggested = Get-FreePort 4096
  $x = Read-Host "Порт [$suggested]"
  $port = if ($x) { [int]$x } else { $suggested }
  if (-not (Test-PortFree $port)) { throw "Порт $port зайнятий" }

  # HOME/USERPROFILE = тека проєкту тримає пікер проєктів усередині неї,
  # XDG_* лишають конфіг opencode на місці
  $saved = @{
    HOME = $env:HOME; USERPROFILE = $env:USERPROFILE
    XDG_CONFIG_HOME = $env:XDG_CONFIG_HOME; XDG_DATA_HOME = $env:XDG_DATA_HOME
    OPENCODE_SERVER_PASSWORD = $env:OPENCODE_SERVER_PASSWORD
  }
  $env:HOME = $dir
  $env:USERPROFILE = $dir
  $env:XDG_CONFIG_HOME = Join-Path $RealHome '.config'
  $env:XDG_DATA_HOME = Join-Path $RealHome '.local\share'
  $env:OPENCODE_SERVER_PASSWORD = $Pass

  $log = Join-Path $LogDir "$(Split-Path $dir -Leaf)-$port.log"
  try {
    $proc = Start-Process -FilePath 'opencode' `
      -ArgumentList 'web', '--hostname', '127.0.0.1', '--port', $port `
      -WorkingDirectory $dir -PassThru -WindowStyle Hidden `
      -RedirectStandardOutput $log -RedirectStandardError "$log.err"
  } finally {
    foreach ($k in $saved.Keys) { Set-Item -Path "env:$k" -Value $saved[$k] -ErrorAction SilentlyContinue }
  }

  Start-Sleep -Seconds 1
  if ($proc.HasExited) { Get-Content $log -Tail 20; throw 'opencode не піднявся' }

  & (Get-Ts) serve --bg --https=$port "localhost:$port" | Out-Null
  Add-Content $Reg "$port`t$($proc.Id)`t$dir"
  "→ https://$(Get-TsHost):$port"
}

function Start-Term([int]$FontSize, [int]$Port) {
  if (-not (Get-Command ttyd -ErrorAction SilentlyContinue)) {
    throw 'ttyd не знайдено — scoop install ttyd, або бінарник з github.com/tsl0922/ttyd/releases'
  }
  $p = Get-FreePort $Port
  # ttyd на Windows біндиться на 0.0.0.0 і не вміє -i lo0, тому публічний
  # порт беремо інший — інакше конфлікт із tailscaled за той самий порт
  $servePort = Get-FreePort ($p + 100)
  $log = Join-Path $LogDir "ttyd-$p.log"

  # без -c: Basic Auth ламає websocket-апгрейд, периметр — тайнет
  $proc = Start-Process -FilePath 'ttyd' `
    -ArgumentList '-p', $p, '-W', '-t', "fontSize=$FontSize", '-t', 'lineHeight=1.2',
                  '-t', 'scrollback=5000', 'pwsh' `
    -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError "$log.err"

  Start-Sleep -Seconds 1
  if ($proc.HasExited) { Get-Content $log -Tail 10; throw 'ttyd не піднявся' }

  & (Get-Ts) serve --bg --https=$servePort "localhost:$p" | Out-Null
  Add-Content $Reg "$servePort`t$($proc.Id)`tttyd"
  "→ https://$(Get-TsHost):$servePort  (шрифт $FontSize)"
}

function Show-List {
  $h = Get-TsHost
  foreach ($r in Read-Registry) {
    if (Get-Process -Id $r.Pid -ErrorAction SilentlyContinue) {
      "  $($r.Port)  $(Split-Path $r.Dir -Leaf)  https://${h}:$($r.Port)"
    }
  }
  ''
  'правила tailscale:'
  & (Get-Ts) serve status
}

function Stop-Instance([string]$Key) {
  $keep = @()
  foreach ($r in Read-Registry) {
    if ($Key -eq 'all' -or $Key -eq "$($r.Port)") {
      Stop-Process -Id $r.Pid -Force -ErrorAction SilentlyContinue
      & (Get-Ts) serve --https=$($r.Port) off 2>$null | Out-Null
      "зупинено $($r.Port)"
    } else {
      $keep += "$($r.Port)`t$($r.Pid)`t$($r.Dir)"
    }
  }
  Set-Content $Reg ($keep -join "`n")
  ''
  'правила tailscale зараз:'
  & (Get-Ts) serve status
}

switch ($Cmd) {
  'start'  { Start-Instance }
  'ls'     { Show-List }
  'stop'   { if (-not $A1) { throw 'потрібен порт або all' }; Stop-Instance $A1 }
  'term'   {
    $fs = if ($A1) { [int]$A1 } else { 25 }
    $pt = if ($A2) { [int]$A2 } else { 7681 }
    Start-Term $fs $pt
  }
  'expose' {
    if (-not $A1) { throw 'потрібен порт' }
    & (Get-Ts) serve --bg --https=$A1 "localhost:$A1" | Out-Null
    "→ https://$(Get-TsHost):$A1"
  }
  'off'    {
    if (-not $A1) { throw 'потрібен порт' }
    & (Get-Ts) serve --https=$A1 off | Out-Null
    "знято $A1"
  }
  'reset'  {
    $a = Read-Host 'Зняти ВСІ правила tailscale serve? [y/N]'
    if ($a -in 'y', 'Y') { & (Get-Ts) serve reset; Set-Content $Reg ''; 'готово' }
    else { 'скасовано' }
  }
  default  { Show-Usage }
}
