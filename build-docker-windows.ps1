$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

$BuildsDir = Join-Path $PSScriptRoot 'builds'
New-Item -ItemType Directory -Force -Path $BuildsDir | Out-Null
Remove-Item (Join-Path $BuildsDir 'MoonlightPortable-x64.zip') -ErrorAction SilentlyContinue

Write-Host '=== Building Windows Portable ==='

# Check submodules
if (-not (Test-Path 'moonlight-common-c\moonlight-common-c\CMakeLists.txt')) {
    Write-Host 'Initializing submodules...'
    git submodule update --init --recursive
}

# Check Docker is in Windows containers mode
$dockerOs = docker version --format '{{.Server.Os}}' 2>$null
if ($dockerOs -ne 'windows') {
    Write-Host ''
    Write-Host 'ERROR: Docker is not in Windows containers mode.'
    Write-Host ''
    Write-Host 'To switch:'
    Write-Host '  1. Right-click the Docker Desktop tray icon'
    Write-Host '  2. Select "Switch to Windows containers..."'
    Write-Host '  3. Re-run this script'
    Write-Host ''
    exit 1
}

Write-Host 'Building Docker image (this will take a while on first run)...'
docker compose build --progress=plain windows
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

docker compose run --rm windows
$runExitCode = $LASTEXITCODE

# Remove dangling images from previous builds (build cache is unaffected)
docker image prune -f --filter "label=com.moonlight-qt.build=true" 2>$null | Out-Null

if ($runExitCode -ne 0) { exit $runExitCode }

$zipPath = Join-Path $BuildsDir 'MoonlightPortable-x64.zip'
if (Test-Path $zipPath) {
    Write-Host '=== Windows build successful ==='
    Write-Host "Output: $zipPath"
} else {
    Write-Host 'ERROR: Windows portable ZIP not found in output directory'
    exit 1
}

Write-Host ''
Write-Host '=== Build artifacts in .\builds\ ==='
Get-ChildItem $BuildsDir
