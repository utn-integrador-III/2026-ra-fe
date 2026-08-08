@echo off
title PathAR - Actualizar Red
echo ==========================================
echo    PathAR - Configurar acceso al backend
echo ==========================================
echo.

:: Verificar que corre como Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Ejecuta este archivo como Administrador
    echo Click derecho ^> Ejecutar como administrador
    pause
    exit /b 1
)

:: Obtener IP de WSL
echo Obteniendo IP de WSL...
for /f "tokens=1" %%i in ('wsl hostname -I') do set WSLIP=%%i
echo IP de WSL: %WSLIP%
echo.

:: Obtener IP de Windows en WiFi actual
echo Obteniendo IP de Windows...
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4" ^| findstr /v "172.26" ^| findstr /v "127.0.0.1"') do (
    set WINIP=%%a
    goto :gotwinip
)
:gotwinip
:: Limpiar espacios
set WINIP=%WINIP: =%
echo IP de Windows: %WINIP%
echo.

:: Limpiar portproxy anterior
netsh interface portproxy reset >nul 2>&1

:: Crear nuevo portproxy
netsh interface portproxy add v4tov4 listenport=8000 listenaddress=0.0.0.0 connectport=8000 connectaddress=%WSLIP%

:: Firewall
powershell -Command "Remove-NetFirewallRule -DisplayName 'PathAR 8000' -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'PathAR 8000' -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -Profile Any" >nul 2>&1

:: Actualizar .env de Flutter automáticamente
set ENVFILE=C:\Users\quesa\Documents\GitHub\2026-ra-fe\.env
if exist "%ENVFILE%" (
    powershell -Command "(Get-Content '%ENVFILE%') -replace 'API_URL=.*', 'API_URL=http://%WINIP%:8000' | Set-Content '%ENVFILE%'"
    echo .env actualizado automaticamente
) else (
    echo AVISO: No se encontro el .env en %ENVFILE%
    echo Actualizalo manualmente con: API_URL=http://%WINIP%:8000
)

echo.
echo ==========================================
echo  Configuracion completada
echo.
echo  WSL IP:     %WSLIP%
echo  Windows IP: %WINIP%
echo  API URL:    http://%WINIP%:8000
echo.
echo  Ahora levanta uvicorn en WSL:
echo  uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
echo ==========================================
echo.
pause