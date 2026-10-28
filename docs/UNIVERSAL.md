# CODM 120 FPS universal — investigación y diseño v5

Fecha: 27–28/10/2026. Alcance: hacer que el módulo `codm_s23_120` funcione en
cualquier teléfono, marca y versión de Android, con garantías verificables
aunque no se pueda probar en hardware ese equipo.

## 1. Qué está verificado y qué no

Verificado en SM-S918B (dm3q), Android 14, Magisk 30.7:

| Hecho | Evidencia |
| --- | --- |
| 120 fps reales en BR con `CODM_<uid>_iMSDK_King_EnableFramerateCustomize=1` y `FramerateCustomizeValue=120` | `logs/br_timestats.txt`: 119,84 fps, 0 jank |
| `FPSLevel=5` (ULTRA) es el único nivel que dio 120; MUY ALTA (4) dio 40 | `evidencia/v3.5_gfx_tests/`, `gfx_keys_test.md` |
| `kUserGraphicApi`, `EnableVulkan` y `EnableBloom_Br_2Show` no controlan la API ni el framerate | `gfx_keys_test.md` (G2–G4) |
| CODM reescribe las claves de menú (FPSLevel, API, bloom) al arrancar; las de framerate por cuenta sobreviven | G1–G4, readback del XML |
| La cuenta se identifica por `lastUserId.xml` (clave `4e42c67f78`) y las claves viven en el namespace `CODM_<uid>_…` | `files/account.sh`, XML real |
| El prefijo de paquete global es `com.activision.callofduty.shooter` | dispositivo |
| No hay lista de modelos en `global-metadata.dat` (NX789J/SM-S918B/REDMAGIC ausentes) | `strings_probe.sh` |
| `su` de PATH puede ser el stub OEM de Samsung y devolver uid 2000 | diagnóstico en dispositivo; root real en `/debug_ramdisk/su` |
| v4 arranca en frío: post-fs-data spoofea solo en dm3q, el servicio lanza los 5 workers, `doctor` pasa a `120_LISTO` tras el desbloqueo | `evidencia/v4_universal/status_after_reboot.txt` |
| v4 abre CODM por componente resuelto (`game launch`), arma la capa y la confirma en el proceso; al cerrar, limpia y reaplica | `logs/watch.log`, `evidencia/v4_universal/codm_launched.png` |
| App 1.5 (`versionCode 10`) instalada por el módulo y mostrando estado v4 (paquete, doctor, app v10) | `evidencia/v4_universal/app_15_status.png` |
| v4.1 conserva los originales al actualizar el módulo: flash v4.0→v4.1 + reinicio mantuvo `prefs.orig=0/90` y el ciclo restore→0/90 / apply→1/120 no perdió el original | `evidencia/v4_universal/v41_persistencia.txt`, `app_15_v41_status.png` |
| v5.0 arranca en frío con Magisk, PIN del dispositivo, 5 workers, `prefs=1/120`, `prefs.orig=0/90` y `doctor=120_LISTO` | `evidencia/v5_universal/status_restored.txt` |
| `account_mode=auto` sigue y registra la cuenta activa; los seis escenarios sintéticos (activa, cambio, confirmada, ambigua, única, apply_all) pasan sin caer a «todas» | prueba unitaria `codm_v5_unit.sh`; estado en hardware con la cuenta de prueba |
| La inserción local de `1/120` **no** crea el ajuste de cuenta: el juego la mantuvo ~45 s y la reescribió a 90; al cerrar, el juego eliminó las claves | `evidencia/v5_universal/codm_v5_ev/keys_lobby2.txt`, captura `game_lobby2.png` |
| Tras reparar un duplicado por carrera con el worker, el XML queda con una sola pareja 1/120 y el original 0/90 | `evidencia/v5_universal/status_restored.txt`, `repair_prefs_<uid>.sh` |

No verificado en hardware:

- Que las claves de framerate por sí solas den 120 **sin** spoof ni capa Vulkan.
- Que el mecanismo funcione en Garena, Tencent CN/KR o Vietnam.
- KernelSU/APatch en hardware, Android 15/16, One UI 7/8, HyperOS, ColorOS, etc.
- Que una cuenta nueva sin el ajuste de 120 activado en el juego quede en 120
  solo por insertar las claves (el experimento v5 dice que no).

## 2. Qué es universal por construcción

