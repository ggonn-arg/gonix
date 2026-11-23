# ============================================================
#  Mantenimiento.ps1 - Limpieza, reparación, Windows Update,
#                      desinstalador de apps e instalador (winget)
# ============================================================

# ------------------------------------------------------------
#  Limpieza de archivos temporales
# ------------------------------------------------------------
function Get-FolderSize {
    param([string]$Ruta)
    if (-not (Test-Path -LiteralPath $Ruta)) { return [int64]0 }
    $m = Get-ChildItem -LiteralPath $Ruta -Recurse -Force -File -ErrorAction SilentlyContinue |
         Measure-Object -Property Length -Sum
    return [int64]($m.Sum)
}

function Clear-FolderContents {
    param([string]$Ruta)
    if (-not (Test-Path -LiteralPath $Ruta)) { return }
    foreach ($i in @(Get-ChildItem -LiteralPath $Ruta -Force -ErrorAction SilentlyContinue)) {
        # Nunca borrar la carpeta desde la que corre Gonix (modo "una línea")
        if ($script:GonixRoot.StartsWith($i.FullName, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($i.Name -like 'gonix_*') { continue }
        Remove-Item -LiteralPath $i.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Cleanup {
    Write-Banner
    Write-Host '   --- Limpieza de archivos temporales ---' -ForegroundColor Magenta
    Write-Host ''
    Write-Info 'Calculando tamaño...'
    $objetivos = @(
        [pscustomobject]@{ Nombre = 'Temporales del usuario'; Ruta = $env:TEMP }
        [pscustomobject]@{ Nombre = 'Temporales de Windows';  Ruta = (Join-Path $env:windir 'Temp') }
    )
    $total = [int64]0
    foreach ($o in $objetivos) {
        $o | Add-Member -NotePropertyName Bytes -NotePropertyValue (Get-FolderSize $o.Ruta)
        $total += $o.Bytes
        Write-Host ('   - {0,-26} {1,8:N1} MB' -f $o.Nombre, ($o.Bytes / 1MB)) -ForegroundColor White
    }
    Write-Host '   - Papelera de reciclaje' -ForegroundColor White
    Write-Host ''
    Write-Info 'Los archivos en uso se omiten. Esta limpieza no se puede deshacer.'
    if (-not (Confirm-Gonix '¿Limpiar ahora?')) { Write-Warn 'Cancelado.'; return }

    foreach ($o in $objetivos) { Clear-FolderContents $o.Ruta }
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}

    $despues = [int64]0
    foreach ($o in $objetivos) { $despues += (Get-FolderSize $o.Ruta) }
    $liberado = [math]::Max(0, ($total - $despues)) / 1MB
    Write-Ok ('Listo. Se liberaron aproximadamente {0:N1} MB.' -f $liberado)
    Write-Log ('LIMPIEZA: {0:N1} MB liberados' -f $liberado)
}

# ------------------------------------------------------------
#  Reparación
# ------------------------------------------------------------
function Repair-NetworkSoft {
    Write-Info 'Limpiando caché DNS y renovando IP...'
    & ipconfig.exe /flushdns | Out-Null
    & ipconfig.exe /registerdns | Out-Null
    & ipconfig.exe /release | Out-Null
    & ipconfig.exe /renew | Out-Null
    Write-Ok 'Listo. Si seguís sin conexión, probá el reinicio completo de red.'
}

function Repair-NetworkFull {
    Write-Warn 'Esto reinicia Winsock y la pila TCP/IP. BORRA las IP estáticas configuradas'
    Write-Warn 'y puede requerir reconfigurar VPNs. Hace falta reiniciar después.'
    if (-not (Confirm-Gonix '¿Continuar?')) { Write-Warn 'Cancelado.'; return }
    & netsh.exe winsock reset | Out-Null
    & netsh.exe int ip reset | Out-Null
    & ipconfig.exe /flushdns | Out-Null
    Write-Ok 'Red reiniciada. Reiniciá la PC.'
    Write-Log 'RED: reset completo de Winsock/TCP-IP'
}

function Reset-WindowsUpdateComponents {
    Write-Info 'Esto renombra SoftwareDistribution y catroot2 para que Windows los regenere.'
    if (-not (Confirm-Gonix '¿Continuar?')) { Write-Warn 'Cancelado.'; return }
    $servicios = 'wuauserv', 'cryptSvc', 'bits', 'msiserver'
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    try {
        foreach ($s in $servicios) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
        foreach ($d in @((Join-Path $env:windir 'SoftwareDistribution'), (Join-Path $env:windir 'System32\catroot2'))) {
            if (Test-Path -LiteralPath $d) {
                try {
                    Rename-Item -LiteralPath $d -NewName ((Split-Path $d -Leaf) + ".old-$stamp") -ErrorAction Stop
                    Write-Ok "$(Split-Path $d -Leaf) renombrada."
                }
                catch { Write-Fail "No se pudo renombrar $(Split-Path $d -Leaf): $($_.Exception.Message)" }
            }
        }
    }
    finally {
        foreach ($s in 'cryptSvc', 'bits', 'wuauserv') { Start-Service -Name $s -ErrorAction SilentlyContinue }
    }
    Write-Ok 'Componentes de Windows Update reiniciados.'
    Write-Log 'WU: componentes reiniciados'
}

function Show-MaintenanceMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Limpieza y reparación ---' -ForegroundColor Magenta
        Write-Host ''
        Write-MenuItem '1' 'Limpiar archivos temporales y papelera'
        Write-MenuItem '2' 'Verificar archivos del sistema (SFC)'
        Write-MenuItem '3' 'Reparar la imagen de Windows (DISM)'
        Write-MenuItem '4' 'Red: limpiar DNS y renovar IP (suave)'
        Write-MenuItem '5' 'Red: reinicio completo de Winsock/TCP-IP'
        Write-MenuItem '6' 'Reiniciar componentes de Windows Update'
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una opción'
        $valida = $true
        switch ($op) {
            '0' { return }
            '1' { Invoke-Cleanup }
            '2' { Write-Info 'Puede tardar varios minutos. No cierres la ventana.'; & sfc.exe /scannow }
            '3' { Write-Info 'Puede tardar varios minutos. No cierres la ventana.'; & DISM.exe /Online /Cleanup-Image /RestoreHealth }
            '4' { Repair-NetworkSoft }
            '5' { Repair-NetworkFull }
            '6' { Reset-WindowsUpdateComponents }
            default { Write-Warn 'Opción inválida.'; Start-Sleep 1; $valida = $false }
        }
        if ($valida) { Write-Host ''; Wait-Enter }
    }
}

# ------------------------------------------------------------
#  Windows Update: pausa con fecha (la misma que usa Configuración)
# ------------------------------------------------------------
$script:WuKey = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$script:WuValores = 'PauseUpdatesStartTime', 'PauseUpdatesExpiryTime',
                    'PauseFeatureUpdatesStartTime', 'PauseFeatureUpdatesEndTime',
                    'PauseQualityUpdatesStartTime', 'PauseQualityUpdatesEndTime'

function Get-UpdatePauseEnd {
    $r = Get-RegState $script:WuKey 'PauseUpdatesExpiryTime'
    if ($r.Existe -and $r.Valor) {
        try {
            $d = [datetime]::Parse([string]$r.Valor, [Globalization.CultureInfo]::InvariantCulture,
                                   [Globalization.DateTimeStyles]'AssumeUniversal,AdjustToUniversal')
            if ($d -gt (Get-Date).ToUniversalTime()) { return $d.ToLocalTime() }
        } catch {}
    }
    return $null
}

function Suspend-WindowsUpdates {
    param([int]$Dias)
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $fmt = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    $ahora = (Get-Date).ToUniversalTime()
    $inicio = $ahora.ToString($fmt, $inv)
    $fin = $ahora.AddDays($Dias).ToString($fmt, $inv)
    Set-RegValue $script:WuKey 'PauseUpdatesStartTime' $inicio 'String'
    Set-RegValue $script:WuKey 'PauseUpdatesExpiryTime' $fin 'String'
    Set-RegValue $script:WuKey 'PauseFeatureUpdatesStartTime' $inicio 'String'
    Set-RegValue $script:WuKey 'PauseFeatureUpdatesEndTime' $fin 'String'
    Set-RegValue $script:WuKey 'PauseQualityUpdatesStartTime' $inicio 'String'
    Set-RegValue $script:WuKey 'PauseQualityUpdatesEndTime' $fin 'String'
    Write-Log "WU: pausadas $Dias dias"
}

function Resume-WindowsUpdates {
    foreach ($v in $script:WuValores) { Remove-RegValue $script:WuKey $v }
    Write-Log 'WU: reanudadas'
}

function Show-UpdateMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Windows Update ---' -ForegroundColor Magenta
        Write-Host ''
        $fin = Get-UpdatePauseEnd
        if ($fin) { Write-Host ("   Estado: PAUSADO hasta el {0:dd/MM/yyyy HH:mm}" -f $fin) -ForegroundColor Yellow }
        else { Write-Host '   Estado: activo' -ForegroundColor Green }
        Write-Host ''
        Write-Info 'La pausa tiene fecha de vencimiento: Windows retoma solo las actualizaciones.'
        Write-Info 'No la dejes pasar de largo: las de seguridad se instalan recién al reanudar.'
        Write-Host ''
        Write-MenuItem '1' 'Pausar 7 días'
        Write-MenuItem '2' 'Pausar 14 días'
        Write-MenuItem '3' 'Pausar 35 días (máximo de Windows)'
        Write-MenuItem '4' 'Reanudar ahora'
        Write-MenuItem '5' 'Abrir Windows Update'
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una opción'
        try {
            switch ($op) {
                '0' { return }
                '1' { Suspend-WindowsUpdates 7;  Write-Ok 'Actualizaciones pausadas 7 días.' }
                '2' { Suspend-WindowsUpdates 14; Write-Ok 'Actualizaciones pausadas 14 días.' }
                '3' { Suspend-WindowsUpdates 35; Write-Ok 'Actualizaciones pausadas 35 días.' }
                '4' { Resume-WindowsUpdates;     Write-Ok 'Actualizaciones reanudadas.' }
                '5' { Start-Process 'ms-settings:windowsupdate' }
                default { Write-Warn 'Opción inválida.'; Start-Sleep 1 }
            }
        }
        catch { Write-Fail $_.Exception.Message }
        Start-Sleep -Milliseconds 600
    }
}

