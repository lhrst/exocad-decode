# 全自动: 下 70MB bundle(DLL+crack) -> 部署破解(Injektor驱动注入) -> 编译harness -> 解码 -> 上传STL
$ErrorActionPreference = 'Continue'
function Log($m){ Write-Host ("==== " + $m + " ====") }
Set-Location C:\

Log "download bundle (70MB from github release)"
$burl = "https://ghfast.top/https://github.com/lhrst/exocad-decode/releases/download/v1/exobundle.zip"
for ($i=0; $i -lt 30; $i++) {
  & curl.exe -L -C - --retry 8 --retry-all-errors -o C:\b.zip $burl
  if ((Test-Path C:\b.zip) -and (Get-Item C:\b.zip).Length -ge 73000000) { break }
  Start-Sleep 3
}
Write-Host ("bundle size: " + (Get-Item C:\b.zip).Length)

Log "extract bundle"
Expand-Archive -Path C:\b.zip -DestinationPath C:\B -Force

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
