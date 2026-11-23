<<<<<<< HEAD
﻿function Write-Banner {
    Clear-Host
    Write-Host ""
    # Logo ASCII GIGANTE
    Write-Host "   ██████╗  ██████╗ ███╗   ██╗██╗██╗  ██╗" -ForegroundColor Cyan
    Write-Host "  ██╔════╝ ██╔═══██╗████╗  ██║██║╚██╗██╔╝" -ForegroundColor Cyan
    Write-Host "  ██║  ███╗██║   ██║██╔██╗ ██║██║ ╚███╔╝ " -ForegroundColor Cyan
    Write-Host "  ██║   ██║██║   ██║██║╚██╗██║██║ ██╔██╗ " -ForegroundColor Cyan
    Write-Host "  ╚██████╔╝╚██████╔╝██║ ╚████║██║██╔╝ ██╗" -ForegroundColor Cyan
    Write-Host "   ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "        [ Optimizador de Windows 11 ]  v$(Get-GonixVersion)" -ForegroundColor DarkGray
    Write-Host "   ════════════════════════════════════════════════════" -ForegroundColor DarkCyan
}

function Show-SystemInfo {
    # Obtiene info real de la PC para que se vea pro
    $os = (Get-CimInstance Win32_OperatingSystem)
    $cpu = (Get-CimInstance Win32_Processor).Name
    $ram = [math]::round($os.TotalVisibleMemorySize / 1MB, 1)
    
    Write-Host "   OS: $($os.Caption) | CPU: $($cpu) | RAM: $ram GB" -ForegroundColor DarkGray
    Write-Host "   ════════════════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host ""
}

