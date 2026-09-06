$ErrorActionPreference='Stop'
$buildEnv=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$temp=Join-Path ([IO.Path]::GetTempPath()) ('vibe-workflow-test-'+[guid]::NewGuid().ToString('N'))
$source=Join-Path $temp 'source'
$target=Join-Path $temp 'opensagetv-vibe-workflow-fixture'
$explicitTarget=Join-Path $temp 'explicit\opensagetv-vibe-workflow-fixture'
function Convert-ToWslPath([string]$Path) {
  $full=[IO.Path]::GetFullPath($Path)
  if($full -notmatch '^([A-Za-z]):\\(.*)$'){throw "Cannot convert to WSL path: $full"}
  '/mnt/'+$Matches[1].ToLowerInvariant()+'/'+$Matches[2].Replace('\','/')
}
try {
  New-Item -ItemType Directory -Force -Path $source | Out-Null
  & git -C $source init -q
  & git -C $source config user.email workflow@example.invalid
  & git -C $source config user.name 'Workflow Test'
  @('README.md','CHANGELOG.md','HANDOFF.md','TASKS.md','AGENTS.md','WORKFLOW.md','release-deletions.lst') |
    ForEach-Object { Set-Content -LiteralPath (Join-Path $source $_) -Value $_ -Encoding ascii }
  Set-Content -LiteralPath (Join-Path $source 'release.properties') -Encoding ascii -Value @(
    'VERSION=1.0.0','PACKAGE_ID=opensagetv-vibe-workflow-fixture','REQUIRES_BUILD=true')
  Set-Content -LiteralPath (Join-Path $source 'payload.txt') -Value 'base' -Encoding ascii
  Set-Content -LiteralPath (Join-Path $source '.gitignore') -Encoding ascii -Value @(
    '/artifacts/*','!/artifacts/downloads/','/artifacts/downloads/*','!/artifacts/downloads/.gitkeep')
  Set-Content -LiteralPath (Join-Path $source '.gitattributes') -Value '*.sh text eol=lf' -Encoding ascii
  New-Item -ItemType Directory -Force -Path (Join-Path $source 'artifacts/downloads') | Out-Null
  Set-Content -LiteralPath (Join-Path $source 'artifacts/downloads/.gitkeep') -Value '' -Encoding ascii
  $fixtureDev=@'
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$root/artifacts"
echo "$1" >> "$root/artifacts/gates.log"
'@
  [IO.File]::WriteAllText((Join-Path $source 'dev.sh'),
    $fixtureDev.Replace("`r`n","`n")+"`n",[Text.UTF8Encoding]::new($false))
  Set-Content -LiteralPath (Join-Path $source 'dev.cmd') -Value '@echo off' -Encoding ascii
  Set-Content -LiteralPath (Join-Path $source 'dev.ps1') -Value '# fixture' -Encoding ascii
  Set-Content -LiteralPath (Join-Path $source 'update.sh') -Value '#!/usr/bin/env bash' -Encoding ascii
  Set-Content -LiteralPath (Join-Path $source 'update.cmd') -Value '@echo off' -Encoding ascii
  Set-Content -LiteralPath (Join-Path $source 'update.ps1') -Value '# fixture' -Encoding ascii
  Set-Content -LiteralPath (Join-Path $source 'create_ai_handoff_zip.cmd') -Value '@echo off' -Encoding ascii
  & git -C $source add -A
  & git -C $source commit -qm baseline
  & git clone -q $source $target
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $explicitTarget) | Out-Null
  & git clone -q $source $explicitTarget

  Set-Content -LiteralPath (Join-Path $source 'release.properties') -Encoding ascii -Value @(
    'VERSION=1.1.0','PACKAGE_ID=opensagetv-vibe-workflow-fixture','REQUIRES_BUILD=true')
  Set-Content -LiteralPath (Join-Path $source 'payload.txt') -Value 'updated' -Encoding ascii
  & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File `
    (Join-Path $buildEnv 'scripts/create-ai-handoff.ps1') -ProjectRoot $source
  if($LASTEXITCODE){throw 'handoff creator failed'}
  $zip=Get-ChildItem -LiteralPath (Join-Path $source 'artifacts/downloads') -Filter '*.zip' | Select-Object -First 1
  New-Item -ItemType Directory -Force -Path (Join-Path $target 'artifacts/downloads') | Out-Null
  Copy-Item -LiteralPath $zip.FullName -Destination (Join-Path $target 'artifacts/downloads')
  $linuxBuildEnv=Convert-ToWslPath $buildEnv
  $linuxUpdate="$linuxBuildEnv/scripts/component-update.sh"
  $linuxTarget=Convert-ToWslPath $target
  & wsl.exe --cd $linuxTarget env "OPENSAGETV_VIBE_BUILD_ENV_ROOT=$linuxBuildEnv" `
    bash $linuxUpdate '.'
  if($LASTEXITCODE){throw 'component update failed'}
  if((Get-Content (Join-Path $target 'payload.txt') -Raw).Trim() -ne 'updated'){throw 'payload not updated'}
  $gates=@(Get-Content (Join-Path $target 'artifacts/gates.log'))
  if(($gates -join ',') -ne 'test,validate,build,install'){throw "unexpected gates: $($gates -join ',')"}
  & wsl.exe --cd $linuxTarget env "OPENSAGETV_VIBE_BUILD_ENV_ROOT=$linuxBuildEnv" `
    bash $linuxUpdate '.'
  if($LASTEXITCODE){throw 'component update resume failed'}
  $gates=@(Get-Content (Join-Path $target 'artifacts/gates.log'))
  if(($gates -join ',') -ne 'test,validate,build,install'){throw "completed gates reran unexpectedly: $($gates -join ',')"}
  $linuxExplicitTarget=Convert-ToWslPath $explicitTarget
  $linuxZip=Convert-ToWslPath $zip.FullName
  & wsl.exe --cd $linuxExplicitTarget env "OPENSAGETV_VIBE_BUILD_ENV_ROOT=$linuxBuildEnv" `
    bash $linuxUpdate '.' --apply-package $linuxZip
  if($LASTEXITCODE){throw 'explicit package application failed'}
  if((Get-Content (Join-Path $explicitTarget 'payload.txt') -Raw).Trim() -ne 'updated'){throw 'explicit payload not updated'}
  $explicitGates=@(Get-Content (Join-Path $explicitTarget 'artifacts/gates.log'))
  if(($explicitGates -join ',') -ne 'test,validate,build,install'){throw "unexpected explicit gates: $($explicitGates -join ',')"}
  Write-Output 'PASS: verified auto/explicit package extraction, all gates, and completed-state resume workflow'
} finally {
  if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}
}