# ------------------------------------------------------------
#  Apps preinstaladas (bloatware)
# ------------------------------------------------------------
function Remove-AppxCompleto {
    param([string]$Paquete)
    $quitado = $false
    foreach ($p in @(Get-AppxPackage -AllUsers -Name $Paquete -ErrorAction SilentlyContinue)) {
        Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
        $quitado = $true
    }
    # También del "molde" de Windows, para que no vuelva con usuarios nuevos
    foreach ($p in @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $Paquete })) {
        [void](Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop)
        $quitado = $true
    }
    return $quitado
}

function Show-BloatwareMenu {
    $apps = Read-JsonArray (Join-Path $script:GonixRoot 'tweaks\bloatware.json')
    while ($true) {
        Write-Banner
        Write-Host '   --- Desinstalar apps preinstaladas ---' -ForegroundColor Magenta
        Write-Info 'Buscando apps instaladas...'
        $instaladas = @{}
        foreach ($p in @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)) { $instaladas[$p.Name] = $true }
        Write-Host ''
        for ($i = 0; $i -lt $apps.Count; $i++) {
            $a = $apps[$i]
            if ($instaladas.ContainsKey($a.paquete)) {
                Write-Host ('   [{0,2}] {1}' -f ($i + 1), $a.nombre) -ForegroundColor White
            }
            else {
                Write-Host ('   [{0,2}] {1}  (no instalada)' -f ($i + 1), $a.nombre) -ForegroundColor DarkGray
            }
        }
        Write-Host ''
        Write-Info 'Escribí números (ej: 1,3,5-7) o T para todas las instaladas. Enter o 0 para volver.'
        Write-Info 'No se pueden restaurar desde Gonix; se reinstalan desde Microsoft Store.'
        $sel = Read-Host '   Tu elección'
        if ([string]::IsNullOrWhiteSpace($sel) -or $sel -eq '0') { return }

        if ($sel -match '^[Tt]$') {
            $idx = @(0..($apps.Count - 1) | Where-Object { $instaladas.ContainsKey($apps[$_].paquete) })
        }
        else { $idx = @(ConvertTo-Indices -Texto $sel -Max $apps.Count) }
        $idx = @($idx | Where-Object { $instaladas.ContainsKey($apps[$_].paquete) })
        if ($idx.Count -eq 0) { Write-Warn 'No elegiste ninguna app instalada.'; Start-Sleep 1; continue }

        Write-Host ''
        foreach ($n in $idx) {
            Write-Host "   - $($apps[$n].nombre)" -ForegroundColor Yellow
            if ($apps[$n].aviso) { Write-Host "     $($apps[$n].aviso)" -ForegroundColor DarkYellow }
        }
        Write-Host ''
        if (-not (Confirm-Gonix '¿Eliminar estas apps?')) { Write-Warn 'Cancelado.'; continue }

        foreach ($n in $idx) {
            $a = $apps[$n]
            try {
                if (Remove-AppxCompleto -Paquete $a.paquete) { Write-Ok "$($a.nombre) eliminada." }
                else { Write-Warn "$($a.nombre) no estaba instalada." }
                Write-Log "BLOATWARE: $($a.paquete) eliminada"
            }
            catch { Write-Fail "$($a.nombre): $($_.Exception.Message)" }
        }
        Write-Host ''
        Wait-Enter
    }
}

