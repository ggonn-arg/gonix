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

function Get-GamingDiagnostic {
    $errores = New-Object System.Collections.ArrayList
    $os = $null
    $procesadores = @()
    $equipo = $null
    $adaptadoresVideo = @()

    try { $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop | Select-Object -First 1 }
    catch { [void]$errores.Add("Windows: $($_.Exception.Message)") }
    try { $procesadores = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop) }
    catch { [void]$errores.Add("CPU: $($_.Exception.Message)") }
    try { $equipo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop | Select-Object -First 1 }
    catch { [void]$errores.Add("Equipo y memoria: $($_.Exception.Message)") }
    try { $adaptadoresVideo = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name }) }
    catch { [void]$errores.Add("GPU: $($_.Exception.Message)") }

    $nombresCpu = @($procesadores | ForEach-Object { $_.Name } | Where-Object { $_ } | Select-Object -Unique)
    $cpu = if ($nombresCpu.Count -gt 0) { $nombresCpu -join ', ' } else { 'No disponible' }
    if ($procesadores.Count -gt 0) {
        $nucleos = ($procesadores | Measure-Object -Property NumberOfCores -Sum).Sum
        $hilos = ($procesadores | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        $cpu += " ($nucleos núcleos / $hilos hilos)"
    }

    $ramGB = $null
    if ($equipo -and $equipo.TotalPhysicalMemory) {
        $ramGB = [math]::Round($equipo.TotalPhysicalMemory / 1GB, 1)
    }
    $tipoEquipo = if ($equipo) {
        switch ([int]$equipo.PCSystemType) {
            1 { 'Escritorio' }
            2 { 'Portátil' }
            3 { 'Workstation' }
            default { 'No determinado' }
        }
    } else { 'No determinado' }
    $esPortatil = $equipo -and [int]$equipo.PCSystemType -eq 2

    $windows = 'No disponible'
    if ($os) { $windows = '{0} (compilación {1})' -f $os.Caption, $os.BuildNumber }
    $gpus = @($adaptadoresVideo | ForEach-Object {
        [pscustomobject]@{ Nombre = $_.Name; Driver = $_.DriverVersion }
    })

    $gameBarPath = 'HKCU:\Software\Microsoft\GameBar'
    $gameModeAllowed = Get-RegState $gameBarPath 'AllowAutoGameMode'
    $gameModeEnabled = Get-RegState $gameBarPath 'AutoGameModeEnabled'
    if ($gameModeAllowed.Existe -and $gameModeEnabled.Existe) {
        if ([int]$gameModeAllowed.Valor -eq 1 -and [int]$gameModeEnabled.Valor -eq 1) { $gameMode = 'Activado' }
        elseif ([int]$gameModeAllowed.Valor -eq 0 -and [int]$gameModeEnabled.Valor -eq 0) { $gameMode = 'Desactivado' }
        else { $gameMode = 'Configuración mixta' }
    } else { $gameMode = 'No determinado (Windows puede usar su valor predeterminado)' }

    $gameDvr = Get-RegState 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
    $capture = Get-RegState 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
    if ($gameDvr.Existe -and $capture.Existe) {
        if ([int]$gameDvr.Valor -eq 0 -and [int]$capture.Valor -eq 0) { $gameDvrState = 'Grabación en segundo plano desactivada' }
        elseif ([int]$gameDvr.Valor -eq 1 -and [int]$capture.Valor -eq 1) { $gameDvrState = 'Grabación en segundo plano activada' }
        else { $gameDvrState = 'Configuración mixta' }
    } else { $gameDvrState = 'No determinado' }

    $hagsState = Get-RegState 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
    if (-not $hagsState.Existe) { $hags = 'No configurada / valor predeterminado de Windows' }
    else {
        switch ([int]$hagsState.Valor) {
            2 { $hags = 'Activada' }
            1 { $hags = 'Desactivada' }
            default { $hags = "Valor $($hagsState.Valor)" }
        }
    }

    $planEnergia = 'No disponible'
    try {
        $salidaPlan = & powercfg.exe /getactivescheme 2>&1
        if ($LASTEXITCODE -eq 0 -and $salidaPlan) { $planEnergia = ($salidaPlan | Out-String).Trim() }
        else { [void]$errores.Add("Plan de energía: powercfg devolvió el código $LASTEXITCODE.") }
    }
    catch { [void]$errores.Add("Plan de energía: $($_.Exception.Message)") }

    return [pscustomobject]@{
        Windows = $windows
        CPU = $cpu
        RAMGB = $ramGB
        TipoEquipo = $tipoEquipo
        EsPortatil = [bool]$esPortatil
        GPU = $gpus
        ModoJuego = $gameMode
        CapturaJuego = $gameDvrState
        HAGS = $hags
        PlanEnergia = $planEnergia
        Errores = @($errores.ToArray())
    }
}

