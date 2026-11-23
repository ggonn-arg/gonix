# ============================================================
#  UI.ps1 - Interfaz de consola
# ============================================================

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '   Gonix - Optimizador de Windows 11' -ForegroundColor Cyan
    Write-Host ('   Version ' + (Get-GonixVersion)) -ForegroundColor DarkGray
    Write-Host '   ====================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Show-SystemInfo {
    if ($script:InfoSistema) {
        Write-Host ('   ' + $script:InfoSistema) -ForegroundColor DarkGray
    }
    Write-Host ''
}

function Show-MainMenu {
    while ($true) {
        Write-Banner
        Show-SystemInfo
        Write-MenuItem '1' 'Perfiles'
        Write-MenuItem '2' 'Tweaks individuales'
        Write-MenuItem '3' 'Instalar aplicaciones'
        Write-MenuItem '4' 'Historial y deshacer'
        Write-MenuItem '5' 'Windows Update'
        Write-MenuItem '6' 'Limpieza y reparacion'
        Write-MenuItem '7' 'Crear punto de restauracion'
        Write-Host ''
        Write-MenuItem '0' 'Salir' 'DarkGray'

        $op = Read-Host '   Elegi una opcion'
        switch ($op) {
            '1' { Show-ProfilesMenu }
            '2' { Show-TweaksMenu }
            '3' { Show-AppInstaller }
            '4' { Show-HistoryMenu }
            '5' { Show-UpdateMenu }
            '6' { Show-MaintenanceMenu }
            '7' { Show-RestorePointMenu }
            '0' { return }
            default { Write-Warn 'Opcion invalida.'; Start-Sleep 1 }
        }
    }
}

function Show-ProfilesMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Perfiles ---' -ForegroundColor Magenta
        Write-Host ''

        for ($i = 0; $i -lt $script:Perfiles.Count; $i++) {
            $perfil = $script:Perfiles[$i]
            Write-MenuItem ([string]($i + 1)) $perfil.nombre
            if ($perfil.descripcion) {
                Write-Host ('       ' + $perfil.descripcion) -ForegroundColor DarkGray
            }
            Write-Host ''
        }

        Write-MenuItem '0' 'Volver' 'DarkGray'
        $op = Read-Host '   Elegi un perfil'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }

        $numero = 0
        if (-not [int]::TryParse($op, [ref]$numero) -or $numero -lt 1 -or $numero -gt $script:Perfiles.Count) {
            Write-Warn 'Opcion invalida.'
            Start-Sleep 1
            continue
        }

        $perfil = $script:Perfiles[$numero - 1]
        Invoke-TweakSet -Ids @($perfil.tweaks) -Titulo ('Perfil: ' + $perfil.nombre) -Descripcion $perfil.descripcion
        Wait-Enter
    }
}

function Show-TweaksMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Tweaks individuales ---' -ForegroundColor Magenta
        Write-Host ''
        Write-MenuItem '1' ('Privacidad (' + @(Get-TweaksByCategory 'privacidad').Count + ' tweaks)')
        Write-MenuItem '2' ('Sistema (' + @(Get-TweaksByCategory 'sistema').Count + ' tweaks)')
        Write-MenuItem '3' ('Rendimiento (' + @(Get-TweaksByCategory 'rendimiento').Count + ' tweaks)')
        Write-MenuItem '4' 'Desinstalar aplicaciones preinstaladas'
        Write-MenuItem '5' ('Zona de peligro (' + @(Get-TweaksByCategory 'avanzado').Count + ' tweaks)')
        Write-MenuItem '0' 'Volver' 'DarkGray'

        $op = Read-Host '   Elegi una categoria'
        switch ($op) {
            '1' { Show-TweakCategory -Categoria 'privacidad' -Titulo 'Privacidad' }
            '2' { Show-TweakCategory -Categoria 'sistema' -Titulo 'Sistema' }
            '3' { Show-TweakCategory -Categoria 'rendimiento' -Titulo 'Rendimiento y red' }
            '4' { Show-BloatwareMenu }
            '5' { Show-TweakCategory -Categoria 'avanzado' -Titulo 'Zona de peligro' -Aviso 'Solo para usuarios avanzados.' }
            '0' { return }
            default { Write-Warn 'Opcion invalida.'; Start-Sleep 1 }
        }
    }
}

