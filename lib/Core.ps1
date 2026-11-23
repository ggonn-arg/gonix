# ============================================================
#  Core.ps1 - Motor de tweaks, perfiles y acciones internas
# ============================================================
#  Los tweaks viven en tweaks\*.json (única fuente de verdad):
#   - tipo "registro": lista de cambios {ruta, nombre, valor, tipoValor}
#                      o {ruta, nombre, eliminar:true}
#   - tipo "accion"  : nombre de un manejador de $script:Acciones
#  Los menús se generan solos a partir del campo "categoria".
# ============================================================

$script:Tweaks         = @()
$script:TweakIndex     = @{}
$script:Perfiles       = @()
$script:InfoSistema    = ''
$script:BuildWindows   = 0
$script:PuntoOfrecido  = $false

# ------------------------------------------------------------
#  Carga inicial
# ------------------------------------------------------------
function Initialize-Gonix {
    $script:Tweaks = @()
    $script:TweakIndex = @{}

    foreach ($f in 'privacidad', 'sistema', 'rendimiento', 'avanzado') {
        $p = Join-Path $script:GonixRoot "tweaks\$f.json"
        if (-not (Test-Path -LiteralPath $p)) { Write-Warn "Falta tweaks\$f.json"; continue }
        try {
            $items = @(Read-JsonArray $p)
        }
        catch {
            Write-Fail "Error al leer tweaks\$f.json: $($_.Exception.Message)"
            continue
        }
        foreach ($t in $items) {
            if (-not $t.id) { Write-Warn "Tweak sin 'id' en tweaks\$f.json"; continue }
            if ($script:TweakIndex.ContainsKey($t.id)) { Write-Warn "Id de tweak duplicado: $($t.id)"; continue }
            if ($t.tipo -eq 'accion' -and -not $script:Acciones.ContainsKey($t.accion)) {
                Write-Warn "El tweak '$($t.id)' usa una acción inexistente: $($t.accion)"; continue
            }
            $script:TweakIndex[$t.id] = $t
            $script:Tweaks += $t
        }
    }

    # Perfiles (orden fijo para los conocidos, después cualquier otro .json)
    $script:Perfiles = @()
    $orden = 'recomendado', 'gaming', 'oficina', 'notebook', 'privacidad-total'
    $archivos = @(Get-ChildItem -LiteralPath (Join-Path $script:GonixRoot 'profiles') -Filter *.json -ErrorAction SilentlyContinue)
    $archivos = @($archivos | Sort-Object { $i = [array]::IndexOf($orden, $_.BaseName); if ($i -lt 0) { 99 } else { $i } }, Name)
    foreach ($a in $archivos) {
        try {
            $pf = Read-JsonObject $a.FullName
            foreach ($id in @($pf.tweaks)) {
                if (-not $script:TweakIndex.ContainsKey($id)) {
                    Write-Warn "El perfil '$($a.BaseName)' menciona un tweak inexistente: $id"
                }
            }
            $script:Perfiles += $pf
        }
        catch { Write-Warn "No se pudo leer el perfil $($a.Name): $($_.Exception.Message)" }
    }

    # Info del sistema (se calcula una sola vez)
    try {
        $os  = Get-CimInstance Win32_OperatingSystem
        $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
        $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $script:InfoSistema = "$($os.Caption) | CPU: $cpu | RAM: $ram GB"
        $script:BuildWindows = [int]$os.BuildNumber
    }
    catch {
        $script:InfoSistema = 'No se pudo leer la información del sistema'
        $script:BuildWindows = 0
    }
}

function Get-TweakById { param([string]$Id) return $script:TweakIndex[$Id] }

function Get-TweaksByCategory {
    param([string]$Categoria)
    return @($script:Tweaks | Where-Object { $_.categoria -eq $Categoria })
}

function Get-RiskColor {
    param($T)
    switch ($T.riesgo) { 'alto' { 'Red' } 'medio' { 'Yellow' } default { 'White' } }
}

function Get-RiskSuffix {
    param($T)
    switch ($T.riesgo) { 'alto' { '  (riesgo alto)' } 'medio' { '  (riesgo medio)' } default { '' } }
}