function Show-MainMenu {
    while ($true) {
        Write-Banner
        Show-SystemInfo
        
        Write-Host "   [1] " -ForegroundColor Cyan -NoNewline
        Write-Host "Aplicar Perfil (Gaming / Oficina)" -ForegroundColor White
        
        Write-Host "   [2] " -ForegroundColor Cyan -NoNewline
        Write-Host "Tweaks individuales" -ForegroundColor White
        
        Write-Host "   [3] " -ForegroundColor Cyan -NoNewline
        Write-Host "Instalar Aplicaciones (Winget)" -ForegroundColor White
        
        Write-Host "   [4] " -ForegroundColor Cyan -NoNewline
        Write-Host "Historial y Deshacer" -ForegroundColor White
        
        Write-Host "   [5] " -ForegroundColor Cyan -NoNewline
        Write-Host "Actualizaciones de Windows" -ForegroundColor White
        
        Write-Host "   [6] " -ForegroundColor Cyan -NoNewline
        Write-Host "Crear Punto de Restauración" -ForegroundColor White

        Write-Host "   [7] " -ForegroundColor Cyan -NoNewline
        Write-Host "Reparación y Mantenimiento (SFC, DISM, Red)" -ForegroundColor White
        
        Write-Host ""
        Write-Host "   [9] " -ForegroundColor Green -NoNewline
        Write-Host "OPTIMIZACIÓN RÁPIDA (Privacidad y sistema)" -ForegroundColor Green
        
        Write-Host ""
        Write-Host "   [0] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Salir" -ForegroundColor DarkGray
        Write-Host ""
        $opcion = Read-Host "   Elegí una opción"

        switch ($opcion) {
            "1" { Show-ProfilesMenu }
            "2" { Show-TweaksMenu }
            "3" { Invoke-AppInstaller }
                        "4" { 
                try {
                    $lotes = Get-Lotes
                    if ($lotes.Count -eq 0) { Write-Host "   [!] No hay historial." -ForegroundColor Yellow }
                    else {
                        Write-Host "`n   --- Historial de cambios ---" -ForegroundColor Magenta
                        for ($i=0; $i -lt $lotes.Count; $i++) {
                            Write-Host "   [$($i+1)] $($lotes[$i].Fecha) - $($lotes[$i].Cambios) cambios" -ForegroundColor White
                            Write-Host "       $($lotes[$i].Nombres)" -ForegroundColor DarkGray
                        }
                        $sel = Read-Host "`n   Elegí el lote a deshacer (0 para volver)"
                        if ($sel -match '^\d+$' -and $sel -gt 0 -and $sel -le $lotes.Count) {
                            Undo-Lote -Lote $lotes[$sel - 1].Lote
                        }
                    }
                } catch {
                    Write-Host "   [X] Error al leer el historial: $($_.Exception.Message)" -ForegroundColor Red
                }
                Write-Host ""
                Read-Host "   Enter para continuar" 
            }
            "5" { Show-UpdateMenu }
            "6" { New-GonixRestorePoint }
            "7" { Invoke-RepairMenu }
            "9" { Invoke-QuickOptimize }
            "0" { Write-Host "   Chau, Gon!" -ForegroundColor Cyan; return }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}

function Show-TweaksMenu {
    while ($true) {
        Write-Banner
        Write-Host "   --- Categorías de Tweaks ---" -ForegroundColor Magenta
        Write-Host "   [1] Privacidad (Quita anuncios y rastreo)" -ForegroundColor White
        Write-Host "   [2] Sistema y Rendimiento (Velocidad, Red y Limpieza)" -ForegroundColor White
        Write-Host "   [3] Desinstalar Apps (Bloatware)" -ForegroundColor White
        Write-Host "   [4] ⚠️ ZONA DE PELIGRO (Modo Avanzado)" -ForegroundColor Red
        Write-Host "   [0] Volver" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí una categoría"

        switch ($op) {
            "1" { Show-PrivacyTweaks }
            "2" { Show-SystemTweaks }
            "3" { Invoke-BloatwareRemoval }
            "4" { Show-AdvancedTweaks }
            "0" { return }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1; continue }
        }
    }
}

function Show-PrivacyTweaks {
    while ($true) {
        Write-Banner
        Write-Host "   --- Privacidad ---" -ForegroundColor Magenta
        Write-Host "   [1] Desactivar Telemetría" -ForegroundColor White
        Write-Host "   [2] Desactivar Cortana" -ForegroundColor White
        Write-Host "   [3] Quitar Anuncios del Inicio" -ForegroundColor White
        Write-Host "   [4] Desactivar Widgets" -ForegroundColor White
        Write-Host "   [5] Quitar Bing de Búsqueda" -ForegroundColor White
        Write-Host "   [6] Desactivar Copilot" -ForegroundColor White
        Write-Host "   [7] Desactivar ID de Publicidad" -ForegroundColor White
        Write-Host "   [8] Desactivar Experiencias Personalizadas" -ForegroundColor White
        Write-Host "   [9] Desactivar Voz en Línea" -ForegroundColor White
        Write-Host "   [10] Desactivar Comentarios" -ForegroundColor White
        Write-Host "   [11] Desactivar Historial de Actividad" -ForegroundColor White
        Write-Host "   [12] Desactivar Rastreo de Ubicación" -ForegroundColor White
        Write-Host "   [13] Desactivar Funciones de Consumidor" -ForegroundColor White
        Write-Host "   [14] Desactivar Muestras de Defender" -ForegroundColor White
        Write-Host "   [A] APLICAR TODOS LOS DE ESTA LISTA" -ForegroundColor Green
        Write-Host "   [0] Volver" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí un tweak"
        
        if ($op -eq "0") { return }
        if ($op -match "^[Aa]$") { Invoke-AllTweaks -Categoria "privacidad"; Read-Host "   Enter para continuar"; continue }
        
        switch ($op) {
            "1" { Invoke-Tweak -Id "disable-telemetry" }
            "2" { Invoke-Tweak -Id "disable-cortana" }
            "3" { Invoke-Tweak -Id "disable-start-suggestions" }
            "4" { Invoke-Tweak -Id "disable-widgets" }
            "5" { Invoke-Tweak -Id "disable-windows-search-bing" }
            "6" { Invoke-Tweak -Id "disable-copilot" }
            "7" { Invoke-Tweak -Id "disable-advertising-id" }
            "8" { Invoke-Tweak -Id "disable-tailored-experiences" }
            "9" { Invoke-Tweak -Id "disable-online-speech-privacy" }
            "10" { Invoke-Tweak -Id "disable-feedback" }
            "11" { Invoke-Tweak -Id "disable-activity-history" }
            "12" { Invoke-Tweak -Id "disable-location-tracking" }
            "13" { Invoke-Tweak -Id "disable-consumer-features" }
            "14" { Invoke-Tweak -Id "disable-defender-samples" }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1; continue }
        }
        Read-Host "   Enter para continuar"
    }
}

