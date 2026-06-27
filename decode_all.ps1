# 全自动: 下 70MB bundle(DLL+crack) -> 部署破解(Injektor驱动注入) -> 编译harness -> 解码 -> 上传STL
$ErrorActionPreference = 'Continue'
function Log($m){ Write-Host ("==== " + $m + " ====") }
Set-Location C:\

Log "cleanup stale processes/files"
Get-Process | Where-Object { $_.Name -match 'curl|decode_scene' } | Stop-Process -Force -EA SilentlyContinue
Start-Sleep 2
Remove-Item C:\b.zip,C:\B -Recurse -Force -EA SilentlyContinue

Log "download bundle (70MB, multi-mirror)"
$rel = "https://github.com/lhrst/exocad-decode/releases/download/v2/exobundle.zip"
$mirrors = @("https://ghfast.top/","https://gh-proxy.com/","https://ghproxy.net/","")
$ok = $false
for ($i=0; $i -lt 40 -and -not $ok; $i++) {
  $m = $mirrors[$i % $mirrors.Count]
  & curl.exe -L -C - --retry 4 --retry-all-errors -m 300 -o C:\b.zip ($m + $rel)
  if (Test-Path C:\b.zip) { $sz = (Get-Item C:\b.zip).Length } else { $sz = 0 }
  Write-Host ("try " + $i + " via [" + $m + "]: " + $sz)
  if ($sz -ge 73000000) { $ok = $true; break }
  Start-Sleep 2
}
if (-not $ok) { throw "bundle download failed all mirrors" }
Write-Host ("bundle size: " + (Get-Item C:\b.zip).Length)

Log "extract bundle (with retry)"
Start-Sleep 3
for ($e=0; $e -lt 6; $e++) {
  try { Expand-Archive -Path C:\b.zip -DestinationPath C:\B -Force; if (Test-Path C:\B\dlls) { break } }
  catch { Write-Host ("extract retry " + $e + ": " + $_.Exception.Message); Start-Sleep 3 }
}
Write-Host ("C:\B\dlls exists: " + (Test-Path C:\B\dlls))

Log "install VC2013 runtime"
Start-Process "C:\B\vcredist_2013u1_x64.exe" -ArgumentList "/quiet","/norestart" -Wait

Log "deploy crack + install Injektor service (kernel global-inject)"
$crack = "C:\B\ldrg"
$appdata = "$env:LOCALAPPDATA\DentalCAD"
New-Item -ItemType Directory -Force $appdata | Out-Null
if (Test-Path "$crack\DentalCAD") { Copy-Item "$crack\DentalCAD\*" $appdata -Recurse -Force -EA SilentlyContinue }
Push-Location $crack
Start-Process ".\Injektor.exe" -ArgumentList "-I" -Wait -NoNewWindow
Pop-Location
Start-Sleep 12
sc.exe query | Select-String -Pattern "Mitigation","njekt"

Log "setup working dir (dlls + harness + scene)"
$bin = "C:\work"
New-Item -ItemType Directory -Force $bin | Out-Null
Copy-Item "C:\B\dlls\*.dll" $bin -Force
curl.exe -L -o "$bin\decode_scene.cs" "https://ghfast.top/https://raw.githubusercontent.com/lhrst/exocad-decode/main/decode_scene.cs"
curl.exe -L -o "$bin\scene.dentalCAD" "https://ghfast.top/https://raw.githubusercontent.com/lhrst/exocad-decode/main/scene.dentalCAD"

Log "compile harness"
& C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:"$bin\decode_scene.exe" "$bin\decode_scene.cs"

Log "run decode"
New-Item -ItemType Directory -Force C:\out | Out-Null
Set-Location $bin
& ".\decode_scene.exe" scene.dentalCAD C:\out
Log "decode output"
Get-ChildItem C:\out | Format-Table Name,Length

Log "upload STL"
$stls = Get-ChildItem C:\out -Filter *.stl -EA SilentlyContinue
if ($stls -and $stls.Count -gt 0) {
  Compress-Archive -Path C:\out\* -DestinationPath C:\stl.zip -Force
  $r = & curl.exe -s -F "file=@C:\stl.zip" "https://0x0.st"
  Write-Host ("STL_URL: " + $r)
} else {
  Write-Host "NO_STL_GENERATED"
}
Log "DONE"
