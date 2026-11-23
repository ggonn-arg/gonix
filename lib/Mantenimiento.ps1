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

function Get-GonixOptionalFeatureDefinitions {
    @(
        [pscustomobject]@{
            FeatureName = 'Microsoft-Windows-Subsystem-Linux'
            Nombre = 'Subsistema de Windows para Linux (WSL)'
            Descripcion = 'Habilita el componente WSL; no instala una distribución. WSL 2 también requiere Plataforma de máquina virtual.'
        }
        [pscustomobject]@{
            FeatureName = 'VirtualMachinePlatform'
            Nombre = 'Plataforma de máquina virtual'
            Descripcion = 'Componente usado por WSL 2 y algunas herramientas de virtualización. La virtualización debe estar habilitada en UEFI/BIOS.'
        }
        [pscustomobject]@{
            FeatureName = 'Microsoft-Hyper-V-All'
            Nombre = 'Hyper-V'
            Descripcion = 'Hipervisor de Microsoft. Cambiarlo puede afectar máquinas virtuales, WSL 2, Docker u otros hipervisores.'
        }
        [pscustomobject]@{
            FeatureName = 'Containers-DisposableClientVM'
            Nombre = 'Windows Sandbox'
            Descripcion = 'Entorno temporal aislado; requiere edición compatible y virtualización de hardware.'
        }
        [pscustomobject]@{
            FeatureName = 'NetFx3'
            Nombre = '.NET Framework 3.5'
            Descripcion = 'Compatibilidad para aplicaciones antiguas. Si faltan archivos, Windows puede descargarlos desde Windows Update.'
        }
    )
}

function Get-GonixOptionalFeatures {
    if (-not (Test-Admin)) { throw 'Abrí Gonix como administrador para consultar las funciones opcionales.' }
    if (-not (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue)) {
        throw 'No está disponible el módulo DISM de Windows para consultar funciones opcionales.'
    }

    $resultados = New-Object System.Collections.ArrayList
    foreach ($definicion in Get-GonixOptionalFeatureDefinitions) {
        try {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $definicion.FeatureName -ErrorAction Stop
            if (-not $feature) { throw 'DISM no devolvió el estado de la función.' }
            [void]$resultados.Add([pscustomobject]@{
                FeatureName = $definicion.FeatureName
                Nombre = $definicion.Nombre
                Descripcion = $definicion.Descripcion
                Estado = [string]$feature.State
            })
        }
        catch {
            Write-Warn "Se omitió '$($definicion.Nombre)': $($_.Exception.Message)"
        }
    }
    return @($resultados.ToArray())
}

function Set-GonixOptionalFeatureState {
    param(
        [Parameter(Mandatory = $true)][string]$FeatureName,
        [Parameter(Mandatory = $true)][string]$State
    )

    switch ($State) {
        'Enabled' {
            return Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart -ErrorAction Stop
        }
        'Disabled' {
            return Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart -ErrorAction Stop
        }
        'DisabledWithPayloadRemoved' {
            return Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart -Remove -ErrorAction Stop
        }
        default { throw "No se puede restaurar el estado de función '$State'." }
    }
}

function Invoke-GonixOptionalFeatureChange {
    param(
        [Parameter(Mandatory = $true)][string]$FeatureName,
        [Parameter(Mandatory = $true)][string]$Nombre
    )

    if (-not (Test-Admin)) { throw 'Abrí Gonix como administrador para cambiar funciones opcionales.' }
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    if (-not $feature) { throw "No se encontró la función opcional '$Nombre'." }
    $estadoAnterior = [string]$feature.State
    if ($estadoAnterior -in @('EnablePending', 'DisablePending')) {
        throw "'$Nombre' tiene un cambio pendiente; reiniciá Windows antes de modificarlo."
    }
    if ($estadoAnterior -notin @('Enabled', 'Disabled', 'DisabledWithPayloadRemoved')) {
        throw "El estado '$estadoAnterior' de '$Nombre' no se puede cambiar de forma segura."
    }

    $estadoNuevo = if ($estadoAnterior -eq 'Enabled') { 'Disabled' } else { 'Enabled' }
    $verbo = if ($estadoNuevo -eq 'Enabled') { 'habilitar' } else { 'deshabilitar' }
    if (-not (Confirm-Gonix "¿Querés $verbo '$Nombre'? El cambio puede requerir reiniciar Windows.")) {
        Write-Warn 'Operación cancelada.'
        return [pscustomobject]@{ Changed = $false; RestartNeeded = $false }
    }

    Start-Lote
    $operacion = Set-GonixOptionalFeatureState -FeatureName $FeatureName -State $estadoNuevo
    $reinicio = $false
    if ($operacion -and $operacion.PSObject.Properties['RestartNeeded']) {
        $reinicio = [bool]$operacion.RestartNeeded
    }
    Add-History @{
        Tipo = 'windows-feature'
        TweakId = "windows-feature:$FeatureName"
        Nombre = $Nombre
        FeatureName = $FeatureName
        EstadoAnterior = $estadoAnterior
        EstadoNuevo = $estadoNuevo
    }
    try { Save-History }
    catch {
        $errorHistorial = $_.Exception.Message
        try {
            [void](Set-GonixOptionalFeatureState -FeatureName $FeatureName -State $estadoAnterior)
            $script:Pendientes.Clear()
        }
        catch {
            throw "No se pudo guardar el historial ($errorHistorial) ni restaurar '$Nombre' ($($_.Exception.Message)). Revisá la función en Características de Windows."
        }
        throw "No se pudo guardar el historial ($errorHistorial); se restauró el estado anterior de '$Nombre'."
    }
    Write-Log ('FUNCION WINDOWS {0}: {1} -> {2}' -f $FeatureName, $estadoAnterior, $estadoNuevo)
    Write-Ok "Se solicitó $verbo '$Nombre'."
    if ($reinicio) { Write-Warn 'Windows indicó que hace falta reiniciar para completar el cambio.' }
    return [pscustomobject]@{ Changed = $true; RestartNeeded = $reinicio }
}

