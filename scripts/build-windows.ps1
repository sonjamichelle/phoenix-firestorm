# Build Phoenix Firestorm on Windows (ReleaseFS_open, 64-bit).
# Requires: Python with autobuild (pip install -r requirements.txt), CMake, Cygwin or Git bash (bash in PATH).
# Optional: Set AUTOBUILD_VARIABLES_FILE to your fs-build-variables path (e.g. D:\src\grid\fs-build-variables\variables); otherwise uses build-support/variables.
# Optional: Set AUTOBUILD_VSVER (e.g. 170 = VS 2022, 180 = VS 2026); otherwise auto-detected from vswhere.
# Note: Configure runs under bash; use Cygwin (C:\Cygwin64\bin before System32 in PATH) so cmake and VS env are found. See doc/building_windows.md.

$ErrorActionPreference = "Stop"
$RepoRoot = (Get-Item (Join-Path $PSScriptRoot "..")).FullName
$VariablesPath = Join-Path (Join-Path $RepoRoot "build-support") "variables"

if (-not (Test-Path $VariablesPath)) {
    Write-Error "Build variables not found: $VariablesPath. Create build-support/variables or set AUTOBUILD_VARIABLES_FILE."
}
if (-not $env:AUTOBUILD_VARIABLES_FILE) {
    $env:AUTOBUILD_VARIABLES_FILE = $VariablesPath
    Write-Host "Using AUTOBUILD_VARIABLES_FILE=$env:AUTOBUILD_VARIABLES_FILE"
}

# Ensure autobuild is on PATH (pip may install to user Scripts when not run as admin).
if (-not (Get-Command autobuild -ErrorAction SilentlyContinue)) {
    $candidates = @(
        (python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null),
        (python -c "import autobuild, os; p=os.path.dirname(autobuild.__file__); print(os.path.join(os.path.dirname(os.path.dirname(p)), 'Scripts'))" 2>$null)
    )
    foreach ($dir in $candidates) {
        if ($dir -and (Test-Path (Join-Path $dir "autobuild.exe"))) {
            $env:Path = "$dir;$env:Path"
            Write-Host "Prepending Python Scripts to PATH: $dir"
            break
        }
    }
}

# Prefer explicit VSVER; otherwise detect highest VS via vswhere. Use 2-digit major + 0 (e.g. 17 -> 170, 18 -> 180); autobuild expects that convention.
if (-not $env:AUTOBUILD_VSVER) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $versionLine = & $vswhere -all -products "*" -requires "Microsoft.Component.MSBuild" -property installationVersion 2>$null | Select-Object -Last 1
        if ($versionLine -match '^(\d+)\.(\d)') {
            $major = [int]$Matches[1]
            $env:AUTOBUILD_VSVER = ("$major" + "0").Trim()
            Write-Host "Detected Visual Studio $major.x -> AUTOBUILD_VSVER=$env:AUTOBUILD_VSVER"
        }
    }
    if (-not $env:AUTOBUILD_VSVER) {
        $env:AUTOBUILD_VSVER = "170"
        Write-Host "Defaulting AUTOBUILD_VSVER=170 (Visual Studio 2022). Set AUTOBUILD_VSVER=180 for VS 2026."
    }
}

Push-Location $RepoRoot
try {
    Write-Host "Configuring (ReleaseFS_open, 64-bit)..."
    & autobuild configure -A 64 -c ReleaseFS_open
    if ($LASTEXITCODE -ne 0) { throw "autobuild configure failed with exit code $LASTEXITCODE" }

    Write-Host "Building..."
    & autobuild build -A 64 -c ReleaseFS_open --no-configure
    if ($LASTEXITCODE -ne 0) { throw "autobuild build failed with exit code $LASTEXITCODE" }

    Write-Host "Build completed. Solution: $RepoRoot\build-vc$env:AUTOBUILD_VSVER-64\Firestorm.sln"
} finally {
    Pop-Location
}
