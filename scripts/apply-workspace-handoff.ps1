[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$BundleRoot,
  [string]$ProjectsRoot
)
$ErrorActionPreference='Stop'
$bundle=[IO.Path]::GetFullPath($BundleRoot)
if(-not $ProjectsRoot){$ProjectsRoot=Split-Path -Parent $bundle}
$projects=[IO.Path]::GetFullPath($ProjectsRoot)
$tool=Join-Path $bundle 'tools\component-update.sh'
if(-not (Test-Path -LiteralPath $tool)){throw "Missing workspace updater: $tool"}
function Convert-ToWslPath([string]$Path){
  $full=[IO.Path]::GetFullPath($Path)
  if($full -notmatch '^([A-Za-z]):\\(.*)$'){throw "Cannot convert to WSL path: $full"}
  '/mnt/'+$Matches[1].ToLowerInvariant()+'/'+$Matches[2].Replace('\','/')
}
$order=@(
  'opensagetv-vibe-build-env',
  'opensagetv-vibe-core',
  'opensagetv-vibe-ffmpeg-mim',
  'opensagetv-vibe-xmltv-import',
  'opensagetv-vibe-tmdb',
  'opensagetv-vibe-logo',
  'opensagetv-vibe-android-client',
  'opensagetv-vibe-sagemc',
  'opensagetv-vibe-container',
  'opensagetv-vibe-archive'
)
$linuxTool=Convert-ToWslPath $tool
foreach($repo in $order){
  $target=Join-Path $projects $repo
  if(-not (Test-Path -LiteralPath (Join-Path $target '.git'))){throw "Missing Git checkout: $target"}
  $packages=@(Get-ChildItem -LiteralPath (Join-Path $bundle "updates\$repo") -Filter '*.zip')
  if($packages.Count -ne 1){throw "Expected exactly one package for $repo"}
  Write-Output "===== APPLY $repo ====="
  $linuxTarget=Convert-ToWslPath $target
  $linuxPackage=Convert-ToWslPath $packages[0].FullName
  & wsl.exe env bash $linuxTool $linuxTarget --apply-package $linuxPackage
  if($LASTEXITCODE){throw "$repo update/build workflow failed with exit $LASTEXITCODE"}
}
Write-Output 'WORKSPACE HANDOFF PASSED'
