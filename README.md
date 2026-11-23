 🚀 Gonix - El Optimizador Definitivo para Windows 11

**Gonix** es una herramienta de código abierto, rápida y segura para optimizar Windows 11. Aplica tweaks de privacidad, mejora el rendimiento, limpia el sistema y instala tus aplicaciones favoritas, todo desde una interfaz de consola intuitiva y sin necesidad de instalar nada.

[![Version](https://img.shields.io/badge/version-v0.1-blue.svg)]()
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)]()

---

## ⚡ Instalación (1 sola línea)

Abrí **PowerShell como Administrador** y pegá el siguiente comando:

Descargá el archivo `Lanzador.ps1` publicado en el release
[`v0.1`](https://github.com/ggonn-arg/gonix/releases/tag/v0.1), hacé doble clic
en él o ejecutalo desde PowerShell como administrador. El lanzador descarga
`gonix.zip`, verifica su SHA256 contra `gonix.zip.sha256` y recién después
ejecuta Gonix.

Gonix no se instala en tu disco. Los archivos temporales se eliminan al salir y el historial se guarda en `%ProgramData%\Gonix`.

## Pruebas

Instalá Pester si todavía no está disponible:

```powershell
Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
Invoke-Pester -Path .\Tests\Gonix.Tests.ps1 -Output Detailed
```

✨ Características Principales
🎮 Perfiles de Optimización
Aplica configuraciones probadas con un solo clic:

Gaming Extremo: Máximo rendimiento para juegos (FPS, red y GPU).

Oficina / Notebook: Privacidad sin gastar batería.

Privacidad Total: Bloquea toda la telemetría y rastreo de Microsoft.

🛡️ Privacidad y Sistema
Colección de tweaks individuales: privacidad, rendimiento, limpieza y aplicaciones.

Zona de Peligro: Para usuarios avanzados (Plan de Máximo Rendimiento, Core Parking).

Historial y Deshacer: Todos los cambios se guardan en un historial. Si no te gusta el resultado, podés revertir todo con un clic.

📦 Gestor de Aplicaciones (Winget)
Instala automáticamente Navegadores (Chrome, Firefox, Brave).

Juegos (Steam, Epic Games, Battle.net).

Desarrollo (VS Code, Git, Python).

Multimedia (VLC, Spotify, OBS Studio).

Utilidades (7-Zip, WinRAR, CPU-Z).

🧹 Limpieza y Reparación
Desinstalador de Bloatware (Apps preinstaladas de Windows).

Reparación de archivos del sistema (SFC y DISM).

Reparación de red (Flush DNS, Winsock).

Pausar/Reanudar Windows Update.

Crear Puntos de Restauración.

🎨 Interfaz Visual
Gonix cuenta con una interfaz de consola moderna, con información en tiempo real de tu procesador y memoria RAM, y un sistema de navegación por menús con colores.

text
   ██████╗  ██████╗ ███╗   ██╗██╗██╗  ██╗
  ██╔════╝ ██╔═══██╗████╗  ██║██║╚██╗██╔╝
  ██║  ███╗██║   ██║██╔██╗ ██║██║ ╚███╔╝ 
  ██║   ██║██║   ██║██║╚██╗██║██║ ██╔██╗ 
  ╚██████╔╝╚██████╔╝██║ ╚████║██║██╔╝ ██╗
   ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝
        [ Optimizador de Windows 11 ]  v0.1
⚠️ Descargo de Responsabilidad
Gonix modifica el registro y la configuración de Windows. No todos los cambios son reversibles ni adecuados para cada equipo. Los perfiles y la "Zona de Peligro" requieren confirmación y se recomienda crear un Punto de Restauración antes de usarlos.

👨‍💻 Autor
Creado con pasión por Gonzalo (Gon).

GitHub: @ggonn-arg