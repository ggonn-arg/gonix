# Gonix v0.2

Optimizador de Windows 11 en PowerShell, con historial y deshacer.

## Cómo abrirlo

- Doble clic en `Gonix.bat` (pide administrador solo), o
- PowerShell como administrador:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
cd "C:\ruta\a\Gonix"
.\Gonix.ps1
```

## Cómo se usa un menú

En cada menú de tweaks (Privacidad, Sistema y rendimiento, Zona de peligro):

| Entrada | Qué hace |
|---|---|
| `1,3,5` o `2-4` | Aplica esos tweaks |
| `A` | Aplica TODOS los tweaks de ESE menú (omite los ya aplicados) |
| `S` | Simula: muestra valor actual y valor nuevo, sin tocar nada |
| `0` | Volver |

Marcas: `[x]` ya aplicado, `[ ]` sin aplicar, `[?]` no se puede comprobar.

## Deshacer

Todo lo que aplica Gonix se guarda en `historial.json`, agrupado por operación.
En **Historial y deshacer** podés revertir la última operación (`U`) o todo (`T`).
Lo único que no se puede deshacer es desinstalar apps (se reinstalan desde la Store).

## Agregar un tweak nuevo

Solo editá el JSON de la categoría (`tweaks\privacidad.json`, `rendimiento.json` o
`avanzado.json`). El menú se arma solo. Ejemplo de tweak de registro:

```json
{
  "id": "mi-tweak",
  "nombre": "Nombre que se ve en el menú",
  "descripcion": "Qué hace y qué se pierde.",
  "riesgo": "bajo",
  "rapida": false,
  "tipo": "registro",
  "cambios": [
    { "ruta": "HKCU:\\Software\\Ejemplo", "nombre": "Valor", "valor": 1, "tipoValor": "DWord" }
  ]
}
```

Tipos disponibles: `registro`, `servicio`, `powercfg`, `plan-energia`, `dns`, `comando`.
Riesgo: `bajo`, `medio`, `alto` (los de riesgo alto van en `avanzado.json` y nunca
entran en perfiles ni en la optimización rápida).

## Perfiles

Archivos en `profiles\`: una lista de ids en `"tweaks"` y/o categorías enteras en `"categorias"`.
