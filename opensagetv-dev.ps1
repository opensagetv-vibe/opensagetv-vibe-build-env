param([ValidateSet('image','all','core','ffmpeg-linux','ffmpeg-windows','test-mim','xmltv','shell')] [string]$Command='all')
$ErrorActionPreference='Stop'; $root=Split-Path -Parent $MyInvocation.MyCommand.Path; $projects=Split-Path -Parent $root
$image=if($env:OPENSAGETV_BUILD_IMAGE){$env:OPENSAGETV_BUILD_IMAGE}else{'opensagetv-build-env:u26-j11'}
if($Command -in @('image','all')) { docker build -t $image $root; if($LASTEXITCODE){exit $LASTEXITCODE}; if($Command -eq 'image'){exit 0} }
& docker run --rm --init -v "$projects\opensagetv-core:/work/sagetv" -v "$projects\opensagetv-ffmpeg-mim:/project" -v "$projects\opensagetv-xmltv-import:/workspace/xmltv-import" -v "${root}:/workspace/release-manifest" $image $Command
exit $LASTEXITCODE