# ------------------------------------------------------------
#  Cambios dinámicos (dependen del equipo)
# ------------------------------------------------------------
# Nagle: TcpAckFrequency/TCPNoDelay van dentro de la clave de CADA interfaz activa.
function Get-NagleChanges {
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    $res = @()
    foreach ($a in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })) {
        $ruta = "$base\$($a.InterfaceGuid)"
        if (Test-Path -LiteralPath $ruta) {
            $res += [pscustomobject]@{ ruta = $ruta; nombre = 'TcpAckFrequency'; valor = 1; tipoValor = 'DWord' }
            $res += [pscustomobject]@{ ruta = $ruta; nombre = 'TCPNoDelay';      valor = 1; tipoValor = 'DWord' }
        }
    }
    return $res
}

function Get-NagleResetChanges {
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    $res = @()
    foreach ($a in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {
        $ruta = "$base\$($a.InterfaceGuid)"
        if (Test-Path -LiteralPath $ruta) {
            $res += [pscustomobject]@{ ruta = $ruta; nombre = 'TcpAckFrequency'; eliminar = $true }
            $res += [pscustomobject]@{ ruta = $ruta; nombre = 'TCPNoDelay'; eliminar = $true }
        }
    }
    return $res
}

function Get-TweakChanges {
    param($Tweak)
    if ($Tweak.cambiosDinamicos -eq 'nagle') { return @(Get-NagleChanges) }
    if ($Tweak.cambios) { return @($Tweak.cambios) }
    return @()
}

# ------------------------------------------------------------
#  Acciones internas (con su "deshacer")
#  Apply devuelve un hashtable con lo necesario para revertir.
# ------------------------------------------------------------
function Set-ServiceTweak {
    param([string]$Nombre, [int]$Start)
    $s = Get-ServiceStartup $Nombre
    if (-not $s) { throw "El servicio $Nombre no existe en este equipo." }
    if ($Start -eq 4) { Stop-Service -Name $Nombre -Force -ErrorAction SilentlyContinue }
    Set-ServiceStartup -Nombre $Nombre -Start $Start
    return @{ Servicio = $Nombre; Start = $s.Start; Delayed = $s.Delayed }
}

function Restore-ServiceTweak {
    param($Datos)
    Set-ServiceStartup -Nombre $Datos.Servicio -Start ([int]$Datos.Start) -Delayed ([bool]$Datos.Delayed)
    if ([int]$Datos.Start -eq 2) { Start-Service -Name $Datos.Servicio -ErrorAction SilentlyContinue }
}

function Test-ServiceTweak {
    param([string]$Nombre, [int]$Start)
    $s = Get-ServiceStartup $Nombre
    if (-not $s) { return $null }
    return ($s.Start -eq $Start)
}

function Get-CoreParkingPath {
    param([string]$Esquema)
    "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$Esquema\54533251-82be-4824-96c1-47b62ac9cc27\0cc5b647-c1df-4d3c-a8a1-4a6abb9d02ba"
}

$script:Acciones = @{

    'hibernacion-off' = @{
        Test  = { (Get-RegState 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled').Valor -eq 0 }
        Apply = {
            $prev = (Get-RegState 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled').Valor
            & powercfg.exe -h off
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            return @{ Habilitada = [int]$prev }
        }
        Undo  = {
            param($d)
            if ([int]$d.Habilitada -eq 1) {
                & powercfg.exe -h on
                if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            }
        }
        Reset = {
            & powercfg.exe -h on
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
        }
    }

    'dns-cloudflare' = @{
        Test  = {
            $ads = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
            if ($ads.Count -eq 0) { return $null }
            foreach ($a in $ads) {
                $dns = @((Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4).ServerAddresses)
                if (($dns -join ',') -ne '1.1.1.1,1.0.0.1') { return $false }
            }
            return $true
        }
        Apply = {
            $ads = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
            if ($ads.Count -eq 0) { throw 'No hay adaptadores de red físicos activos.' }
            $guardado = @()
            foreach ($a in $ads) {
                $prev = @((Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4).ServerAddresses)
                Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses @('1.1.1.1', '1.0.0.1') -ErrorAction Stop
                $guardado += @{ Alias = $a.Name; Anterior = $prev }
            }
            Clear-DnsClientCache
            return @{ Adaptadores = $guardado }
        }
        Undo  = {
            param($d)
            foreach ($a in @($d.Adaptadores)) {
                $prev = @($a.Anterior)
                if ($prev.Count -gt 0) { Set-DnsClientServerAddress -InterfaceAlias $a.Alias -ServerAddresses $prev -ErrorAction Stop }
                else { Set-DnsClientServerAddress -InterfaceAlias $a.Alias -ResetServerAddresses -ErrorAction Stop }
            }
            Clear-DnsClientCache
        }
        Reset = {
            $adaptadores = @(Get-NetAdapter -Physical -ErrorAction Stop)
            if ($adaptadores.Count -eq 0) { throw 'No hay adaptadores de red físicos para restablecer.' }
            foreach ($a in $adaptadores) {
                Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop
            }
            Clear-DnsClientCache
        }
    }

    'diagtrack-off' = @{
        Test  = { Test-ServiceTweak -Nombre 'DiagTrack' -Start 4 }
        Apply = { Set-ServiceTweak -Nombre 'DiagTrack' -Start 4 }
        Undo  = { param($d) Restore-ServiceTweak -Datos $d }
        Reset = {
            Set-ServiceStartup -Nombre 'DiagTrack' -Start 2 -Delayed $true
            Start-Service -Name 'DiagTrack' -ErrorAction Stop
        }
    }

    'maps-manual' = @{
        Test  = {
            $s = Get-ServiceStartup 'MapsBroker'
            if (-not $s) { return $null }
            if ($s.Start -eq 3) { return $null }
            return $false
        }
        Apply = { Set-ServiceTweak -Nombre 'MapsBroker' -Start 3 }
        Undo  = { param($d) Restore-ServiceTweak -Datos $d }
        Reset = { Set-ServiceStartup -Nombre 'MapsBroker' -Start 3 }
    }

    # Solo con corriente (AC). El valor por defecto de Windows es 1 (suspensión habilitada).
    'usb-suspend-off' = @{
        Apply = {
            & powercfg.exe -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            & powercfg.exe -setactive SCHEME_CURRENT
            return @{ Defecto = 1 }
        }
        Undo  = {
            param($d)
            & powercfg.exe -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            & powercfg.exe -setactive SCHEME_CURRENT
        }
        Reset = {
            & powercfg.exe -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            & powercfg.exe -setactive SCHEME_CURRENT
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
        }
    }

    # -duplicatescheme crea un plan NUEVO con GUID propio: hay que leerlo de la salida.
    'plan-ultimate' = @{
        Apply = {
            $anterior = Get-ActiveSchemeGuid
            $salida = (& powercfg.exe -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) -join ' '
            if ($salida -match '([0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})') { $nuevo = $Matches[1] }
            else { throw 'Este equipo no permite el plan Máximo rendimiento (¿Modern Standby?).' }
            & powercfg.exe -setactive $nuevo
            if ($LASTEXITCODE -ne 0) { throw "No se pudo activar el plan nuevo (código $LASTEXITCODE)." }
            return @{ Anterior = $anterior; Nuevo = $nuevo }
        }
        Undo  = {
            param($d)
            & powercfg.exe -setactive $d.Anterior
            if ($LASTEXITCODE -ne 0) { throw "No se pudo reactivar el plan anterior (código $LASTEXITCODE)." }
            & powercfg.exe -delete $d.Nuevo
        }
        Reset = {
            & powercfg.exe -setactive SCHEME_BALANCED
            if ($LASTEXITCODE -ne 0) { throw "No se pudo activar el plan Equilibrado (código $LASTEXITCODE)." }
            Write-Warn 'Se activó Equilibrado; sin historial no se puede identificar ni borrar con seguridad el plan duplicado.'
        }
    }

    'core-parking-off' = @{
        Test  = {
            try {
                $s = Get-RegState (Get-CoreParkingPath (Get-ActiveSchemeGuid)) 'ACSettingIndex'
                return ($s.Existe -and [int]$s.Valor -eq 100)
            } catch { return $null }
        }
        Apply = {
            $esq  = Get-ActiveSchemeGuid
            $prev = Get-RegState (Get-CoreParkingPath $esq) 'ACSettingIndex'
            & powercfg.exe -setacvalueindex $esq 54533251-82be-4824-96c1-47b62ac9cc27 0cc5b647-c1df-4d3c-a8a1-4a6abb9d02ba 100
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            & powercfg.exe -setactive $esq
            $valorPrev = 0
            if ($prev.Existe) { $valorPrev = [int]$prev.Valor }
            return @{ Esquema = $esq; Tenia = [bool]$prev.Existe; Anterior = $valorPrev }
        }
        Undo  = {
            param($d)
            if ($d.Tenia) {
                & powercfg.exe -setacvalueindex $d.Esquema 54533251-82be-4824-96c1-47b62ac9cc27 0cc5b647-c1df-4d3c-a8a1-4a6abb9d02ba ([int]$d.Anterior)
                if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            }
            else {
                # No había valor propio: se borra el override y el plan vuelve a su valor por defecto
                Remove-RegValue -Ruta (Get-CoreParkingPath $d.Esquema) -Nombre 'ACSettingIndex'
            }
            & powercfg.exe -setactive $d.Esquema
        }
        Reset = {
            $esquema = Get-ActiveSchemeGuid
            $ruta = Get-CoreParkingPath $esquema
            if ((Get-RegState $ruta 'ACSettingIndex').Existe) {
                Remove-ItemProperty -LiteralPath $ruta -Name 'ACSettingIndex' -Force -ErrorAction Stop
            }
            & powercfg.exe -setactive $esquema
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
        }
    }
}

# ------------------------------------------------------------
#  Estado, detalle y aplicación
# ------------------------------------------------------------
# Devuelve $true (aplicado), $false (pendiente) o $null (no se puede saber)
function Test-TweakApplied {
    param($Tweak)
    try {
        if ($Tweak.tipo -eq 'accion') {
            $h = $script:Acciones[$Tweak.accion]
            if (-not $h -or -not $h.Test) { return $null }
            $sb = $h.Test
            return (& $sb)
        }
        $cambios = @(Get-TweakChanges $Tweak)
        if ($cambios.Count -eq 0) { return $null }
        $estadoDesconocido = $false
        foreach ($c in $cambios) {
            $s = Get-RegState $c.ruta $c.nombre
            if ($c.eliminar) {
                if ($s.Existe) { return $false }
                $estadoDesconocido = $true
                continue
            }
            if (-not $s.Existe) { return $false }
            $tipo = if ($c.tipoValor) { $c.tipoValor } else { 'DWord' }
            if (-not (Test-RegValueEqual $s.Valor $c.valor $tipo)) { return $false }
        }
        if ($estadoDesconocido) { return $null }
        return $true
    }
    catch { return $null }
}

function Get-TweakAppliedState {
    param($Tweak)

    $estado = Test-TweakApplied -Tweak $Tweak
    if ($null -eq $estado) {
        $historial = @(Read-History | Where-Object { $_.TweakId -eq $Tweak.id })
        if ($historial.Count -gt 0) { return $true }
    }
    return $estado
}

function Invoke-TweakResetToDefault {
    param($Tweak)

    if ($Tweak.tipo -eq 'accion') {
        $h = $script:Acciones[$Tweak.accion]
        if (-not $h -or -not $h.Reset) {
            throw "No hay un restablecimiento predeterminado definido para '$($Tweak.id)'."
        }
        $sb = $h.Reset
        [void](& $sb)
    }
    else {
        $cambios = if ($Tweak.cambiosDinamicos -eq 'nagle') {
            @(Get-NagleResetChanges)
        }
        else {
            @(Get-TweakChanges $Tweak)
        }
        if ($cambios.Count -eq 0) { throw 'No se encontraron valores para restablecer.' }

        foreach ($c in $cambios) {
            if ($c.eliminar) {
                if (-not $c.restablecer) {
                    throw "No se puede reconstruir el valor eliminado de '$($Tweak.id)' sin historial."
                }
                if ($c.restablecer.validarExiste) {
                    $archivo = [Environment]::ExpandEnvironmentVariables([string]$c.restablecer.validarExiste)
                    if (-not (Test-Path -LiteralPath $archivo)) {
                        throw "No se encontró el archivo necesario para restablecer '$($Tweak.id)': $archivo"
                    }
                }
                $tipo = if ($c.restablecer.tipoValor) { $c.restablecer.tipoValor } else { 'String' }
                $valor = [Environment]::ExpandEnvironmentVariables([string]$c.restablecer.valor)
                Set-RegValue -Ruta $c.ruta -Nombre $c.nombre -Valor $valor -Tipo $tipo
            }
            elseif ((Get-RegState $c.ruta $c.nombre).Existe) {
                Remove-ItemProperty -LiteralPath $c.ruta -Name $c.nombre -Force -ErrorAction Stop
            }
        }
    }

    Write-Log "RESTABLECER DEFAULT $($Tweak.id)"
}

function Show-TweakDetail {
    param($T)
    Write-Host ''
    Write-Host "   $($T.nombre)" -ForegroundColor Cyan
    Write-Host "   $($T.descripcion)" -ForegroundColor Gray
    Write-Host ("   Riesgo: {0}" -f $T.riesgo) -ForegroundColor (Get-RiskColor $T)
    if ($T.requiere -eq 'reinicio') { Write-Host '   Requiere reiniciar.' -ForegroundColor DarkGray }
    elseif ($T.requiere -eq 'sesion') { Write-Host '   Requiere cerrar sesión y volver a entrar.' -ForegroundColor DarkGray }
    Write-Host ''
    if ($T.tipo -eq 'accion') {
        Write-Host '   Ejecuta una acción interna de Gonix (se guarda lo necesario para deshacerla).' -ForegroundColor DarkGray
    }
    else {
        foreach ($c in @(Get-TweakChanges $T)) {
            $s = Get-RegState $c.ruta $c.nombre
            $actual = if ($s.Existe) { $s.Valor } else { '(no existe)' }
            $nuevo  = if ($c.eliminar) { '(se elimina)' } else { $c.valor }
            Write-Host "   $($c.ruta)" -ForegroundColor DarkGray
            Write-Host "     $($c.nombre):  $actual  ->  $nuevo" -ForegroundColor DarkGray
        }
    }
    Write-Host ''
}

function Invoke-TweakApply {
    param($Tweak)
    $res = [pscustomobject]@{ Id = $Tweak.id; Nombre = $Tweak.nombre; Estado = 'ok'; Mensaje = '' }
    try {
        if ($Tweak.tipo -eq 'accion') {
            $h = $script:Acciones[$Tweak.accion]
            if (-not $h) { throw "Acción interna desconocida: $($Tweak.accion)" }
            $sb = $h.Apply
            $datos = @(& $sb) | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1
            Add-History @{ Tipo = 'accion'; TweakId = $Tweak.id; Accion = $Tweak.accion; Datos = $datos }
        }
        else {
            $cambios = @(Get-TweakChanges $Tweak)
            if ($cambios.Count -eq 0) { throw 'No hay nada para modificar en este equipo (por ejemplo, sin adaptador de red activo).' }
            $hechos = 0; $fallos = 0; $ultimoError = ''
            foreach ($c in $cambios) {
                try {
                    $s = Get-RegState $c.ruta $c.nombre
                    if ($c.eliminar) {
                        if ($s.Existe) {
                            Remove-ItemProperty -LiteralPath $c.ruta -Name $c.nombre -Force -ErrorAction Stop
                            Add-History @{ Tipo = 'registro'; TweakId = $Tweak.id; Ruta = $c.ruta; Nombre = $c.nombre
                                           Existia = $true; ValorAnterior = $s.Valor; TipoValor = $s.Tipo }
                        }
                    }
                    else {
                        $tipo = if ($c.tipoValor) { $c.tipoValor } else { 'DWord' }
                        Set-RegValue -Ruta $c.ruta -Nombre $c.nombre -Valor $c.valor -Tipo $tipo
                        $tipoPrev = if ($s.Existe) { $s.Tipo } else { $tipo }
                        Add-History @{ Tipo = 'registro'; TweakId = $Tweak.id; Ruta = $c.ruta; Nombre = $c.nombre
                                       Existia = $s.Existe; ValorAnterior = $s.Valor; TipoValor = $tipoPrev }
                    }
                    $hechos++
                }
                catch { $fallos++; $ultimoError = $_.Exception.Message }
            }
            if ($fallos -gt 0 -and $hechos -eq 0) { throw $ultimoError }
            if ($fallos -gt 0) {
                $res.Estado = 'parcial'
                $res.Mensaje = "$fallos de $($cambios.Count) cambios no se pudieron aplicar ($ultimoError)"
            }
        }
    }
    catch {
        $res.Estado = 'error'
        $res.Mensaje = $_.Exception.Message
    }
    Write-Log ("APLICAR {0}: {1} {2}" -f $Tweak.id, $res.Estado, $res.Mensaje)
    return $res
}

# Punto único de entrada para aplicar uno o varios tweaks (menús, perfiles, "aplicar todos")
function Invoke-TweakSet {
    param(
        [string[]]$Ids,
        [string]$Titulo = '',
        [string]$Descripcion = '',
        [switch]$Alternar
    )

    $tweaks = @()
    foreach ($id in $Ids) {
        $t = Get-TweakById $id
        if ($t -and $tweaks.id -notcontains $t.id) { $tweaks += $t }
        elseif (-not $t) { Write-Warn "Tweak desconocido: $id" }
    }
    if ($tweaks.Count -eq 0) { Write-Warn 'No hay nada para aplicar.'; return }

    Write-Host ''
    if ($Titulo)      { Write-Host "   === $Titulo ===" -ForegroundColor Cyan }
    if ($Descripcion) { Write-Host "   $Descripcion" -ForegroundColor Gray }
    Write-Host ''

    $pendientes = @()
    $aplicados = @()
    $sinHistorial = @()
    $historialActual = if ($Alternar) { @(Read-History) } else { @() }
    $cancelado = $false
    foreach ($t in $tweaks) {
        $estado = Get-TweakAppliedState $t
        if ($Alternar -and $null -eq $estado) {
            $decision = (Read-Host "   Estado desconocido para '$($t.nombre)'. [A] aplicar / [R] restablecer valor predeterminado / Enter cancelar").Trim().ToUpperInvariant()
            if ($decision -eq 'R') {
                $aplicados += $t
                $sinHistorial += $t
                Write-Host ('   [restablecer] {0}' -f $t.nombre) -ForegroundColor Yellow
            }
            elseif ($decision -eq 'A') {
                $pendientes += $t
                Write-Host ('   [  aplicar  ] {0}{1}' -f $t.nombre, (Get-RiskSuffix $t)) -ForegroundColor (Get-RiskColor $t)
            }
            else {
                Write-Warn 'Operación cancelada.'
                $cancelado = $true
                break
            }
        }
        elseif ($estado -eq $true) {
            if ($Alternar) {
                $aplicados += $t
                $hayHistorial = @($historialActual | Where-Object { $_.TweakId -eq $t.id }).Count -gt 0
                if (-not $hayHistorial) {
                    $sinHistorial += $t
                    Write-Host ('   [restablecer] {0}' -f $t.nombre) -ForegroundColor Yellow
                }
                else {
                    Write-Host ('   [desactivar] {0}' -f $t.nombre) -ForegroundColor Yellow
                }
            }
            else {
                Write-Host ('   [ya aplicado] {0}' -f $t.nombre) -ForegroundColor DarkGray
            }
        }
        else {
            $pendientes += $t
            Write-Host ('   [  aplicar  ] {0}{1}' -f $t.nombre, (Get-RiskSuffix $t)) -ForegroundColor (Get-RiskColor $t)
        }
    }
    if ($cancelado) { return }
    Write-Host ''
    if ($pendientes.Count -eq 0 -and $aplicados.Count -eq 0) { Write-Ok 'Todo esto ya estaba aplicado.'; return }

    if ($sinHistorial.Count -gt 0) {
        Write-Warn 'Sin historial, se usarán los valores predeterminados documentados de Windows; no se recuperarán personalizaciones anteriores.'
    }

    $hayAlto = @($pendientes | Where-Object { $_.riesgo -eq 'alto' }).Count -gt 0
    if ($hayAlto) {
        Write-Warn 'Incluye tweaks de RIESGO ALTO: pueden causar inestabilidad, calor o consumo excesivo.'
        $c = Read-Host '   Para continuar escribí ACEPTO (Enter para cancelar)'
        if ($c -cne 'ACEPTO') { Write-Warn 'Cancelado.'; return }
    }
    else {
        $pregunta = if ($sinHistorial.Count -gt 0) {
            $conHistorial = $aplicados.Count - $sinHistorial.Count
            "¿Aplicar $($pendientes.Count), desactivar $conHistorial y restablecer $($sinHistorial.Count) al valor predeterminado?"
        }
        elseif ($aplicados.Count -gt 0) {
            "¿Aplicar $($pendientes.Count) y desactivar $($aplicados.Count) tweak(s)?"
        }
        else {
            "¿Aplicar $($pendientes.Count) cambio(s)?"
        }
        if (-not (Confirm-Gonix $pregunta)) { Write-Warn 'Cancelado.'; return }
    }

    if ($pendientes.Count -gt 0 -and -not $script:PuntoOfrecido -and ($pendientes.Count -ge 3 -or $hayAlto)) {
        $script:PuntoOfrecido = $true
        if (Confirm-Gonix '¿Crear antes un punto de restauración? (recomendado)') {
            if (-not (New-GonixRestorePoint)) {
                if (-not (Confirm-Gonix '¿Continuar igual sin punto de restauración?')) { Write-Warn 'Cancelado.'; return }
            }
        }
    }

    Write-Host ''
    foreach ($t in $aplicados) {
        if ($sinHistorial.id -contains $t.id) {
            try {
                Invoke-TweakResetToDefault -Tweak $t
                Write-Ok "$($t.nombre) restablecido al valor predeterminado de Windows."
            }
            catch {
                Write-Fail "$($t.nombre): $($_.Exception.Message)"
                Write-Log "RESTABLECER DEFAULT FALLO $($t.id): $($_.Exception.Message)"
            }
        }
        else {
            $r = Undo-Tweak -TweakId $t.id
            if ($r.Total -eq 0) {
                try {
                    Invoke-TweakResetToDefault -Tweak $t
                    Write-Ok "$($t.nombre) restablecido al valor predeterminado de Windows."
                }
                catch {
                    Write-Fail "$($t.nombre): $($_.Exception.Message)"
                    Write-Log "RESTABLECER DEFAULT FALLO $($t.id): $($_.Exception.Message)"
                }
            }
            elseif ($r.Fallos -gt 0) {
                Write-Warn "$($t.nombre): se revirtieron $($r.Ok) de $($r.Total) cambios."
            }
            else {
                Write-Ok "$($t.nombre) desactivado; se restauró su estado anterior."
            }
        }
    }

    $resultados = @()
    if ($pendientes.Count -gt 0) {
        Start-Lote
        try {
            foreach ($t in $pendientes) {
                $r = @(Invoke-TweakApply $t) | Select-Object -Last 1
                $resultados += $r
                switch ($r.Estado) {
                    'ok'      { Write-Ok $t.nombre }
                    'parcial' { Write-Warn "$($t.nombre): $($r.Mensaje)" }
                    default   { Write-Fail "$($t.nombre): $($r.Mensaje)" }
                }
            }
        }
        finally { Save-History }
    }

    if ($pendientes.Count -gt 0) {
        $aplicadosOk = @($resultados | Where-Object { $_.Estado -ne 'error' })
        $errores = @($resultados | Where-Object { $_.Estado -eq 'error' })
        Write-Host ''
        Write-Host ('   Resultado: {0} aplicado(s), {1} con error.' -f $aplicadosOk.Count, $errores.Count) -ForegroundColor White

        $idsOk = @($aplicadosOk | ForEach-Object { $_.Id })
        $reqs = @($pendientes | Where-Object { $idsOk -contains $_.id } | ForEach-Object { $_.requiere })
        if ($reqs -contains 'reinicio') { Write-Warn 'Reiniciá la PC para que todo tome efecto.' }
        elseif ($reqs -contains 'sesion') { Write-Warn 'Cerrá sesión y volvé a entrar para ver todos los cambios.' }
        if ($aplicadosOk.Count -gt 0) { Write-Info 'Podés revertirlo desde "Historial y deshacer".' }
    }
}
