function Get-TweaksFromFile {
    param($Archivo)
    $path = Join-Path $script:GonixRoot "tweaks\$Archivo"
    if (Test-Path -LiteralPath $path) { return @(Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json) }
    return @()
}

function Get-TweakById {
    param([string]$Id)
    $files = @("privacidad.json", "sistema.json", "rendimiento.json", "avanzado.json")
    foreach ($f in $files) {
        $t = Get-TweaksFromFile -Archivo $f | Where-Object { $_.id -eq $Id }
        if ($t) { return $t }
    }
    return $null
}

function Invoke-GonixAction {
    param([string]$Accion)

    switch ($Accion) {
        'disable-hibernation' { & powercfg.exe -h off; if ($LASTEXITCODE -ne 0) { throw "powercfg no pudo desactivar la hibernacion." } }
        'enable-hibernation' { & powercfg.exe -h on; if ($LASTEXITCODE -ne 0) { throw "powercfg no pudo activar la hibernacion." } }
        'disable-onedrive' { Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force }
        'set-dns-cloudflare' {
            Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
                ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses @('1.1.1.1','1.0.0.1') -ErrorAction Stop }
        }
        'disable-teredo' { & netsh.exe interface teredo set state disabled; if ($LASTEXITCODE -ne 0) { throw "No se pudo desactivar Teredo." } }
        'disable-diagtrack' {
            Stop-Service -Name DiagTrack -Force -ErrorAction SilentlyContinue
            Set-Service -Name DiagTrack -StartupType Disabled -ErrorAction Stop
        }
        'disable-maps-broker' { Set-Service -Name MapsBroker -StartupType Manual -ErrorAction Stop }
        'clean-temp-files' {
            Get-ChildItem -LiteralPath $env:TEMP -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            Get-ChildItem -LiteralPath 'C:\Windows\Temp' -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
        'run-disk-cleanup' { Start-Process cleanmgr.exe -ArgumentList '/sagerun:1' -ErrorAction Stop }
        'disable-usb-suspend' {
            & powercfg.exe -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            & powercfg.exe -setactive SCHEME_CURRENT
        }
        'optimize-xbox-services' {
            Set-Service -Name XblAuthManager,XblGameSave,XboxNetApiSvc,XboxGipSvc -StartupType Manual -ErrorAction Stop
        }
        'ultimate-performance-plan' {
            & powercfg.exe -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
            & powercfg.exe -setactive e9a42b02-d5df-448d-aa00-03f14749eb61
        }
        'disable-core-parking' {
            & powercfg.exe -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 100
            & powercfg.exe -setactive SCHEME_CURRENT
        }
        'disable-bitlocker' { Get-BitLockerVolume -ErrorAction Stop | Disable-BitLocker -ErrorAction Stop }
        'disable-windows-ai' { & dism.exe /Online /Disable-Feature /FeatureName:Recall /NoRestart; if ($LASTEXITCODE -ne 0) { throw "DISM no pudo desactivar Recall." } }
        default { throw "Accion no soportada: $Accion" }
    }
}

function Invoke-GonixUndoAction {
    param([string]$Accion)

    switch ($Accion) {
        'disable-hibernation' { & powercfg.exe -h on }
        'enable-hibernation' { & powercfg.exe -h off }
        'disable-onedrive' { Start-Process "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe" -ErrorAction SilentlyContinue }
        'set-dns-cloudflare' {
            Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue }
        }
        'disable-teredo' { & netsh.exe interface teredo set state type=default }
        'disable-diagtrack' { Set-Service -Name DiagTrack -StartupType Automatic -ErrorAction SilentlyContinue; Start-Service -Name DiagTrack -ErrorAction SilentlyContinue }
        'disable-maps-broker' { Set-Service -Name MapsBroker -StartupType Automatic -ErrorAction SilentlyContinue }
        'clean-temp-files' { }
        'run-disk-cleanup' { }
        'disable-usb-suspend' { & powercfg.exe -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1; & powercfg.exe -setactive SCHEME_CURRENT }
        'optimize-xbox-services' { Set-Service -Name XblAuthManager,XblGameSave,XboxNetApiSvc,XboxGipSvc -StartupType Automatic -ErrorAction SilentlyContinue }
        'ultimate-performance-plan' { & powercfg.exe -setactive 381b4222-f694-41f0-9685-ff5bb260df2e }
        'disable-core-parking' { & powercfg.exe -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR CPMINCORES 0; & powercfg.exe -setactive SCHEME_CURRENT }
        'disable-bitlocker' { throw "El cifrado de BitLocker no puede reactivarse automaticamente." }
        'disable-windows-ai' { throw "Recall no puede reactivarse automaticamente." }
        default { throw "Deshacer no soportado: $Accion" }
    }
}

