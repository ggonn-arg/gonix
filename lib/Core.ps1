function Get-TweaksFromFile {
    param($Archivo)
    $path = Join-Path $scriptDir "tweaks\$Archivo"
    if (Test-Path $path) { return @(Get-Content $path -Raw | ConvertFrom-Json) }
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
        if ($tweak.tipo -eq 'registro') {
            # Formato viejo: ruta directa
            if ($tweak.PSObject.Properties.Name -contains 'ruta') {
                if (-not (Test-Path $tweak.ruta)) { New-Item -Path $tweak.ruta -Force | Out-Null }
                $actual = $null; $existe = $false
                try { $item = Get-ItemProperty -Path $tweak.ruta -Name $tweak.nombreValor -ErrorAction Stop; $actual = $item.$($tweak.nombreValor); $existe = $true } catch {}
                
                Set-ItemProperty -Path $tweak.ruta -Name $tweak.nombreValor -Value $tweak.valorNuevo -Type DWord -Force
                Add-History -Tipo 'registro' -TweakId $tweak.id -Ruta $tweak.ruta -Nombre $tweak.nombreValor -Existia $existe -ValorAnterior $actual -TipoValor 'DWord'
                Write-Host "   [OK] Registro modificado." -ForegroundColor Green
            }
            # Formato nuevo: cambios en lista
            elseif ($tweak.PSObject.Properties.Name -contains 'cambios') {
                foreach ($c in $tweak.cambios) {
                    if (-not (Test-Path $c.ruta)) { New-Item -Path $c.ruta -Force | Out-Null }
                    $actual = $null; $existe = $false
                    try { $item = Get-ItemProperty -Path $c.ruta -Name $c.nombre -ErrorAction Stop; $actual = $item.$($c.nombre); $existe = $true } catch {}
                    
                    $tipoVal = if ($c.tipoValor) { $c.tipoValor } else { 'DWord' }
                    Set-ItemProperty -Path $c.ruta -Name $c.nombre -Value $c.valor -Type $tipoVal -Force
                    Add-History -Tipo 'registro' -TweakId $tweak.id -Ruta $c.ruta -Nombre $c.nombre -Existia $existe -ValorAnterior $actual -TipoValor $tipoVal
                    Write-Host "   [OK] $($c.nombre) aplicado." -ForegroundColor Green
                }
            }
        }
        elseif ($tweak.tipo -eq 'comando') {
            Invoke-Expression $tweak.comando
            Add-History -Tipo 'comando' -TweakId $tweak.id -Undo $tweak.comandoOriginal
            Write-Host "   [OK] Comando ejecutado." -ForegroundColor Green
        }
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
    $perfilPath = Join-Path $scriptDir "profiles\$NombreArchivo.json"
    if (-not (Test-Path $perfilPath)) { Write-Host "   [!] Perfil no encontrado." -ForegroundColor Red; return }
    $perfil = Get-Content $perfilPath -Raw | ConvertFrom-Json
    
    Write-Host "`n   >>> $($perfil.nombre)" -ForegroundColor Cyan
    Write-Host "       $($perfil.descripcion)`n" -ForegroundColor Gray
    
    if ((Read-Host "   ¿Aplicar perfil completo? (s/n)") -ne "s") { return }
    
    Start-Lote
    foreach ($id in $perfil.tweaks) {
        $tweak = Get-TweakById -Id $id
        if (-not $tweak) { continue }
        Write-Host "   -> $($tweak.nombre)" -ForegroundColor DarkGray
        
        if ($tweak.tipo -eq 'registro') {
            $cambios = if ($tweak.cambios) { $tweak.cambios } else { @([PSCustomObject]@{ruta=$tweak.ruta; nombre=$tweak.nombreValor; valor=$tweak.valorNuevo; tipoValor='DWord'}) }
            foreach ($c in $cambios) {
                if (-not (Test-Path $c.ruta)) { New-Item -Path $c.ruta -Force | Out-Null }
                $actual = $null; $existe = $false
                try { $item = Get-ItemProperty -Path $c.ruta -Name $c.nombre -ErrorAction Stop; $actual = $item.$($c.nombre); $existe = $true } catch {}
                $tipoVal = if ($c.tipoValor) { $c.tipoValor } else { 'DWord' }
                Set-ItemProperty -Path $c.ruta -Name $c.nombre -Value $c.valor -Type $tipoVal -Force
                Add-History -Tipo 'registro' -TweakId $tweak.id -Ruta $c.ruta -Nombre $c.nombre -Existia $existe -ValorAnterior $actual -TipoValor $tipoVal
            }
        } elseif ($tweak.tipo -eq 'comando') {
            Invoke-Expression $tweak.comando
            Add-History -Tipo 'comando' -TweakId $tweak.id -Undo $tweak.comandoOriginal
        }
    }
    Write-Host "   [OK] Perfil aplicado con éxito." -ForegroundColor Green
}