function Show-SystemTweaks {
    while ($true) {
        Write-Banner
        Write-Host "   --- Sistema y Rendimiento ---" -ForegroundColor Magenta
        Write-Host "   [1] Desactivar Hibernación" -ForegroundColor White
        Write-Host "   [2] Activar Hibernación (Notebooks)" -ForegroundColor White
        Write-Host "   [3] Desactivar GameDVR" -ForegroundColor White
        Write-Host "   [4] Desactivar Apps en 2do Plano" -ForegroundColor White
        Write-Host "   [5] Desactivar Animaciones" -ForegroundColor White
        Write-Host "   [6] Quitar OneDrive del Inicio" -ForegroundColor White
        Write-Host "   [7] Optimizar Servicios Xbox" -ForegroundColor White
        Write-Host "   [9] Aceleración GPU (HAGS)" -ForegroundColor White
        Write-Host "   [10] Desactivar Barra de Juegos Xbox" -ForegroundColor White
        Write-Host "   [11] Eliminar Límite de Ancho de Banda" -ForegroundColor White
        Write-Host "   [12] Evitar Suspensión de Puertos USB" -ForegroundColor White
        Write-Host "   [13] Eliminar Retraso de Arranque" -ForegroundColor White
        Write-Host "   [14] Configurar DNS Cloudflare" -ForegroundColor White
        Write-Host "   [15] Finalizar Tarea en Clic Derecho" -ForegroundColor White
        Write-Host "   [16] Desactivar Sensor de Almacenamiento" -ForegroundColor White
        Write-Host "   [17] Desactivar Teredo (IPv6)" -ForegroundColor White
        Write-Host "   [18] Efectos Visuales a Máximo Rendimiento" -ForegroundColor White
        Write-Host "   [19] Mostrar Extensiones de Archivo" -ForegroundColor White
        Write-Host "   [20] Desactivar Aceleración del Mouse" -ForegroundColor White
        Write-Host "   [21] Desactivar Sticky Keys" -ForegroundColor White
        Write-Host "   [22] Desactivar Servicio DiagTrack" -ForegroundColor White
        Write-Host "   [23] Poner Servicio de Mapas en Manual" -ForegroundColor White
        Write-Host "   [24] Limpiar Archivos Temporales" -ForegroundColor White
        Write-Host "   [25] Ejecutar Liberador de Espacio" -ForegroundColor White
        Write-Host "   [A] APLICAR TODOS LOS DE ESTA LISTA" -ForegroundColor Green
        Write-Host "   [0] Volver" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí un tweak"
        
        if ($op -eq "0") { return }
        if ($op -match "^[Aa]$") { Invoke-AllTweaks -Categoria "sistema"; Read-Host "   Enter para continuar"; continue }
        
        switch ($op) {
            "1" { Invoke-Tweak -Id "disable-hibernation" }
            "2" { Invoke-Tweak -Id "enable-hibernation-laptops" }
            "3" { Invoke-Tweak -Id "disable-gamedvr" }
            "4" { Invoke-Tweak -Id "disable-background-apps" }
            "5" { Invoke-Tweak -Id "disable-animations" }
            "6" { Invoke-Tweak -Id "disable-onedrive-startup" }
            "7" { Invoke-Tweak -Id "optimize-services" }
            "9" { Invoke-Tweak -Id "gpu-scheduling" }
            "10" { Invoke-Tweak -Id "disable-xbox-gamebar" }
            "11" { Invoke-Tweak -Id "disable-network-throttling" }
            "12" { Invoke-Tweak -Id "disable-usb-selective-suspend" }
            "13" { Invoke-Tweak -Id "disable-startup-delay" }
            "14" { Invoke-Tweak -Id "set-dns-cloudflare" }
            "15" { Invoke-Tweak -Id "enable-end-task" }
            "16" { Invoke-Tweak -Id "disable-storage-sense" }
            "17" { Invoke-Tweak -Id "disable-teredo" }
            "18" { Invoke-Tweak -Id "set-visual-effects-performance" }
            "19" { Invoke-Tweak -Id "show-file-extensions" }
            "20" { Invoke-Tweak -Id "disable-mouse-acceleration" }
            "21" { Invoke-Tweak -Id "disable-sticky-keys" }
            "22" { Invoke-Tweak -Id "disable-diagtrack" }
            "23" { Invoke-Tweak -Id "disable-maps-broker" }
            "24" { Invoke-Tweak -Id "clean-temp-files" }
            "25" { Invoke-Tweak -Id "run-disk-cleanup" }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1; continue }
        }
        Read-Host "   Enter para continuar"
    }
}

