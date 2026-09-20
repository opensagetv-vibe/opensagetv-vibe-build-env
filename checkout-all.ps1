param(
  [switch]$SkipArchive,
  [string]$Organization = 'opensagetv-vibe',
  [string]$SourceRoot = $env:OPENSAGETV_VIBE_SOURCE_ROOT,
  [string]$ResolvedManifest = $env:OPENSAGETV_VIBE_RESOLVED_MANIFEST
)

$ErrorActionPreference = 'Stop'
$buildEnv = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspace = Split-Path -Parent $buildEnv
$repositories = [ordered]@{
  'opensagetv-vibe-build-env' = 'ubuntu26-modern-build'
  'opensagetv-vibe-core' = 'ubuntu26-modern-build'
  'opensagetv-vibe-container' = 'ubuntu26-modern-build'
  'opensagetv-vibe-ffmpeg-mim' = 'ubuntu26-modern-build'
  'opensagetv-vibe-SageTVFFmpegPlugin' = 'main'
  'opensagetv-vibe-xmltv-import' = 'ubuntu26-modern-build'
  'opensagetv-vibe-tmdb' = 'main'
  'opensagetv-vibe-logo' = 'main'
  'opensagetv-vibe-android-client' = 'main'
  'opensagetv-vibe-sagemc' = 'main'
  'opensagetv-vibe-archive' = 'main'
}
$manifestNames = @{
  'opensagetv-vibe-build-env' = 'build_env'
  'opensagetv-vibe-core' = 'core'
  'opensagetv-vibe-container' = 'container'
  'opensagetv-vibe-ffmpeg-mim' = 'ffmpeg_mim'
  'opensagetv-vibe-SageTVFFmpegPlugin' = 'ffmpeg_plugin'
  'opensagetv-vibe-xmltv-import' = 'xmltv_import'
  'opensagetv-vibe-tmdb' = 'tmdb'
  'opensagetv-vibe-logo' = 'logo'
  'opensagetv-vibe-android-client' = 'android_client'
  'opensagetv-vibe-sagemc' = 'sagemc'
}
$manifest = $null
if ($ResolvedManifest) {
  $manifestPath = (Resolve-Path -LiteralPath $ResolvedManifest).Path
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if (-not $manifest.repositories) { throw "Invalid resolved manifest: $manifestPath" }
}
if ($SourceRoot) {
  $SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
}

function Invoke-Git([string[]]$Arguments) {
  & git @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "git failed: git $($Arguments -join ' ')"
  }
}

foreach ($repository in $repositories.Keys) {
  if ($SkipArchive -and $repository -eq 'opensagetv-vibe-archive') { continue }

  $branch = $repositories[$repository]
  $target = Join-Path $workspace $repository
  $url = if ($SourceRoot) { Join-Path $SourceRoot $repository } else { "https://github.com/$Organization/$repository.git" }

  if (-not (Test-Path -LiteralPath $target)) {
    $cloneArguments = @('clone','--branch',$branch,'--single-branch')
    if ($SourceRoot) { $cloneArguments += '--no-local' }
    $cloneArguments += @($url,$target)
    Invoke-Git $cloneArguments
  } else {
    if (-not (Test-Path -LiteralPath (Join-Path $target '.git'))) {
      throw "Existing path is not a Git repository: $target"
    }
    $dirty = & git -C $target status --porcelain
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect $target" }
    if ($dirty) { throw "Refusing to update dirty repository: $target" }
    if ($SourceRoot) { Invoke-Git @('-C',$target,'remote','set-url','origin',$url) }
    Invoke-Git @('-C',$target,'fetch','origin',$branch)
    & git -C $target show-ref --verify --quiet "refs/heads/$branch"
    if ($LASTEXITCODE -eq 0) {
      Invoke-Git @('-C',$target,'switch',$branch)
    } else {
      Invoke-Git @('-C',$target,'switch','--create',$branch,'--track',"origin/$branch")
    }
    Invoke-Git @('-C',$target,'merge','--ff-only',"origin/$branch")
  }

  if ($manifest -and $manifestNames.ContainsKey($repository)) {
    $manifestName = $manifestNames[$repository]
    $commit = $manifest.repositories.$manifestName.commit
    if ($commit -notmatch '^[0-9a-f]{40}$') {
      throw "Resolved manifest has no valid commit for $manifestName"
    }
    Invoke-Git @('-C',$target,'cat-file','-e',"$commit`^{commit}")
    Invoke-Git @('-C',$target,'switch','--detach',$commit)
  }
}

Write-Output "OpenSageTV Vibe workspace ready: $workspace"
