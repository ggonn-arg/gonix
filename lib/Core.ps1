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
            $cambios = if ($tweak.cambios) { $tweak.cambios } else { @([PSCustomObject]@{ruta=$tweak.ruta; nombre=$tweak.nombreValor; valor=$tweak.valorNuevo; tipoValor='DWord'}) }
            foreach ($c in $cambios) {
                if (-not (Test-Path $c.ruta)) { New-Item -Path $c.ruta -Force | Out-Null }
                $actual = $null; $existe = $false
                try { $item = Get-ItemProperty -Path $c.ruta -Name $c.nombre -ErrorAction Stop; $actual = $item.$($c.nombre); $existe = $true } catch {}
                
                $tipoVal = if ($c.tipoValor) { $c.tipoValor } else { 'DWord' }
                Set-ItemProperty -Path $c.ruta -Name $c.nombre -Value $c.valor -Type $tipoVal -Force
                Add-History -Tipo 'registro' -TweakId $tweak.id -Ruta $c.ruta -Nombre $c.nombre -Existia $existe -ValorAnterior $actual -TipoValor $tipoVal
                Write-Host "   [OK] $($c.nombre) aplicado." -ForegroundColor Green
            }
        }
        elseif ($tweak.tipo -eq 'comando') {
            Invoke-Expression $tweak.comando
            Add-History -Tipo 'comando' -TweakId $tweak.id -Undo $tweak.comandoOriginal
            Write-Host "   [OK] Comando ejecutado." -ForegroundColor Green
        }
    } catch { Write-Host "   [X] Error: $($_.Exception.Message)" -ForegroundColor Red }
}

# ==========================================
# NUEVA FUNCIÓN TOGGLE (Prender / Apagar)
# ==========================================
function Toggle-Tweak {
    param([string]$Id)
    
    $tweak = Get-TweakById -Id $Id
    if (-not $tweak) { Write-Host "   [!] Tweak '$Id' no encontrado." -ForegroundColor Red; return }

    # Verificamos si está aplicado actualmente
    $estaAplicado = $false
    if ($tweak.tipo -eq 'registro') {
        $c = if ($tweak.cambios) { $tweak.cambios[0] } else { $tweak }
        $ruta = if ($c.ruta) { $c.ruta } else { $tweak.ruta }
        $nombre = if ($c.nombre) { $c.nombre } else { $tweak.nombreValor }
        $valorEsperado = if ($c.valor) { $c.valor } else { $tweak.valorNuevo }

        try {
            $item = Get-ItemProperty -Path $ruta -Name $nombre -ErrorAction Stop
            if ($item.$nombre -eq $valorEsperado) { $estaAplicado = $true }
        } catch {}
    }

    if ($estaAplicado) {
        # Si está aplicado, lo revertimos
        Write-Host ""
        Write-Host "   <<< REVIRTIENDO: $($tweak.nombre)" -ForegroundColor Yellow
        
        Start-Lote
        if ($tweak.tipo -eq 'registro') {
            $cambios = if ($tweak.cambios) { $tweak.cambios } else { @([PSCustomObject]@{ruta=$tweak.ruta; nombre=$tweak.nombreValor; valor=$tweak.valorNuevo; tipoValor='DWord'}) }
            foreach ($c in $cambios) {
                # Volvemos al valor original (o 0 por defecto si no hay)
                $valorOriginal = 0
                if ($c.tipoValor -eq 'String') { $valorOriginal = "" }
                
                $tipoVal = if ($c.tipoValor) { $c.tipoValor } else { 'DWord' }
                Set-ItemProperty -Path $c.ruta -Name $c.nombre -Value $valorOriginal -Type $tipoVal -Force
                Add-History -Tipo 'registro' -TweakId $tweak.id -Ruta $c.ruta -Nombre $c.nombre -Existia $true -ValorAnterior $c.valor -TipoValor $tipoVal
            }
        } elseif ($tweak.tipo -eq 'comando') {
            Invoke-Expression $tweak.comandoOriginal
            Add-History -Tipo 'comando' -TweakId $tweak.id -Undo $tweak.comando
        }
        Write-Host "   [OK] Tweak desactivado." -ForegroundColor Green
    } else {
        # Si no está aplicado, lo aplicamos normal
        Invoke-Tweak -Id $Id
    }
}

# ... (El resto de tus funciones: Invoke-AllTweaks, Invoke-Profile, Invoke-QuickOptimize, etc. quedan igual)