function Show-AdvancedTweaks {
    while ($true) {
        Write-Banner
        Write-Host "   ⚠️ ⚠️ ⚠️  ZONA DE PELIGRO  ⚠️ ⚠️ ⚠️" -ForegroundColor Red
        Write-Host "   Los siguientes tweaks pueden causar inestabilidad," -ForegroundColor Yellow
        Write-Host "   sobrecalentamiento o consumo excesivo de energía." -ForegroundColor Yellow
        Write-Host "   Úsalos BAJO TU PROPIO RIESGO." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   [1] Plan de Energía 'Máximo Rendimiento'" -ForegroundColor White
        Write-Host "   [2] Desactivar Core Parking (CPU al 100%)" -ForegroundColor White
        Write-Host "   [3] Priorizar Procesos en Primer Plano" -ForegroundColor White
        Write-Host "   [4] Limitar Reserva de CPU del Sistema" -ForegroundColor White
        Write-Host "   [5] Desactivar BitLocker" -ForegroundColor White
        Write-Host "   [6] Desactivar y Eliminar Windows AI" -ForegroundColor White
        Write-Host "   [7] Debloat de Microsoft Edge" -ForegroundColor White
        Write-Host "   [8] Desactivar Optimizaciones de Pantalla Completa" -ForegroundColor White
        Write-Host "   [9] Establecer Hora en UTC" -ForegroundColor White
        Write-Host "   [0] Volver" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí un tweak (o 0 para volver)"

        if ($op -eq "0") { return }

        Write-Host "`n   Para confirmar que entendés el riesgo, escribí la palabra 'ACEPTO'" -ForegroundColor Red
        $confirmacion = Read-Host "   Confirmación"
        
        if ($confirmacion -cne "ACEPTO") {
            Write-Host "   Cancelado. Volviendo a la Zona de Peligro." -ForegroundColor Yellow
            Start-Sleep 1
            continue
        }

        switch ($op) {
            "1" { Invoke-Tweak -Id "ultimate-performance-plan" }
            "2" { Invoke-Tweak -Id "disable-core-parking" }
            "3" { Invoke-Tweak -Id "win32-priority-separation" }
            "4" { Invoke-Tweak -Id "disable-system-responsiveness" }
            "5" { Invoke-Tweak -Id "disable-bitlocker" }
            "6" { Invoke-Tweak -Id "disable-windows-ai" }
            "7" { Invoke-Tweak -Id "disable-edge-debloat" }
            "8" { Invoke-Tweak -Id "disable-fso" }
            "9" { Invoke-Tweak -Id "set-time-utc" }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1; continue }
        }
        Read-Host "   Enter para continuar"
    }
}

