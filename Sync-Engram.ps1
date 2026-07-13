param (
    [Parameter(Mandatory=$false)]
    [string]$RemoteUser = "admin",

    [Parameter(Mandatory=$true)]
    [string]$RemoteHost,

    [Parameter(Mandatory=$false)]
    [string]$RemotePath = "/tmp",

    [Parameter(Mandatory=$false)]
    [string]$ExportFileLocal = "engram-local.json",

    [Parameter(Mandatory=$false)]
    [string]$ExportFileRemote = "engram-remote.json"
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "`n[1/6] Exportando Engram local..." -ForegroundColor Cyan
    engram export > $ExportFileLocal

    Write-Host "[2/6] Exportando Engram remoto..." -ForegroundColor Cyan
    ssh "${RemoteUser}@${RemoteHost}" "engram export > ${RemotePath}/${ExportFileRemote}"

    Write-Host "[3/6] Intercambiando archivos (Cross-Sync)..." -ForegroundColor Cyan
    # Enviamos el local a la remota
    scp $ExportFileLocal "${RemoteUser}@${RemoteHost}:${RemotePath}/${ExportFileLocal}"
    # Traemos el remoto a la local
    scp "${RemoteUser}@${RemoteHost}:${RemotePath}/${ExportFileRemote}" $ExportFileRemote

    Write-Host "[4/6] Importando datos remotos en la máquina local..." -ForegroundColor Cyan
    Get-Content -Raw $ExportFileRemote | engram import

    Write-Host "[5/6] Importando datos locales en la máquina remota..." -ForegroundColor Cyan
    ssh "${RemoteUser}@${RemoteHost}" "engram import < ${RemotePath}/${ExportFileLocal}"

    Write-Host "[6/6] Limpiando archivos temporales..." -ForegroundColor Cyan
    if (Test-Path $ExportFileLocal) { Remove-Item -Path $ExportFileLocal }
    if (Test-Path $ExportFileRemote) { Remove-Item -Path $ExportFileRemote }
    ssh "${RemoteUser}@${RemoteHost}" "rm ${RemotePath}/${ExportFileLocal} ${RemotePath}/${ExportFileRemote}"

    Write-Host "`n¡Sincronización bidireccional completada con éxito, loco! 🚀 Ambas máquinas están a la par." -ForegroundColor Green
}
catch {
    Write-Host "`n[ERROR] Falló la sincronización: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
