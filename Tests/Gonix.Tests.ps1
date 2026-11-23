$ErrorActionPreference = 'Stop'

Describe 'Gonix suite' {
    BeforeAll {
        $script:root = Split-Path -Parent $PSScriptRoot
        $script:GonixRoot = $script:root
        $env:GONIX_TEST_DATA_ROOT = Join-Path $env:TEMP ("gonix-pester-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $env:GONIX_TEST_DATA_ROOT -Force | Out-Null

        . (Join-Path $script:root 'lib\Helpers.ps1')
        . (Join-Path $script:root 'lib\Backup.ps1')
        . (Join-Path $script:root 'lib\Core.ps1')

        $script:testKey = 'HKCU:\Software\GonixPester'
        if (Test-Path -LiteralPath $script:testKey) {
            Remove-Item -LiteralPath $script:testKey -Recurse -Force
        }
        New-Item -Path $script:testKey -Force | Out-Null
    }

    AfterAll {
        if (Test-Path -LiteralPath $script:testKey) {
            Remove-Item -LiteralPath $script:testKey -Recurse -Force
        }
        if ($env:GONIX_TEST_DATA_ROOT -and (Test-Path -LiteralPath $env:GONIX_TEST_DATA_ROOT)) {
            Remove-Item -LiteralPath $env:GONIX_TEST_DATA_ROOT -Recurse -Force
        }
        Remove-Item Env:GONIX_TEST_DATA_ROOT -ErrorAction SilentlyContinue
    }

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

        $result = Invoke-TweakApply -Tweak $tweak
        $result.Estado | Should -Be 'ok'
        Save-History

        $entry = @(Read-History)[-1]
        $entry.Tipo | Should -Be 'registro'
        $entry.TweakId | Should -Be 'test-existing'
        $entry.Ruta | Should -Be $script:testKey
        $entry.Nombre | Should -Be 'TestValue'
        $entry.Existia | Should -BeTrue
        $entry.ValorAnterior | Should -Be 7
        $entry.TipoValor | Should -Be 'DWord'
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

        $result = Invoke-TweakApply -Tweak $tweak
        $result.Estado | Should -Be 'ok'
        Save-History
        (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'TestValue') | Should -Be 1

        $lote = $script:LoteActual
        (Undo-Lote -Lote $lote).Ok | Should -Be 1
        (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'TestValue') | Should -Be 7
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

        $result = Invoke-TweakApply -Tweak $tweak
        $result.Estado | Should -Be 'ok'
        Save-History
        (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'NewValue') | Should -Be 1

        (Undo-Lote -Lote $script:LoteActual).Ok | Should -Be 1
        $property = Get-ItemProperty -LiteralPath $script:testKey -Name 'NewValue' -ErrorAction SilentlyContinue
        @($property).Count | Should -Be 0
    }

    It 'desactiva solo el tweak seleccionado y restaura su valor previo' {
        Set-ItemProperty -LiteralPath $script:testKey -Name 'ToggleValue' -Value 7 -Type DWord
        Set-ItemProperty -LiteralPath $script:testKey -Name 'OtherValue' -Value 4 -Type DWord

        $toggle = [pscustomobject]@{
            id = 'test-toggle'
            tipo = 'registro'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'ToggleValue'
                valor = 1
                tipoValor = 'DWord'
            })
        }
        $other = [pscustomobject]@{
            id = 'test-other'
            tipo = 'registro'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'OtherValue'
                valor = 2
                tipoValor = 'DWord'
            })
        }

        (Invoke-TweakApply -Tweak $toggle).Estado | Should -Be 'ok'
        (Invoke-TweakApply -Tweak $other).Estado | Should -Be 'ok'
        Save-History

        $result = Undo-Tweak -TweakId 'test-toggle'
        $result.Ok | Should -Be 1
        $result.Fallos | Should -Be 0
        (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'ToggleValue') | Should -Be 7
        (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'OtherValue') | Should -Be 2
        @((Read-History) | Where-Object { $_.TweakId -eq 'test-toggle' }).Count | Should -Be 0
        @((Read-History) | Where-Object { $_.TweakId -eq 'test-other' }).Count | Should -Be 1
    }

    It 'elimina al desactivar un valor que no existia antes' {
        $tweak = [pscustomobject]@{
            id = 'test-toggle-remove'
            tipo = 'registro'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'ToggleNewValue'
                valor = 1
                tipoValor = 'DWord'
            })
        }

        (Invoke-TweakApply -Tweak $tweak).Estado | Should -Be 'ok'
        Save-History
        (Undo-Tweak -TweakId 'test-toggle-remove').Ok | Should -Be 1
        $property = Get-ItemProperty -LiteralPath $script:testKey -Name 'ToggleNewValue' -ErrorAction SilentlyContinue
        @($property).Count | Should -Be 0
    }

    It 'al volver a elegir un tweak activo en el menú lo desactiva' {
        Set-ItemProperty -LiteralPath $script:testKey -Name 'MenuToggleValue' -Value 9 -Type DWord
        $tweak = [pscustomobject]@{
            id = 'test-menu-toggle'
            nombre = 'Tweak de prueba'
            tipo = 'registro'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'MenuToggleValue'
                valor = 1
                tipoValor = 'DWord'
            })
        }
        $script:TweakIndex[$tweak.id] = $tweak
        (Invoke-TweakApply -Tweak $tweak).Estado | Should -Be 'ok'
        Save-History
        Mock Confirm-Gonix { return $true }

        Invoke-TweakSet -Ids @($tweak.id) -Alternar

        (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'MenuToggleValue') | Should -Be 9
        @((Read-History) | Where-Object { $_.TweakId -eq $tweak.id }).Count | Should -Be 0
    }

    It 'restablece al valor predeterminado si está activo pero no hay historial' {
        Set-ItemProperty -LiteralPath $script:testKey -Name 'ExternalValue' -Value 1 -Type DWord
        $tweak = [pscustomobject]@{
            id = 'test-external-toggle'
            nombre = 'Tweak externo'
            tipo = 'registro'
            riesgo = 'bajo'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'ExternalValue'
                valor = 1
                tipoValor = 'DWord'
            })
        }
        $script:TweakIndex[$tweak.id] = $tweak
        Mock Confirm-Gonix { return $true }

        Invoke-TweakSet -Ids @($tweak.id) -Alternar

        $property = Get-ItemProperty -LiteralPath $script:testKey -Name 'ExternalValue' -ErrorAction SilentlyContinue
        @($property).Count | Should -Be 0
        @((Read-History) | Where-Object { $_.TweakId -eq $tweak.id }).Count | Should -Be 0
    }
}