function Show-ProfilesMenu {
    while ($true) {
        Write-Banner
        Write-Host "   --- Perfiles de Configuración ---" -ForegroundColor Magenta
        Write-Host "   [1] Gaming Extremo (Máximo FPS y Cero Lag)" -ForegroundColor White
        Write-Host "   [2] Oficina / Notebook (Privacidad sin gastar batería)" -ForegroundColor White
        Write-Host "   [3] Privacidad Total (Bloqueo máximo)" -ForegroundColor White
        Write-Host "   [0] Volver al menú principal" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí un perfil"

        switch ($op) {
            "1" { Invoke-Profile -NombreArchivo "gaming" }
            "2" { Invoke-Profile -NombreArchivo "oficina" }
            "3" { Invoke-Profile -NombreArchivo "privacidad-total" }
            "0" { return }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1; continue }
        }
        Read-Host "   Enter para continuar"
    }
}
=======
﻿# ============================================================
#  UI.ps1 - Interfaz de consola (menús generados desde los JSON)
# ============================================================

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '   ██████╗  ██████╗ ███╗   ██╗██╗██╗  ██╗' -ForegroundColor Cyan
    Write-Host '  ██╔════╝ ██╔═══██╗████╗  ██║██║╚██╗██╔╝' -ForegroundColor Cyan
    Write-Host '  ██║  ███╗██║   ██║██╔██╗ ██║██║ ╚███╔╝ ' -ForegroundColor Cyan
    Write-Host '  ██║   ██║██║   ██║██║╚██╗██║██║ ██╔██╗ ' -ForegroundColor Cyan
    Write-Host '  ╚██████╔╝╚██████╔╝██║ ╚████║██║██╔╝ ██╗' -ForegroundColor Cyan
    Write-Host '   ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('        [ Optimizador de Windows 11 ]  v{0}' -f (Get-GonixVersion)) -ForegroundColor DarkGray
    Write-Host '   ════════════════════════════════════════════════════' -ForegroundColor DarkCyan
    Write-Host ''
}

function Show-SystemInfo {
    Write-Host "   $($script:InfoSistema)" -ForegroundColor DarkGray
    if ($script:BuildWindows -gt 0 -and $script:BuildWindows -lt 22000) {
        Write-Host '   Aviso: Gonix está pensado para Windows 11; algunos tweaks pueden no tener efecto.' -ForegroundColor Yellow
    }
    Write-Host '   ════════════════════════════════════════════════════' -ForegroundColor DarkCyan
    Write-Host ''
}

# ------------------------------------------------------------
#  Menú principal
# ------------------------------------------------------------
function Show-MainMenu {
    while ($true) {
        Write-Banner
        Show-SystemInfo
        Write-MenuItem '1' 'Perfiles (Recomendado, Gaming, Oficina, Notebook, Privacidad)'
        Write-MenuItem '2' 'Tweaks individuales'
        Write-MenuItem '3' 'Instalar aplicaciones (winget)'
        Write-MenuItem '4' 'Historial y deshacer'
        Write-MenuItem '5' 'Windows Update'
        Write-MenuItem '6' 'Limpieza y reparación'
        Write-MenuItem '7' 'Crear punto de restauración'
        Write-Host ''
        Write-MenuItem '0' 'Salir' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una opción'
        switch ($op) {
            '1' { Show-ProfilesMenu }
            '2' { Show-TweaksMenu }
            '3' { Show-AppInstaller }
            '4' { Show-HistoryMenu }
            '5' { Show-UpdateMenu }
            '6' { Show-MaintenanceMenu }
            '7' { Show-RestorePointMenu }
            '0' { Write-Host '   ¡Chau, Gon!' -ForegroundColor Cyan; return }
            default { Write-Warn 'Opción inválida.'; Start-Sleep 1 }
        }
    }
}

# ------------------------------------------------------------
#  Perfiles
# ------------------------------------------------------------
function Format-WrappedLines {
    param(
        [string]$Texto,
        [int]$Sangria = 7
    )
    if ([string]::IsNullOrWhiteSpace($Texto)) { return @() }
    $anchoVentana = try { [Console]::WindowWidth } catch { 100 }
    $maxAncho = [Math]::Max(36, $anchoVentana - $Sangria - 2)
    $prefijo = ' ' * $Sangria
    $palabras = $Texto -split '\s+'
    $lineas = New-Object System.Collections.Generic.List[string]
    $actual = ''

    foreach ($w in $palabras) {
        if ([string]::IsNullOrWhiteSpace($w)) { continue }
        $candidato = if ($actual) { "$actual $w" } else { $w }
        if ($candidato.Length -le $maxAncho) {
            $actual = $candidato
        }
        else {
            if ($actual) { $lineas.Add("$prefijo$actual") }
            $actual = $w
        }
    }
    if ($actual) { $lineas.Add("$prefijo$actual") }
    return @($lineas)
}

