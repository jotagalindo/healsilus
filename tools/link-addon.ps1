# Enlaza la carpeta del repositorio como addon de WoW Forever (junction: no copia ficheros).
param(
  [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"
)
$ErrorActionPreference = "Stop"
$repository = Split-Path -Parent $PSScriptRoot
$target = Join-Path $AddOnsPath "Healsilus"
if (-not (Test-Path $AddOnsPath)) {
  throw "AddOns folder not found: $AddOnsPath"
}
if (Test-Path $target) {
  $item = Get-Item $target -Force
  if ($item.LinkType -eq "Junction") {
    Write-Output "Already linked: $target -> $($item.Target)"
    exit 0
  }
  throw "$target already exists and is not a junction. Move it away first."
}
New-Item -ItemType Junction -Path $target -Target $repository | Out-Null
Write-Output "Linked $target -> $repository"
