# Call Of Duty Mobile Global (Root) 120FPS Module Magisk (Test S23 Ultra)

### CODM 120 FPS + Control — módulo universal para Android 11+ con root · by AJ

![Magisk probado](https://img.shields.io/badge/Magisk-probado-00A651?style=flat-square)
![Android 11+](https://img.shields.io/badge/Android-11%2B-3DDC84?style=flat-square&logo=android&logoColor=white)
![120 FPS en BR](https://img.shields.io/badge/120%20FPS-Battle%20Royale-FF6B00?style=flat-square)
![Licencia MIT](https://img.shields.io/badge/licencia-MIT-blue?style=flat-square)

Módulo Magisk/KernelSU/APatch que desbloquea y **mantiene 120 fps reales en Battle
Royale de Call of Duty: Mobile** en cualquier teléfono Android 11+ con root, con
**cualquier cuenta** y para CODM global, Garena, Tencent CN/KR y VNG. Incluye una
app de control que viaja dentro del módulo, diagnóstico con veredicto, originales
por cuenta y reversión completa a stock.

Verificado en hardware en un **Galaxy S23 Ultra (SM-S918B, Android 14, Magisk
30.7)**: **119,84 fps** medidos en partida BR real con el overlay, **23.271
frames, 0 dropped y 0 jank** en la capa del juego, 99,08 % a 8 ms
([TimeStats](docs/evidencia/timestats_br.txt)).

> **English summary.** A Magisk/KernelSU/APatch module that unlocks and keeps
> 120 fps in CODM Battle Royale on any rooted Android 11+ phone, for any account
> and for the global/Garena/Tencent/VNG packages. It edits only the game's
> per-account Unity preferences, discovers the active account automatically,
> saves and restores exact originals, ships its own control app and a doctor
> with a verdict. Verified on an S23 Ultra (SM-S918B, Android 14, Magisk 30.7);
> other brands, Android 15/16 and KernelSU/APatch are implemented but not yet
> hardware-tested. MIT licensed. No cheats, no aimbot, no wallhack, no
> anticheat evasion, no game APK modification.

---

## Índice

- [Qué hace](#qué-hace)
- [Cómo funciona](#cómo-funciona)
- [Lo que NO hace](#lo-que-no-hace)
- [Requisitos y compatibilidad](#requisitos-y-compatibilidad)
- [Instalación](#instalación)
- [Primeros pasos](#primeros-pasos)
- [La app de control](#la-app-de-control)
- [Configuración](#configuración)
- [Desactivar, restaurar y desinstalar](#desactivar-restaurar-y-desinstalar)
- [Pruebas y evidencia](#pruebas-y-evidencia)
- [Límites honestos](#límites-honestos)
- [Pendiente de hardware](#pendiente-de-hardware)
- [Riesgos, ban y legalidad](#riesgos-ban-y-legalidad)
- [Módulos similares y créditos](#módulos-similares-y-créditos)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Licencia](#licencia)

---

## Qué hace

- **120 fps en Battle Royale**: mantiene las dos claves de framerate de la cuenta
  activa (`EnableFramerateCustomize=1`, `FramerateCustomizeValue=120`) y guarda
  el valor original exacto de cada cuenta para poder revertirlo.
- **Cualquier cuenta**: en `account_mode=auto` (por defecto) detecta la cuenta
  activa desde `lastUserId.xml`, la registra sola y guarda originales por
  paquete y UID. Si no puede saber cuál está activa, **no escribe**.
- **Cualquier teléfono root**: descubre CODM global, Garena, Tencent CN/KR y VNG
  por la huella de sus PlayerPrefs, no por una lista de paquetes o modelos.
- **Perfiles por equipo**: en el S23 Ultra (dm3q) aplica el paquete verificado
  (spoof NX789J + capa Vulkan Adreno + audio); en cualquier otro equipo, por
  defecto **no toca identidad, GPU ni audio** y aplica solo las preferencias.
  El spoof de modelo (`spoof=compat`) es opt-in.
- **Diagnóstico con veredicto**: `doctor` responde `120_LISTO`, `FALTA_ULTRA`,
  `PANEL_60`, `SIN_JUEGO`, `CUENTA_AMBIGUA` o `ESPERA_DESBLOQUEO`, en vez de un
  montón de datos sin interpretar.
- **Reversión real**: `restore.sh` y el ciclo desactivar/eliminar devuelven
  prefs, GFX, Perf Z, GameManager, capa y props a su estado original, con
  originales persistidos fuera del módulo para sobrevivir a actualizaciones.
- **App incluida**: estado, interruptores, abrir/cerrar CODM, doctor, reaplicar
  120, cuenta activa, GFX, logs, restauración y baldosa QS. Sin permisos de
  INTERNET.

## Cómo funciona

El 120 de CODM en BR no se consigue parcheando el APK: es una **preferencia de
Unity por cuenta** que el propio juego escribe cuando el menú ofrece 120 fps.
El módulo hace tres cosas:

1. **Detecta** el paquete de CODM y la cuenta activa
   (`shared_prefs/lastUserId.xml`, clave `4e42c67f78`).
2. **Mantiene** las dos claves de framerate de esa cuenta en `1/120`, con el
   juego cerrado, verificando cada escritura y guardando el original exacto
   (`0/90` en la unidad de prueba) para poder restaurarlo.
3. **Ayuda a que el menú ofrezca 120** con un perfil de compatibilidad
   (`spoof=compat`, modelo NX789J) en equipos no verificados, o con el paquete
   completo verificado en dm3q (spoof + capa Vulkan Adreno 830 + audio).

El ajuste de **calidad gráfica ULTRA (`FPSLevel=5`) sigue siendo necesario**. El
módulo lo intenta con el juego cerrado (`fpslevel=1`), pero CODM lo reescribe al
arrancar, así que en la práctica hay que activarlo desde el menú del juego. El
doctor lo comprueba y avisa `FALTA_ULTRA` si falta.

Un worker reaplica las claves al cerrar el juego y tras el desbloqueo (en el
arranque `/data` está cifrado y no se puede diagnosticar). El lobby sigue a 60
fps por diseño del juego; los 120 son en partida BR.

## Lo que NO hace

- **No es un cheat**: no hay aimbot, wallhack, ESP, radar, macros ni ventajas de
  combate. Solo cambia el límite de fotogramas y la identidad que el juego ya
  usa para decidir qué opciones mostrar.
- **No modifica el APK ni los splits del juego**, no parchea memoria ni usa
  hooks de juego. En dm3q carga una **capa Vulkan propia** (mecanismo oficial
  del loader, activada por `debug.vulkan.layers`) que solo declara otra GPU.
- **No evita ni engaña al anticheat**: no se ejecuta ningún bypass.
- **No toca** FOV, sensibilidad, MSAA, modo de disparo ni ajustes de combate.
- **No toca** relojes de CPU/GPU, límites térmicos, animaciones del sistema,
  resolución ni densidad del teléfono.
- **No funciona sin root**: sin root no se puede montar el XML, espoofear antes
  de zygote ni cargar la capa.

## Requisitos y compatibilidad

| Requisito | Detalle |
| --- | --- |
| Root | Magisk, KernelSU o APatch (probado solo en Magisk 30.7) |
| Android | 11 o superior (probado en Android 14 / One UI 6.1.1) |
| Juego | CODM global, Garena, Tencent CN/KR o VNG |
| Panel | ≥120 Hz para 120 fps reales; 90 Hz da 90; 60 Hz no da 120 |
| Cuenta | Cualquiera; el módulo sigue la activa y guarda originales por cuenta |

Porcentaje honesto, con la incertidumbre incluida:

| Métrica | Estimación | Base |
| --- | --- | --- |
| Instalación y gestión | **≈100 %** de teléfonos root Android 11+ con CODM | Scripts POSIX, descubrimiento por huella, Magisk/KSU/APatch |
| 120 fps reales | **≈40 %** (rango conservador 35–55 %) | Requiere panel ≥120 Hz (37,4 % del mercado móvil 2026), GPU compatible y que el juego honre la clave |
| Verificado en hardware | **Solo SM-S918B / Magisk 30.7 / Android 14** | Pruebas de este repositorio |

No se declara compatibilidad verificada en Garena, Tencent, VNG, KernelSU,
APatch, Android 15/16 ni otras marcas: está **implementada** y pendiente de
medirse. La matriz completa y el protocolo de prueba están en
[docs/UNIVERSAL.md](docs/UNIVERSAL.md).

## Instalación

### Magisk (recomendado, verificado)

1. Descarga `codm_s23_120_v5.1.zip` desde
   [Releases](https://github.com/AJfiles/call-of-duty-mobile-120fps-magisk/releases/latest).
2. Magisk → **Módulos** → **Instalar desde almacenamiento** → elige el ZIP.
3. Reinicia el teléfono.
4. Desbloquea y espera ~15 segundos (los workers necesitan `/data`
   descifrado).

Por consola:

```sh
adb push codm_s23_120_v5.1.zip /sdcard/Download/
adb shell su -c 'magisk --install-module /sdcard/Download/codm_s23_120_v5.1.zip'
adb reboot
```

### KernelSU / APatch

Mismo ZIP: KernelSU → **Módulos** → **Instalar desde almacenamiento**; APatch →
**Módulos** → instalar el ZIP. Reinicia igual. Están implementados con
`root_compat.sh`, pero **no probados en hardware**. En KernelSU, si no hay
`resetprop`, el spoof se deja en `system.prop` y el módulo entra en modo
degradado (prefs y capa siguen funcionando).

### Verificar la instalación

```sh
su -c 'sh /data/adb/modules/codm_s23_120/tools/codmctl.sh status'
su -c 'sh /data/adb/modules/codm_s23_120/tools/codmctl.sh doctor'
```

En Android 14 la app usa `su -M` para ver `/data/data` de CODM; si tu gestor
root no lo soporta, cae a `su` normal y el estado puede aparecer parcial.

La app **CODM Control by AJ 1.5** se instala sola al arrancar y se actualiza
desde el propio módulo. El APK también se publica como asset del release para
quien quiera inspeccionarlo o instalarlo a mano.

## Primeros pasos

1. Abre CODM → **Ajustes → Gráficos** → calidad **ULTRA**. Es el único nivel
   que dio 120 fps en las pruebas; el módulo no puede forzarlo.
2. En **Ajustes → Gráficos → Fotogramas**, activa **120 fps** una vez. Esa
   acción crea el ajuste de cuenta; a partir de ahí el módulo lo mantiene.
3. Cierra el juego por completo (no lo dejes en segundo plano).
4. Ejecuta `doctor` o abre la app: debe decir **`120_LISTO`**. Si dice
   `FALTA_ULTRA`, vuelve al paso 1; si dice `PANEL_60`, el panel no da 120.
5. Juega una partida BR. El lobby seguirá a 60 fps; en partida el overlay
   Perf Z debe marcar ~120.

> **Importante:** insertar las claves con el juego cerrado **no crea** el
> ajuste de 120 de la cuenta. Se probó: el juego las mantuvo ~45 s y las
> reescribió a 90, y al cerrar las eliminó. Por eso `keys_insert` está en `0`
> por defecto y el camino correcto es activar 120 una vez en el menú.

## La app de control

**CODM Control by AJ 1.5** (`versionCode 10`) viaja dentro del módulo:

- Estado del módulo, del perfil, de Perf Z y del doctor en una sola pantalla.
- Interruptores de perfil, Perf Z y notificación.
- **Abrir / cerrar / reintentar CODM** resolviendo el componente real y
  confirmando el proceso (no se declara éxito sin `pidof`).
- **Diagnóstico 120** y **reaplicar 120** con el juego cerrado.
- **Cuenta activa** y aviso de ambigüedad.
- **Presets GFX** (bajo/equilibrado/alto/nativo) con resaltado real del preset
  aplicado y aviso de que CODM puede reescribirlos.
- **Visor de logs** con copia al portapapeles.
- **Restaurar todo y dejar stock**, con elección entre desactivar y eliminar.
- **Baldosa QS** y una única sesión root por arranque para que Magisk muestre
  su aviso una sola vez.

No pide INTERNET ni añade permisos de red. Con el módulo inactivo muestra
«MODULO INACTIVO» y deshabilita los controles que no pueden actuar.

## Configuración

Archivo `module/config` dentro del módulo (se lee en cada arranque):

| Clave | Valores | Por defecto | Qué hace |
| --- | --- | --- | --- |
| `spoof` | `auto` / `compat` / `on` / `off` | `auto` | `auto`: perfil completo solo en dm3q. `compat`: solo modelo NX789J en cualquier equipo. `on`: perfil completo en cualquier equipo (bajo tu riesgo) |
| `layer` | `auto` / `on` / `off` | `auto` | Capa Vulkan Adreno 830; `auto` solo en dm3q |
| `fpslevel` | `0` / `1` | `1` | Intenta ULTRA (`FPSLevel=5`) con el juego cerrado; el juego puede reescribirlo |
| `apply_all` | `0` / `1` | `0` | `1`: aplicar a todas las cuentas del XML (opt-in) |
| `account_mode` | `auto` / `confirmed` / `active` / `all` | `auto` | `auto` sigue la cuenta activa; `confirmed` exige confirmación; `active` exige leerla; `all` solo con `apply_all=1` |
| `keys_insert` | `0` / `1` | `0` | Experimental: inserta `1/120` si la cuenta no las tiene; el juego puede revertirlas a 90 |
| `gfx_universal` | `0` / `1` | `0` | Permite los presets GFX de S23 en otros equipos (bajo tu riesgo) |

Los paquetes extra se pueden declarar a mano en `game.packages` o con la
variable `CODM_PKGS`.

## Desactivar, restaurar y desinstalar

Desde la app: **Restaurar todo y dejar stock** ofrece dos caminos, ambos con
confirmación y reinicio:

1. **Desactivar módulo**: restaura prefs, GFX, Perf Z, GameManager, capa y
   props, y deja el módulo instalado pero apagado. La app queda en «MODULO
   INACTIVO»; se puede reactivar en el gestor root.
2. **Eliminar módulo y esta app**: restaura igual, borra el módulo, desinstala
   la app con sus datos y reinicia mediante un worker diferido en
   `/data/local/tmp/codm_deferred`.

Alternativa manual:

```sh
su -c 'sh /data/adb/modules/codm_s23_120/restore.sh'
# después: desactivar en Magisk/KernelSU/APatch y reiniciar
```

Tras restaurar, las prefs vuelven al original guardado por cuenta (en la unidad
de prueba, `0/90`), el GFX a su valor previo y Perf Z a su visibilidad original.
El ciclo desactivar → stock → reactivar → 120 está verificado en hardware, igual
que eliminar → stock → reinstalar.

## Pruebas y evidencia

| Prueba | Resultado | Evidencia |
| --- | --- | --- |
| Partida BR real (v5.0) | 119,84 fps medidos con el overlay; 23.271 frames, 0 dropped, 0 jank en la capa de CODM, 99,08 % a 8 ms | [timestats_br.txt](docs/evidencia/timestats_br.txt) |
| G1–G4: claves gráficas | `FPSLevel=5` es el único nivel que dio 120; API, Vulkan y bloom no controlan el framerate y el juego los reescribe | [gfx_keys_test.md](docs/gfx_keys_test.md) |
| Inserción local de claves (negativa) | El juego mantuvo `1/120` ~45 s, la reescribió a 90 y eliminó las claves al cerrar; no crea el ajuste de cuenta | [docs/UNIVERSAL.md](docs/UNIVERSAL.md) |
| Persistencia de originales (v4.0 → v4.1) | El original `0/90` sobrevive a la actualización del módulo y el ciclo restore/apply no lo pierde | [v41_persistencia.txt](docs/evidencia/v41_persistencia.txt) |
| Cuenta-agnóstico (v5) | Seis escenarios sintéticos (activa, cambio, confirmada, ambigua, única, `apply_all`) pasan sin caer a «todas»; verificado en hardware con una cuenta | [docs/UNIVERSAL.md](docs/UNIVERSAL.md) |
| Arranque en frío v5.1 | v5.1/15, 5 workers, `prefs=1/120`, `prefs.orig=0/90`, `doctor=120_LISTO`, app 1.5/10 | [status_v5.1_reboot.txt](docs/evidencia/status_v5.1_reboot.txt) |
| Desactivar / eliminar | Stock real tras reiniciar; la app queda inactiva al desactivar y se borra con sus datos al eliminar | [docs/ESTADO_CODM.md](docs/ESTADO_CODM.md) |

Los informes completos, con lo verificado y lo pendiente separados, están en
[docs/](docs/README.md). Las capturas y volcados crudos no se publican porque
contienen datos personales.

## Límites honestos

- **Requiere root.** Sin root no hay spoof pre-zygote, ni XML montado, ni capa
  en el proceso del juego.
- **El módulo no puede forzar `FPSLevel=5`** ni el API gráfico: si el juego
  reescribe el ajuste, el doctor avisa y hay que activarlo en el menú.
- **El 120 depende del panel y de la GPU.** Un panel de 90 Hz da 90; uno de
  60 Hz no da 120. El doctor lo detecta.
- **La copia de la capa en el juego** existe solo durante el arranque del
  proceso y se elimina en cuanto Vulkan la mapea.
- **El lobby va a 60 fps** por diseño del juego; la medición de 120 es en
  partida BR.
- El A/B de fluidez se hizo con el jugador quieto en una partida real; no cubre
  combate intenso con humo y explosiones. El overlay Perf Z permite verlo en
  vivo.
- El perfil no eleva los límites térmicos de Samsung: si el teléfono se
  calienta, el sistema puede bajar la pantalla según su tabla térmica.
- **Una actualización de CODM puede romper el mecanismo**: si cambia el nombre
  o el significado de las claves, el doctor lo detectará y habrá que adaptarlo.
- El GFX del juego no persiste: CODM reescribe las claves al abrir y la app lo
  muestra como «No persistió». No se inventan ajustes que el juego no tenga.

## Pendiente de hardware

- Otras marcas (Xiaomi, OnePlus, RedMagic, ASUS, Motorola…) y otras capas
  (HyperOS, ColorOS, OxygenOS).
- Android 15/16, One UI 7/8.
- CODM Garena, Tencent CN/KR y VNG.
- KernelSU y APatch en un equipo real.
- Validación del 120 en partida tras los cambios de la v4/v5 (la última
  medición de 119,84 fps es de la v5.0 en el S23 Ultra).
- Pass-through con cargador PD/PPS de 25 W o más.
- HUD de BR al 50 % de opacidad: es manual, desde el editor del juego; el
  estudio y los respaldos están en [docs/HUD_BR_50.md](docs/HUD_BR_50.md).

## Riesgos, ban y legalidad

- **Modificar la identidad del dispositivo y las preferencias del juego puede
  violar los términos de servicio de CODM.** Existe riesgo de sanción, incluido
  el ban permanente de la cuenta. **Usa una cuenta prescindible.**
- No hay estadística oficial de baneos por este tipo de módulo. La estimación
  subjetiva del autor está en
  [INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md](docs/INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md),
  con sus límites.
- El proyecto **no vende, no monetiza y no incluye cheats**. No es un bypass de
  anticheat ni una herramienta para obtener ventajas competitivas.
- No está afiliado a Activision, Tencent, TiMi, Samsung ni a los autores de los
  módulos citados.
- Instalar y usar el módulo es responsabilidad de quien lo hace. El software se
  ofrece **sin garantía**, bajo licencia MIT.

## Módulos similares y créditos

Este proyecto estudió cuatro referencias públicas y adoptó lo que las hace
universales, sin copiar su código:

| Proyecto | Qué aporta | Qué se adoptó |
| --- | --- | --- |
| [ULTRA-EXTREME-UNLOCKER](https://github.com/shakilxt/ULTRA-EXTREME-UNLOCKER) | Spoof de modelo por `system.prop` (NX789J) | El perfil `compat` de solo modelo, reversible y con doctor |
| [Flame-Unlocker](https://github.com/not-GIANT/Flame-Unlocker) | Mismo patrón para 165 fps (CPH2747) | La idea de no depender de binarios ni hooks |
| [GameUnlocker](https://github.com/yadavnikhil03/GameUnlocker) | Spoof por proceso con Zygisk, routing por app | El spoof solo como opción, nunca como requisito |
| [AlexGfxCodm](https://github.com/thelordalex/AlexGfxCodm) | Ajustes gráficos por script con root | La simplicidad de no empaquetar un daemon |

Lo que este módulo añade: descubrimiento de paquetes por huella, cuenta activa
automática, originales por paquete/UID, `restore.sh` con código de retorno,
veredicto `doctor`, worker que reaplica al cerrar el juego, app de control y
estado persistente fuera del módulo. El análisis completo está en
[docs/UNIVERSAL.md](docs/UNIVERSAL.md).

Gracias también a la comunidad de Magisk/KernelSU/APatch por la documentación
pública de sus APIs.

## Estructura del repositorio

```
module/        Módulo v5.1 completo (lo que va dentro del ZIP)
  app/         CODMControl.apk 1.5/10 que el módulo instala
  files/       Scripts POSIX: detección, prefs, doctor, workers, restauración
  system/      XML de audio de dm3q
app/           Código fuente Java de la app, recursos y build.sh
layer/         Código fuente de la capa Vulkan y el .so compilado
docs/          Informes técnicos y evidencia seleccionada
tools/         timestats_diff.py para analizar SurfaceFlinger TimeStats
```

Artefactos del release:

| Archivo | Versión | SHA-256 |
| --- | --- | --- |
| `codm_s23_120_v5.1.zip` | módulo v5.1 / 15 | `acc1d51cb90a0b8cec516d6b8720ad0e80bdddaaa5d4c4949ffbda380d2393ce` |
| `CODMControl-1.5.apk` | app 1.5 / 10 | `91b3f1c1da707ef1594974b9d92f6e83d8cf5aa3654ca70d26e426831cdafed1` |

El ZIP se verifica en frío en el S23 Ultra antes de publicarse: los hashes de
los archivos desplegados coinciden con los del ZIP y el doctor da `120_LISTO`.

## Licencia

[MIT](LICENSE) © 2026 AJ (AJfiles).

El módulo se distribuye **tal cual**, sin garantía de funcionamiento en equipos
no verificados. Si lo usas, lo haces bajo tu cuenta y tu riesgo.
