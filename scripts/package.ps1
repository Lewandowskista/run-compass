param(
  [Parameter(Mandatory=$true)][string]$OutputPath
)

$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
$sourceFull = [System.IO.Path]::GetFullPath($sourceRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
if ($resolvedOutput -eq $sourceFull -or $resolvedOutput.StartsWith($sourceFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to package inside the source tree" }
if (Test-Path -LiteralPath $resolvedOutput) { Remove-Item -LiteralPath $resolvedOutput -Recurse -Force }
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
Copy-Item -LiteralPath (Join-Path $sourceRoot 'main.lua') -Destination $resolvedOutput -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'metadata.xml') -Destination $resolvedOutput -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'README.md') -Destination $resolvedOutput -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'runcompass') -Destination $resolvedOutput -Recurse -Force
if (Test-Path -LiteralPath (Join-Path $sourceRoot 'strings')) { Copy-Item -LiteralPath (Join-Path $sourceRoot 'strings') -Destination $resolvedOutput -Recurse -Force }
if (Test-Path -LiteralPath (Join-Path $sourceRoot 'gfx')) { Copy-Item -LiteralPath (Join-Path $sourceRoot 'gfx') -Destination $resolvedOutput -Recurse -Force }
$docsSource = Join-Path $sourceRoot 'docs'
$docsOutput = Join-Path $resolvedOutput 'docs'
$publicDocs = @('INSTALLATION.md', 'CONTROLS.md', 'FAIR_PLAY.md', 'COMPATIBILITY.md', 'RELEASES.md')
if (Test-Path -LiteralPath $docsSource) {
  New-Item -ItemType Directory -Force -Path $docsOutput | Out-Null
  foreach ($doc in $publicDocs) {
    $docPath = Join-Path $docsSource $doc
    if (Test-Path -LiteralPath $docPath) { Copy-Item -LiteralPath $docPath -Destination $docsOutput -Force }
  }
  $imageSource = Join-Path $docsSource 'images'
  if (Test-Path -LiteralPath $imageSource) { Copy-Item -LiteralPath $imageSource -Destination $docsOutput -Recurse -Force }
}
Write-Output "Packaged Run Compass runtime at $resolvedOutput"
