# інсталятор ocs (Windows, PowerShell 7):
#   irm https://raw.githubusercontent.com/Ivlad003/ocs/main/install.ps1 | iex
# OCS_INSTALL_DIR — куди класти (типово ~\.ocs-bin), OCS_REF — гілка/тег (типово main)

$ErrorActionPreference = 'Stop'

$ref = if ($env:OCS_REF) { $env:OCS_REF } else { 'main' }
$dir = if ($env:OCS_INSTALL_DIR) { $env:OCS_INSTALL_DIR } else { Join-Path $HOME '.ocs-bin' }
$url = "https://raw.githubusercontent.com/Ivlad003/ocs/$ref/ocs.ps1"

New-Item -ItemType Directory -Path $dir -Force | Out-Null
$dst = Join-Path $dir 'ocs.ps1'
"завантажую $url"
Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
"встановлено: $dst"

# ocs.ps1 у теці з PATH запускається як `ocs`
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $dir) {
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$dir", 'User')
  "  додано $dir у PATH користувача — перезапусти термінал"
}

foreach ($t in 'tailscale', 'opencode') {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { "  (ще потрібен $t — ocs підкаже, як встановити)" }
}
''
'далі:  ocs help'