function Get-GamingRecommendations {
    param([Parameter(Mandatory = $true)]$Diagnostico)

    $recomendaciones = New-Object System.Collections.ArrayList
    if ($Diagnostico.ModoJuego -ne 'Activado') {
        [void]$recomendaciones.Add([pscustomobject]@{
            Nivel = 'BAJO'
            Titulo = 'Activar Modo Juego'
            Motivo = 'Windows puede priorizar el juego y reducir algunas tareas de fondo.'
            Advertencia = 'No garantiza más FPS. En este equipo el estado figura como: ' + $Diagnostico.ModoJuego
        })
    }

    if ($Diagnostico.CapturaJuego -eq 'Grabación en segundo plano activada') {
        [void]$recomendaciones.Add([pscustomobject]@{
            Nivel = 'BAJO'
            Titulo = 'Desactivar GameDVR solo si no usás clips automáticos'
            Motivo = 'La captura constante puede usar recursos mientras jugás.'
            Advertencia = 'Se pierde la grabación en segundo plano; la Game Bar puede seguir abierta.'
        })
    }

    $gpuCompatibleHags = $false
    foreach ($gpu in @($Diagnostico.GPU)) {
        if ($gpu.Nombre -match '(?i)\b(GTX\s*(10\d{2}|16\d{2})|RTX\s*\d{4}|RX\s*(5\d{3}|6\d{3}|7\d{3}|9\d{3}))\b') {
            $gpuCompatibleHags = $true
        }
    }
    if ($gpuCompatibleHags -and $Diagnostico.HAGS -ne 'Activada') {
        [void]$recomendaciones.Add([pscustomobject]@{
            Nivel = 'MEDIO'
            Titulo = 'Probar HAGS de a un cambio'
            Motivo = 'La GPU detectada está dentro de la compatibilidad indicada por Gonix.'
            Advertencia = 'Puede mejorar o empeorar la fluidez; requiere reiniciar. Compará el mismo juego y revertí si empeora.'
        })
    }
    elseif (-not $gpuCompatibleHags -and @($Diagnostico.GPU).Count -gt 0) {
        [void]$recomendaciones.Add([pscustomobject]@{
            Nivel = 'PRECAUCIÓN'
            Titulo = 'No recomiendo cambiar HAGS en esta GPU'
            Motivo = 'El modelo detectado no coincide con los requisitos de compatibilidad que documenta este tweak.'
            Advertencia = "Estado actual: $($Diagnostico.HAGS). No lo cambies solo por buscar más FPS."
        })
    }

    $planMaximo = $Diagnostico.PlanEnergia -match '(?i)(ultimate performance|máximo rendimiento|maximo rendimiento)'
    if ($Diagnostico.EsPortatil) {
        [void]$recomendaciones.Add([pscustomobject]@{
            Nivel = 'ALTO'
            Titulo = 'Energía: usar el perfil Gaming solo conectado a corriente'
            Motivo = 'En notebooks, el modo de máximo rendimiento puede elevar temperatura y consumo.'
            Advertencia = 'No lo recomiendo con batería; si se calienta, volvé al plan anterior.'
        })
    }
    elseif ($Diagnostico.TipoEquipo -in @('Escritorio', 'Workstation') -and -not $planMaximo -and $Diagnostico.PlanEnergia -ne 'No disponible') {
        [void]$recomendaciones.Add([pscustomobject]@{
            Nivel = 'ALTO'
            Titulo = 'Probar máximo rendimiento solo si el juego está limitado por CPU'
            Motivo = 'Puede evitar algunos límites de ahorro de energía en equipos de escritorio.'
            Advertencia = 'Aumenta calor y consumo y puede no cambiar los FPS. Gonix pide ACEPTO y ofrece un punto de restauración.'
        })
    }
    elseif ($planMaximo) {
        [void]$recomendaciones.Add([pscustomobject]@{
            Nivel = 'INFO'
            Titulo = 'El plan Máximo rendimiento ya está activo'
            Motivo = 'No hace falta volver a aplicarlo.'
            Advertencia = 'Vigilá las temperaturas; más consumo no significa automáticamente más FPS.'
        })
    }

    [void]$recomendaciones.Add([pscustomobject]@{
        Nivel = 'INFO'
        Titulo = 'No aplicar tweaks de latencia a ciegas'
        Motivo = 'Nagle solo afecta conexiones TCP; la mayoría de los juegos online usan UDP. Ninguno cambia los FPS ni la distancia al servidor.'
        Advertencia = 'Probá ajustes de red solo si medís un problema concreto y podés comparar antes y después.'
    })

    return @($recomendaciones.ToArray())
}

