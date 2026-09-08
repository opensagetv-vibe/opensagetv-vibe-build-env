$ErrorActionPreference='Stop'
$buildEnv=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$temp=Join-Path ([IO.Path]::GetTempPath()) ('vibe-workspace-test-'+[guid]::NewGuid().ToString('N'))
$sources=Join-Path $temp 'sources'
$projects=Join-Path $temp 'projects'
$bundle=Join-Path $temp 'bundle'
$repos=@(
  'opensagetv-vibe-build-env','opensagetv-vibe-core','opensagetv-vibe-container',
  'opensagetv-vibe-ffmpeg-mim','opensagetv-vibe-xmltv-import',
  'opensagetv-vibe-tmdb',
  'opensagetv-vibe-logo','opensagetv-vibe-android-client',
  'opensagetv-vibe-sagemc','opensagetv-vibe-archive'
)
function Write-Ascii([string]$Path,[string[]]$Value){
  $parent=Split-Path -Parent $Path
  if($parent){New-Item -ItemType Directory -Force -Path $parent | Out-Null}
  Set-Content -LiteralPath $Path -Value $Value -Encoding ascii
}
try {
  New-Item -ItemType Directory -Force -Path $sources,$projects,$bundle | Out-Null
  foreach($repo in $repos){
    $source=Join-Path $sources $repo
    $target=Join-Path $projects $repo
    New-Item -ItemType Directory -Force -Path $source | Out-Null
    & git -C $source init -q
    & git -C $source config user.email workflow@example.invalid
    & git -C $source config user.name 'Workspace Workflow Test'
    foreach($doc in 'README.md','CHANGELOG.md','HANDOFF.md','TASKS.md','AGENTS.md','WORKFLOW.md','release-deletions.lst'){
      Write-Ascii (Join-Path $source $doc) $doc
    }
    Write-Ascii (Join-Path $source 'release.properties') @('VERSION=1.0.0',"PACKAGE_ID=$repo",'REQUIRES_BUILD=true')
    Write-Ascii (Join-Path $source 'payload.txt') 'base'
    Write-Ascii (Join-Path $source '.gitignore') @('/artifacts/*','!/artifacts/downloads/','/artifacts/downloads/*','!/artifacts/downloads/.gitkeep')
    Write-Ascii (Join-Path $source '.gitattributes') '*.sh text eol=lf'
    Write-Ascii (Join-Path $source 'artifacts/downloads/.gitkeep') ''
    $dev=@'
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$root/artifacts"
echo "$1" >> "$root/artifacts/gates.log"
'@
    [IO.File]::WriteAllText((Join-Path $source 'dev.sh'),$dev.Replace("`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
    Write-Ascii (Join-Path $source 'dev.cmd') '@echo off'
    Write-Ascii (Join-Path $source 'dev.ps1') '# fixture'
    Write-Ascii (Join-Path $source 'update.sh') '#!/usr/bin/env bash'
    Write-Ascii (Join-Path $source 'update.cmd') '@echo off'
    Write-Ascii (Join-Path $source 'update.ps1') '# fixture'
    Write-Ascii (Join-Path $source 'create_ai_handoff_zip.cmd') '@echo off'
    & git -C $source add -A
    & git -C $source commit -qm baseline
    & git clone -q $source $target
    Write-Ascii (Join-Path $source 'release.properties') @('VERSION=1.1.0',"PACKAGE_ID=$repo",'REQUIRES_BUILD=true')
    Write-Ascii (Join-Path $source 'payload.txt') 'updated'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `
      (Join-Path $buildEnv 'scripts/create-ai-handoff.ps1') -ProjectRoot $source
    if($LASTEXITCODE){throw "Package creation failed for $repo"}
    $package=Join-Path $source "artifacts/downloads/$repo-v1.1.0-changed-files-only.zip"
    $destination=Join-Path $bundle "updates/$repo"
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Copy-Item -LiteralPath $package -Destination $destination
  }
  $tools=Join-Path $bundle 'tools'
  New-Item -ItemType Directory -Force -Path $tools | Out-Null
  Copy-Item -LiteralPath (Join-Path $buildEnv 'scripts/component-update.sh') -Destination $tools
  Copy-Item -LiteralPath (Join-Path $buildEnv 'scripts/apply-workspace-handoff.ps1') -Destination $tools
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=Join-Path $temp 'workspace-ai-handoff.zip'
  [IO.Compression.ZipFile]::CreateFromDirectory($bundle,$zip)
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `
    (Join-Path $buildEnv 'scripts/install-workspace-handoff.ps1') `
    -ZipPath $zip -ProjectsRoot $projects
  if($LASTEXITCODE){throw 'Outer workspace ZIP commissioning failed'}
  foreach($repo in $repos){
    $target=Join-Path $projects $repo
    if((Get-Content (Join-Path $target 'payload.txt') -Raw).Trim() -ne 'updated'){throw "$repo payload was not updated"}
    $gates=@(Get-Content (Join-Path $target 'artifacts/gates.log'))
    if(($gates -join ',') -ne 'test,validate,build,install'){throw "$repo gates were $($gates -join ',')"}
  }
  Write-Output 'PASS: outer ZIP extraction and ten-repository test/validate/build/install commissioning'
} finally {
  if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
