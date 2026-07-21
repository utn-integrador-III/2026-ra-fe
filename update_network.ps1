# Obtener IP de WSL automáticamente
$wslIP = wsl hostname -I | ForEach-Object { $_.Trim().Split(' ')[0] }

# Actualizar portproxy
netsh interface portproxy reset
netsh interface portproxy add v4tov4 listenport=8000 listenaddress=0.0.0.0 connectport=8000 connectaddress=$wslIP
New-NetFirewallRule -DisplayName "PathAR 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -Profile Any -ErrorAction SilentlyContinue

Write-Host "✓ Portproxy actualizado → WSL IP: $wslIP"
Write-Host "✓ Ahora actualizá el .env de Flutter con la IP de Windows (ipconfig)"