function Invoke-GonixTweak {
    param([Parameter(Mandatory)][object]$Tweak)

    if ($Tweak.tipo -eq 'registro') {
        $cambios = if ($Tweak.cambios) {
            $Tweak.cambios
        } elseif ($Tweak.PSObject.Properties.Name -contains 'ruta') {
            @([PSCustomObject]@{
                ruta = $Tweak.ruta
                nombre = $Tweak.nombreValor
                valor = $Tweak.valorNuevo
                tipoValor = 'DWord'
            })
        } else {
            @()
        }

        foreach ($c in $cambios) {
            if (-not (Test-Path -LiteralPath $c.ruta)) { New-Item -Path $c.ruta -Force | Out-Null }
            $actual = $null
            $existe = $false
            try {
                $item = Get-ItemProperty -Path $c.ruta -Name $c.nombre -ErrorAction Stop
                $actual = $item.$($c.nombre)
                $existe = $true
            } catch {}

            $tipoVal = if ($c.tipoValor) { $c.tipoValor } else { 'DWord' }
            Set-ItemProperty -LiteralPath $c.ruta -Name $c.nombre -Value $c.valor -Type $tipoVal -Force -ErrorAction Stop
            Add-History @{ Tipo='registro'; TweakId=$Tweak.id; Ruta=$c.ruta; Nombre=$c.nombre; Existia=$existe; ValorAnterior=$actual; TipoValor=$tipoVal }
        }
    } elseif ($Tweak.tipo -eq 'accion') {
        Invoke-GonixAction -Accion $Tweak.accion
        if ($Tweak.PSObject.Properties.Name -notcontains 'reversible' -or $Tweak.reversible -ne $false) {
            Add-History @{ Tipo='accion'; TweakId=$Tweak.id; Accion=$Tweak.accion }
        }
    } else {
        throw "Tipo de tweak no soportado: $($Tweak.tipo)"
    }
}

function Invoke-Tweak {
    param([string]$Id)
    
    $tweak = Get-TweakById -Id $Id
    if (-not $tweak) { Write-Host "   [!] Tweak '$Id' no encontrado." -ForegroundColor Red; return }

    Write-Host ""
    Write-Host "   >>> $($tweak.nombre)" -ForegroundColor Cyan
    Write-Host "       $($tweak.descripcion)" -ForegroundColor Gray
    Write-Host ""

    $conf = Read-Host "   ¿Aplicar? (s/n)"
    if ($conf -ne "s") { Write-Host "   Cancelado." -ForegroundColor Yellow; return }

    try {
        if (-not $script:LoteActual) { Start-Lote }
        Invoke-GonixTweak -Tweak $tweak
        Write-Host "   [OK] Cambio aplicado." -ForegroundColor Green
    } catch { Write-Host "   [X] Error: $($_.Exception.Message)" -ForegroundColor Red }
}

function Show-DryRun {
    param([string]$Id)
    $tweak = Get-TweakById -Id $Id
    if (-not $tweak) { Write-Host "   [!] Tweak no encontrado." -ForegroundColor Red; return }
    
    Write-Host "`n   [SIMULACIÓN] $($tweak.nombre)" -ForegroundColor Cyan
    Write-Host "   $($tweak.descripcion)`n" -ForegroundColor Gray
    
    if ($tweak.tipo -eq 'registro') {
        $cambios = if ($tweak.cambios) { $tweak.cambios } else { @([PSCustomObject]@{ruta=$tweak.ruta; nombre=$tweak.nombreValor; valor=$tweak.valorNuevo}) }
        foreach ($c in $cambios) {
            $actual = "No existe"
            try { $item = Get-ItemProperty -Path $c.ruta -Name $c.nombre -ErrorAction Stop; $actual = $item.$($c.nombre) } catch {}
            Write-Host "   Ruta   : $($c.ruta)" -ForegroundColor DarkGray
            Write-Host "   Valor  : $($c.nombre)" -ForegroundColor DarkGray
            Write-Host "   Actual : $actual" -ForegroundColor Yellow
            Write-Host "   Nuevo  : $($c.valor)" -ForegroundColor Green
        }
    }
}