1. **El mecanismo de 120 es una preferencia de Unity.** El juego guarda el
   framerate personalizado por cuenta en `shared_prefs/*.v2.playerprefs.xml`.
   No depende de marca, GPU ni versión de Android: solo de que el juego cree
   esas claves (las crea su propio menú de gráficos).
2. **El namespace de cuenta es estable.** `CODM_<uid>_iMSDK_King_*` aparece en
   todas las versiones conocidas del juego, en global y regionales.
3. **La detección de cuenta no depende del paquete.** `lastUserId.xml` está en
   la carpeta de datos del juego; la clave `4e42c67f78` es del framework, no del
   modelo.
4. **La escritura es XML estándar.** Se puede editar con `sed` sobre el mismo
   inodo conservando dueño, modo y contexto SELinux, sin parsear/reescribir el
   documento completo (menos riesgo de corrupción).

## 3. Qué es dependiente del equipo

| Dependencia | Consecuencia | Trato en v4 |
| --- | --- | --- |
| Panel de 60 Hz | 120 fps imposible | `doctor` lo declara; el módulo no promete lo imposible |
| Panel de 90/120/144 Hz | el juego debe pedir esa tasa | se aplican las claves; el juego decide el techo real |
| GPU no Adreno / no Vulkan | la capa Adreno 830 puede romper o no cargar | capa **opt-in** fuera de dm3q |
| ABI arm32 | la capa arm64 no carga | se omite la capa y se conservan las prefs |
| Audio Samsung (`audio_effects_sec.xml`) | solo aplica a Samsung | ya está limitado a dm3q |
| GameManager (`cmd game`) | perfil de fluidez no disponible | `perf_mode.sh` ya degrada sin error |
| Perf Z | solo Samsung | se ignora si no está instalado |
| GFX presets | calibrados para 2316×1080 | se limitan a dm3q; en otros equipos se usan los ajustes del juego |

## 4. Paquetes regionales

Confirmados por Google Play / tiendas oficiales:

| Región | Paquete |
| --- | --- |
| Global (América, Europa, Japón, Corea del Sur en la práctica) | `com.activision.callofduty.shooter` |
| Garena (SEA, Taiwán, Hong Kong) | `com.garena.game.codm` |
| China (Tencent) | `com.tencent.tmgp.cod` |
| Corea (Tencent) | `com.tencent.tmgp.kr.codm` |
| Vietnam (VNG) | `com.vng.codmvn` |

