# Build Firestorm on Windows using only PowerShell + cmd: cmake and MSBuild, no bash.
# Uses D:\src\grid\fs-build-variables by default; CopyBot/Darkstorm and draw distance are in source (TOGGLE_HACKED_GODLIKE_VIEWER=1).
# Requires: CMake and Visual Studio on PATH (or in VS install), Git.

$ErrorActionPreference = "Stop"
$RepoRoot = (Get-Item (Join-Path $PSScriptRoot "..")).FullName
$VariablesFile = $env:AUTOBUILD_VARIABLES_FILE
if (-not $VariablesFile) {
    $VariablesFile = Join-Path (Join-Path $RepoRoot "build-support") "variables"
    if (-not (Test-Path $VariablesFile)) {
        $VariablesFile = "D:\src\grid\fs-build-variables\variables"
    }
    $env:AUTOBUILD_VARIABLES_FILE = $VariablesFile
}
Write-Host "AUTOBUILD_VARIABLES_FILE=$env:AUTOBUILD_VARIABLES_FILE"

# Parse variables file and resolve LL_BUILD_WINDOWS_RELEASEFS_OPEN -> LL_BUILD for cmake
$varFile = $env:AUTOBUILD_VARIABLES_FILE
if (-not (Test-Path $varFile)) { Write-Error "Variables file not found: $varFile" }
$vars = @{}
foreach ($line in (Get-Content $varFile -Raw) -split "`n") {
    $line = $line.Trim()
    if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)="(.*)"$') {
        $vars[$Matches[1]] = $Matches[2]
    }
}
# Resolve $VAR and ${VAR} references (multiple passes)
for ($pass = 0; $pass -lt 20; $pass++) {
    $changed = $false
    foreach ($k in @($vars.Keys)) {
        $v = $vars[$k]
        $newV = [regex]::Replace($v, '\$([A-Za-z_][A-Za-z0-9_]*)|\$\{([A-Za-z_][A-Za-z0-9_]*)\}', { param($m) $name = if ($m.Groups[1].Value) { $m.Groups[1].Value } else { $m.Groups[2].Value }; if ($vars.ContainsKey($name)) { $vars[$name] } else { $m.Value } })
        if ($newV -ne $v) { $vars[$k] = $newV; $changed = $true }
    }
    if (-not $changed) { break }
}
$LL_BUILD = $vars["LL_BUILD_WINDOWS_RELEASEFS_OPEN"]
if (-not $LL_BUILD) { Write-Error "LL_BUILD_WINDOWS_RELEASEFS_OPEN not found in variables file." }
$env:LL_BUILD = $LL_BUILD

# Detect Visual Studio via vswhere (use 2-digit major + 0 for autobuild convention)
$VSVER = $env:AUTOBUILD_VSVER
if (-not $VSVER) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $versionLine = & $vswhere -all -products "*" -requires "Microsoft.Component.MSBuild" -property installationVersion 2>$null | Select-Object -Last 1
        if ($versionLine -match '^(\d+)\.') {
            $major = [int]$Matches[1]
            $VSVER = ("$major" + "0").Trim()
            $env:AUTOBUILD_VSVER = $VSVER
        }
    }
    if (-not $VSVER) { $VSVER = "170"; $env:AUTOBUILD_VSVER = $VSVER }
}
Write-Host "AUTOBUILD_VSVER=$VSVER"

# VS installation path for vcvarsall.bat
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsMajor = $VSVER.Substring(0, [Math]::Min(2, $VSVER.Length))
$versionRange = "[$($vsMajor).0,$([int]$vsMajor+1).0)"
$vsPath = & $vswhere -version $versionRange -products "*" -requires "Microsoft.Component.MSBuild" -property installationPath 2>$null | Select-Object -First 1
if (-not $vsPath -or -not (Test-Path $vsPath)) {
    Write-Error "Visual Studio not found for version $VSVER. Install VS or set AUTOBUILD_VSVER."
}
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
if (-not (Test-Path $vcvars)) {
    Write-Error "vcvarsall.bat not found: $vcvars"
}

# CMake generator: "Visual Studio 17 2022" or "Visual Studio 18 2026"
$genMap = @{ "17" = "Visual Studio 17 2022"; "18" = "Visual Studio 18 2026" }
$genKey = $VSVER.Substring(0, [Math]::Min(2, $VSVER.Length))
$CMAKE_GEN = $genMap[$genKey]
if (-not $CMAKE_GEN) { $CMAKE_GEN = "Visual Studio 17 2022" }

