param(
  [ValidateSet('image','start','stop','remove-dev','all','core','ffmpeg-linux','ffmpeg-windows','ffmpeg-info','test-mim','xmltv','logo-info','logo-test','logo-validate','logo-build','logo-install','logo-all','android-info','android-test','android-validate','android-build','android-bundle','android-bundle-install','android-all','android-mcp','runtime-stage','runtime-images','runtime-image-status','runtime-test','runtime-update-package','runtime-update-test','release','runtime-all','clean','shell')]
  [string]$Command='all',
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$CommandArgs
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projects = Split-Path -Parent $root
$image = if ($env:OPENSAGETV_VIBE_BUILD_IMAGE) { $env:OPENSAGETV_VIBE_BUILD_IMAGE } else { 'opensagetv-vibe-build-env:u26-j11' }
$container = if ($env:OPENSAGETV_VIBE_DEV_CONTAINER) { $env:OPENSAGETV_VIBE_DEV_CONTAINER } else { 'opensagetv-vibe-dev' }
$ffmpegCommit = if ($env:OPENSAGETV_VIBE_FFMPEG_COMMIT) { $env:OPENSAGETV_VIBE_FFMPEG_COMMIT } else { 'bf1b838f2ab88b4f8fd83443325c782ea0e0f7fa' }
$ffmpegContext = if ($env:OPENSAGETV_VIBE_FFMPEG_SOURCE_CONTEXT) { $env:OPENSAGETV_VIBE_FFMPEG_SOURCE_CONTEXT } else { "https://github.com/FFmpeg/FFmpeg.git?tag=n9.0.1&checksum=$ffmpegCommit" }
$legacyBuilderImage = 'opensagetv-vibe-ffmpeg-mim-builder:9.0.1-v5'
$projectsId = ([IO.Path]::GetFullPath($projects)).TrimEnd('\', '/').Replace('\', '/')
if ($projectsId -match '^([A-Za-z]):/(.*)$') {
  $projectsId = $Matches[1].ToLowerInvariant() + ':/' + $Matches[2]
}
$forwardedEnvironment = @(
  'OPENDCT_TEST_HOST',
  'OPENDCT_TEST_PORT',
  'OPENDCT_TEST_ENCODER',
  'OPENSAGETV_VIBE_RELEASE_ID',
  'OPENSAGETV_VIBE_BUILD_IMAGE',
  'OPENSAGETV_VIBE_SERVER_IMAGE',
  'OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE',
  'FORCE_RUNTIME_IMAGE_BUILD',
  'OPENSAGETV_VIBE_RESTART_CYCLES',
  'OPENSAGETV_VIBE_RESTART_TIMEOUT_SECONDS',
  'OPENSAGETV_VIBE_STOP_TIMEOUT_SECONDS',
  'OPENSAGETV_VIBE_METRIC_SETTLE_SECONDS',
  'OPENSAGETV_VIBE_MAX_FD_GROWTH',
  'OPENSAGETV_VIBE_MAX_THREAD_GROWTH',
  'OPENSAGETV_VIBE_MAX_RSS_GROWTH_KIB'
)

function Test-DockerObject([string[]]$Arguments) {
  # Windows PowerShell can promote redirected native stderr to a terminating
  # error when the caller uses Stop. A missing object is expected here.
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'
  & docker @Arguments 1>$null 2>$null
  $status = $LASTEXITCODE
  $ErrorActionPreference = $previousPreference
  return ($status -eq 0)
}

function Build-Image {
  & docker buildx build --load --progress=plain `
    --build-context "ffmpeg_src=$ffmpegContext" `
    --build-context "logo_src=$projects\opensagetv-vibe-logo" `
    --build-arg "FFMPEG_COMMIT=$ffmpegCommit" `
    -t $image $root
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Remove-LegacyBuilderImage {
  if (Test-DockerObject @('image','inspect',$legacyBuilderImage)) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    & docker image rm $legacyBuilderImage 1>$null 2>$null
    $ErrorActionPreference = $previousPreference
  }
}

function Ensure-Image {
  if (-not (Test-DockerObject @('image','inspect',$image))) {
    Write-Output "Build image $image is missing; building it once."
    Build-Image
  }
}

function Remove-DevContainer {
  if (Test-DockerObject @('container','inspect',$container)) {
    & docker rm -f -v $container | Out-Null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}

function Ensure-DevContainer {
  Ensure-Image
  $desiredImage = (& docker image inspect $image --format '{{.Id}}').Trim()
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  if (Test-DockerObject @('container','inspect',$container)) {
    $currentImage = (& docker inspect $container --format '{{.Image}}').Trim()
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($currentImage -ne $desiredImage) {
      Write-Output "Recreating $container because the build image changed."
      Remove-DevContainer
    }
    else {
      $containerDetails = ((& docker inspect $container) | ConvertFrom-Json)[0]
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
      $currentProjects = [string]$containerDetails.Config.Labels.'org.opensagetv.vibe.projects-root'
      if ($currentProjects -ne $projectsId) {
        Write-Output "Recreating $container because the sibling workspace changed."
        Remove-DevContainer
      }
    }
  }

  if (-not (Test-DockerObject @('container','inspect',$container))) {
    & docker create --name $container --init `
      --label 'org.opensagetv.vibe.role=unified-dev' `
      --label "org.opensagetv.vibe.projects-root=$projectsId" `
      --entrypoint sleep `
      -v 'opensagetv-vibe-gradle-cache:/work/.gradle' `
      -v 'opensagetv-vibe-ccache:/work/.ccache' `
      -v "$projects\opensagetv-vibe-core:/work/sagetv" `
      -v "$projects\opensagetv-vibe-ffmpeg-mim:/project" `
      -v "$projects\opensagetv-vibe-xmltv-import:/workspace/xmltv-import" `
      -v "$projects\opensagetv-vibe-container:/workspace/container" `
      -v "$projects\opensagetv-vibe-logo:/workspace/logo" `
      -v "$projects\opensagetv-vibe-android-client:/workspace/android-client" `
      -v "${root}:/workspace/release-manifest" `
      -v '/var/run/docker.sock:/var/run/docker.sock' `
      $image infinity | Out-Null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }

  $running = (& docker inspect $container --format '{{.State.Running}}').Trim()
  if ($running -ne 'true') {
    & docker start $container | Out-Null
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}

switch ($Command) {
  'image' {
    $previousImage = $null
    if (Test-DockerObject @('image','inspect',$image)) {
      $previousImage = (& docker image inspect $image --format '{{.Id}}').Trim()
    }
    Build-Image
    $desiredImage = (& docker image inspect $image --format '{{.Id}}').Trim()
    if (Test-DockerObject @('container','inspect',$container)) {
      $currentImage = (& docker inspect $container --format '{{.Image}}').Trim()
      if ($currentImage -ne $desiredImage) { Remove-DevContainer }
    }
    if ($previousImage -and $previousImage -ne $desiredImage) {
      $previousPreference = $ErrorActionPreference
      $ErrorActionPreference = 'SilentlyContinue'
      & docker image rm $previousImage 1>$null 2>$null
      $ErrorActionPreference = $previousPreference
    }
    Remove-LegacyBuilderImage
    exit 0
  }
  'start' { Ensure-DevContainer; Write-Output "$container is running"; exit 0 }
  'stop' {
    if (Test-DockerObject @('container','inspect',$container)) {
      & docker stop $container | Out-Null
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    exit 0
  }
  'remove-dev' { Remove-DevContainer; exit 0 }
  'shell' {
    Ensure-DevContainer
    & docker exec -it $container bash
    exit $LASTEXITCODE
  }
  default {
    Ensure-DevContainer
    # Run the bind-mounted controller so orchestration changes do not require
    # rebuilding the dependency image.
    $dockerArgs = @('exec')
    if ($Command -eq 'android-mcp') { $dockerArgs += '-i' }
    foreach ($name in $forwardedEnvironment) {
      $value = [Environment]::GetEnvironmentVariable($name)
      if (-not [string]::IsNullOrEmpty($value)) {
        $dockerArgs += @('--env', "${name}=${value}")
      }
    }
    $dockerArgs += @($container, 'bash', '/workspace/release-manifest/scripts/dev-entrypoint.sh', $Command)
    $dockerArgs += $CommandArgs
    & docker @dockerArgs
    exit $LASTEXITCODE
  }
}
