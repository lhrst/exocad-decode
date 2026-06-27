$ErrorActionPreference='Continue'
function Log($m){Write-Host("==== "+$m+" ====")}
Set-MpPreference -DisableRealtimeMonitoring $true -EA SilentlyContinue
Add-MpPreference -ExclusionPath "C:\" -EA SilentlyContinue
Get-Process|?{$_.Name -match 'curl|gonogo'}|Stop-Process -Force -EA SilentlyContinue
Remove-Item C:\b.zip,C:\B -Recurse -Force -EA SilentlyContinue
New-Item -ItemType Directory -Force C:\work | Out-Null
Log "download bundle dlls (VC deps + DentalBase native deps)"
$mir=@("https://ghfast.top/","https://gh-proxy.com/","https://ghproxy.net/")
for($i=0;$i -lt 30;$i++){ & curl.exe -L -C - --retry 4 -m 300 -o C:\b.zip ($mir[$i%3]+"https://github.com/lhrst/exocad-decode/releases/download/v2/exobundle.zip"); if((Test-Path C:\b.zip)-and(Get-Item C:\b.zip).Length -ge 73000000){break}; Start-Sleep 2 }
Start-Sleep 2; Expand-Archive C:\b.zip C:\B -Force
Copy-Item C:\B\dlls\*.dll C:\work -Force
Log "download de-netified DLL"
for($i=0;$i -lt 30;$i++){ & curl.exe -L -C - --retry 4 -m 300 -o C:\work\DBN_native.dll ($mir[$i%3]+"https://github.com/lhrst/exocad-decode/releases/download/v4/DBN_native.dll"); if((Test-Path C:\work\DBN_native.dll)-and(Get-Item C:\work\DBN_native.dll).Length -ge 20000000){break}; Start-Sleep 2 }
Write-Host("DBN_native.dll size: "+(Get-Item C:\work\DBN_native.dll).Length)
Log "install VC2013"
Start-Process C:\B\vcredist_2013u1_x64.exe -ArgumentList "/quiet","/norestart" -Wait
Log "compile + run go/no-go (pure native LoadLibrary)"
for($i=0;$i -lt 10;$i++){ & curl.exe -s -L -o C:\work\gonogo.cs ($mir[$i%3]+"https://raw.githubusercontent.com/lhrst/exocad-decode/main/gonogo.cs"); if((Test-Path C:\work\gonogo.cs)-and(Get-Item C:\work\gonogo.cs).Length -gt 500){break}; Start-Sleep 1 }
Set-Location C:\work
& C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:gonogo.exe gonogo.cs
& .\gonogo.exe
Log "DONE"