# ------------------------------------------------------------
#  Perfiles
# ------------------------------------------------------------
function Show-ProfilesMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Perfiles ---' -ForegroundColor Magenta
        Write-Host ''
        for ($i = 0; $i -lt $script:Perfiles.Count; $i++) {
            $p = $script:Perfiles[$i]
            Write-MenuItem ($i + 1) $p.nombre
            foreach ($l in (Format-WrappedLines -Texto $p.descripcion -Sangria 7)) {
                Write-Host $l -ForegroundColor DarkGray
            }
            Write-Host ''
        }
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí un perfil'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }
        $n = 0
        if (-not [int]::TryParse($op, [ref]$n) -or $n -lt 1 -or $n -gt $script:Perfiles.Count) {
            Write-Warn 'Opción inválida.'; Start-Sleep 1; continue
        }
        $p = $script:Perfiles[$n - 1]
        Invoke-TweakSet -Ids @($p.tweaks) -Titulo "Perfil: $($p.nombre)" -Descripcion $p.descripcion
        Write-Host ''
        Wait-Enter
    }
}

# ------------------------------------------------------------
#  Tweaks individuales (menú genérico por categoría)
# ------------------------------------------------------------
function Show-TweaksMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Tweaks individuales ---' -ForegroundColor Magenta
        Write-Host ''
        Write-MenuItem '1' ('Privacidad            ({0} tweaks)' -f @(Get-TweaksByCategory 'privacidad').Count)
        Write-MenuItem '2' ('Sistema               ({0} tweaks)' -f @(Get-TweaksByCategory 'sistema').Count)
        Write-MenuItem '3' ('Rendimiento y red     ({0} tweaks)' -f @(Get-TweaksByCategory 'rendimiento').Count)
        Write-MenuItem '4' 'Desinstalar apps preinstaladas'
        Write-MenuItem '5' ('ZONA DE PELIGRO       ({0} tweaks avanzados)' -f @(Get-TweaksByCategory 'avanzado').Count) 'Red'
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una categoría'
        switch ($op) {
            '1' { Show-TweakCategory -Categoria 'privacidad'  -Titulo 'Privacidad' }
            '2' { Show-TweakCategory -Categoria 'sistema'     -Titulo 'Sistema' }
            '3' { Show-TweakCategory -Categoria 'rendimiento' -Titulo 'Rendimiento y red' }
            '4' { Show-BloatwareMenu }
            '5' { Show-TweakCategory -Categoria 'avanzado' -Titulo 'ZONA DE PELIGRO' `
                    -Aviso "Pueden causar inestabilidad, calor o consumo excesivo. Solo para usuarios avanzados.`nCada cambio se puede deshacer desde el historial." }
            '0' { return }
            default { Write-Warn 'Opción inválida.'; Start-Sleep 1 }
        }
    }
}

