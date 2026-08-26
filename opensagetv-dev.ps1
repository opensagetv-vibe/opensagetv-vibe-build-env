param(
  [ValidateSet('image','start','stop','remove-dev','all','core','ffmpeg-linux','ffmpeg-windows','test-mim','xmltv','clean','shell')]
  [string]$Command='all'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$projects = Split-Path -Parent $root
$image = if ($env:OPENSAGETV_BUILD_IMAGE) { $env:OPENSAGETV_BUILD_IMAGE } else { 'opensagetv-build-env:u26-j11' }
$container = if ($env:OPENSAGETV_DEV_CONTAINER) { $env:OPENSAGETV_DEV_CONTAINER } else { 'opensagetv-dev' }

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
  & docker build -t $image $root
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
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
  }

  if (-not (Test-DockerObject @('container','inspect',$container))) {
    & docker create --name $container --init `
      --label 'io.opensagetv.role=unified-dev' `
      --entrypoint sleep `
      -v 'opensagetv-gradle-cache:/work/.gradle' `
      -v "$projects\opensagetv-core:/work/sagetv" `
      -v "$projects\opensagetv-ffmpeg-mim:/project" `
      -v "$projects\opensagetv-xmltv-import:/workspace/xmltv-import" `
      -v "${root}:/workspace/release-manifest" `
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
    & docker exec $container bash /workspace/release-manifest/scripts/dev-entrypoint.sh $Command
    exit $LASTEXITCODE
  }
}
