param(
  [switch]$SkipArchive,
  [string]$Organization = 'opensagetv-vibe'
)

$ErrorActionPreference = 'Stop'
$buildEnv = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspace = Split-Path -Parent $buildEnv
$repositories = [ordered]@{
  'opensagetv-vibe-build-env' = 'ubuntu26-modern-build'
  'opensagetv-vibe-core' = 'ubuntu26-modern-build'
  'opensagetv-vibe-container' = 'ubuntu26-modern-build'
  'opensagetv-vibe-ffmpeg-mim' = 'ubuntu26-modern-build'
  'opensagetv-vibe-xmltv-import' = 'ubuntu26-modern-build'
  'opensagetv-vibe-archive' = 'main'
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
  $url = "https://github.com/$Organization/$repository.git"

  if (-not (Test-Path -LiteralPath $target)) {
    Invoke-Git @('clone','--branch',$branch,'--single-branch',$url,$target)
    continue
  }

  if (-not (Test-Path -LiteralPath (Join-Path $target '.git'))) {
    throw "Existing path is not a Git repository: $target"
  }

  $dirty = & git -C $target status --porcelain
  if ($LASTEXITCODE -ne 0) { throw "Unable to inspect $target" }
  if ($dirty) {
    throw "Refusing to update dirty repository: $target"
  }

  Invoke-Git @('-C',$target,'fetch','origin',$branch)
  & git -C $target show-ref --verify --quiet "refs/heads/$branch"
  if ($LASTEXITCODE -eq 0) {
    Invoke-Git @('-C',$target,'switch',$branch)
  } else {
    Invoke-Git @('-C',$target,'switch','--create',$branch,'--track',"origin/$branch")
  }
  Invoke-Git @('-C',$target,'merge','--ff-only',"origin/$branch")
}

Write-Output "OpenSageTV Vibe workspace ready: $workspace"