function Get-TweaksByCategory {
    param([string]$Categoria)
    return @($script:Tweaks | Where-Object { $_.categoria -eq $Categoria })
}

function Get-StartupItemId {
    param([string]$Fuente, [string]$Identidad)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $contenido = [System.Text.Encoding]::UTF8.GetBytes("$Fuente`0$Identidad".ToLowerInvariant())
        $hash = [BitConverter]::ToString($sha.ComputeHash($contenido)).Replace('-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
    return "startup-$hash"
}

function Get-StartupItems {
    param(
        [string]$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        [string]$StartupFolder = ''
    )

    if (-not $StartupFolder) { $StartupFolder = [Environment]::GetFolderPath('Startup') }
    $items = New-Object System.Collections.ArrayList
    $vistos = @{}
    $historial = @(Read-History)
    $extensiones = @('.lnk', '.url', '.bat', '.cmd', '.exe', '.ps1', '.vbs', '.js')

    if (Test-Path -LiteralPath $RunKey) {
        try {
            $run = Get-Item -LiteralPath $RunKey -ErrorAction Stop
            foreach ($nombre in $run.GetValueNames()) {
                if ([string]::IsNullOrWhiteSpace($nombre)) { continue }
                $tipo = $run.GetValueKind($nombre).ToString()
                if ($tipo -notin @('String', 'ExpandString')) {
                    $nombreSeguro = [regex]::Replace([string]$nombre, '[\x00-\x1F\x7F]', ' ')
                    Write-Warn "Se omitió '$nombreSeguro': su valor de inicio no es texto."
                    continue
                }
                $id = Get-StartupItemId -Fuente 'registro' -Identidad "$RunKey|$nombre"
                $valor = $run.GetValue($nombre, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                [void]$items.Add([pscustomobject]@{
                    Id = $id; Tipo = 'inicio-registro'; Nombre = $nombre
                    Fuente = 'Registro de inicio'; Estado = 'Activado'
                    Ruta = $RunKey; NombreValor = $nombre; Valor = $valor; TipoValor = $tipo
                    Comando = [string]$valor; ArchivoOriginal = ''; ArchivoDeshabilitado = ''
                })
                $vistos[$id] = $true
            }
        }
        catch { Write-Warn "No se pudo leer el Registro de inicio del usuario: $($_.Exception.Message)" }
    }

    $registroDeshabilitado = @{}
    foreach ($entrada in $historial) {
        if ($entrada.Tipo -eq 'inicio-registro' -and $entrada.Ruta -eq $RunKey) {
            $registroDeshabilitado[[string]$entrada.TweakId] = $entrada
        }
    }
    foreach ($id in @($registroDeshabilitado.Keys)) {
        if ($vistos.ContainsKey($id)) { continue }
        $entrada = $registroDeshabilitado[$id]
        if ((Get-RegState -Ruta $RunKey -Nombre $entrada.NombreValor).Existe) { continue }
        [void]$items.Add([pscustomobject]@{
            Id = $id; Tipo = 'inicio-registro'; Nombre = $entrada.Nombre
            Fuente = 'Registro de inicio'; Estado = 'Desactivado'
            Ruta = $RunKey; NombreValor = $entrada.NombreValor
            Valor = $entrada.ValorAnterior; TipoValor = $entrada.TipoValor
            Comando = [string]$entrada.ValorAnterior; ArchivoOriginal = ''; ArchivoDeshabilitado = ''
        })
    }

    if ($StartupFolder -and (Test-Path -LiteralPath $StartupFolder)) {
        try {
            foreach ($archivo in (Get-ChildItem -LiteralPath $StartupFolder -File -Force -ErrorAction Stop)) {
                if ($archivo.Extension -notin $extensiones) { continue }
                $id = Get-StartupItemId -Fuente 'carpeta' -Identidad $archivo.FullName
                [void]$items.Add([pscustomobject]@{
                    Id = $id; Tipo = 'inicio-archivo'; Nombre = $archivo.BaseName
                    Fuente = 'Carpeta Inicio'; Estado = 'Activado'
                    Ruta = ''; NombreValor = ''; Valor = ''; TipoValor = ''
                    Comando = $archivo.FullName; ArchivoOriginal = $archivo.FullName
                    ArchivoDeshabilitado = ''
                })
                $vistos[$id] = $true
            }
        }
        catch { Write-Warn "No se pudo leer la carpeta Inicio del usuario: $($_.Exception.Message)" }
    }

    $archivosDeshabilitados = @{}
    foreach ($entrada in $historial) {
        if ($entrada.Tipo -eq 'inicio-archivo') {
            $archivosDeshabilitados[[string]$entrada.TweakId] = $entrada
        }
    }
    foreach ($id in @($archivosDeshabilitados.Keys)) {
        if ($vistos.ContainsKey($id)) { continue }
        $entrada = $archivosDeshabilitados[$id]
        if (-not (Test-Path -LiteralPath $entrada.ArchivoDeshabilitado)) { continue }
        if (Test-Path -LiteralPath $entrada.ArchivoOriginal) { continue }
        [void]$items.Add([pscustomobject]@{
            Id = $id; Tipo = 'inicio-archivo'
            Nombre = [System.IO.Path]::GetFileNameWithoutExtension($entrada.ArchivoOriginal)
            Fuente = 'Carpeta Inicio'; Estado = 'Desactivado'
            Ruta = ''; NombreValor = ''; Valor = ''; TipoValor = ''
            Comando = $entrada.ArchivoDeshabilitado
            ArchivoOriginal = $entrada.ArchivoOriginal
            ArchivoDeshabilitado = $entrada.ArchivoDeshabilitado
        })
    }

    return @($items | Sort-Object -Property Fuente, Nombre)
}

function Toggle-StartupItem {
    param($Item)

    if ($Item.Estado -eq 'Desactivado') {
        $resultado = Undo-Tweak -TweakId $Item.Id
        if ($resultado.Total -eq 0) { throw 'No se encontró el historial necesario para reactivar este elemento.' }
        if ($resultado.Fallos -gt 0) { throw 'No se pudo reactivar el elemento; sigue registrado en el historial.' }
        return
    }

    Start-Lote
    try {
        if ($Item.Tipo -eq 'inicio-registro') {
            $actual = Get-RegState -Ruta $Item.Ruta -Nombre $Item.NombreValor
            if (-not $actual.Existe) { throw 'La entrada ya no está en el Registro; actualizá la lista.' }
            if ($actual.Tipo -ne $Item.TipoValor -or
                -not (Test-RegValueEqual -Actual $actual.Valor -Deseado $Item.Valor -Tipo $Item.TipoValor)) {
                throw 'La entrada cambió desde que se mostró; actualizá la lista antes de continuar.'
            }
            Remove-ItemProperty -LiteralPath $Item.Ruta -Name $Item.NombreValor -Force -ErrorAction Stop
            Add-History @{
                Tipo = 'inicio-registro'; TweakId = $Item.Id; Nombre = $Item.Nombre
                Ruta = $Item.Ruta; NombreValor = $Item.NombreValor
                Existia = $true; ValorAnterior = $actual.Valor; TipoValor = $actual.Tipo
            }
        }
        elseif ($Item.Tipo -eq 'inicio-archivo') {
            if (-not (Test-Path -LiteralPath $Item.ArchivoOriginal -PathType Leaf)) {
                throw 'El acceso directo o archivo ya no está en la carpeta Inicio; actualizá la lista.'
            }
            $deshabilitado = "$($Item.ArchivoOriginal).gonix-disabled"
            if (Test-Path -LiteralPath $deshabilitado) {
                throw "Ya existe un archivo de respaldo: $deshabilitado"
            }
            Move-Item -LiteralPath $Item.ArchivoOriginal -Destination $deshabilitado -ErrorAction Stop
            Add-History @{
                Tipo = 'inicio-archivo'; TweakId = $Item.Id; Nombre = $Item.Nombre
                ArchivoOriginal = $Item.ArchivoOriginal; ArchivoDeshabilitado = $deshabilitado
            }
        }
        else { throw 'Tipo de elemento de inicio desconocido.' }
    }
    finally { Save-History }
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
            $esquema = Get-ActiveSchemeGuid
            $ruta = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$esquema\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
            $prev = Get-RegState $ruta 'ACSettingIndex'
            $valorAnterior = 0
            if ($prev.Existe) { $valorAnterior = [int]$prev.Valor }

            & powercfg.exe -setacvalueindex $esquema 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            try {
                & powercfg.exe -setactive $esquema
                if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            }
            catch {
                if ($prev.Existe) {
                    & powercfg.exe -setacvalueindex $esquema 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 $valorAnterior
                    if ($LASTEXITCODE -ne 0) { throw "No se pudo activar el plan ni restaurar el valor anterior del ahorro USB." }
                }
                else {
                    Remove-RegValue -Ruta $ruta -Nombre 'ACSettingIndex'
                }
                throw
            }
            return @{ Esquema = $esquema; Tenia = [bool]$prev.Existe; Anterior = $valorAnterior }
        }
        Undo  = {
            param($d)
            $esquema = if ($d.Esquema) { [string]$d.Esquema } else { Get-ActiveSchemeGuid }
            $teniaValor = if ($d -is [System.Collections.IDictionary]) {
                $d.Contains('Tenia')
            } else {
                [bool]$d.PSObject.Properties['Tenia']
            }
            if ($teniaValor) {
                if ([bool]$d.Tenia) {
                    $anterior = [int]$d.Anterior
                    & powercfg.exe -setacvalueindex $esquema 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 $anterior
                    if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
                }
                else {
                    $ruta = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$esquema\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
                    Remove-RegValue -Ruta $ruta -Nombre 'ACSettingIndex'
                }
            }
            else {
                & powercfg.exe -setacvalueindex $esquema 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1
                if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
            }
            & powercfg.exe -setactive $esquema
            if ($LASTEXITCODE -ne 0) { throw "powercfg devolvió el código $LASTEXITCODE" }
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