# ------------------------------------------------------------
#  Instalador de aplicaciones (winget)
# ------------------------------------------------------------
function Show-AppCategory {
    param($Cat)
    while ($true) {
        Write-Banner
        Write-Host "   --- $($Cat.categoria) ---" -ForegroundColor Magenta
        Write-Host ''
        for ($i = 0; $i -lt $Cat.apps.Count; $i++) {
            Write-Host ('   [{0,2}] {1}' -f ($i + 1), $Cat.apps[$i].nombre) -ForegroundColor White
        }
        Write-Host ''
        Write-Info 'Escribí números (ej: 1,3,5-7) o T para todas. Enter o 0 para volver.'
        $sel = Read-Host '   Qué instalar'
        if ([string]::IsNullOrWhiteSpace($sel) -or $sel -eq '0') { return }

        if ($sel -match '^[Tt]$') { $idx = @(0..($Cat.apps.Count - 1)) }
        else { $idx = @(ConvertTo-Indices -Texto $sel -Max $Cat.apps.Count) }
        if ($idx.Count -eq 0) { Write-Warn 'Selección inválida.'; Start-Sleep 1; continue }

        Write-Host ''
        foreach ($n in $idx) {
            $app = $Cat.apps[$n]
            Write-Host "   -> $($app.nombre)..." -ForegroundColor DarkGray
            & winget.exe install --id $app.id -e --silent --accept-package-agreements --accept-source-agreements
            $code = $LASTEXITCODE
            if ($code -eq 0) { Write-Ok "$($app.nombre) instalada." }
            elseif ($code -eq -1978335135 -or $code -eq -1978335189) { Write-Info "$($app.nombre) ya estaba instalada (o está al día)." }
            else { Write-Fail "$($app.nombre): winget terminó con el código $code." }
            Write-Log "WINGET $($app.id): código $code"
        }
        Write-Host ''
        Wait-Enter
    }
}

function Show-AppInstaller {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Write-Banner
        Write-Fail 'No se encontró winget en este equipo.'
        Write-Info 'Instalá o actualizá "Instalador de aplicación" desde Microsoft Store.'
        Write-Host ''
        Wait-Enter
        return
    }
    $cats = Read-JsonArray (Join-Path $script:GonixRoot 'tweaks\apps.json')
    while ($true) {
        Write-Banner
        Write-Host '   --- Instalador de aplicaciones (winget) ---' -ForegroundColor Magenta
        Write-Host ''
        for ($i = 0; $i -lt $cats.Count; $i++) { Write-MenuItem ($i + 1) $cats[$i].categoria }
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una categoría'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }
        $n = 0
        if (-not [int]::TryParse($op, [ref]$n) -or $n -lt 1 -or $n -gt $cats.Count) {
            Write-Warn 'Opción inválida.'; Start-Sleep 1; continue
        }
        Show-AppCategory $cats[$n - 1]
    }
}
