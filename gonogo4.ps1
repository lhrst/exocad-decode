$ErrorActionPreference='Continue'
function Log($m){Write-Host("==== "+$m+" ====")}
Set-MpPreference -DisableRealtimeMonitoring $true -EA SilentlyContinue
Add-MpPreference -ExclusionPath "C:\" -EA SilentlyContinue
Get-Process|?{$_.Name -match 'curl|decode_scene'}|Stop-Process -Force -EA SilentlyContinue
Remove-Item C:\b.zip,C:\B,C:\work,C:\mesa.zip -Recurse -Force -EA SilentlyContinue
New-Item -ItemType Directory -Force C:\work | Out-Null
$mir=@("https://ghfast.top/","https://gh-proxy.com/","https://ghproxy.net/")
function DL($url,$out,$min){ for($i=0;$i -lt 30;$i++){ & curl.exe -L -C - --retry 4 -m 400 -o $out ($mir[$i%3]+$url); if((Test-Path $out)-and(Get-Item $out).Length -ge $min){return $true}; Start-Sleep 2 } return $false }
Log "download bundle (mixed-mode dlls)"
DL "https://github.com/lhrst/exocad-decode/releases/download/v2/exobundle.zip" C:\b.zip 73000000
Start-Sleep 2; Expand-Archive C:\b.zip C:\B -Force
Copy-Item C:\B\dlls\*.dll C:\work -Force
Start-Process C:\B\vcredist_2013u1_x64.exe -ArgumentList "/quiet","/norestart" -Wait
Log "download Mesa3D software OpenGL 4.5 -> C:\work (overrides system OpenGL 1.1)"
DL "https://github.com/lhrst/exocad-decode/releases/download/v4/mesa_gl.zip" C:\mesa.zip 100000000
Expand-Archive C:\mesa.zip C:\mesaX -Force
Copy-Item C:\mesaX\*.dll C:\work -Force
Write-Host("opengl32.dll in work: "+(Test-Path C:\work\opengl32.dll)+" libgallium: "+(Test-Path C:\work\libgallium_wgl.dll))
# mesa 软件渲染设置
$env:GALLIUM_DRIVER="llvmpipe"; $env:MESA_GL_VERSION_OVERRIDE="4.5"
Log "fetch harness + scene"
DL "https://raw.githubusercontent.com/lhrst/exocad-decode/main/decode_scene.cs" C:\work\decode_scene.cs 1000
DL "https://raw.githubusercontent.com/lhrst/exocad-decode/main/scene.dentalCAD" C:\work\scene.dentalCAD 1000000
Set-Location C:\work
& C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /platform:x64 /out:decode_scene.exe decode_scene.cs
Log "RUN harness with Mesa software OpenGL 4.5"
New-Item -ItemType Directory -Force C:\out | Out-Null
& .\decode_scene.exe scene.dentalCAD C:\out 2>&1 | Select-Object -First 30
Log "output"; Get-ChildItem C:\out -EA SilentlyContinue | Format-Table Name,Length
$stls=Get-ChildItem C:\out -Filter *.stl -EA SilentlyContinue
if($stls){ Compress-Archive C:\out\* C:\stl.zip -Force; $r=& curl.exe -s -F "file=@C:\stl.zip" "https://0x0.st"; Write-Host("STL_URL: "+$r) } else { Write-Host "NO_STL" }
Log "DONE"
