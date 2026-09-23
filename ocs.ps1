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
$Reg  = Join-Path $RealHome '.ocs'
$LogDir = Join-Path $RealHome '.ocs-logs'

if (-not (Test-Path $Reg))    { New-Item -ItemType File      -Path $Reg    -Force | Out-Null }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Show-Missing([string]$Tool) {
  Write-Host ''
  switch ($Tool) {

    'opencode' {
      Write-Host 'opencode не знайдено в PATH.' -ForegroundColor Red
      Write-Host ''
      Write-Host '  1) Node.js, якщо ще немає:'
      Write-Host '       winget install OpenJS.NodeJS.LTS'
      Write-Host '     перевірити:  node --version'
      Write-Host ''
      Write-Host '  2) opencode:'
      Write-Host '       npm install -g opencode-ai'
      Write-Host '     перевірити:  opencode --version'
      Write-Host ''
      Write-Host '  Якщо після встановлення команду не видно — перезапусти термінал,'
      Write-Host '  npm-глобальні пакети лягають у %APPDATA%\npm.'
      Write-Host ''
      Write-Host '  сайт:  https://opencode.ai'
    }

    'tailscale' {
      Write-Host 'tailscale не знайдено в PATH.' -ForegroundColor Red
      Write-Host ''
      Write-Host '  1) встановити:'
      Write-Host '       winget install tailscale.tailscale'
      Write-Host '     або завантажити:  https://tailscale.com/download/windows'
      Write-Host ''
      Write-Host '  2) увійти:'
      Write-Host '       tailscale up'
      Write-Host ''
      Write-Host '  3) увімкнути HTTPS в адмінці (одноразово на весь тайнет):'
      Write-Host '       https://login.tailscale.com/admin/dns'
      Write-Host '       MagicDNS → увімкнути, нижче кнопка Enable HTTPS'
      Write-Host ''
      Write-Host '  ВАЖЛИВО: tailscale serve на Windows працює лише з PowerShell,' -ForegroundColor Yellow
      Write-Host '  запущеного від імені адміністратора.' -ForegroundColor Yellow
      Write-Host ''
      Write-Host '  Якщо команду не видно після встановлення, вона лежить тут:'
      Write-Host '       C:\Program Files\Tailscale\tailscale.exe'
      Write-Host ''
      Write-Host '  сайт:  https://tailscale.com'
    }

    'ttyd' {
      Write-Host 'ttyd не знайдено в PATH.' -ForegroundColor Red
      Write-Host ''
      Write-Host '  1) scoop, якщо ще немає:'
      Write-Host '       Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
      Write-Host '       irm get.scoop.sh | iex'
      Write-Host ''
      Write-Host '  2) ttyd:'
      Write-Host '       scoop install ttyd'
      Write-Host '     перевірити:  ttyd --version'
      Write-Host ''
      Write-Host '  Без scoop — бінарник з релізів, покласти в теку з PATH:'
      Write-Host '       https://github.com/tsl0922/ttyd/releases'
      Write-Host ''
      Write-Host '  Потрібен Windows 10 або новіший: ttyd використовує ConPTY.'
      Write-Host ''
      Write-Host '  доки:  https://tsl0922.github.io/ttyd/'
    }
  }
  Write-Host ''
  exit 1
}