function Invoke-Profile {
    param([string]$NombreArchivo)
    $perfilPath = Join-Path $script:GonixRoot "profiles\$NombreArchivo.json"
    
    if (-not (Test-Path $perfilPath)) {
        Write-Host "   [!] Perfil no encontrado." -ForegroundColor Red
        return
    }
    
    $perfil = Get-Content -LiteralPath $perfilPath -Raw -Encoding UTF8 | ConvertFrom-Json
    
    Write-Banner
    Write-Host "   ========================================================" -ForegroundColor Cyan
    Write-Host "     PERFIL: $($perfil.nombre)" -ForegroundColor White
    Write-Host "   ========================================================" -ForegroundColor Cyan
    Write-Host "   $($perfil.descripcion)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Este perfil va a aplicar los siguientes cambios:" -ForegroundColor Yellow
    Write-Host ""

    # ==========================================================
    # ACÁ ESTÁ EL ARREGLO REAL:
    # No usamos Get-TweakById. Imprimimos el ID y un nombre amigable
    # sacado de un diccionario local para que NUNCA falle.
    # ==========================================================
    $diccionario = @{
        "disable-telemetry" = "Desactivar Telemetría"
        "disable-cortana" = "Desactivar Cortana"
        "disable-start-suggestions" = "Quitar Anuncios del Inicio"
        "disable-widgets" = "Desactivar Widgets"
        "disable-windows-search-bing" = "Quitar Bing de Búsqueda"
        "disable-background-apps" = "Desactivar Apps en 2do Plano"
        "disable-animations" = "Desactivar Animaciones"
        "disable-copilot" = "Desactivar Copilot"
        "disable-advertising-id" = "Desactivar ID de Publicidad"
        "disable-tailored-experiences" = "Desactivar Experiencias"
        "disable-online-speech-privacy" = "Desactivar Voz en Línea"
        "disable-feedback" = "Desactivar Comentarios"
        "disable-activity-history" = "Desactivar Historial de Actividad"
        "disable-location-tracking" = "Desactivar Rastreo de Ubicación"
        "disable-consumer-features" = "Desactivar Funciones de Consumidor"
        "disable-defender-samples" = "Desactivar Muestras de Defender"
        "disable-hibernation" = "Desactivar Hibernación"
        "enable-hibernation-laptops" = "Activar Hibernación (Notebooks)"
        "disable-gamedvr" = "Desactivar GameDVR"
        "disable-onedrive-startup" = "Quitar OneDrive del Inicio"
        "disable-startup-delay" = "Eliminar Retraso de Arranque"
        "set-dns-cloudflare" = "Configurar DNS Cloudflare"
        "enable-end-task" = "Habilitar Finalizar Tarea en Clic Derecho"
        "disable-storage-sense" = "Desactivar Sensor de Almacenamiento"
        "disable-teredo" = "Desactivar Teredo (IPv6)"
        "set-visual-effects-performance" = "Efectos Visuales a Máximo Rendimiento"
        "show-file-extensions" = "Mostrar Extensiones de Archivo"
        "disable-mouse-acceleration" = "Desactivar Aceleración del Mouse"
        "disable-sticky-keys" = "Desactivar Sticky Keys"
        "disable-diagtrack" = "Desactivar Servicio DiagTrack"
        "disable-maps-broker" = "Poner Servicio de Mapas en Manual"
        "clean-temp-files" = "Limpiar Archivos Temporales"
        "run-disk-cleanup" = "Ejecutar Liberador de Espacio"
        "optimize-services" = "Optimizar Servicios Xbox"
        "gpu-scheduling" = "Aceleración GPU (HAGS)"
        "disable-xbox-gamebar" = "Desactivar Barra de Juegos Xbox"
        "disable-network-throttling" = "Eliminar Límite de Ancho de Banda"
        "disable-usb-selective-suspend" = "Evitar Suspensión de Puertos USB"
        "ultimate-performance-plan" = "Plan de Energía 'Máximo Rendimiento'"
        "disable-core-parking" = "Desactivar Core Parking"
        "win32-priority-separation" = "Priorizar Procesos en Primer Plano"
        "disable-system-responsiveness" = "Desactivar Reserva de CPU"
        "disable-bitlocker" = "Desactivar BitLocker"
        "disable-windows-ai" = "Desactivar Windows AI"
        "disable-edge-debloat" = "Debloat de Microsoft Edge"
        "disable-fso" = "Desactivar Optimizaciones de Pantalla Completa"
        "set-time-utc" = "Establecer Hora en UTC"
    }

    $contador = 1
    foreach ($id in $perfil.tweaks) {
        $nombreAmigable = $diccionario[$id]
        if ($nombreAmigable) {
            Write-Host "   $contador. $nombreAmigable" -ForegroundColor White
        } else {
            Write-Host "   $contador. $id" -ForegroundColor Yellow
        }
        $contador++
    }

    Write-Host ""
    $conf = Read-Host "   ¿Querés aplicar TODOS estos cambios ahora? (s/n)"
    if ($conf -ne "s") {
        Write-Host "   Cancelado." -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "   Aplicando cambios..." -ForegroundColor Magenta
    
    Start-Lote
    foreach ($id in $perfil.tweaks) {
        $tweak = Get-TweakById -Id $id
        if (-not $tweak) { continue }
        try {
            Invoke-GonixTweak -Tweak $tweak
            Write-Host "   [OK] $($tweak.nombre) aplicado." -ForegroundColor Green
        } catch {
            Write-Host "   [X] $($tweak.nombre): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "   [OK] Perfil aplicado con éxito." -ForegroundColor Green
    Write-Host "   (Recordá reiniciar para que todo tome efecto)." -ForegroundColor Yellow
}

function Invoke-QuickOptimize {
    Write-Banner
    Write-Host "   ⚡ --- OPTIMIZACIÓN RÁPIDA --- ⚡" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Esta opción aplicará automáticamente los tweaks más seguros y efectivos:" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   1. Desactivar Telemetría" -ForegroundColor White
    Write-Host "   2. Desactivar Cortana y Widgets" -ForegroundColor White
    Write-Host "   3. Desactivar Apps en 2do Plano" -ForegroundColor White
    Write-Host "   4. Desactivar GameDVR (Gaming)" -ForegroundColor White
    Write-Host "   5. Quitar Anuncios del Menú Inicio" -ForegroundColor White
    Write-Host "   6. Aplicar preferencias visuales básicas" -ForegroundColor White
    Write-Host "   7. Efectos Visuales a Máximo Rendimiento" -ForegroundColor White
    Write-Host ""
    
    $conf = Read-Host "   ¿Aplicar estas optimizaciones ahora? (s/n)"
    if ($conf -ne "s") {
        Write-Host "   Cancelado." -ForegroundColor Yellow
        Start-Sleep 1
        return
    }

    Write-Host ""
    Write-Host "   Aplicando optimizaciones..." -ForegroundColor Magenta

    $tweaksAAplicar = @(
        "disable-telemetry",
        "disable-cortana",
        "disable-widgets",
        "disable-background-apps",
        "disable-gamedvr",
        "disable-start-suggestions",
        "gpu-scheduling",
        "set-visual-effects-performance"
    )

    Start-Lote

    foreach ($id in $tweaksAAplicar) {
        $tweak = Get-TweakById -Id $id
        if ($tweak) {
            Write-Host "   -> $($tweak.nombre)" -ForegroundColor DarkGray
            try {
                Invoke-GonixTweak -Tweak $tweak
            } catch {
                Write-Host "      [X] $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    Write-Host ""
    Write-Host "   [OK] Optimización rápida finalizada." -ForegroundColor Green
    Write-Host "   (Revisá el resumen anterior; reiniciar puede ser necesario)." -ForegroundColor Yellow
    Read-Host "   Enter para volver al menú"
}
function Invoke-AllTweaks {
    param([string]$Categoria)

    Write-Host "`n   Aplicando TODOS los tweaks de la categoría '$Categoria'..." -ForegroundColor Magenta
    Write-Host "   (Solo se aplican los cambios disponibles para esta categoría)" -ForegroundColor DarkGray

    $archivo = "$Categoria.json"
    $lista = Get-TweaksFromFile -Archivo $archivo

    if ($lista.Count -eq 0) {
        Write-Host "   [!] No se encontraron tweaks en $archivo" -ForegroundColor Red
        return
    }

    $conf = Read-Host "`n   ¿Confirmás aplicar todos estos cambios? (s/n)"
    if ($conf -ne "s") {
        Write-Host "   Cancelado." -ForegroundColor Yellow
        return
    }

    Start-Lote
    $ok = 0
    $fallidos = 0
    $omitidos = 0

    foreach ($tweak in $lista) {
        if ($tweak.PSObject.Properties.Name -contains 'masivoSeguro' -and $tweak.masivoSeguro -eq $false) {
            $omitidos++
            Write-Host "      [-] $($tweak.nombre) omitido por ser sensible o irreversible." -ForegroundColor Yellow
            continue
        }
        Write-Host "   -> $($tweak.nombre)" -ForegroundColor DarkGray
        try {
            Invoke-GonixTweak -Tweak $tweak
            $ok++
        } catch {
            $fallidos++
            Write-Host "      [X] $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    $color = if ($fallidos -eq 0) { 'Green' } else { 'Yellow' }
    Write-Host "`n   Resumen: $ok aplicados, $fallidos fallaron, $omitidos omitidos." -ForegroundColor $color
}
function Invoke-BloatwareRemoval {
    while ($true) {
        $appsPath = Join-Path $script:GonixRoot "tweaks\bloatware.json"
        if (-not (Test-Path -LiteralPath $appsPath)) {
            Write-Host "   [X] No se encontró tweaks\bloatware.json." -ForegroundColor Red
            Read-Host "   Enter para volver"
            return
        }
        $apps = @(Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8 | ConvertFrom-Json)

        Write-Banner
        Write-Host "   --- Desinstalador de Apps Preinstaladas ---" -ForegroundColor Magenta
        Write-Host "   (Seleccioná las apps que querés ELIMINAR)" -ForegroundColor DarkGray
        Write-Host ""

        # Al estar en el código, el bucle siempre va a separar cada app en su línea
        for ($i = 0; $i -lt $apps.Count; $i++) {
            Write-Host "   [$($i + 1)] $($apps[$i].nombre)" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "   Escribí los números separados por coma (ej: 1,3,5)." -ForegroundColor Cyan
        Write-Host "   O escribí [T] para eliminar TODAS las de esta lista." -ForegroundColor Green
        Write-Host "   Presioná '0' o Enter para volver." -ForegroundColor DarkGray
        Write-Host ""
        $seleccion = Read-Host "   Tu elección"

        if ([string]::IsNullOrWhiteSpace($seleccion) -or $seleccion -eq "0") {
            Write-Host "   Volviendo al menú anterior..." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500
            return 
        }

        $indicesAEliminar = @()
        if ($seleccion -match "^[Tt]$") {
            0..($apps.Count - 1) | ForEach-Object { $indicesAEliminar += $_ }
        } else {
            $partes = $seleccion -split ","
            foreach ($parte in $partes) {
                $num = 0
                if ([int]::TryParse($parte.Trim(), [ref]$num)) {
                    if ($num -gt 0 -and $num -le $apps.Count) {
                        $indicesAEliminar += ($num - 1)
                    }
                }
            }
        }

        if ($indicesAEliminar.Count -eq 0) {
            Write-Host "   [!] No se seleccionó ninguna app válida." -ForegroundColor Red
            Start-Sleep 1
            continue
        }

        Write-Host ""
        Write-Host "   Vas a eliminar: " -NoNewline
        $nombres = $indicesAEliminar | ForEach-Object { $apps[$_].nombre }
        Write-Host ($nombres -join ", ") -ForegroundColor Yellow
        Write-Host ""
        $conf = Read-Host "   ¿Confirmás la eliminación? (s/n)"
        
        if ($conf -ne "s") {
            Write-Host "   Cancelado." -ForegroundColor Yellow
            Start-Sleep 1
            continue
        }

        Write-Host ""
        Write-Host "   Eliminando apps..." -ForegroundColor Magenta

        foreach ($idx in $indicesAEliminar) {
            $app = $apps[$idx]
            Write-Host "   -> Quitando $($app.nombre)..." -ForegroundColor DarkGray
            
            $paqueteInstalado = Get-AppxPackage -Name $app.paquete -ErrorAction SilentlyContinue
            
            if ($paqueteInstalado) {
                try {
                    Remove-AppxPackage -Package $paqueteInstalado.PackageFullName -ErrorAction Stop
                    Write-Host "      [OK] $($app.nombre) eliminada." -ForegroundColor Green
                } catch {
                    Write-Host "      [X] Error al eliminar $($app.nombre)." -ForegroundColor Red
                }
            } else {
                Write-Host "      [-] $($app.nombre) no está instalada." -ForegroundColor Yellow
            }
        }

        Write-Host ""
        Write-Host "   [OK] Proceso de limpieza finalizado." -ForegroundColor Green
        Write-Host "   (Presioná Enter para actualizar la lista)" -ForegroundColor DarkGray
        Read-Host
    }
}
function Show-UpdateMenu {
    while ($true) {
        Write-Banner
        Write-Host "   --- Actualizaciones de Windows ---" -ForegroundColor Magenta
        Write-Host "   [1] Pausar actualizaciones (Deshabilitar servicio)" -ForegroundColor White
        Write-Host "   [2] Reanudar actualizaciones (Habilitar servicio)" -ForegroundColor White
        Write-Host "   [0] Volver al menú principal" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí una opción"

        if ($op -eq "0") { return }

        switch ($op) {
            "1" {
                Write-Host "`n   Deteniendo y deshabilitando Windows Update..." -ForegroundColor Yellow
                try {
                    Stop-Service -Name wuauserv -Force -ErrorAction Stop
                    Set-Service -Name wuauserv -StartupType Disabled -ErrorAction Stop
                    Write-Host "   [OK] Actualizaciones pausadas." -ForegroundColor Green
                    Write-Host "   (Para reanudar, volvé a este menú)." -ForegroundColor DarkGray
                } catch {
                    Write-Host "   [X] Error al pausar: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            "2" {
                Write-Host "`n   Habilitando y arrancando Windows Update..." -ForegroundColor Yellow
                try {
                    Set-Service -Name wuauserv -StartupType Automatic -ErrorAction Stop
                    Start-Service -Name wuauserv -ErrorAction Stop
                    Write-Host "   [OK] Actualizaciones reanudadas." -ForegroundColor Green
                } catch {
                    Write-Host "   [X] Error al reanudar: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            default { 
                Write-Host "   Opción inválida." -ForegroundColor Red
                Start-Sleep 1
                continue 
            }
        }
        Write-Host ""
        Read-Host "   Presioná Enter para continuar"
    }
}
function Invoke-AppInstaller {
    $appsPath = Join-Path $script:GonixRoot "tweaks\apps.json"
    
    if (-not (Test-Path $appsPath)) {
        Write-Host "`n   [!] No se encontró el archivo de apps." -ForegroundColor Red
        Read-Host "   Enter para volver"
        return
    }

    # Leemos el JSON crudo para evitar problemas de formato
    $jsonContent = Get-Content -LiteralPath $appsPath -Raw -Encoding UTF8
    $categorias = $jsonContent | ConvertFrom-Json

    while ($true) {
        Write-Banner
        Write-Host "   ========================================" -ForegroundColor Cyan
        Write-Host "       INSTALADOR DE APLICACIONES (WINGET)   " -ForegroundColor Cyan
        Write-Host "   ========================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Mostramos las categorías. Al poner el número en el JSON, ya se ven ordenadas.
        for ($i = 0; $i -lt $categorias.Count; $i++) {
            Write-Host "   $($categorias[$i].categoria)" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "   [0] Volver al menú principal" -ForegroundColor DarkGray
        Write-Host ""
        
        $opCat = Read-Host "   Elegí el número de categoría (1, 2, 3...)"

        if ($opCat -eq "0") { return }

        # Convertimos la opción a índice (1 -> 0)
        $idxCat = [int]$opCat - 1

        if ($idxCat -ge 0 -and $idxCat -lt $categorias.Count) {
            $cat = $categorias[$idxCat]
            
            while ($true) {
                Write-Banner
                Write-Host "   --- $($cat.categoria) ---" -ForegroundColor Magenta
                Write-Host "   (Elegí los números separados por coma. Ej: 1,3)" -ForegroundColor DarkGray
                Write-Host ""
                
                # Mostramos las apps de la categoría
                for ($j = 0; $j -lt $cat.apps.Count; $j++) {
                    Write-Host "   [$($j+1)] $($cat.apps[$j].nombre)" -ForegroundColor White
                }
                
                Write-Host ""
                Write-Host "   [T] Instalar TODAS las de esta categoría" -ForegroundColor Green
                Write-Host "   [0] Volver a las categorías" -ForegroundColor DarkGray
                Write-Host ""
                $opApp = Read-Host "   Elegí qué instalar"

                if ($opApp -eq "0") { break }

                $aInstalar = @()
                if ($opApp -match "^[Tt]$") {
                    $aInstalar = $cat.apps
                } else {
                    foreach ($p in ($opApp -split ",")) {
                        $n = 0
                        if ([int]::TryParse($p.Trim(), [ref]$n) -and $n -gt 0 -and $n -le $cat.apps.Count) {
                            $aInstalar += $cat.apps[$n - 1]
                        }
                    }
                }

                if ($aInstalar.Count -eq 0) {
                    Write-Host "   [!] Selección inválida." -ForegroundColor Red
                    Start-Sleep 1
                    continue
                }

                Write-Host "`n   Instalando apps con Winget..." -ForegroundColor Yellow
                
                foreach ($app in $aInstalar) {
                    Write-Host "   -> Instalando $($app.nombre)..." -ForegroundColor DarkGray
                    # Ejecutamos winget de forma limpia
                    winget install --id $($app.id) -e --silent --accept-package-agreements --accept-source-agreements
                    Write-Host "      [OK] Proceso terminado para $($app.nombre)." -ForegroundColor Green
                }
                
                Write-Host "`n   [OK] Listo." -ForegroundColor Green
                Read-Host "   Enter para continuar"
            }
        } else {
            Write-Host "   [!] Categoría inválida." -ForegroundColor Red
            Start-Sleep 1
        }
    }
}
function Invoke-RepairMenu {
    while ($true) {
        Write-Banner
        Write-Host "   --- Reparación y Mantenimiento ---" -ForegroundColor Magenta
        Write-Host "   [1] Escanear y Reparar Archivos del Sistema (SFC)" -ForegroundColor White
        Write-Host "   [2] Reparar Imagen de Windows (DISM)" -ForegroundColor White
        Write-Host "   [3] Reparar Red (Flush DNS, Reset Winsock, Release/Renew IP)" -ForegroundColor White
        Write-Host "   [4] Reiniciar Windows Update y reparar componentes" -ForegroundColor White
        Write-Host "   [0] Volver al menú principal" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí una opción"

        if ($op -eq "0") { return }

        switch ($op) {
            "1" {
                Write-Host "`n   Ejecutando SFC (System File Checker)..." -ForegroundColor Yellow
                Write-Host "   Esto puede tardar varios minutos. No cierres la ventana." -ForegroundColor DarkGray
                sfc /scannow
                Write-Host "`n   [OK] Escaneo finalizado." -ForegroundColor Green
            }
            "2" {
                Write-Host "`n   Ejecutando DISM (Deployment Image Servicing and Management)..." -ForegroundColor Yellow
                Write-Host "   Esto puede tardar varios minutos." -ForegroundColor DarkGray
                DISM /Online /Cleanup-Image /RestoreHealth
                Write-Host "`n   [OK] Reparación de imagen finalizada." -ForegroundColor Green
            }
            "3" {
                Write-Host "`n   Reparando configuración de red..." -ForegroundColor Yellow
                ipconfig /flushdns
                ipconfig /release
                ipconfig /renew
                netsh winsock reset
                netsh int ip reset
                Write-Host "`n   [OK] Red reparada. Se recomienda reiniciar." -ForegroundColor Green
            }
            "4" {
                Write-Host "`n   Reiniciando servicios de Windows Update..." -ForegroundColor Yellow
                net stop wuauserv
                net stop cryptSvc
                net stop bits
                net stop msiserver
                ren C:\Windows\SoftwareDistribution SoftwareDistribution.old
                ren C:\Windows\System32\catroot2 catroot2.old
                net start wuauserv
                net start cryptSvc
                net start bits
                net start msiserver
                Write-Host "`n   [OK] Servicios reiniciados." -ForegroundColor Green
            }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1; continue }
        }
        Write-Host ""
        Read-Host "   Presioná Enter para continuar"
    }
}
    