function Restore-GonixOptionalFeatureState {
    param(
        [Parameter(Mandatory = $true)][string]$FeatureName,
        [Parameter(Mandatory = $true)][string]$State
    )

    if (-not (Test-Admin)) { throw 'Abrí Gonix como administrador para restaurar funciones opcionales.' }
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    if (-not $feature) { throw "No se encontró la función opcional '$FeatureName'." }
    if ([string]$feature.State -eq $State) { return }
    if ([string]$feature.State -in @('EnablePending', 'DisablePending')) {
        throw "'$FeatureName' tiene un cambio pendiente; reiniciá Windows antes de revertirlo."
    }

    $operacion = Set-GonixOptionalFeatureState -FeatureName $FeatureName -State $State
    if ($operacion -and $operacion.PSObject.Properties['RestartNeeded'] -and $operacion.RestartNeeded) {
        Write-Warn "La reversión de '$FeatureName' requiere reiniciar Windows."
    }
    Write-Log "RESTAURAR FUNCION WINDOWS $FeatureName -> $State"
}

function Get-GonixOptionalFeatureStateLabel {
    param([string]$State)
    switch ($State) {
        'Enabled' { 'Activada' }
        'Disabled' { 'Desactivada' }
        'DisabledWithPayloadRemoved' { 'Desactivada (archivos quitados)' }
        'EnablePending' { 'Activación pendiente (reinicio)' }
        'DisablePending' { 'Desactivación pendiente (reinicio)' }
        default { $State }
    }
}

