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
        Write-Host "   [2] Sistema y Rendimiento (Velocidad y Red)" -ForegroundColor White
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
        Write-Host "   [2] Desactivar GameDVR" -ForegroundColor White
        Write-Host "   [3] Desactivar Apps en 2do Plano" -ForegroundColor White
        Write-Host "   [4] Desactivar Animaciones" -ForegroundColor White
        Write-Host "   [5] Quitar OneDrive del Inicio" -ForegroundColor White
        Write-Host "   [6] Optimizar Servicios Xbox" -ForegroundColor White
        Write-Host "   [7] Reducir Ping (Nagle)" -ForegroundColor White
        Write-Host "   [8] Aceleración GPU (HAGS)" -ForegroundColor White
        Write-Host "   [9] Desactivar Barra de Juegos Xbox" -ForegroundColor White
        Write-Host "   [10] Eliminar Límite de Ancho de Banda" -ForegroundColor White
        Write-Host "   [11] Evitar Suspensión de Puertos USB" -ForegroundColor White
        Write-Host "   [12] Eliminar Retraso de Arranque" -ForegroundColor White
        Write-Host "   [13] Configurar DNS Cloudflare" -ForegroundColor White
        Write-Host "   [14] Habilitar 'Finalizar Tarea' en Clic Derecho" -ForegroundColor White
        Write-Host "   [15] Desactivar Sensor de Almacenamiento" -ForegroundColor White
        Write-Host "   [16] Desactivar Teredo (IPv6)" -ForegroundColor White
        Write-Host "   [17] Efectos Visuales a Máximo Rendimiento" -ForegroundColor White
        Write-Host "   [A] APLICAR TODOS LOS DE ESTA LISTA" -ForegroundColor Green
        Write-Host "   [0] Volver" -ForegroundColor DarkGray
        Write-Host ""
        $op = Read-Host "   Elegí un tweak"
        
        if ($op -eq "0") { return }
        if ($op -match "^[Aa]$") { Invoke-AllTweaks -Categoria "sistema"; Read-Host "   Enter para continuar"; continue }
        
        switch ($op) {
            "1" { Invoke-Tweak -Id "disable-hibernation" }
            "2" { Invoke-Tweak -Id "disable-gamedvr" }
            "3" { Invoke-Tweak -Id "disable-background-apps" }
            "4" { Invoke-Tweak -Id "disable-animations" }
            "5" { Invoke-Tweak -Id "disable-onedrive-startup" }
            "6" { Invoke-Tweak -Id "optimize-services" }
            "7" { Invoke-Tweak -Id "disable-nagle-algorithm" }
            "8" { Invoke-Tweak -Id "gpu-scheduling" }
            "9" { Invoke-Tweak -Id "disable-xbox-gamebar" }
            "10" { Invoke-Tweak -Id "disable-network-throttling" }
            "11" { Invoke-Tweak -Id "disable-usb-selective-suspend" }
            "12" { Invoke-Tweak -Id "disable-startup-delay" }
            "13" { Invoke-Tweak -Id "set-dns-cloudflare" }
            "14" { Invoke-Tweak -Id "enable-end-task" }
            "15" { Invoke-Tweak -Id "disable-storage-sense" }
            "16" { Invoke-Tweak -Id "disable-teredo" }
            "17" { Invoke-Tweak -Id "set-visual-effects-performance" }
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
        Write-Host ""
        Read-Host "   Presioná Enter para continuar"
    }
}