function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "   ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "   ║              G O N I X                   ║" -ForegroundColor Cyan
    Write-Host "   ║   Optimizador de Windows 11 · v$(Get-GonixVersion)        ║" -ForegroundColor Cyan
    Write-Host "   ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-MainMenu {
    while ($true) {
        Write-Banner
        Write-Host "   [1] Aplicar Perfil (Gaming / Oficina)" -ForegroundColor White
        Write-Host "   [2] Tweaks individuales" -ForegroundColor White
        Write-Host "   [3] Instalar Aplicaciones (Winget)" -ForegroundColor White
        Write-Host "   [4] Historial y Deshacer" -ForegroundColor White
        Write-Host "   [5] Actualizaciones de Windows (Pausar/Reanudar)" -ForegroundColor White
        Write-Host "   [6] Crear Punto de Restauración" -ForegroundColor White
        Write-Host ""
        Write-Host "   [9] ⚡ OPTIMIZACIÓN RÁPIDA (Recomendado)" -ForegroundColor Green
        Write-Host ""
        Write-Host "   [0] Salir" -ForegroundColor DarkGray
        Write-Host ""
        $opcion = Read-Host "   Elegí una opción"

        switch ($opcion) {
            "1" { Show-ProfilesMenu }
            "2" { Show-TweaksMenu }
            "3" { Invoke-AppInstaller }
            "4" { 
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
                Read-Host "   Enter para continuar" 
            }
            "5" { Show-UpdateMenu }
            "6" { New-GonixRestorePoint }
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
        Write-Host "   [15] Desactivar Wifi-Sense" -ForegroundColor White
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
            "15" { Invoke-Tweak -Id "disable-wifi-sense" }
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
        Write-Host "   [8] Reducir Ping (Nagle)" -ForegroundColor White
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
            "8" { Invoke-Tweak -Id "disable-nagle-algorithm" }
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
        Write-Host "   [4] Desactivar Reserva de CPU del Sistema" -ForegroundColor White
        Write-Host "   [5] Desactivar BitLocker" -ForegroundColor White
        Write-Host "   [6] Desactivar y Eliminar Windows AI" -ForegroundColor White
        Write-Host "   [7] Debloat de Microsoft Edge" -ForegroundColor White
        Write-Host "   [8] Desactivar Optimizaciones de Pantalla Completa" -ForegroundColor White
        Write-Host "   [9] Eliminar Microsoft Edge" -ForegroundColor White
        Write-Host "   [10] Establecer Hora en UTC" -ForegroundColor White
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
            "9" { Invoke-Tweak -Id "uninstall-edge" }
            "10" { Invoke-Tweak -Id "set-time-utc" }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1; continue }
        }
        Read-Host "   Enter para continuar"
    }
}

function Show-ProfilesMenu {
    while ($true) {
        Write-Banner
        Write-Host "   --- Perfiles disponibles ---" -ForegroundColor Magenta
        Write-Host "   [1] Perfil Gaming Extremo (Máximo FPS y Cero Lag)" -ForegroundColor White
        Write-Host "   [0] Volver al menú principal" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí un perfil"

        if ($op -eq "0") { return }

        switch ($op) {
            "1" { Invoke-Profile -NombreArchivo "gaming" }
            default { Write-Host "   Opción inválida." -ForegroundColor Red; Start-Sleep 1; continue }
        }
        Read-Host "   Enter para continuar"
    }
}