Describe 'Seguridad basica del proyecto' {
    It 'el lanzador usa un release fijado y verifica SHA256' {
        $launcher = Get-Content -LiteralPath (Join-Path $script:root 'Lanzador.ps1') -Raw -Encoding UTF8
        $launcher | Should -Match "\`$ref = 'v0\.1'"
        $launcher | Should -Match 'Get-FileHash.*SHA256'
        ($launcher -split "`n" | Where-Object { $_ -match 'Invoke-Expression|irm .*\\|.*iex|/main/' }).Count | Should -Be 0
    }

    It 'no usa Invoke-Expression en los scripts activos' {
        $matches = Get-ChildItem -Path $script:root -Recurse -Filter *.ps1 |
            Where-Object { $_.FullName -notlike (Join-Path $script:root 'Tests') + '*' } |
            Select-String -Pattern 'Invoke-Expression'
        @($matches).Count | Should -Be 0
    }

    It 'todos los archivos JSON siguen siendo JSON valido' {
        $invalid = @()
        Get-ChildItem -Path $script:root -Recurse -Filter *.json | ForEach-Object {
            try {
                Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop | Out-Null
            } catch {
                $invalid += $_.FullName
            }
        }
        @($invalid).Count | Should -Be 0
    }

    It 'conserva el logo y los menus dinamicos principales' {
        $ui = Get-Content -LiteralPath (Join-Path $script:root 'lib\UI.ps1') -Raw -Encoding UTF8
        $ui | Should -Match 'Optimizador de Windows 11'
        $ui | Should -Match 'function Show-MainMenu'
        $ui | Should -Match 'function Show-TweaksMenu'
        $ui | Should -Match 'Get-TweaksByCategory'
    }

    It 'todos los perfiles apuntan a tweaks existentes' {
        $ids = @{}
        Get-ChildItem -LiteralPath (Join-Path $script:root 'tweaks') -Filter *.json |
            Where-Object { $_.Name -notin @('apps.json','bloatware.json') } |
            ForEach-Object {
                $items = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($item in $items) {
                    if ($item.id) { $ids[$item.id] = $true }
                }
            }

        $invalid = @()
        Get-ChildItem -LiteralPath (Join-Path $script:root 'profiles') -Filter *.json | ForEach-Object {
            $profile = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($id in @($profile.tweaks)) {
                if (-not $ids.ContainsKey($id)) { $invalid += "$($_.Name): $id" }
            }
        }
        @($invalid).Count | Should -Be 0
    }

    It 'Read-JsonArray carga los objetos individuales en Windows PowerShell' {
        foreach ($categoria in @('privacidad','sistema','rendimiento','avanzado')) {
            $items = @(Read-JsonArray (Join-Path $script:GonixRoot "tweaks\$categoria.json"))
            @($items).Count | Should -BeGreaterThan 0
            foreach ($item in $items) {
                $item.id | Should -Not -BeNullOrEmpty
            }
        }
    }
}
}
