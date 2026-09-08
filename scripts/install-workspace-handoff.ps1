[CmdletBinding()]
param(
  [string]$ZipPath,
  [string]$ProjectsRoot
)
$ErrorActionPreference='Stop'
$buildEnv=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if(-not $ZipPath){
  $candidate=Get-ChildItem -LiteralPath (Join-Path $buildEnv 'artifacts\downloads') `
    -Filter 'opensagetv-vibe-workspace-*-ai-handoff.zip' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if(-not $candidate){throw 'No workspace handoff ZIP was supplied or found in artifacts/downloads.'}
  $ZipPath=$candidate.FullName
}
$zip=[IO.Path]::GetFullPath($ZipPath)
if(-not (Test-Path -LiteralPath $zip -PathType Leaf)){throw "Handoff ZIP not found: $zip"}
if(-not $ProjectsRoot){$ProjectsRoot=Split-Path -Parent $buildEnv}
$projects=[IO.Path]::GetFullPath($ProjectsRoot)
$stage=Join-Path ([IO.Path]::GetTempPath()) ('vibe-workspace-install-'+[guid]::NewGuid().ToString('N'))
try {
  Expand-Archive -LiteralPath $zip -DestinationPath $stage
  $apply=Join-Path $stage 'tools\apply-workspace-handoff.ps1'
  if(-not (Test-Path -LiteralPath $apply)){throw 'Workspace ZIP lacks its commissioning script.'}
  $packages=@(Get-ChildItem -LiteralPath (Join-Path $stage 'updates') -Recurse -Filter '*-changed-files-only.zip')
  if($packages.Count -ne 9){throw "Workspace ZIP must contain nine component packages; found $($packages.Count)."}
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $apply `
    -BundleRoot $stage -ProjectsRoot $projects
  if($LASTEXITCODE){throw "Workspace commissioning failed with exit $LASTEXITCODE"}
  Write-Output "WORKSPACE ZIP INSTALLED: $zip"
} finally {
  if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
