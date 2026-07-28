param(
  [Parameter(Mandatory=$true)][string]$GamePath
)

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$target = Join-Path $GamePath 'mods\run-compass'
if (-not (Test-Path -LiteralPath $GamePath)) { throw "Game path does not exist: $GamePath" }
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'main.lua') -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'metadata.xml') -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'README.md') -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'runcompass') -Destination $target -Recurse -Force
if (Test-Path -LiteralPath (Join-Path $sourceRoot 'gfx')) { Copy-Item -LiteralPath (Join-Path $sourceRoot 'gfx') -Destination $target -Recurse -Force }
if (Test-Path -LiteralPath (Join-Path $sourceRoot 'strings')) { Copy-Item -LiteralPath (Join-Path $sourceRoot 'strings') -Destination $target -Recurse -Force }
Write-Output "Deployed Run Compass to $target"
