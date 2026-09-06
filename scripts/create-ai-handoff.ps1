[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
$project=Split-Path -Leaf $root
$metadata=Join-Path $root 'release.properties'
if(-not (Test-Path -LiteralPath $metadata)){throw "Missing $metadata"}
$version=(Select-String -LiteralPath $metadata -Pattern '^VERSION=(.+)$').Matches.Groups[1].Value
if(-not $version){throw 'release.properties has no VERSION'}
$packageMatch=Select-String -LiteralPath $metadata -Pattern '^PACKAGE_ID=(.+)$'
$packageId=if($packageMatch){$packageMatch.Matches.Groups[1].Value}else{$project}
$out=Join-Path $root 'artifacts\downloads'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$deleted=@(& git -C $root diff --name-only --diff-filter=D HEAD)
if($LASTEXITCODE){throw 'git deleted-file inventory failed'}
@('# Files intentionally removed by this update.')+$deleted |
  Set-Content -LiteralPath (Join-Path $root 'release-deletions.lst') -Encoding ascii
$projectManifestTool=Join-Path $root 'scripts\project_manifest.py'
if(Test-Path -LiteralPath $projectManifestTool){
  & python $projectManifestTool --write
  if($LASTEXITCODE){throw 'Project manifest regeneration failed'}
}
$stage=Join-Path ([IO.Path]::GetTempPath()) ("vibe-handoff-"+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
  $tracked=@(& git -C $root ls-files --cached --others --exclude-standard)
  if($LASTEXITCODE){throw 'git ls-files failed'}
  $existing=@($tracked | Where-Object {$_ -and (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf)})
  $required=@('README.md','CHANGELOG.md','HANDOFF.md','TASKS.md','AGENTS.md','WORKFLOW.md','release.properties','release-deletions.lst','dev.sh','dev.cmd','dev.ps1','update.sh','update.cmd','update.ps1','create_ai_handoff_zip.cmd','create_workspace_handoff_zip.cmd','install_workspace_handoff_zip.cmd','artifacts/downloads/.gitkeep')
  $changed=@(& git -C $root diff --name-only --diff-filter=ACMRTUXB HEAD)
  $untracked=@(& git -C $root ls-files --others --exclude-standard)
  $packageFiles=@($changed+$untracked+$required | Sort-Object -Unique | Where-Object {Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf})
  foreach($relative in $packageFiles){
    $destination=Join-Path $stage $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $destination -Force
  }
  $rootManifest=Join-Path $root 'PROJECT_MANIFEST.sha256'
  if((Test-Path -LiteralPath $projectManifestTool) -and (Test-Path -LiteralPath $rootManifest)){
    Copy-Item -LiteralPath $rootManifest -Destination (Join-Path $stage 'PROJECT_MANIFEST.sha256') -Force
  } else {
    $manifest=foreach($relative in ($existing | Sort-Object)){
      $hash=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $root $relative)).Hash.ToLowerInvariant()
      "$hash  $($relative.Replace('\','/'))"
    }
    $manifest | Set-Content -LiteralPath (Join-Path $stage 'PROJECT_MANIFEST.sha256') -Encoding ascii
  }
  $zip=Join-Path $out "$packageId-v$version-changed-files-only.zip"
  if(Test-Path -LiteralPath $zip){Remove-Item -LiteralPath $zip -Force}
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $stream=[IO.File]::Open($zip,[IO.FileMode]::CreateNew)
  try {
    $archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false)
    try {
      foreach($file in Get-ChildItem -LiteralPath $stage -File -Recurse){
        $relative=$file.FullName.Substring($stage.Length+1).Replace('\','/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
          $archive,$file.FullName,$relative,[IO.Compression.CompressionLevel]::Optimal)
      }
    } finally {$archive.Dispose()}
  } finally {$stream.Dispose()}
  $hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
  Write-Output "CREATED: $zip"
  Write-Output "SHA-256: $hash"
} finally {
  if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
