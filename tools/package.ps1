# Empaqueta el addon para una release: dist/Healsilus-<versión>.zip con solo la carpeta Healsilus del juego.
$ErrorActionPreference = "Stop"
$repository = Split-Path -Parent $PSScriptRoot
$tocPath = Join-Path $repository "Healsilus.toc"
$versionLine = Select-String -Path $tocPath -Pattern "^## Version: (.+)$"
if (-not $versionLine) {
  throw "Healsilus.toc has no ## Version line"
}
$version = $versionLine.Matches[0].Groups[1].Value.Trim()

$distribution = Join-Path $repository "dist"
$staging = Join-Path $distribution "Healsilus"
if (Test-Path $staging) {
  Remove-Item -Recurse -Force $staging
}
New-Item -ItemType Directory -Force $staging | Out-Null

Copy-Item $tocPath $staging
foreach ($folder in @("Core", "Data", "Frames", "Auras", "UI", "Locales", "Media")) {
  Copy-Item -Recurse (Join-Path $repository $folder) (Join-Path $staging $folder)
}
Copy-Item (Join-Path $repository "README.md") $staging

$archive = Join-Path $distribution "Healsilus-$version.zip"
if (Test-Path $archive) {
  Remove-Item -Force $archive
}
# Entradas con "/" (Compress-Archive de PowerShell 5.1 usa "\" y algunos descompresores no lo entienden).
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($archive, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($file in Get-ChildItem -Recurse -File $staging) {
    $relative = $file.FullName.Substring($distribution.Length + 1).Replace("\", "/")
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $relative) | Out-Null
  }
}
finally {
  $zip.Dispose()
}
Remove-Item -Recurse -Force $staging
Write-Output $archive