function Show-TweakCategory {
    param([string]$Categoria, [string]$Titulo, [string]$Aviso = '')
    while ($true) {
        Write-Banner
        Write-Host "   --- $Titulo ---" -ForegroundColor Magenta
        if ($Aviso) { foreach ($l in ($Aviso -split "`n")) { Write-Host "   $l" -ForegroundColor Yellow } }
        Write-Host ''
        $lista = @(Get-TweaksByCategory $Categoria)
        for ($i = 0; $i -lt $lista.Count; $i++) {
            $t = $lista[$i]
            $e = Test-TweakApplied $t
            if ($e -eq $true)      { $marca = '[ON]'; $color = 'Green' }
            elseif ($e -eq $false) { $marca = '[  ]'; $color = Get-RiskColor $t }
            else                   { $marca = '[??]'; $color = Get-RiskColor $t }
            Write-Host ('   {0,2}. {1} {2}{3}' -f ($i + 1), $marca, $t.nombre, (Get-RiskSuffix $t)) -ForegroundColor $color
        }
        Write-Host ''
        Write-Info '[ON] aplicado   [  ] pendiente   [??] no se puede detectar'
        Write-Info 'Escribí números para aplicar (ej: 1,3,5-7)  |  "d 3" = ver detalle del 3'
        if ($Categoria -ne 'avanzado') { Write-Info '"A" = aplicar todos los pendientes de riesgo bajo' }
        Write-Info 'Enter o 0 para volver'
        Write-Host ''
        $op = (Read-Host '   Tu elección').Trim()
        if ($op -eq '' -or $op -eq '0') { return }

        if ($op -match '^[dD]\s*(\d{1,3})$') {
            $n = [int]$Matches[1]
            if ($n -ge 1 -and $n -le $lista.Count) { Show-TweakDetail $lista[$n - 1] } else { Write-Warn 'Número inválido.' }
            Wait-Enter
            continue
        }

        if ($op -match '^[aA]$') {
            if ($Categoria -eq 'avanzado') { Write-Warn 'En la zona de peligro se elige de a uno.'; Start-Sleep 2; continue }
            $ids = @($lista | Where-Object { $_.riesgo -eq 'bajo' } | ForEach-Object { $_.id })
            Invoke-TweakSet -Ids $ids -Titulo "${Titulo}: todos los de riesgo bajo"
            Write-Host ''; Wait-Enter
            continue
        }

        $idx = @(ConvertTo-Indices -Texto $op -Max $lista.Count)
        if ($idx.Count -eq 0) { Write-Warn 'No entendí esa selección.'; Start-Sleep 1; continue }
        $ids = @($idx | ForEach-Object { $lista[$_].id })
        Invoke-TweakSet -Ids $ids
        Write-Host ''; Wait-Enter
    }
}

# ------------------------------------------------------------
#  Historial y deshacer
# ------------------------------------------------------------
function Show-HistoryMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Historial y deshacer ---' -ForegroundColor Magenta
        Write-Host ''
        $lotes = @(Get-Lotes)
        if ($lotes.Count -eq 0) {
            Write-Info 'Todavía no hay cambios registrados.'
            Write-Host ''; Wait-Enter; return
        }
        for ($i = 0; $i -lt $lotes.Count; $i++) {
            $l = $lotes[$i]
            Write-Host ('   [{0}] {1}  -  {2} cambio(s)' -f ($i + 1), $l.Fecha, $l.Cambios) -ForegroundColor White
            $nombres = $l.Nombres
            if ($nombres.Length -gt 110) { $nombres = $nombres.Substring(0, 107) + '...' }
            Write-Host "       $nombres" -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Info 'Elegí el número a deshacer: se revierten todos los cambios de ese lote.'
        Write-Info 'Enter o 0 para volver.'
        $op = Read-Host '   Tu elección'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }
        $n = 0
        if (-not [int]::TryParse($op, [ref]$n) -or $n -lt 1 -or $n -gt $lotes.Count) {
            Write-Warn 'Opción inválida.'; Start-Sleep 1; continue
        }
        if (-not (Confirm-Gonix "¿Deshacer el lote del $($lotes[$n - 1].Fecha)?")) { continue }
        $r = @(Undo-Lote -Lote $lotes[$n - 1].Lote) | Select-Object -Last 1
        Write-Host ''
        if ($r.Fallos -eq 0) { Write-Ok "Se revirtieron $($r.Ok) cambio(s)." }
        else { Write-Warn "Se revirtieron $($r.Ok) de $($r.Total). Los que fallaron siguen en el historial." }
        Write-Info 'Algunos cambios se ven recién al reiniciar o cerrar sesión.'
        Write-Host ''; Wait-Enter
    }
}
>>>>>>> a6dfffd7622dd4f687b104b0df2867a126c36b36