function Invoke-QuickOptimize {
    Write-Banner
    Write-Host "   ⚡ --- OPTIMIZACIÓN RÁPIDA --- ⚡`n" -ForegroundColor Green
    Write-Host "   Aplicando tweaks seguros...`n" -ForegroundColor Gray
    
    $tweaksAAplicar = @("disable-telemetry", "disable-cortana", "disable-widgets", "disable-background-apps", "disable-gamedvr", "disable-start-suggestions", "disable-nagle-algorithm", "gpu-scheduling")
    
    Start-Lote
    foreach ($id in $tweaksAAplicar) {
        $tweak = Get-TweakById -Id $id
        if ($tweak -and $tweak.tipo -eq 'registro') {
            foreach ($c in $tweak.cambios) {
                if (-not (Test-Path $c.ruta)) { New-Item -Path $c.ruta -Force | Out-Null }
                $actual = $null; $existe = $false
                try { $item = Get-ItemProperty -Path $c.ruta -Name $c.nombre -ErrorAction Stop; $actual = $item.$($c.nombre); $existe = $true } catch {}
                Set-ItemProperty -Path $c.ruta -Name $c.nombre -Value $c.valor -Type $c.tipoValor -Force
                Add-History -Tipo 'registro' -TweakId $tweak.id -Ruta $c.ruta -Nombre $c.nombre -Existia $existe -ValorAnterior $actual -TipoValor $c.tipoValor
                Write-Host "   -> $($tweak.nombre)" -ForegroundColor DarkGray
            }
        } elseif ($tweak -and $tweak.tipo -eq 'comando') {
            Invoke-Expression $tweak.comando
            Add-History -Tipo 'comando' -TweakId $tweak.id -Undo $tweak.comandoOriginal
            Write-Host "   -> $($tweak.nombre)" -ForegroundColor DarkGray
        }
    }
    Write-Host "`n   [OK] Optimización rápida completada." -ForegroundColor Green
    Read-Host "   Enter para volver"
}
function Invoke-AllTweaks {
    param([string]$Categoria)
    
    Write-Host "`n   Aplicando TODOS los tweaks de la categoría '$Categoria'..." -ForegroundColor Magenta
    Write-Host "   (Los que ya están aplicados se ignorarán automáticamente)" -ForegroundColor DarkGray
    
    $archivo = "$Categoria.json"
    $lista = Get-TweaksFromFile -Archivo $archivo
    
    if ($lista.Count -eq 0) {
        Write-Host "   [!] No se encontraron tweaks en $archivo" -ForegroundColor Red
        return
    }

    Start-Lote
    
    foreach ($tweak in $lista) {
        Write-Host "   -> $($tweak.nombre)" -ForegroundColor DarkGray
        
        if ($tweak.tipo -eq 'registro') {
            # Soporte para formato viejo (ruta) y nuevo (cambios)
            $cambios = if ($tweak.cambios) { $tweak.cambios } else { @([PSCustomObject]@{ruta=$tweak.ruta; nombre=$tweak.nombreValor; valor=$tweak.valorNuevo; tipoValor='DWord'}) }
            
            foreach ($c in $cambios) {
                if (-not (Test-Path $c.ruta)) { New-Item -Path $c.ruta -Force | Out-Null }
                $actual = $null; $existe = $false
                try { $item = Get-ItemProperty -Path $c.ruta -Name $c.nombre -ErrorAction Stop; $actual = $item.$($c.nombre); $existe = $true } catch {}
                
                $tipoVal = if ($c.tipoValor) { $c.tipoValor } else { 'DWord' }
                Set-ItemProperty -Path $c.ruta -Name $c.nombre -Value $c.valor -Type $tipoVal -Force
                Add-History -Tipo 'registro' -TweakId $tweak.id -Ruta $c.ruta -Nombre $c.nombre -Existia $existe -ValorAnterior $actual -TipoValor $tipoVal
            }
        } elseif ($tweak.tipo -eq 'comando') {
            Invoke-Expression $tweak.comando
            Add-History -Tipo 'comando' -TweakId $tweak.id -Undo $tweak.comandoOriginal
        }
    }
    
    Write-Host "`n   [OK] Todos los tweaks de $Categoria han sido aplicados." -ForegroundColor Green
}
function Invoke-BloatwareRemoval {
    while ($true) {
        $bloatPath = Join-Path $scriptDir "tweaks\bloatware.json"
        
        if (-not (Test-Path $bloatPath)) {
            Write-Host "   [!] No se encontró el archivo de bloatware." -ForegroundColor Red
            return
        }

        $apps = @(Get-Content $bloatPath -Raw | ConvertFrom-Json)

        Write-Banner
        Write-Host "   --- Desinstalador de Apps Preinstaladas ---" -ForegroundColor Magenta
        Write-Host "   (Seleccioná las apps que querés ELIMINAR)" -ForegroundColor DarkGray
        Write-Host ""

        # Este bucle es el que arregla el problema: imprime una app por línea
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
            # Si elige T, carga todos los índices de la lista
            0..($apps.Count - 1) | ForEach-Object { $indicesAEliminar += $_ }
        } else {
            # Si elige números, los separa por coma
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
function New-GonixRestorePoint {
    Write-Banner
    Write-Host "   --- Punto de Restauración ---" -ForegroundColor Magenta
    Write-Host "   Creando un punto de restauración de seguridad..." -ForegroundColor Gray
    Write-Host "   (Esto puede tardar unos segundos)" -ForegroundColor DarkGray
    Write-Host ""
    
    try {
        Checkpoint-Computer -Description "Gonix - Antes de optimizar" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "   [OK] Punto de restauración creado con éxito." -ForegroundColor Green
        Write-Host "   Si algo sale mal, podés volver atrás desde el Panel de Control." -ForegroundColor DarkGray
    } catch {
        Write-Host "   [!] No se pudo crear el punto de restauración." -ForegroundColor Yellow
        Write-Host "       Motivo: $($_.Exception.Message)" -ForegroundColor DarkGray
        Write-Host "       (Recordá que Windows solo permite uno cada 24hs, o la Protección del Sistema puede estar desactivada)." -ForegroundColor DarkGray
    }
    Write-Host ""
    Read-Host "   Presioná Enter para volver"
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
    $appsPath = Join-Path $scriptDir "tweaks\apps.json"
    
    if (-not (Test-Path $appsPath)) {
        Write-Host "`n   [!] No se encontró el archivo de apps." -ForegroundColor Red
        Read-Host "   Enter para volver"
        return
    }

    # Leemos el JSON crudo para evitar problemas de formato
    $jsonContent = Get-Content $appsPath -Raw -Encoding UTF8
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
    
