$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "Flutter is required. Install Flutter 3.47 or newer and put it on PATH."
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python is required once for platform setup."
}

$Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("salah_focus_" + [System.Guid]::NewGuid())
try {
    flutter create --platforms=android,ios --org com.salahfocus --project-name salah_focus (Join-Path $Temp "salah_focus")
    Remove-Item -Recurse -Force android, ios -ErrorAction SilentlyContinue
    Copy-Item -Recurse (Join-Path $Temp "salah_focus/android") ./android
    Copy-Item -Recurse (Join-Path $Temp "salah_focus/ios") ./ios
    python tool/apply_platform_setup.py
    flutter pub get
    flutter analyze
    flutter test
    Write-Host "SalahFocus is ready. Run: flutter run"
}
finally {
    Remove-Item -Recurse -Force $Temp -ErrorAction SilentlyContinue
}