function Show-OptionalFeatureManager {
    while ($true) {
        Write-Banner
        Write-Host '   --- Funciones opcionales de Windows ---' -ForegroundColor Magenta
        Write-Warn 'No son ajustes de rendimiento. Cambiarlas puede afectar WSL, máquinas virtuales y apps que dependan de ellas.'
        Write-Host ''

        try { $features = @(Get-GonixOptionalFeatures) }
        catch {
            Write-Fail "No se pudieron consultar las funciones opcionales: $($_.Exception.Message)"
            Write-Host ''; Wait-Enter
            return
        }
        if ($features.Count -eq 0) {
            Write-Info 'No se encontró ninguna función compatible para mostrar.'
            Write-Host ''; Wait-Enter
            return
        }

        for ($i = 0; $i -lt $features.Count; $i++) {
            $state = Get-GonixOptionalFeatureStateLabel $features[$i].Estado
            Write-Host ('   {0,2}. [{1}] {2}' -f ($i + 1), $state, $features[$i].Nombre) -ForegroundColor White
        }
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una función para cambiar'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }
        $n = 0
        if (-not [int]::TryParse($op, [ref]$n) -or $n -lt 1 -or $n -gt $features.Count) {
            Write-Warn 'Opción inválida.'; Start-Sleep 1; continue
        }

        $feature = $features[$n - 1]
        Write-Host ''
        Write-Info $feature.Descripcion
        try {
            [void](Invoke-GonixOptionalFeatureChange -FeatureName $feature.FeatureName -Nombre $feature.Nombre)
        }
        catch {
            Write-Fail "No se pudo cambiar '$($feature.Nombre)': $($_.Exception.Message)"
            Write-Log "FUNCION WINDOWS $($feature.FeatureName): $($_.Exception.Message)"
        }
        Write-Host ''
        Wait-Enter
    }
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
        Write-MenuItem '7' 'Administrar funciones opcionales de Windows'
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
            '7' { Show-OptionalFeatureManager }
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

function Show-InstalledApplications {
    Write-Host ''
    & winget.exe list
    $code = $LASTEXITCODE
    if ($code -eq 0) { Write-Ok 'Consulta de aplicaciones instaladas finalizada.' }
    else {
        Write-Fail "No se pudieron consultar las aplicaciones instaladas (código $code)."
        Write-Log "WINGET list: código $code"
    }
    Write-Host ''
    Wait-Enter
}

function Show-AppUpdates {
    Write-Host ''
    & winget.exe upgrade
    $code = $LASTEXITCODE
    if ($code -eq 0) { Write-Ok 'Búsqueda de actualizaciones finalizada.' }
    else {
        Write-Fail "No se pudieron buscar actualizaciones (código $code)."
        Write-Log "WINGET upgrade: código $code"
    }
    Write-Host ''
    Wait-Enter
}

function Invoke-AppUpdates {
    if (-not (Confirm-Gonix '¿Buscar e instalar las actualizaciones disponibles para todas las aplicaciones?')) {
        Write-Warn 'Actualización cancelada.'
        return
    }

    Write-Host ''
    & winget.exe upgrade --all
    $code = $LASTEXITCODE
    if ($code -eq 0) { Write-Ok 'Proceso de actualización finalizado.' }
    else {
        Write-Fail "WinGet terminó con el código $code. Algunas aplicaciones podrían no haberse actualizado."
        Write-Log "WINGET upgrade --all: código $code"
    }
    Write-Host ''
    Wait-Enter
}

function Update-WinGetSources {
    Write-Host ''
    & winget.exe source update
    $code = $LASTEXITCODE
    if ($code -eq 0) { Write-Ok 'Fuentes de WinGet actualizadas.' }
    else {
        Write-Fail "No se pudieron actualizar las fuentes de WinGet (código $code)."
        Write-Log "WINGET source update: código $code"
    }
    Write-Host ''
    Wait-Enter
}

function Show-WinGetRecoveryGuide {
    Write-Banner
    Write-Host '   --- Recuperar WinGet ---' -ForegroundColor Magenta
    Write-Info 'WinGet forma parte de Instalador de aplicación (App Installer) de Microsoft.'
    Write-Info 'En Microsoft Store, abrí Biblioteca > Obtener actualizaciones y actualizá App Installer.'
    Write-Info 'Si WinGet abre pero no encuentra paquetes, elegí primero "Actualizar fuentes".'
    Write-Host ''
    if (Confirm-Gonix '¿Abrir la página de App Installer en Microsoft Store?') {
        try {
            Start-Process -FilePath 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1' -ErrorAction Stop
            Write-Ok 'Se abrió la página de App Installer.'
        }
        catch {
            Write-Fail "No se pudo abrir Microsoft Store: $($_.Exception.Message)"
            Write-Info 'Abrí Microsoft Store manualmente y buscá "Instalador de aplicación".'
            Write-Log "WINGET abrir Microsoft Store: $($_.Exception.Message)"
        }
    }
    Write-Host ''
    Wait-Enter
}

function Show-AppInstaller {
    $cats = Read-JsonArray (Join-Path $script:GonixRoot 'tweaks\apps.json')
    $wingetAvailable = [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
    $actions = @(
        'Ver aplicaciones instaladas'
        'Buscar actualizaciones'
        'Actualizar todas las aplicaciones'
        'Actualizar fuentes de WinGet'
        'Ayuda para recuperar WinGet'
    )
    while ($true) {
        Write-Banner
        Write-Host '   --- Aplicaciones y actualizaciones (WinGet) ---' -ForegroundColor Magenta
        Write-Host ''
        for ($i = 0; $i -lt $cats.Count; $i++) { Write-MenuItem ($i + 1) $cats[$i].categoria }
        for ($i = 0; $i -lt $actions.Count; $i++) {
            Write-MenuItem ($cats.Count + $i + 1) $actions[$i]
        }
        if (-not $wingetAvailable) {
            Write-Host ''
            Write-Fail 'No se encontró WinGet. Usá la opción de recuperación para actualizar App Installer.'
        }
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una opción'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }
        $n = 0
        if (-not [int]::TryParse($op, [ref]$n) -or $n -lt 1 -or $n -gt ($cats.Count + $actions.Count)) {
            Write-Warn 'Opción inválida.'; Start-Sleep 1; continue
        }

        if ($n -le $cats.Count) {
            if ($wingetAvailable) { Show-AppCategory $cats[$n - 1] }
            else { Write-Fail 'Instalá o actualizá App Installer para usar WinGet.'; Wait-Enter }
            continue
        }

        switch ($n - $cats.Count) {
            1 { if ($wingetAvailable) { Show-InstalledApplications } else { Show-WinGetRecoveryGuide } }
            2 { if ($wingetAvailable) { Show-AppUpdates } else { Show-WinGetRecoveryGuide } }
            3 { if ($wingetAvailable) { Invoke-AppUpdates } else { Show-WinGetRecoveryGuide } }
            4 { if ($wingetAvailable) { Update-WinGetSources } else { Show-WinGetRecoveryGuide } }
            5 { Show-WinGetRecoveryGuide }
        }
    }
}
