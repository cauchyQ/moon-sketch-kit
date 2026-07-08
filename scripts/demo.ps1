$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  Write-Host "== Overall report =="
  moon run cmd/main -- report "login view login cart checkout login refund"

  Write-Host "== Windowed report =="
  moon run cmd/main -- windows "login login view | view cart cart checkout | checkout refund refund"

  Write-Host "== Weighted report =="
  moon run cmd/main -- weighted "login:12 view:7 checkout:3 refund:1"

  Write-Host "== Numeric summaries =="
  moon run cmd/main -- histogram "12 18 21 21 35 89" 0 100 10
  moon run cmd/main -- quantile "12 18 21 21 35 89"

  Write-Host "== Budget plan =="
  moon run cmd/main -- budget "login view login cart checkout refund user42 user43" 6
}
finally {
  Pop-Location
}