Fuentes: ficha de Google Play de Garena
(<https://play.google.com/store/apps/details?id=com.garena.game.codm>), ficha de
Tencent en APKMirror/应用宝 (`com.tencent.tmgp.cod`), y lista de paquetes del
módulo SFPS que incluye `com.tencent.tmgp.kr.codm`.

**La lista no es la garantía.** v4 descubre el juego por huella:

1. Paquetes conocidos instalados (`pm list packages`).
2. Cualquier paquete cuyo `shared_prefs/*.playerprefs*.xml` contenga
   `iMSDK_King_FramerateCustomizeValue` (huella exclusiva de CODM).
3. Cualquier paquete declarado por el usuario en `$MODDIR/game.packages`
   (una línea por paquete) o en la variable `CODM_PKGS`.

Con eso, un cambio de ID regional o una versión futura no rompe el módulo.

## 5. Resolución de root

Diagnóstico real: en Samsung, `su` de PATH resolvió a `/product/bin/su` (stub
OEM) y `id -u` devolvió 2000. El root real de Magisk 30.7 está en
`/debug_ramdisk/su`. v4:

- En scripts de arranque no hace falta: Magisk/KSU/APatch ya ejecutan como root.
- En la app, `RootShell` prueba rutas absolutas antes que PATH:
  `/debug_ramdisk/su`, `/data/adb/ksu/bin/su`, `/data/adb/ap/bin/su`,
  `/system/bin/su`, `/system/xbin/su`, `/sbin/su`, y por último `su`.
- Cada variante se valida con `id -u` = 0 antes de aceptarla. Si el stub
  responde 2000, se descarta y se pasa a la siguiente.

## 6. Diseño v4

### 6.1 Perfiles

`$MODDIR/config` (clave=valor), leído en cada arranque:

```
spoof=auto      # auto: dm3q sí, resto no | compat: solo modelo NX789J | on: full | off
layer=auto      # auto: dm3q sí, resto no | on | off
fpslevel=1      # intentar FPSLevel=5 (ULTRA) con el juego cerrado
apply_all=0     # 0: cuenta activa; 1: todas las cuentas del XML (opt-in)
account_mode=auto  # auto|confirmed|active|all; auto sigue la activa y NUNCA cae a todas
keys_insert=0   # 1: insertar 1/120 si faltan (experimental; el juego puede revertir)
gfx_universal=0 # 1: permitir presets GFX fuera de dm3q (no calibrados)
```

`auto` conserva intacto el comportamiento verificado del S23 Ultra y evita
tocar identidad/GPU en equipos desconocidos. El usuario puede forzar
`spoof=on`/`layer=on` si su equipo lo necesita; el doctor avisa del riesgo.

### 6.2 Prefs

- Descubre paquetes y XML por huella.
- Elige la cuenta activa (`lastUserId.xml`) y la registra sola. Si hay varias
  cuentas y no puede leer la activa, **no escribe**: el doctor devuelve
  `CUENTA_AMBIGUA`. Nunca aplica a «todas» por descarte; `apply_all=1` y
  `account_mode=all` son opt-in explícitos.
- Guarda originales por paquete y UID en `$STATE_DIR/prefs.orig.<pkg>.<uid>`;
  conserva compatibilidad con `prefs.orig.<uid>` de v3.
- `FPSLevel=5` se intenta una vez y se registra; si el juego lo reescribe, el
  doctor lo reporta como `fpslevel.menu` y la app guía a poner ULTRA.
- Nunca escribe con el juego abierto. Reaplica al detectar el cierre.
- `keys_insert=0` por defecto. Con `keys_insert=1` el módulo puede crear las
  claves que falten, pero el experimento v5 demostró que el juego las reescribe
  a 90 si el ajuste no está activado en la cuenta; no sustituye al menú.

### 6.3 Aplicación y restauración

- `files/game_prefs.sh apply|restore|status` sustituye a los dos scripts v3,
  que se conservan como envoltorios para no romper llamadas existentes.
- `restore.sh` restaura **todos** los paquetes/UID modificados, GFX (solo dm3q),
  Perf Z, GameManager, capa y props.
- Toda escritura se verifica leyendo de nuevo; si falla, se revierte con la
  copia y se registra.

### 6.4 Diagnóstico

`files/doctor.sh` (dentro de `codmctl.sh doctor`) informa sin escribir:

- root/gestor, paquete(s) detectados, XML legible, cuentas y cuenta activa;
- `FPSLevel` actual y si el juego lo reescribió;
- claves de framerate por cuenta y valores;
- panel: resolución y refresco máximo (`dumpsys display`);
- capa/spoof: perfil, estado, mapeo;
- veredicto: `120_LISTO`, `FALTA_ULTRA`, `FALTA_120`, `PANEL_90`, `PANEL_60`,
  `SIN_CUENTA`, `SIN_PREFS`, `SIN_JUEGO`, `SIN_ROOT`, `ESPERA_DESBLOQUEO`.

En el arranque, `/data` aún está cifrado: el servicio deja `ESPERA_DESBLOQUEO` y
el worker de prefs vuelve a ejecutar el doctor en el primer ciclo tras el
desbloqueo, para que la app no muestre un falso `SIN_JUEGO`.

### 6.5 App

App 1.5 (`versionCode 10`):

- `RootShell` con rutas absolutas y validación de uid.
- «Abrir CODM» usa `codmctl game launch`, que resuelve el paquete real; deja de
  depender de `com.activision.callofduty.shooter`.
- El estado sigue leyendo las mismas claves de `codmctl status` (contrato v3
  intacto) y muestra `game.package`/`doctor` cuando están disponibles.

### 6.6 Persistencia entre actualizaciones

El gestor root reemplaza el directorio del módulo al actualizar; `run/` es
efímero. Por eso los registros de reversión y los ajustes viven en
`/data/adb/codm_s23_120_state` (`files/state_env.sh`): `prefs.orig.*`,
`fpslevel.orig.*`, `gfx.orig`, `gfx.state`, `perfz.orig`, `perf.state`,
`orig_props.txt`, `account.confirmed` y `perf_state`. La primera carga adopta
los ficheros de `run/` y `perf_state` de v3/v4.0 sin pisar los persistidos.
`restore.sh` y `disable_cleanup.sh` eliminan ese directorio solo cuando no queda
ningún registro pendiente, y devuelven error si una restauración falla.
**Ciclo completo verificado (SM-S918B):** `restore.sh` devolvió RC=0 y dejó el
equipo stock (prefs 0/90, props, capa y Perf Z fuera; `STATE_DIR` eliminado); al
reiniciar, el worker capturó como original el 0/90 real y reaplicó 1/120, con
`doctor=120_LISTO`, cuenta de prueba auto-confirmada y la capa mapeada al abrir CODM
(`evidencia/v4_universal/v41_restore_cycle.txt`,
`v41_cycle_after_restore.txt`).

## 7. Garantías honestas

Lo que el módulo **sí** garantiza en cualquier equipo con root:

1. No escribe con el juego abierto y conserva el inodo/permisos/SELinux.
2. Guarda los valores originales antes de cambiar, los conserva fuera del
   directorio del módulo (sobreviven a actualizaciones) y los restaura.
3. Es idempotente: repetir `apply` no duplica ni corrompe.
4. No toca cuentas que no correspondan (activa por defecto; `apply_all` opt-in).
5. No toca identidad, GPU, audio ni rendimiento fuera de su perfil y solo si el
   perfil está activo.
6. Si el equipo no puede 120 (panel 60 Hz, ABI, juego no instalado), lo dice y
   no finge éxito.
7. Si el juego reescribe una clave, lo reporta en vez de declarar victoria.
8. No inserta claves por defecto; si el usuario activa `keys_insert=1`, avisa de
   que es experimental y puede ser revertido por el juego.

### 7.1 Porcentaje de teléfonos root

La cifra se separa en dos, porque «funciona» significa cosas distintas:

| Alcance | Estimación | Base |
| --- | --- | --- |
| Instalación y gestión del módulo | ≈ **100 %** de teléfonos root Android 11+ con CODM instalado | scripts POSIX, Magisk/KernelSU/APatch, descubrimiento por huella, sin binarios propios salvo la capa arm64 opt-in |
| 120 fps reales | ≈ **40 %** (rango conservador 35–55 %) | requiere panel ≥120 Hz; 37,4 % del mercado móvil 2026 según scoop.market.us (<https://scoop.market.us/android-phones-statistics/>), con sesgo hacia gama alta donde se concentra el root |

Desglose por panel: ≥120 Hz → 120 posible (si el juego lo ofrece y la GPU
sostiene); 90 Hz → máximo 90; 60 Hz → no. La cifra de 120 no es una promesa por
marca: solo SM-S918B/Magisk 30.7/Android 14 está verificado en hardware.

Lo que **no** puede garantizar:

- 120 fps en un panel de 60 Hz, o si el juego limita por GPU/térmica.
- Que el servidor no considere el cambio una modificación (riesgo aceptado por
  el usuario; cuenta prescindible).
- Que una versión futura del juego cambie el formato del XML o el namespace de
  cuenta (se detecta con `doctor` y se puede desactivar/restaurar).
- Funcionamiento sin root.

## 8. Matriz de compatibilidad

| Plataforma | Estado | Nota |
| --- | --- | --- |
| SM-S918B / Android 14 / Magisk 30.7 | **verificado v5** | arranque en frío, workers, capa, launch, app 1.5, 120 prefs, cuenta activa auto, reparación de duplicados |
| Otras Samsung con panel ≥120 Hz | implementado, sin probar | perfil auto sin spoof; audio solo dm3q |
| Pixel / Motorola / Nothing / Sony (AOSP-ish) | implementado, sin probar | prefs + GameManager si existe |
| Xiaomi HyperOS / OPPO ColorOS / vivo | implementado, sin probar | `su` y permisos de `/data/data` varían; doctor lo detecta |
| Garena / Tencent CN/KR / VNG | implementado, sin probar | descubrimiento por huella, no por nombre |
| KernelSU / APatch | implementado, sin probar | sin resetprop no hay spoof; prefs sí |
| Android 15/16 | implementado, sin probar | `dumpsys display` y `cmd game` con fallbacks |
| Panel 60 Hz / ABI arm32 / sin root | **no soportado para 120** | se declara el límite, no se rompe nada |

## 9. Protocolo de prueba en un equipo nuevo

1. Instalar módulo, reiniciar, abrir la app → `doctor`.
2. Si `SIN_CUENTA`: abrir CODM, iniciar sesión, cerrar; el worker aplica.
3. Si `FALTA_ULTRA`: poner gráficos en ULTRA una vez (el juego lo exige).
4. Si `FALTA_CLAVES`: abrir Ajustes de CODM y activar 120 (Personalizado) una
   vez; el módulo lo mantiene con el juego cerrado. No usar `keys_insert=1` como
   sustituto: el juego puede devolver 90.
5. `codmctl doctor` debe decir `120_LISTO`; `prefs.framerate=120`.
6. Partida BR: medir con `timestats` o con el overlay del sistema; no se
   declara 120 sin medición en ese equipo.
7. Desactivar módulo → `restore.sh` → verificar valores originales.

## 10. Riesgos

- Cuenta prescindible: aceptado explícitamente por el usuario; no se añade
  evasión ni nada de combate.
- Spoof fuera de dm3q es opt-in y puede romper servicios; el perfil `auto` no lo
  aplica.
- La capa Vulkan copiada al directorio del juego se borra al mapearse; si el
  juego se actualiza, se reinstala en el siguiente arranque de UI.

## 11. Módulos similares: qué los hace universales y qué adoptamos

Se descargaron y leyeron cuatro referencias (clones en `modules_ref/`):

| Proyecto | Tipo | Mecanismo | Universal porque | Límite |
| --- | --- | --- | --- | --- |
| [ULTRA-EXTREME-UNLOCKER](https://github.com/shakilxt/ULTRA-EXTREME-UNLOCKER) | Magisk, `system.prop` | spoofea `ro.product.model` y las variantes `odm/system/vendor/system_ext` a `NX789J` (RedMagic 10 Pro) | no ejecuta código: el gestor root aplica las props en cada arranque; funciona en cualquier ARM con Magisk | no elige cuenta ni restaura; el modelo falso puede romper apps; sin diagnóstico |
| [Flame-Unlocker](https://github.com/not-GIANT/Flame-Unlocker) | Magisk, `system.prop` | idéntico patrón con `CPH2747` (OnePlus 15 Global) para 165 fps | misma ventaja: cero binarios, cero hooks | igual de ciego: sin reversión, sin veredicto, sin cuentas |
| [GameUnlocker](https://github.com/yadavnikhil03/GameUnlocker) | Zygisk (C++/Java) | daemon IPC `gu_controller`, spoof de campos `android.os.Build` en `preAppSpecialize`, PLT hook de `__system_property_get` con bytehook, spoof GPU (`GLES20.glGetString`), routing por app, WebUI | spoof por proceso: solo afecta al juego elegido; Android 9+, Magisk/KSU/APatch; perfiles por juego | exige Zygisk independiente (ZygiskNext/ReZygisk/NeoZygisk; el de Magisk no vale), binarios nativos, y no toca las prefs de CODM: desbloquea el menú, no garantiza 120 sostenido |
| [AlexGfxCodm](https://github.com/thelordalex/AlexGfxCodm) | script shell | `setprop`/permisos y ajustes gráficos vía MT Manager/Brevent | sin módulo: funciona en cualquier Android con root | no persiste entre reinicios, no restaura, no verifica |

**Qué comparten los que funcionan en cualquier teléfono:** ninguno depende del
modelo real ni de una cuenta concreta. Los dos primeros delegan en el gestor
root (`system.prop` se aplica antes de que arranque Android); el tercero
intercepta la identidad solo dentro del proceso del juego. En los tres casos el
«desbloqueo» es una **mentira de identidad**: el juego cree estar en un móvil de
gama alta con panel rápido y habilita opciones que ya existían. Ninguno crea el
ajuste de 120 fps de una cuenta: eso lo sigue escribiendo el menú del juego.

**Qué adoptamos en v5:**

1. **Descubrimiento sin nombres**: paquetes por huella de PlayerPrefs y cuenta
   activa por `lastUserId.xml`, en vez de listas de modelos o paquetes.
2. **Perfil `compat`**: spoof de modelo solo (`NX789J`), sin GPU/audio/Perf Z,
   como los módulos de `system.prop` pero reversible y con `doctor`.
3. **Spoof Zygisk solo como opción, no como requisito**: la capa Vulkan y el
   spoof pre-zygote de dm3q se mantienen; en otros equipos el módulo funciona
   con prefs + GameManager sin necesidad de Zygisk independiente.
4. **Lo que ellos no tienen**: originales por paquete/UID, `restore.sh` con
   RC, veredicto `doctor`, worker que reaplica al cerrar el juego, app de
   control y estado persistente fuera del módulo.

**Qué rechazamos:** depender de ZygiskNext/ReZygisk (no está en todos los
roots), hooks de propiedades en el proceso del juego (superficie de anticheat y
de crashes), y `system.prop` a secas (no restaura y miente si el panel es de
60 Hz).
