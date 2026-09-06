[CmdletBinding(PositionalBinding=$false)]
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
function Convert-ToWslPath([string]$Path){$full=[IO.Path]::GetFullPath($Path);if($full -notmatch '^([A-Za-z]):\\(.*)$'){throw "Cannot convert path to WSL form: $full"};'/mnt/'+$Matches[1].ToLowerInvariant()+'/'+$Matches[2].Replace('\','/')}
if(-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)){throw 'WSL is required on Windows.'}
$linuxRoot=Convert-ToWslPath $root
$forwardedEnvironment = @(
  'OPENDCT_TEST_HOST','OPENDCT_TEST_PORT','OPENDCT_TEST_ENCODER',
  'OPENSAGETV_VIBE_RELEASE_ID','OPENSAGETV_VIBE_BUILD_IMAGE',
  'OPENSAGETV_VIBE_SERVER_IMAGE','OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE',
  'OPENSAGETV_VIBE_RESTART_CYCLES','OPENSAGETV_VIBE_RESTART_TIMEOUT_SECONDS',
  'OPENSAGETV_VIBE_STOP_TIMEOUT_SECONDS','OPENSAGETV_VIBE_METRIC_SETTLE_SECONDS',
  'OPENSAGETV_VIBE_MAX_FD_GROWTH','OPENSAGETV_VIBE_MAX_THREAD_GROWTH',
  'OPENSAGETV_VIBE_MAX_RSS_GROWTH_KIB','FORCE_RUNTIME_IMAGE_BUILD'
)
$previousWslEnv = $env:WSLENV
try {
  $present = foreach ($name in $forwardedEnvironment) {
    if (-not [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name))) { $name }
  }
  $entries = @()
  if (-not [string]::IsNullOrWhiteSpace($previousWslEnv)) { $entries += $previousWslEnv.Trim(':') }
  if ($present) { $entries += ($present -join ':') }
  $env:WSLENV = $entries -join ':'
  & wsl.exe bash "$linuxRoot/dev.sh" @Arguments
  $status = $LASTEXITCODE
}
finally {
  if ($null -eq $previousWslEnv) { Remove-Item Env:WSLENV -ErrorAction SilentlyContinue }
  else { $env:WSLENV = $previousWslEnv }
}
exit $status