$BuildDir = Join-Path $RepoRoot "build-vc$VSVER-64"
$IndraDir = Join-Path $RepoRoot "indra"
$AddrSize = "64"
$BTYPE = "Release"

# Version info (git)
Push-Location $RepoRoot
try {
    $buildVer = & git rev-list --count HEAD 2>$null; if (-not $buildVer) { $buildVer = "0" }
    $gitHash = & git describe --always --exclude '*' 2>$null; if (-not $gitHash) { $gitHash = "unknown" }
    $verLine = Get-Content (Join-Path $RepoRoot "indra\newview\VIEWER_VERSION.txt") -Raw
    $vParts = $verLine.Trim().Split('.')
    $majorVer = $vParts[0]; $minorVer = $vParts[1]; $patchVer = $vParts[2]
    $base = "private-$env:COMPUTERNAME"
    $base = $base -replace '[^a-zA-Z0-9\-]', ''
    $channel = "Firestorm-$base"
    Write-Host "Channel: $channel  Version: $majorVer.$minorVer.$patchVer.$buildVer [$gitHash]"
} finally {
    Pop-Location
}

# Create build dir; remove CMake cache AND packages to avoid "Package 'webrtc' attempts to install files already installed"
if (Test-Path $BuildDir) {
    Remove-Item (Join-Path $BuildDir "CMakeCache.txt") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $BuildDir "CMakeFiles") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $BuildDir "packages") -Recurse -Force -ErrorAction SilentlyContinue
}
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}
$logsDir = Join-Path $BuildDir "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# ReleaseFS_open: no KDU, no FMOD, OpenSim ON (CopyBot/Darkstorm and draw distance are in source)
$cmakeArgs = "-G `"$CMAKE_GEN`" -A x64 `"$IndraDir`" -DUNATTENDED=ON -DLL_TESTS=OFF -DADDRESS_SIZE=$AddrSize -DCMAKE_BUILD_TYPE=$BTYPE -DUSE_KDU=OFF -DUSE_FMODSTUDIO=OFF -DOPENAL=OFF -DOPENSIM=ON -DSINGLEGRID=OFF -DHAVOK_TPV=OFF -DUSE_AVX_OPTIMIZATION=OFF -DUSE_AVX2_OPTIMIZATION=OFF -DUSE_TRACY=OFF -DTESTBUILD=OFF -DPACKAGE=OFF -DRELEASE_CRASH_REPORTING=OFF -DVIEWER_CHANNEL:STRING=`"$channel`" -DVIEWER_VERSION_GITHASH:STRING=`"$gitHash`""

Write-Host "Configuring (ReleaseFS_open, 64-bit) in $BuildDir ..."
$batch = @"
@echo off
call "$vcvars" x64
cd /d "$BuildDir"
cmake $cmakeArgs
exit /b %ERRORLEVEL%
"@
$batchPath = [System.IO.Path]::GetTempFileName() + ".cmd"
$batch | Out-File -FilePath $batchPath -Encoding ASCII
try {
    & cmd /c $batchPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "cmake configure failed. Ensure CMake is on PATH (e.g. 'C:\Program Files\CMake\bin')."
    }
} finally {
    Remove-Item $batchPath -Force -ErrorAction SilentlyContinue
}

$sln = Join-Path $BuildDir "Firestorm.sln"
$slnx = Join-Path $BuildDir "Firestorm.slnx"
$solution = if (Test-Path $slnx) { $slnx } elseif (Test-Path $sln) { $sln } else { $null }
if (-not $solution) {
    Write-Error "No Firestorm.sln or Firestorm.slnx found in $BuildDir"
}

Write-Host "Building..."
$platform = "x64"
$msbuildCmd = "call `"$vcvars`" x64 && cd /d `"$BuildDir`" && msbuild `"$solution`" -p:Configuration=$BTYPE -p:Platform=$platform -t:Build -p:useenv=true -verbosity:minimal"
$result = cmd /c $msbuildCmd
if ($LASTEXITCODE -ne 0) {
    Write-Error "msbuild failed with exit code $LASTEXITCODE"
}

Write-Host "Build completed. Viewer: $BuildDir\newview\$BTYPE\Firestorm.exe"
Write-Host "CopyBot/Darkstorm: enabled in source (TOGGLE_HACKED_GODLIKE_VIEWER=1). Use Advanced -> Hacked Godmode in-world."
