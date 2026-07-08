$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  Write-Host "== MoonBit toolchain =="
  moon version --all

  Write-Host "== Format check =="
  moon fmt --check

  Write-Host "== Build check =="
  moon check

  Write-Host "== Tests =="
  moon test

  Write-Host "== Examples =="
  moon run examples/basic
  moon run examples/windowed
  moon run examples/budget

  Write-Host "== MoonBit LOC =="
  $files = Get-ChildItem -Recurse -File | Where-Object {
    $_.Extension -eq ".mbt" -and $_.FullName -notmatch "[\\/]_build[\\/]"
  }
  $lines = ($files | ForEach-Object { (Get-Content $_.FullName).Count } | Measure-Object -Sum).Sum
  Write-Host "MoonBit files: $($files.Count)"
  Write-Host "MoonBit LOC: $lines"
}
finally {
  Pop-Location
}
