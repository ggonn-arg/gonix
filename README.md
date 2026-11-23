# Gonix

**Optimizador de Windows 11 para la consola.** Aplica ajustes de privacidad y rendimiento, instala programas con winget y limpia el sistema, desde un menú simple. Cada cambio se guarda en un historial para que puedas deshacerlo.

![Versión](https://img.shields.io/badge/versión-1.0.0-blue.svg)
![PowerShell](https://img.shields.io/badge/Windows%20PowerShell-5.1-blue.svg)
![Windows](https://img.shields.io/badge/Windows-11-0078D4.svg)
![Licencia](https://img.shields.io/badge/licencia-MIT-green.svg)

```text
   ██████╗  ██████╗ ███╗   ██╗██╗██╗  ██╗
  ██╔════╝ ██╔═══██╗████╗  ██║██║╚██╗██╔╝
  ██║  ███╗██║   ██║██╔██╗ ██║██║ ╚███╔╝
  ██║   ██║██║   ██║██║╚██╗██║██║ ██╔██╗
  ╚██████╔╝╚██████╔╝██║ ╚████║██║██╔╝ ██╗
   ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝
        [ Optimizador de Windows 11 ]
```

---

## Índice

- [Instalación](#instalación)
- [Qué podés hacer](#qué-podés-hacer)
- [Perfiles](#perfiles)
- [Cómo funciona "Deshacer"](#cómo-funciona-deshacer)
- [Seguridad y transparencia](#seguridad-y-transparencia)
- [Preguntas frecuentes](#preguntas-frecuentes)
- [Agregar tus propios tweaks](#agregar-tus-propios-tweaks)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Aviso legal](#aviso-legal)

---

## Instalación

**Requisitos:** Windows 11 (también corre en Windows 10, con algunos tweaks sin efecto), Windows PowerShell 5.1 y permisos de administrador.

### Opción 1: una línea (sin instalar nada)

Abrí **PowerShell como administrador** y pegá:

Descargá `Lanzador.ps1` desde la sección Releases y ejecútalo como administrador. El lanzador incluido descarga la versión fija `v0.1` y verifica el SHA256 del ZIP antes de ejecutarlo.

Descarga Gonix a una carpeta temporal, lo ejecuta y borra los archivos descargados al cerrar. El historial de cambios **no** se borra: se guarda en `%ProgramData%\Gonix`.

### Opción 2: descargar el ZIP

1. En GitHub: **Code → Download ZIP**, y extraé la carpeta.
2. Doble clic en `Gonix.bat`. Pide permisos de administrador solo.

### Opción 3: una versión fija (recomendado si querés revisar el código)

El lanzador incluido usa una versión fija y verifica el paquete antes de ejecutarlo.

> Ejecutar un script de internet con permisos de administrador exige confianza. Podés leer todo el código antes de usarlo: es texto plano, sin binarios.

---

## Qué podés hacer

| Menú | Para qué sirve |
|---|---|
| **Perfiles** | Aplica un conjunto de ajustes con un solo paso (Recomendado, Gaming, Oficina, Notebook, Privacidad total). Antes de aplicar te muestra la lista. |
| **Tweaks individuales** | 39 ajustes en 4 categorías: Privacidad, Sistema, Rendimiento y Zona de peligro. Cada uno muestra si ya está aplicado y su nivel de riesgo. |
| **Apps preinstaladas** | Desinstala 17 apps de Windows que quizás no uses (Skype, Noticias, Clipchamp, etc.). |
| **Instalar aplicaciones** | 55 programas populares en 7 categorías, instalados con winget. |
| **Historial y deshacer** | Revierte los cambios de cualquier operación anterior. |
| **Windows Update** | Pausa las actualizaciones por 7, 14 o 35 días, o las reanuda. |
| **Limpieza y reparación** | Temporales y papelera, SFC, DISM y reparación de red y de Windows Update. |
| **Punto de restauración** | Crea un punto de restauración de Windows antes de cambiar nada. |

### Cómo se usan los menús

- Escribí el **número** del tweak para activarlo o desactivarlo. Si aparece `[ON]` y Gonix guardó el valor previo, elegirlo otra vez lo restaura. Podés elegir varios: `1,3,5-7`.
- `d 3` muestra el **detalle** del tweak 3: qué clave cambia, su valor actual y el nuevo.
- `A` aplica todos los pendientes de **riesgo bajo** de la categoría.
- Marcas en la lista: `[ON]` ya aplicado, `[  ]` pendiente, `[??]` no se puede detectar (si Gonix lo aplicó, el historial permite reconocerlo).
- Colores: blanco = riesgo bajo, amarillo = medio, rojo = alto.

### Niveles de riesgo

| Nivel | Significado |
|---|---|
| **Bajo** | Cambia una preferencia o política. No afecta la estabilidad. |
| **Medio** | Puede desactivar una función que quizás uses (por ejemplo, la ubicación) o depende de tu hardware. |
| **Alto** | Solo en la **Zona de peligro**. Puede causar calor, consumo o inestabilidad. Pide escribir `ACEPTO` para continuar. |

---

## Perfiles

| Perfil | Pensado para | Qué hace |
|---|---|---|
| **Recomendado** | Cualquier PC | Menos anuncios y rastreo, extensiones de archivo visibles. Solo riesgo bajo. |
| **Gaming** | Jugar | Sin tareas de fondo, GameDVR y Game Bar fuera, mejor red, puntero 1:1 y HAGS. |
| **Oficina** | Trabajar | Privacidad y limpieza sin tocar rendimiento ni energía. |
| **Notebook** | Más batería | Privacidad y menos procesos de fondo. No toca hibernación ni planes de energía. |
| **Privacidad total** | Máxima privacidad | Todos los tweaks de privacidad, incluidos ubicación y muestras de Defender. Algunas funciones online dejan de funcionar. |

Los tweaks que ya están aplicados se omiten solos.

---

## Cómo funciona "Deshacer"

- Antes de cada cambio, Gonix guarda el valor anterior en `%ProgramData%\Gonix\historial.json`.
- Al volver a seleccionar un tweak activo desde el menú individual, Gonix revierte solo ese tweak y restaura el valor anterior; los demás cambios del mismo lote quedan aplicados.
- Si un tweak ya estaba activo antes de usar Gonix y no hay historial, Gonix ofrece restablecer el valor predeterminado documentado de Windows. Esto no recupera personalizaciones previas y no se puede deshacer desde el historial; para estados que no puede detectar, pregunta si querés aplicarlo o restablecerlo.
- Los cambios de una misma operación forman un **lote**. Desde **Historial y deshacer** elegís un lote y se revierte completo.
- Si algo no se puede revertir, Gonix te lo dice y lo deja en el historial para reintentar.
- El historial **nunca se ejecuta como código**: el deshacer solo usa acciones internas de Gonix.
- Para operaciones grandes, Gonix te ofrece crear un **punto de restauración** antes de aplicar.

**Lo que no se puede deshacer desde Gonix:** la limpieza de temporales, la desinstalación de apps preinstaladas (se reinstalan desde Microsoft Store), las reparaciones (SFC, DISM, red) y las apps instaladas con winget.

---

## Seguridad y transparencia

- **Todo es visible.** Los tweaks están en archivos JSON legibles dentro de `tweaks\`. No hay binarios ni código ofuscado.
- **No ejecuta comandos de internet** aparte de descargar el propio Gonix y usar winget cuando se lo pedís.
- **Registro de actividad:** cada operación queda en `%ProgramData%\Gonix\gonix.log`.
- **Qué cambia y qué no:** modifica claves del registro, servicios y planes de energía documentados. No instala drivers, no desactiva Windows Defender ni el firewall, y no toca BitLocker.
- **Sin garantías de resultados:** algunos tweaks tienen un efecto pequeño o dependen de tu hardware. Cada descripción lo aclara.

### Limitaciones conocidas

- Los cambios en `HKCU` se aplican al usuario que ejecuta Gonix. Si elevás con una cuenta de administrador distinta a la tuya, se aplican a *esa* cuenta.
- Algunos ajustes requieren reiniciar o cerrar sesión. Gonix te avisa al terminar.
- Windows puede revertir algunas políticas con actualizaciones grandes. Si pasa, volvé a aplicarlas.
- En PCs administradas por una organización, las políticas de grupo pueden pisar estos cambios.

---

## Preguntas frecuentes

**¿Es seguro?**
Los tweaks de riesgo bajo son preferencias y políticas estándar de Windows y se pueden deshacer. Aun así, creá un punto de restauración antes de aplicar muchos cambios: Gonix te lo ofrece.

**¿Por qué no apaga Windows Update del todo?**
Porque deja el equipo sin parches de seguridad. La pausa tiene fecha de vencimiento, igual que la de Configuración.

**¿Por qué no incluye "Eliminar Edge" ni "Desactivar BitLocker"?**
Eliminar Edge puede romper componentes de Windows y apps que usan WebView2, y desactivar BitLocker descifra el disco: son decisiones que conviene tomar a mano. Gonix sí desactiva la ejecución de Edge en segundo plano.

**¿Funciona en Windows 10?**
Corre, pero algunos tweaks son específicos de Windows 11 y no tendrán efecto.

**¿Un tweak muestra `[??]`?**
Es una acción cuyo estado no se puede leer directamente (por ejemplo, planes de energía). Igual se puede aplicar y deshacer.

**Después de aplicar un tweak no veo el cambio.**
Probá cerrar sesión y volver a entrar, o reiniciar. El detalle (`d N`) indica cuáles lo necesitan.

---

## Agregar tus propios tweaks

Todo el menú se genera desde los JSON, así que agregar un tweak es agregar un bloque. Ejemplo en `tweaks\sistema.json`:

```json
{
  "id": "mi-tweak",
  "nombre": "Nombre corto y claro",
  "descripcion": "Qué hace y qué efecto tiene.",
  "categoria": "sistema",
  "riesgo": "bajo",
  "requiere": "sesion",
  "tipo": "registro",
  "cambios": [
    {
      "ruta": "HKCU:\\Software\\Ejemplo",
      "nombre": "MiValor",
      "valor": 1,
      "tipoValor": "DWord"
    }
  ]
}
```

- `categoria`: `privacidad`, `sistema`, `rendimiento` o `avanzado`. Debe coincidir con el archivo.
- `riesgo`: `bajo`, `medio` o `alto`.
- `requiere`: `reinicio`, `sesion` o `null`.
- Para **borrar** un valor, usá `"eliminar": true` en lugar de `valor`.
- Si un cambio borrado debe poder restablecerse sin historial, definí también `restablecer` con su `valor` y `tipoValor`; opcionalmente, `validarExiste` puede exigir que exista un archivo antes de escribirlo.
- Para acciones más complejas (servicios, planes de energía, DNS), usá `"tipo": "accion"` y agregá un manejador con `Apply`, `Undo` y, opcionalmente, `Test` en `lib\Core.ps1`.
- Para sumarlo a un perfil, agregá su `id` en `profiles\<perfil>.json`.

Al iniciar, Gonix avisa si un perfil menciona un tweak que no existe.

---

## Estructura del proyecto

```text
Gonix/
├── Gonix.ps1            Punto de entrada
├── Gonix.bat            Doble clic para abrir
├── Lanzador.ps1         Descarga y ejecuta (modo "una línea")
├── lib/
│   ├── Helpers.ps1      Mensajes, registro, servicios
│   ├── Backup.ps1       Historial, deshacer, punto de restauración
│   ├── Core.ps1         Motor de tweaks y acciones internas
│   ├── Mantenimiento.ps1  Limpieza, reparación, Windows Update, apps
│   └── UI.ps1           Menús
├── tweaks/              Tweaks (JSON), apps de winget y apps preinstaladas
└── profiles/            Perfiles (JSON)
```

---

## Aviso legal

Gonix modifica el registro y la configuración de Windows. Se entrega **tal cual, sin garantías** (licencia MIT). Usalo bajo tu responsabilidad y creá un punto de restauración antes de aplicar cambios importantes.

## Autor

Creado por **Gonzalo** ([@ggonn-arg](https://github.com/ggonn-arg)). Las sugerencias y los *issues* son bienvenidos.

Licencia [MIT](LICENSE).
