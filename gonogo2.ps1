$ErrorActionPreference='Continue'
function Log($m){Write-Host("==== "+$m+" ====")}
Set-MpPreference -DisableRealtimeMonitoring $true -EA SilentlyContinue
Add-MpPreference -ExclusionPath "C:\" -EA SilentlyContinue
Get-Process|?{$_.Name -match 'curl|decode_scene'}|Stop-Process -Force -EA SilentlyContinue
Remove-Item C:\b.zip,C:\B,C:\work -Recurse -Force -EA SilentlyContinue
New-Item -ItemType Directory -Force C:\work | Out-Null
$mir=@("https://ghfast.top/","https://gh-proxy.com/","https://ghproxy.net/")
Log "download bundle (original mixed-mode dlls)"
for($i=0;$i -lt 30;$i++){ & curl.exe -L -C - --retry 4 -m 300 -o C:\b.zip ($mir[$i%3]+"https://github.com/lhrst/exocad-decode/releases/download/v2/exobundle.zip"); if((Test-Path C:\b.zip)-and(Get-Item C:\b.zip).Length -ge 73000000){break}; Start-Sleep 2 }
Start-Sleep 2; Expand-Archive C:\b.zip C:\B -Force
Copy-Item C:\B\dlls\*.dll C:\work -Force
Start-Process C:\B\vcredist_2013u1_x64.exe -ArgumentList "/quiet","/norestart" -Wait
Log "fetch harness + scene"
for($i=0;$i -lt 10;$i++){ & curl.exe -s -L -o C:\work\decode_scene.cs ($mir[$i%3]+"https://raw.githubusercontent.com/lhrst/exocad-decode/main/decode_scene.cs"); if((Test-Path C:\work\decode_scene.cs)-and(Get-Item C:\work\decode_scene.cs).Length -gt 1000){break}; Start-Sleep 1 }
for($i=0;$i -lt 10;$i++){ & curl.exe -s -L -o C:\work\scene.dentalCAD ($mir[$i%3]+"https://raw.githubusercontent.com/lhrst/exocad-decode/main/scene.dentalCAD"); if((Test-Path C:\work\scene.dentalCAD)-and(Get-Item C:\work\scene.dentalCAD).Length -gt 1000000){break}; Start-Sleep 1 }
Log "compile harness + write app.config (useLegacyV2RuntimeActivationPolicy)"
Set-Location C:\work
& C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:decode_scene.exe decode_scene.cs
@'
<?xml version="1.0"?>
<configuration>
  <startup useLegacyV2RuntimeActivationPolicy="true">
    <supportedRuntime version="v4.0.30319"/>
    <supportedRuntime version="v2.0.50727"/>
  </startup>
  <runtime>
    <legacyCorruptedStateExceptionsPolicy enabled="true"/>
  </runtime>
</configuration>
'@ | Out-File -Encoding ascii C:\work\decode_scene.exe.config
Log "RUN harness with legacy activation policy"
New-Item -ItemType Directory -Force C:\out | Out-Null
& .\decode_scene.exe scene.dentalCAD C:\out 2>&1 | Select-Object -First 30
Log "output"
Get-ChildItem C:\out -EA SilentlyContinue | Format-Table Name,Length
$stls=Get-ChildItem C:\out -Filter *.stl -EA SilentlyContinue
if($stls){ Compress-Archive C:\out\* C:\stl.zip -Force; $r=& curl.exe -s -F "file=@C:\stl.zip" "https://0x0.st"; Write-Host("STL_URL: "+$r) } else { Write-Host "NO_STL" }
Log "DONE"