function Show-TweakCategory {
    param(
        [string]$Categoria,
        [string]$Titulo,
        [string]$Aviso = ''
    )

    while ($true) {
        Write-Banner
        Write-Host ('   --- ' + $Titulo + ' ---') -ForegroundColor Magenta
        if ($Aviso) {
            Write-Warn $Aviso
        }
        Write-Host ''

        $lista = @(Get-TweaksByCategory $Categoria)
        for ($i = 0; $i -lt $lista.Count; $i++) {
            $tweak = $lista[$i]
            $estado = Test-TweakApplied $tweak
            $marca = '[??]'
            $color = Get-RiskColor $tweak
            if ($estado -eq $true) {
                $marca = '[ON]'
                $color = 'Green'
            }
            elseif ($estado -eq $false) {
                $marca = '[  ]'
            }
            Write-Host ('   {0,2}. {1} {2}{3}' -f ($i + 1), $marca, $tweak.nombre, (Get-RiskSuffix $tweak)) -ForegroundColor $color
        }

        Write-Host ''
        Write-Info 'Escribi numeros separados por comas o rangos, por ejemplo: 1,3,5-7.'
        Write-Info 'En categorias normales escribi A para aplicar todos los pendientes de riesgo bajo.'
        Write-Info 'Enter o 0 para volver.'
        Write-Host ''

        $op = (Read-Host '   Tu eleccion').Trim()
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }

        if ($op -match '^[dD]\s*(\d{1,3})$') {
            $numero = [int]$Matches[1]
            if ($numero -ge 1 -and $numero -le $lista.Count) {
                Show-TweakDetail $lista[$numero - 1]
                Wait-Enter
            }
            continue
        }

        if ($op -match '^[aA]$') {
            if ($Categoria -eq 'avanzado') {
                Write-Warn 'En zona de peligro se aplica de a uno.'
                continue
            }
            $ids = @($lista | Where-Object { $_.riesgo -eq 'bajo' } | ForEach-Object { $_.id })
            Invoke-TweakSet -Ids $ids -Titulo ($Titulo + ': todos los de riesgo bajo')
            Wait-Enter
            continue
        }

        $indices = @(ConvertTo-Indices -Texto $op -Max $lista.Count)
        if ($indices.Count -eq 0) {
            Write-Warn 'Seleccion invalida.'
            Start-Sleep 1
            continue
        }

        $ids = @($indices | ForEach-Object { $lista[$_].id })
        Invoke-TweakSet -Ids $ids
        Wait-Enter
    }
}

function Show-HistoryMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Historial y deshacer ---' -ForegroundColor Magenta
        Write-Host ''

        $lotes = @(Get-Lotes)
        if ($lotes.Count -eq 0) {
            Write-Info 'Todavia no hay cambios registrados.'
            Wait-Enter
            return
        }

        for ($i = 0; $i -lt $lotes.Count; $i++) {
            $lote = $lotes[$i]
            Write-Host ('   [{0}] {1} - {2} cambio(s)' -f ($i + 1), $lote.Fecha, $lote.Cambios) -ForegroundColor White
            Write-Host ('       ' + $lote.Nombres) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Info 'Elegi el numero del lote que queres deshacer.'
        $op = Read-Host '   Tu eleccion'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }

        $numero = 0
        if (-not [int]::TryParse($op, [ref]$numero) -or $numero -lt 1 -or $numero -gt $lotes.Count) {
            Write-Warn 'Opcion invalida.'
            continue
        }

        if (-not (Confirm-Gonix '¿Deshacer el lote seleccionado?')) { continue }
        $resultado = Undo-Lote -Lote $lotes[$numero - 1].Lote
        if ($resultado.Fallos -eq 0) {
            Write-Ok ('Se revirtieron ' + $resultado.Ok + ' cambio(s).')
        }
        else {
            Write-Warn 'Hubo cambios que no pudieron deshacerse.'
        }
        Wait-Enter
    }
}
