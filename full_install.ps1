# 阶段1: 完整安装 exocad + 部署破解 + Injektor, 然后跑 DentalCADApp.exe 验证 native init
$ErrorActionPreference = 'Continue'
function Log($m){ Write-Host ("==== " + $m + " ====") }
Set-Location C:\

Log "disable Defender"
Set-MpPreference -DisableRealtimeMonitoring $true -EA SilentlyContinue
Set-MpPreference -DisableIOAVProtection $true -EA SilentlyContinue
Add-MpPreference -ExclusionPath "C:\" -EA SilentlyContinue
Get-Process | Where-Object { $_.Name -match 'DentalCAD|Injektor|curl|ModelCreator|ExoViewer' } | Stop-Process -Force -EA SilentlyContinue

Log "install 7zip"
$sz = "C:\Program Files\7-Zip\7z.exe"
if (!(Test-Path $sz)) {
  curl.exe -L -m 120 -o C:\7z.exe "https://www.7-zip.org/a/7z2408-x64.exe"
  Start-Process C:\7z.exe -ArgumentList "/S" -Wait
}

Log "download 3 parts (multi-mirror) + merge"
$mirrors = @("https://ghfast.top/","https://gh-proxy.com/","https://ghproxy.net/")
$parts = @("exo.part_aa","exo.part_ab","exo.part_ac")
$minsz = @(1700000000,1700000000,700000000)
for ($k=0; $k -lt 3; $k++) {
  $p = $parts[$k]; $ok=$false
  for ($i=0; $i -lt 30 -and -not $ok; $i++) {
    $m = $mirrors[$i % 3]
    & curl.exe -L -C - --retry 5 --retry-all-errors -m 600 -o "C:\$p" ($m + "https://github.com/lhrst/exocad-decode/releases/download/v3/" + $p)
    if (Test-Path "C:\$p") { $cs = (Get-Item "C:\$p").Length } else { $cs = 0 }
    Write-Host ($p + " try " + $i + " [" + $m + "]: " + $cs)
    if ($cs -ge $minsz[$k]) { $ok=$true }
    else { Start-Sleep 2 }
  }
  if (-not $ok) { throw ("part failed: " + $p) }
}
cmd /c "copy /b C:\exo.part_aa+C:\exo.part_ab+C:\exo.part_ac C:\exocad.rar"
Write-Host ("rar size: " + (Get-Item C:\exocad.rar).Length + " (expect 4556048566)")

Log "extract full exocad"
Remove-Item C:\EXO -Recurse -Force -EA SilentlyContinue
& $sz x C:\exocad.rar -oC:\EXO -y | Out-Null
$root = "C:\EXO\exocad-DentalCAD3.0-2021-03-25"
Write-Host ("DentalCADApp.exe exists: " + (Test-Path "$root\DentalCADApp\bin\config\bin\DentalCADApp.exe"))

Log "install VC2013"
Get-ChildItem -Recurse $root -Filter vcredist_2013u1_x64.exe -EA SilentlyContinue | Select -First 1 | ForEach-Object { Start-Process $_.FullName -ArgumentList "/quiet","/norestart" -Wait }

Log "deploy crack + Injektor service"
$crack = "$root\!ldrg"
$appdata = "$env:LOCALAPPDATA\DentalCAD"
New-Item -ItemType Directory -Force $appdata | Out-Null
if (Test-Path "$crack\DentalCAD") { Copy-Item "$crack\DentalCAD\*" $appdata -Recurse -Force -EA SilentlyContinue }
Push-Location $crack
Start-Process ".\Injektor.exe" -ArgumentList "-I" -Wait -NoNewWindow
Pop-Location
Start-Sleep 5
sc.exe start Injektor 2>&1 | Out-Host
Start-Sleep 5
& sc.exe query Injektor | Out-Host
Start-Sleep 20

$bin = "$root\DentalCADApp\bin\config\bin"

Log "TEST A: harness in FULL exocad bin dir (native init may need full install files)"
curl.exe -L -m 60 -o "$bin\decode_scene.cs" "https://ghfast.top/https://raw.githubusercontent.com/lhrst/exocad-decode/main/decode_scene.cs"
curl.exe -L -m 60 -o "$bin\scene.dentalCAD" "https://ghfast.top/https://raw.githubusercontent.com/lhrst/exocad-decode/main/scene.dentalCAD"
& C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:"$bin\decode_scene.exe" "$bin\decode_scene.cs"
New-Item -ItemType Directory -Force C:\out | Out-Null
Set-Location $bin
& ".\decode_scene.exe" scene.dentalCAD C:\out 2>&1 | Select-Object -First 25
Log "harness output"
Get-ChildItem C:\out -EA SilentlyContinue | Format-Table Name,Length

Log "TEST B: run DentalCADApp.exe (native exe) to see if native init passes"
Set-Location $bin
$proc = Start-Process ".\DentalCADApp.exe" -PassThru
Start-Sleep 25
if ($proc.HasExited) { Write-Host ("DentalCADApp EXITED code: " + $proc.ExitCode) }
else { Write-Host "DentalCADApp STILL RUNNING (native init OK)"; Stop-Process -Id $proc.Id -Force -EA SilentlyContinue }

Log "upload STL if any"
$stls = Get-ChildItem C:\out -Filter *.stl -EA SilentlyContinue
if ($stls -and $stls.Count -gt 0) {
  Compress-Archive -Path C:\out\* -DestinationPath C:\stl.zip -Force
  $r = & curl.exe -s -F "file=@C:\stl.zip" "https://0x0.st"
  Write-Host ("STL_URL: " + $r)
} else { Write-Host "NO_STL (harness native init still failed in full env)" }
Log "DONE"
