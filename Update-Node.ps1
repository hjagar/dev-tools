# 1. Detectar versión actual en uso
$versionActualRaw = node -v
$versionActual = $versionActualRaw.Trim().Replace('v', '')
Write-Host "Versión actual de Node.js detectada: v$versionActual" -ForegroundColor Cyan

# 2. Obtener la última LTS disponible desde NVM
Write-Host "Buscando la última versión LTS disponible..." -ForegroundColor Gray
$nvmAvailable = nvm list available
# Extraer la versión de la columna LTS (segunda columna)
$lineaVersion = ($nvmAvailable | Select-String "\|\s+\d+\.\d+\.\d+\s+\|\s+(\d+\.\d+\.\d+)\s+\|" | Select-Object -First 1).Matches[0].Groups[1].Value
$ultimaLTS = $lineaVersion

if ($ultimaLTS -eq $versionActual) {
    Write-Host "Ya estás usando la última versión LTS disponible (v$ultimaLTS)." -ForegroundColor Green
    exit
}

Write-Host "Nueva LTS encontrada: v$ultimaLTS" -ForegroundColor Yellow

# 3. Confirmación del usuario para proceder
$confirm = Read-Host "¿Deseas migrar tus paquetes de v$versionActual a v$ultimaLTS? (s/n)"
if ($confirm -ne 's') { Write-Host "Operación cancelada."; exit }

# 4. Listar paquetes globales actuales (excluyendo npm)
Write-Host "Obteniendo lista de paquetes globales..."
$paquetes = npm list -g --depth=0 --parseable | ForEach-Object { 
    if ($_ -match 'node_modules\\(.+)$') {
        $name = $matches[1] -replace '\\', '/'
        if ($name -and $name -notmatch '^npm$') { $name }
    }
}

# 5. Instalación y Cambio
Write-Host "Instalando Node v$ultimaLTS..." -ForegroundColor Cyan
nvm install $ultimaLTS
nvm use $ultimaLTS

# 6. Reinstalar paquetes
if ($paquetes) {
    Write-Host "Reinstalando $($paquetes.Count) paquetes globales..." -ForegroundColor Cyan
    foreach ($pkg in $paquetes) {
        Write-Host "-> Instalando $pkg..." -ForegroundColor Gray
        npm install -g $pkg
    }
} else {
    Write-Host "No hay paquetes globales adicionales para migrar."
}

Write-Host "`n--- Proceso completado: Ahora estás en v$ultimaLTS ---" -ForegroundColor Green
