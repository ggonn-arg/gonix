$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$script:GonixRoot = $root
$env:GONIX_TEST_DATA_ROOT = Join-Path $env:TEMP ("gonix-pester-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $env:GONIX_TEST_DATA_ROOT -Force | Out-Null

function Assert-Equal {
    param($Actual, $Expected, [string]$Because)
    if ($Actual -ne $Expected) {
        throw "$Because`nEsperado: $Expected`nActual: $Actual"
    }
}

function Assert-True {
    param($Condition, [string]$Because)
    if (-not $Condition) { throw $Because }
}

. (Join-Path $root 'lib\Helpers.ps1')
. (Join-Path $root 'lib\Backup.ps1')
. (Join-Path $root 'lib\Core.ps1')

$script:testKey = 'HKCU:\Software\GonixPester'
if (Test-Path -LiteralPath $script:testKey) {
    Remove-Item -LiteralPath $script:testKey -Recurse -Force
}
New-Item -Path $script:testKey -Force | Out-Null

Describe 'Historial de tweaks de registro' {
    BeforeEach {
        if (Test-Path -LiteralPath $script:testKey) {
            Remove-Item -LiteralPath $script:testKey -Recurse -Force
        }
        New-Item -Path $script:testKey -Force | Out-Null
        Write-History -Lista @()
        Start-Lote
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:testKey) {
            Remove-Item -LiteralPath $script:testKey -Recurse -Force
        }
    }

    It 'guarda ruta, valor anterior y tipo al aplicar' {
        Set-ItemProperty -LiteralPath $script:testKey -Name 'TestValue' -Value 7 -Type DWord

        $tweak = [pscustomobject]@{
            id = 'test-existing'
            tipo = 'registro'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'TestValue'
                valor = 1
                tipoValor = 'DWord'
            })
        }

        Invoke-GonixTweak -Tweak $tweak

        $entry = @(Read-History)[-1]
        Assert-Equal $entry.Tipo 'registro' 'Tipo de historial incorrecto'
        Assert-Equal $entry.TweakId 'test-existing' 'TweakId incorrecto'
        Assert-Equal $entry.Ruta $script:testKey 'Ruta incorrecta'
        Assert-Equal $entry.Nombre 'TestValue' 'Nombre incorrecto'
        Assert-True $entry.Existia 'Debe indicar que el valor existia'
        Assert-Equal $entry.ValorAnterior 7 'Valor anterior incorrecto'
        Assert-Equal $entry.TipoValor 'DWord' 'Tipo anterior incorrecto'
    }

    It 'restaura el valor anterior despues de deshacer' {
        Set-ItemProperty -LiteralPath $script:testKey -Name 'TestValue' -Value 7 -Type DWord
        $tweak = [pscustomobject]@{
            id = 'test-restore'
            tipo = 'registro'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'TestValue'
                valor = 1
                tipoValor = 'DWord'
            })
        }

        Invoke-GonixTweak -Tweak $tweak
        Assert-Equal (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'TestValue') 1 'No aplico el nuevo valor'

        $lote = $script:LoteActual
        Assert-Equal (Undo-Lote -Lote $lote) 1 'El lote no devolvio una desicion'
        Assert-Equal (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'TestValue') 7 'No resto el valor anterior'
    }

    It 'elimina una propiedad que no existia al deshacer' {
        $tweak = [pscustomobject]@{
            id = 'test-remove'
            tipo = 'registro'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'NewValue'
                valor = 1
                tipoValor = 'DWord'
            })
        }

        Invoke-GonixTweak -Tweak $tweak
        Assert-Equal (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'NewValue') 1 'No creo el nuevo valor'

        Assert-Equal (Undo-Lote -Lote $script:LoteActual) 1 'El lote no devolvio una desicion'
        $property = Get-ItemProperty -LiteralPath $script:testKey -Name 'NewValue' -ErrorAction SilentlyContinue
        Assert-Equal (@($property).Count) 0 'La propiedad no se elimino'
    }
}

Describe 'Seguridad basica del proyecto' {
    It 'el lanzador usa un release fijado y verifica SHA256' {
        $launcher = Get-Content -LiteralPath (Join-Path $root 'Lanzador.ps1') -Raw -Encoding UTF8
        Assert-True ($launcher -match "\`$version = 'v[^']+'") 'El lanzador no tiene una version fijada'
        Assert-True ($launcher -match 'Get-FileHash.*SHA256') 'El lanzador no verifica SHA256'
        Assert-Equal (@($launcher -split "`n" | Where-Object { $_ -match 'refs/heads/main|raw\.githubusercontent\.com/.*/main' }).Count) 0 'El lanzador todavia usa main'
    }

    It 'no usa Invoke-Expression en los scripts activos' {
        $matches = Get-ChildItem -Path $root -Recurse -Filter *.ps1 |
            Where-Object { $_.FullName -notlike (Join-Path $root 'Tests') + '*' } |
            Select-String -Pattern 'Invoke-Expression'
        Assert-Equal (@($matches).Count) 0 'Quedo Invoke-Expression en scripts activos'
    }

    It 'todos los archivos JSON siguen siendo JSON valido' {
        $invalid = @()
        Get-ChildItem -Path $root -Recurse -Filter *.json | ForEach-Object {
            try {
                Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop | Out-Null
            } catch {
                $invalid += $_.FullName
            }
        }
        Assert-Equal (@($invalid).Count) 0 'Hay JSON invalido'
    }
}

if (Test-Path -LiteralPath $script:testKey) {
    Remove-Item -LiteralPath $script:testKey -Recurse -Force
}
if ($env:GONIX_TEST_DATA_ROOT -and (Test-Path -LiteralPath $env:GONIX_TEST_DATA_ROOT)) {
    Remove-Item -LiteralPath $env:GONIX_TEST_DATA_ROOT -Recurse -Force
}
Remove-Item Env:GONIX_TEST_DATA_ROOT -ErrorAction SilentlyContinue