function Get-Ts {
  $exe = Get-Command tailscale -ErrorAction SilentlyContinue
  if ($exe) { return $exe.Source }
  $fallback = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
  if (Test-Path $fallback) { return $fallback }
  Show-Missing 'tailscale'
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

function Invoke-Picker {
  # інтерактивний браузер підпапок: старт — поточна тека, номер — углиб, .. — угору, . або Enter — вибрати
  if (-not (Test-Path $Root -PathType Container)) { throw "Немає теки $Root (OCS_ROOT)" }
  $top = (Resolve-Path $Root).Path
  $cur = (Get-Location).Path
  $sep = [IO.Path]::DirectorySeparatorChar
  if ($cur -eq $top -or $cur.StartsWith($top + $sep)) {
    # у межах OCS_ROOT — старт тут, межа ROOT
  } elseif ($cur -eq $RealHome -or $cur.StartsWith($RealHome + $sep)) {
    $top = $RealHome   # поза ROOT, але вдома — межа HOME
  } else {
    $top = $cur        # інакше старт і межа — місце запуску
  }
  while ($true) {
    $dirs = @(Get-ChildItem -Path $cur -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
    ''
    "Тека: $cur"
    '  .)  вибрати цю теку'
    if ($cur -ne $top) { '  ..) вище' }
    for ($i = 0; $i -lt $dirs.Count; $i++) { "  $($i + 1)) $($dirs[$i].Name)/" }
    $choice = Read-Host 'Вибір'
    if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '.') { return $cur }
    if ($choice -eq '..') {
      if ($cur -ne $top) { $cur = Split-Path $cur -Parent }
      continue
    }
    if ($choice -match '^\d+$') {
      $n = [int]$choice
      if ($n -ge 1 -and $n -le $dirs.Count) { $cur = $dirs[$n - 1].FullName }
    }
  }
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

  ocs [тека]          запустити поточну теку (або вказану), вибрати порт
  ocs pick            вибір теки з навігацією (старт — поточна тека)
  ocs ls                що працює зараз
  ocs stop <порт|all>   зупинити інстанс
  ocs term [шрифт]      веб-термінал ttyd (типово 25, порт 7681)
  ocs expose <порт>     прокинути будь-який локальний порт у tailnet
  ocs off <порт>        прибрати прокинутий порт
  ocs reset             зняти ВСІ правила tailscale serve і очистити реєстр
  ocs help              ця довідка

Змінні оточення:
  OCS_ROOT   де шукати проєкти            (типово ~\Documents)

Приклад:
  $env:OCS_ROOT = "$HOME\projects"; ocs
  ocs term 30
  ocs stop all
'@
}

function Start-Instance {
  param([string]$DirArg = '')
  if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) { Show-Missing 'opencode' }
  $dir = ''
  $usedPicker = $false
  if ($DirArg -in 'pick', '--pick', '-p') {
    $usedPicker = $true
    # нижче — інтерактивний браузер підпапок (Invoke-Picker)
  } elseif ([string]::IsNullOrWhiteSpace($DirArg)) {
    # без аргументів — поточна тека, крім самого ROOT/HOME/Documents
    $cur = (Get-Location).Path
    $docs = Join-Path $RealHome 'Documents'
    if (($cur -eq $Root) -or ($cur -eq $RealHome) -or ($cur -eq $docs)) {
      $DirArg = 'pick'
      $usedPicker = $true
    } else {
      $dir = $cur
    }
  } elseif ($DirArg -eq '~' -or $DirArg -like '~/*') {
    $dir = $DirArg -replace '^~', $RealHome
  } elseif ([IO.Path]::IsPathRooted($DirArg) -or $DirArg -like './*' -or $DirArg -like '../*' -or $DirArg -eq '.') {
    $dir = Join-Path (Get-Location).Path $DirArg
  } else {
    $cand = Join-Path (Get-Location).Path $DirArg
    if (Test-Path $cand -PathType Container) { $dir = $cand }
    elseif (Test-Path (Join-Path $Root $DirArg) -PathType Container) { $dir = Join-Path $Root $DirArg }
    else { throw "Немає теки: $DirArg (ні ./$DirArg, ні `$OCS_ROOT/$DirArg)" }
  }
  if ($dir) {
    $dir = (Resolve-Path $dir).Path
  }

  if (-not $dir) {
    $usedPicker = $true
    $dir = Invoke-Picker
  }
  if (-not $usedPicker) { "Тека: $dir" }

  $suggested = Get-FreePort 4096
  $x = Read-Host "Порт [$suggested]"
  $port = if ($x) { [int]$x } else { $suggested }
  if (-not (Test-PortFree $port)) { throw "Порт $port зайнятий" }

  # HOME/USERPROFILE = тека проєкту тримає пікер проєктів усередині неї,
  # XDG_* лишають конфіг opencode на місці
  $saved = @{
    HOME = $env:HOME; USERPROFILE = $env:USERPROFILE
    XDG_CONFIG_HOME = $env:XDG_CONFIG_HOME; XDG_DATA_HOME = $env:XDG_DATA_HOME
  }
  $env:HOME = $dir
  $env:USERPROFILE = $dir
  $env:XDG_CONFIG_HOME = Join-Path $RealHome '.config'
  $env:XDG_DATA_HOME = Join-Path $RealHome '.local\share'

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

  # opencode v2 генерує пароль сервера сам і пише його в лог — показуємо його
  $codeLine = $null
  foreach ($i in 1..5) {
    $codeLine = Select-String -Path $log -Pattern '^server password ' -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($codeLine) { break }
    Start-Sleep -Seconds 1
  }

  & (Get-Ts) serve --bg --https=$port "localhost:$port" | Out-Null
  Add-Content $Reg "$port`t$($proc.Id)`t$dir"
  "→ https://$(Get-TsHost):$port"
  if ($codeLine) {
    $code = $codeLine.Line.Substring('server password '.Length)
    '  код: ' + $code
    # лінк з автоматичним логіном: /connect#<base64url JSON> — формат opencode pair
    $url = 'https://' + (Get-TsHost) + ':' + $port
    $json = '{"urls":["' + $url + '"],"username":"opencode","password":"' + $code + '"}'
    $payload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json)).TrimEnd('=').Replace('+','-').Replace('/','_')
    '  лінк: ' + $url + '/connect#' + $payload
    if (Get-Command qrencode -ErrorAction SilentlyContinue) {
      & qrencode -t ANSIUTF8 ($url + '/connect#' + $payload)
    }
  }
}

function Start-Term([int]$FontSize, [int]$Port) {
  if (-not (Get-Command ttyd -ErrorAction SilentlyContinue)) { Show-Missing 'ttyd' }
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
  'start'  { Start-Instance $A1 }
  'pick'   { Start-Instance 'pick' }
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
    $url = 'https://' + (Get-TsHost) + ':' + $A1
    "→ $url"
    if (Get-Command qrencode -ErrorAction SilentlyContinue) { & qrencode -t ANSIUTF8 $url }
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
  default  {
    if ($Cmd -in '-h', '--help', 'help') { Show-Usage }
    else { Start-Instance $Cmd } # ocs <тека>: шлях або ім'я теки в OCS_ROOT
  }
}
