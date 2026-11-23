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

    It 'restaura el valor personalizado de suspension USB al deshacer' {
        Mock powercfg.exe { $global:LASTEXITCODE = 0 }
        $datos = [pscustomobject]@{
            Esquema = '11111111-2222-3333-4444-555555555555'
            Tenia = $true
            Anterior = 2
        }

        $undo = $script:Acciones['usb-suspend-off'].Undo
        & $undo $datos

        Should -Invoke powercfg.exe -Times 1 -Exactly -ParameterFilter {
            $args -contains '-setacvalueindex' -and $args -contains '2'
        }
        Should -Invoke powercfg.exe -Times 1 -Exactly -ParameterFilter {
            $args -contains '-setactive'
        }
    }

    It 'deshace solo la aplicacion mas reciente si dos lotes ocurren en el mismo segundo' {
        Set-ItemProperty -LiteralPath $script:testKey -Name 'RapidToggleValue' -Value 5 -Type DWord
        $tweak = [pscustomobject]@{
            id = 'test-rapid-toggle'
            tipo = 'registro'
            cambios = @([pscustomobject]@{
                ruta = $script:testKey
                nombre = 'RapidToggleValue'
                valor = 1
                tipoValor = 'DWord'
            })
        }
        Mock Get-Date { [datetime]'2026-11-23T17:00:00' }

        Start-Lote
        $primerLote = $script:LoteActual
        (Invoke-TweakApply -Tweak $tweak).Estado | Should -Be 'ok'
        Save-History

        Set-ItemProperty -LiteralPath $script:testKey -Name 'RapidToggleValue' -Value 9 -Type DWord
        Start-Lote
        $segundoLote = $script:LoteActual
        $segundoLote | Should -Not -Be $primerLote
        (Invoke-TweakApply -Tweak $tweak).Estado | Should -Be 'ok'
        Save-History

        $result = Undo-Tweak -TweakId $tweak.id

        $result.Total | Should -Be 1
        (Get-ItemPropertyValue -LiteralPath $script:testKey -Name 'RapidToggleValue') | Should -Be 9
        $remaining = @(Read-History | Where-Object { $_.TweakId -eq $tweak.id })
        $remaining.Count | Should -Be 1
        $remaining[0].Lote | Should -Be $primerLote
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
    It 'el lanzador resuelve main a un SHA y descarga el ZIP de ese commit' {
        $launcher = Get-Content -LiteralPath (Join-Path $script:root 'Lanzador.ps1') -Raw -Encoding UTF8
        $launcher | Should -Match '/commits/main'
        $launcher | Should -Match '\$ref = \[string\]\$commit\.sha'
        $launcher | Should -Match '\{40\}'
        $launcher | Should -Match 'archive/\$ref\.zip'
        ($launcher -split "`n" | Where-Object { $_ -match 'Invoke-Expression|irm .*\\|.*iex|releases/download' }).Count | Should -Be 0
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
        $ui | Should -Match 'function Show-GamingAdvisor'
        $ui | Should -Match 'Asistente Gaming'
        $ui | Should -Not -Match "Write-MenuItem '9'"
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

    It 'el perfil Gaming incluye ajustes de FPS, latencia y energía' {
        $profile = Read-JsonObject (Join-Path $script:root 'profiles\gaming.json')
        $profile.tweaks | Should -Contain 'enable-game-mode'
        $profile.tweaks | Should -Contain 'disable-nagle-algorithm'
        $profile.tweaks | Should -Contain 'disable-usb-selective-suspend'
        $profile.tweaks | Should -Contain 'gpu-scheduling'
        $profile.tweaks | Should -Contain 'ultimate-performance-plan'
        $profile.tweaks | Should -Contain 'disable-core-parking'
    }

    It 'el diagnóstico Gaming informa el equipo sin modificarlo' {
        Mock Get-CimInstance {
            switch ($ClassName) {
                'Win32_OperatingSystem' {
                    [pscustomobject]@{ Caption = 'Windows 11 Pro'; BuildNumber = '26100' }
                }
                'Win32_Processor' {
                    [pscustomobject]@{ Name = 'CPU de prueba'; NumberOfCores = 8; NumberOfLogicalProcessors = 16 }
                }
                'Win32_ComputerSystem' {
                    [pscustomobject]@{ PCSystemType = 1; TotalPhysicalMemory = 16GB }
                }
                'Win32_VideoController' {
                    [pscustomobject]@{ Name = 'GPU de prueba'; DriverVersion = '1.2.3' }
                }
            }
        }
        Mock Get-RegState {
            param([string]$Ruta, [string]$Nombre)
            $valor = switch ($Nombre) {
                'AllowAutoGameMode' { 1 }
                'AutoGameModeEnabled' { 1 }
                'GameDVR_Enabled' { 0 }
                'AppCaptureEnabled' { 0 }
                'HwSchMode' { 2 }
                default { $null }
            }
            [pscustomobject]@{ Existe = ($null -ne $valor); Valor = $valor }
        }
        Mock powercfg.exe { $global:LASTEXITCODE = 0; 'Power Scheme GUID: test (Balanced)' }
        Mock Set-RegValue {}

        $report = Get-GamingDiagnostic

        $report.Windows | Should -Match '^Windows 11 Pro .+ 26100\)$'
        $report.CPU | Should -Match '^CPU de prueba \(8 .+ / 16 hilos\)$'
        $report.RAMGB | Should -Be 16
        $report.GPU[0].Nombre | Should -Be 'GPU de prueba'
        $report.ModoJuego | Should -Be 'Activado'
        $report.CapturaJuego | Should -Match '^Grabaci.n en segundo plano desactivada$'
        $report.HAGS | Should -Be 'Activada'
        $report.PlanEnergia | Should -Match 'Balanced'
        Should -Invoke Set-RegValue -Times 0 -Exactly
    }

    It 'advierte sobre HAGS en una GPU no compatible y recomienda Modo Juego si no está activo' {
        $diagnostico = [pscustomobject]@{
            ModoJuego = 'Configuración mixta'
            CapturaJuego = 'Grabación en segundo plano desactivada'
            GPU = @([pscustomobject]@{ Nombre = 'Radeon RX 570 Series' })
            HAGS = 'Activada'
            TipoEquipo = 'Escritorio'
            EsPortatil = $false
            PlanEnergia = 'Power Scheme GUID: test (Ultimate Performance)'
        }

        $recomendaciones = @(Get-GamingRecommendations -Diagnostico $diagnostico)

        @($recomendaciones | Where-Object { $_.Titulo -eq 'Activar Modo Juego' }).Count | Should -Be 1
        $hags = @($recomendaciones | Where-Object { $_.Titulo -match 'HAGS' })
        $hags.Count | Should -Be 1
        $hags[0].Nivel | Should -Match '^PRECAUCI'
        @($recomendaciones | Where-Object { $_.Titulo -match 'Máximo rendimiento' }).Count | Should -Be 0
    }

    It 'marca HAGS como riesgo medio y energía como alto en notebooks' {
        $diagnostico = [pscustomobject]@{
            ModoJuego = 'Activado'
            CapturaJuego = 'Grabación en segundo plano desactivada'
            GPU = @([pscustomobject]@{ Nombre = 'NVIDIA GeForce GTX 1660 Ti' })
            HAGS = 'Desactivada'
            TipoEquipo = 'Portátil'
            EsPortatil = $true
            PlanEnergia = 'Power Scheme GUID: test (Balanced)'
        }

        $recomendaciones = @(Get-GamingRecommendations -Diagnostico $diagnostico)

        $hags = @($recomendaciones | Where-Object { $_.Titulo -match 'HAGS' })
        $hags[0].Nivel | Should -Be 'MEDIO'
        $energia = @($recomendaciones | Where-Object { $_.Titulo -match 'Energ' })
        $energia[0].Nivel | Should -Be 'ALTO'
        $energia[0].Advertencia | Should -Match 'No lo recomiendo con bater'
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
