[CmdletBinding()]
param([string]$ProjectsRoot)
$ErrorActionPreference='Stop'
$buildEnv=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if(-not $ProjectsRoot){$ProjectsRoot=Split-Path -Parent $buildEnv}
$projects=[IO.Path]::GetFullPath($ProjectsRoot)
$repos=@(
  'opensagetv-vibe-build-env','opensagetv-vibe-core','opensagetv-vibe-container',
  'opensagetv-vibe-ffmpeg-mim','opensagetv-vibe-xmltv-import',
  'opensagetv-vibe-tmdb',
  'opensagetv-vibe-logo',
  'opensagetv-vibe-android-client','opensagetv-vibe-sagemc',
  'opensagetv-vibe-archive'
)
$stage=Join-Path ([IO.Path]::GetTempPath()) ('vibe-workspace-handoff-'+[guid]::NewGuid().ToString('N'))
$out=Join-Path $buildEnv 'artifacts\downloads'
New-Item -ItemType Directory -Force -Path $stage,$out | Out-Null
try {
  foreach($repo in $repos){
    $root=Join-Path $projects $repo
    if(-not (Test-Path -LiteralPath (Join-Path $root '.git'))){throw "Missing Git checkout: $root"}
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `
      (Join-Path $buildEnv 'scripts\create-ai-handoff.ps1') -ProjectRoot $root
    if($LASTEXITCODE){throw "Package creation failed: $repo"}
    $metadata=Join-Path $root 'release.properties'
    $version=(Select-String -LiteralPath $metadata -Pattern '^VERSION=(.+)$').Matches.Groups[1].Value
    $idMatch=Select-String -LiteralPath $metadata -Pattern '^PACKAGE_ID=(.+)$'
    $packageId=if($idMatch){$idMatch.Matches.Groups[1].Value}else{$repo}
    $package=Join-Path $root "artifacts\downloads\$packageId-v$version-changed-files-only.zip"
    $destination=Join-Path $stage "updates\$repo"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Copy-Item -LiteralPath $package -Destination $destination
  }
  $tools=Join-Path $stage 'tools'
  New-Item -ItemType Directory -Force -Path $tools | Out-Null
  Copy-Item -LiteralPath (Join-Path $buildEnv 'scripts\component-update.sh') -Destination $tools
  Copy-Item -LiteralPath (Join-Path $buildEnv 'scripts\apply-workspace-handoff.ps1') -Destination $tools
  @'
@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\apply-workspace-handoff.ps1" -BundleRoot "%~dp0" -ProjectsRoot "%~1"
exit /b %ERRORLEVEL%
'@ | Set-Content -LiteralPath (Join-Path $stage 'APPLY_WORKSPACE_HANDOFF.cmd') -Encoding ascii
  @'
# OpenSageTV Vibe workspace handoff

Extract this bundle beside the ten existing `opensagetv-vibe-*` Git
checkouts. Run `APPLY_WORKSPACE_HANDOFF.cmd` with no argument when the extracted
bundle and checkouts share one parent, or pass the absolute projects directory.

Each component package is validated before extraction. The script then runs
that component's resumable test, validate, build, and install gates in release
dependency order. Artifact-only components report install as `SKIPPED`.

Requirements: Git checkouts, Docker Desktop, and WSL on Windows. The workflow
uses the one `opensagetv-vibe-build-env:u26-j11` image and the one reusable
`opensagetv-vibe-dev` container. It does not contain appdata, credentials,
recordings, signing keys, or private server configuration.
'@ | Set-Content -LiteralPath (Join-Path $stage 'README.md') -Encoding utf8
  $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
  $zip=Join-Path $out "opensagetv-vibe-workspace-$stamp-ai-handoff.zip"
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $stream=[IO.File]::Open($zip,[IO.FileMode]::CreateNew)
  try {
    $archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
    try {
      foreach($file in Get-ChildItem -LiteralPath $stage -File -Recurse){
        $relative=$file.FullName.Substring($stage.Length+1).Replace('\','/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.FullName,$relative,[IO.Compression.CompressionLevel]::Optimal)
      }
    } finally {$archive.Dispose()}
  } finally {$stream.Dispose()}
  $hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
  Write-Output "CREATED WORKSPACE HANDOFF: $zip"
  Write-Output "SHA-256: $hash"
} finally {
  if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
