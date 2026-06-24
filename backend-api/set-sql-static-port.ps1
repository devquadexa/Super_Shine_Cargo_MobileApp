# Run this ONCE as Administrator (right-click > Run with PowerShell, or run from an elevated terminal).
# It pins SQL Server Express (SQLEXPRESS) to a fixed TCP port 53181 so the backend
# connection stays stable across SQL Server restarts, then updates backend-api\.env to match.

$ErrorActionPreference = 'Stop'

# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Please run this script as Administrator." -ForegroundColor Red
    exit 1
}

$staticPort = '53181'

# Resolve the SQLEXPRESS instance registry path
$instanceId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').SQLEXPRESS
$tcpKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instanceId\MSSQLServer\SuperSocketNetLib\Tcp"

Write-Host "Instance: $instanceId"
Write-Host "Setting static TCP port $staticPort on IPAll..."

# Enable TCP protocol and set a static port (clear dynamic port)
Set-ItemProperty $tcpKey -Name Enabled -Value 1
Set-ItemProperty "$tcpKey\IPAll" -Name TcpPort -Value $staticPort
Set-ItemProperty "$tcpKey\IPAll" -Name TcpDynamicPorts -Value ""

Write-Host "Restarting MSSQL`$SQLEXPRESS service..."
Restart-Service 'MSSQL$SQLEXPRESS' -Force

# Update backend-api\.env DB_PORT to the static port
$envPath = Join-Path $PSScriptRoot '.env'
if (Test-Path $envPath) {
    (Get-Content $envPath) -replace '^DB_PORT=.*', "DB_PORT=$staticPort" | Set-Content $envPath
    Write-Host "Updated $envPath -> DB_PORT=$staticPort"
}

Write-Host "Done. SQL Server is now listening on static port $staticPort." -ForegroundColor Green
