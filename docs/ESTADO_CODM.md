# Estado — S23 Ultra / Call of Duty Mobile (octubre 2026)

Documento de traspaso del trabajo de CODM en el S23 Ultra. Complementa `../ESTADO.md` (navfloat/CPH2737). El informe completo de esta fase está en `INFORME_CODM_120FPS.md`.

> **Actualización v5.0 (28/10/2026):** módulo **v5.0** (`versionCode 14`), app
> 1.5/10 sin cambios. `account_mode=auto` sigue y registra la cuenta activa; con
> varias cuentas y sin poder leer la activa no escribe (`CUENTA_AMBIGUA`), nunca
> aplica a todas por descarte. `spoof=compat` (solo modelo NX789J) para equipos
> no listados y `system.prop` en KernelSU. **Verificado en frío en
> SM-S918B/Magisk 30.7:** zip `build/codm_s23_120_v5.0.zip` SHA-256
> `416a00a5e629a623d22584cd1bc4ffc3754f8ba145c993e24537187927304c9f`,
> reinicio + PIN del dispositivo, 5 workers, `prefs=1/120`, `prefs.orig=0/90`,
> `keys.insert=0`, `doctor=120_LISTO`, app 1.5 instalada
> (`evidencia/v5_universal/status_after_v5_reboot.txt`). **Inserción de claves:
> negativa**; el juego revirtió 120→90 y borró las claves al cerrar, así que
> `keys_insert=0` por defecto y la ruta es activar 120 una vez en el menú.
> **Porcentaje:** instalación/gestión ≈100 % de root Android 11+ con CODM;
> 120 real ≈40 % (panel ≥120 Hz; 37,4 % del mercado 2026; rango 35–55 %).
> Módulos similares analizados y qué se adoptó/rechazó:
> `research/codm_config/UNIVERSAL.md` §11.
> Solo SM-S918B verificado; otras marcas, A15/16, KSU/APatch y regionales siguen
> pendientes de hardware. El HUD de BR al 50 % queda a cargo del usuario desde el
> editor del juego (opacidad por elemento; los ficheros son binarios cifrados),
> fuera de la entrega del módulo.

> **Actualización v4.1 (27/10/2026):** módulo **v4.1** (`versionCode 13`), app
> 1.5/10 sin cambios. El estado necesario para revertir y los ajustes
> (`prefs.orig`, `fpslevel.orig`, `gfx.orig/state`, `perfz.orig`, `perf.state`,
> `orig_props.txt`, `account.confirmed`, `perf_state`) viven ahora en
> `/data/adb/codm_s23_120_state` (`files/state_env.sh`), fuera del directorio
> que el gestor root reemplaza al actualizar. **Verificado en hardware:** flash
> v4.0→v4.1 + reinicio conservó `prefs.orig=0/90`; restore→0/90 y apply→1/120
> sin perder el original (`evidencia/v4_universal/v41_persistencia.txt`,
> `app_15_v41_status.png`). **Ciclo completo verificado:** `restore.sh` (RC=0)
> dejó stock (prefs 0/90, props, capa/Perf Z, `STATE_DIR` borrado) y el reinicio
> posterior recapturó el original real 0/90 y reaplicó 1/120 con
> `doctor=120_LISTO`, workers y capa mapeada al abrir CODM
> (`v41_restore_cycle.txt`, `v41_cycle_after_restore.txt`,
> `app_15_v41_after_restore.png`). **G1–G4 cerradas:** `FPSLevel` (menú del
> juego) es obligatorio en ULTRA; `kUserGraphicApi` y `EnableBloom_Br_2Show` los
> reescribe el juego; `EnableVulkan=0` no cambia el API. Detalle en
> `research/codm_config/gfx_keys_test.md`. Sigue pendiente el HUD de BR al 50%
> (editor del juego: opacidad por elemento verificada, sin slider global; los
> ficheros son binarios cifrados) y la matriz multiequipo sin hardware (otras
> marcas, A15/16, KSU/APatch, regionales).

> **Actualización v4.0 (27/10/2026):** la entrega vigente es el módulo **v4.0**
> (`versionCode 12`) con app **CODM Control 1.5** (`versionCode 10`, SHA-256
> `91b3f1c1…cdafed1`). v4 convierte el módulo en multiequipo: descubre CODM
> global/Garena/Tencent/VNG por huella de PlayerPrefs (no por nombre), aplica
> 1/120 por cuenta con originales por paquete/UID, perfiles `auto` que solo
> tocan spoof/capa/audio en dm3q, worker de prefs que reaplica al cerrar el
> juego y doctor con veredicto (`120_LISTO`, `FALTA_ULTRA`, `PANEL_60`…).
> **Verificado en frío en SM-S918B/Magisk 30.7:** arranque con 5 workers,
> `doctor=120_LISTO` tras desbloquear, app 1.5 instalada por el módulo, CODM
> abierto por `game launch` con capa confirmada, cierre limpio y prefs 1/120
> (`evidencia/v4_universal/`). **Pendiente de hardware:** otras marcas,
> Android 15/16, Garena/Tencent/VNG, KernelSU/APatch. Diseño y matriz en
> `research/codm_config/UNIVERSAL.md`. El HUD de BR al 50% sigue pendiente y
> se hará desde el editor del juego (los ficheros de HUD son binarios cifrados).


> **Actualización v3.4 (27/10/2026):** la entrega vigente es el módulo **v3.4**
> (`versionCode 11`) más la app **CODM Control by AJ 1.4** (`versionCode 9`).
> La app abre **una sola sesión root persistente** (`su -M` + shell con marcadores
> privados) por proceso, así que Magisk muestra su aviso **una sola vez por
> arranque** en vez de cada 30 s: verificado con 1 petición `su` en una ventana de
> 150 s mientras el estado refrescaba cada 30 s y los interruptores seguían
> funcionando por la misma sesión. Sin permisos nuevos, sin INTERNET y sin tocar
> notificaciones ni `magisk.db`; si la sesión muere, la siguiente llamada abre una
> nueva (un aviso extra, aceptable). La red se probó con `tc`/`fq_codel` fuera del
> módulo y dio **negativo** (`wlan0` es `mq`, no admite injertar qdisc; sustituir
> la raíz borraría el `clsact` de netd): no se integró nada. Evidencia:
> `evidencia/v3.4/` y `research/net_qdisc/README.md`.
>
> **Actualización v3.3 (26/10/2026):** la entrega vigente es el módulo **v3.3**
> (`versionCode 10`) más la app **CODM Control by AJ 1.3** (`versionCode 8`).
> La app **viaja dentro del módulo** (`app/CODMControl.apk` + `app/version.txt`):
> al instalar el módulo se instala/actualiza sola al arrancar
> (`files/install_app.sh`, `pm install -r`), y al **desinstalar el módulo** se
> quita junto con sus datos mediante un worker diferido
> (`uninstall.sh` copia el árbol a `/data/local/tmp/codm_deferred` y actúa tras
> `sys.boot_completed`, porque Magisk ejecuta `uninstall.sh` antes del desbloqueo).
> Marca de identidad **AJ** en `module.prop`, banner de `customize.sh`, nombre de la
> app y pie de la interfaz. Probado en hardware: instalar módulo → app instalada;
> eliminar módulo → módulo, app y datos ausentes, prefs 0/90. Evidencia:
> `evidencia/v3.3/`.
>
> **Actualización v3.2 (26/10/2026):** la entrega vigente es el módulo **v3.2**
> (`versionCode 9`) más la app `com.aj.codmcontrol` **1.1** (`versionCode 6`).
> La app corrige «Abrir CODM» (visibilidad de paquete + fallback `monkey`),
> muestra interruptores naranja/gris, resalta el preset GFX realmente aplicado,
> deshabilita todos los controles del módulo cuando está inactivo y sustituye
> «Restaurar todo» por un selector con **Desactivar módulo** o **Eliminar módulo
> y esta app**, ambos con aceptar y reinicio. Probado en hardware el ciclo
> completo desactivar→stock→reactivar y eliminar→stock→reinstalar. GFX «Nativo»
> 2316×1080/q3 quedó aplicado y en naranja; solo son prefs del juego. No se
> añadieron opciones de relojes, térmica ni GOS: el A/B mostró que no mejoran
> frames y sí subirían temperatura. Evidencia: `evidencia/v3.2/`.
>
> **Actualización v3.1 (26/10/2026):** anterior entrega, módulo **v3.1**
> (`versionCode 8`) más la app `com.aj.codmcontrol` 1.0. Añade detección de cuenta
> por `lastUserId.xml` con confirmación, soporte declarado para KernelSU/APatch,
> audio acotado a dm3q (en otras marcas no se toca), GFX visual con resultado
> negativo verificado (CODM reescribe al abrir), baldosa QS, notificación de estado
> y logs en la app. Estado verificado tras reinicio, pendientes y matriz Android
> 15/16 / One UI 7/8: `INFORME_MODULO_V3.md`. Las secciones siguientes describen la
> fase v2.4 y siguen siendo válidas como historial de medición y diseño.

## 1. Objetivo y alcance

Objetivo del usuario: máxima fluidez en Battle Royale de CODM; ideal 120 fps; el S23 Ultra está rooteado, pero la solución debía servir también para teléfonos sin root; se autorizó experimentar y tocar datos del juego, con una cuenta nueva y asumiendo riesgo de ban.

Restricción de cuentas: solo se trabajó sobre la cuenta activa (UID de prueba, redactada). Las demás cuentas del dispositivo no se tocaron, incluidos sus `ConfigCache` y `joystick`. (v5.0 es cuenta-agnóstico por diseño: sigue la cuenta activa; la cuenta de prueba es la que se usó para verificar en hardware y las demás siguen intactas.)

## 2. Estado final

| Dato | Valor |
| --- | --- |
| Modelo | SM-S918B (dm3q), Android 14, build S918BXXU8CYB6 |
| Pantalla | 2316×1080, densidad 411, panel de 120 Hz |
| Root | Magisk 30.7 + Zygisk Next + Shamiko |
| CODM | `com.activision.callofduty.shooter` 1.0.57 |
| Entrega | Módulo `codm_s23_120` **v3.4** (`versionCode 11`) en `/data/adb/modules/codm_s23_120` + app **CODM Control by AJ 1.4** (`versionCode 9`), empaquetada dentro del módulo |
| Overlay de FPS | Perf Z `com.samsung.android.perf_z` 4.1.05, visible, verificado a 120 en BR |
| Props tras arranque | De fábrica (`ro.product.model=SM-S918B`, `ro.soc.model=SM8550`); zygote conserva `Build=NX789J` |
| XML de audio | Parcheado por el módulo: `9e9725af…96d1`, 4.583 bytes, sin `volumemonitor_hw` |
| Prefs CODM | Cuenta activa en `EnableFramerateCustomize=1` y `FramerateCustomizeValue=120` |
| GFX 3D | Nativo 2316×1080, Unity 3 (`gfx.preset=nativo`); solo preferencias del juego, la resolución del teléfono no se toca; CODM puede reescribirlas al abrir |
| GameManager / Doze / refresco | Perfil del módulo: asegura `performance` mientras CODM vive y restaura el modo previo al salir; en esta unidad el modo original ya era `performance`, así que el cambio neto es nulo; whitelist vacía, `peak_refresh_rate=null` (no se tocan) |
| Perfil de fluidez | Interruptor `toggle.sh on/off/status` + botón Acción; aplica solo con CODM vivo |
| Juego | Detenido; teléfono cargando por USB |
| Residuos fuera del módulo | Ninguno: las dos prefs de CODM y la visibilidad de Perf Z se aplican y se revierten desde el módulo; auditoría stock verificada el 25/10/2026 |

El desbloqueo de 120 **no depende** de GameManager, whitelist ni refresco: se midió con GameManager en stock. Desde v2.4 el módulo incluye un perfil de fluidez opcional que, solo mientras CODM vive, asegura el modo `performance` de GameManager y lo restaura al salir; no toca whitelist, refresco, relojes ni térmica. v2.4 además arma la capa solo con UI de CODM (ignora servicios en segundo plano), gestiona Perf Z y limpia automáticamente al desactivar. `restore.sh` ya no resetea GameManager, whitelist ni refresco para no alterar ajustes originales. No hay scripts de arranque sueltos.

## 3. Resultados verificados

| Prueba | Resultado | Evidencia |
| --- | --- | --- |
| BR real, calidad baja, en mapa | **119,84 fps** (127 frames, p50 8,31 ms, p95 11,65 ms) | `logs/br_land_latency.txt`, `evidencia/game_landing.png` |
| BR tras pulsar volumen en partida | **119,74 fps**, audio estable, amps On | `logs/br_vol_latency.txt` |
| Estadísticas acumuladas de la partida | 23.271 frames, **0 dropped, 0 jank**, averageFPS 121,3, 99,08 % a 8 ms | `logs/br_timestats.txt` |
| Área previa a la partida | 117,70 fps | `logs/br_prematch_latency.txt` |
| Avión/paracaídas (streaming) | 109,63 fps | `logs/br_drop_latency.txt` |
| Audio del teléfono | Funciona; amplificadores cs35l43 On en reproducción y en partida | `logs/audio_fix.log`, `logs/br_vol_latency.txt` |
| Teclas de volumen | Sin cuelgue; audioserver/HAL con PID estable (3245/3246) | `logs/br_vol_latency.txt`, `logs/br_crash_check.txt` |
| Overlay de FPS (Perf Z) | **120** en pantalla en BR; 100 en avión; 54-60 en lobby | `evidencia/perfz_codm_3.png`, `evidencia/perfz_br_game_1.png`, `evidencia/perfz_br_game_2.png` |
| Desactivar módulo + reiniciar | Stock verificado: XML `e635…1b89`, props Samsung, prefs 0/90, Perf Z oculto, GameManager performance, sin procesos, montajes ni artefactos | `logs/audit_stock_after_disable.txt`, sección 6 |
| Aviso de root (v3.4) | **1** petición `su` de la app en 150 s (antes 51 en el búfer) y un único `su -M` hijo de `com.aj.codmcontrol`; refresco y toggles por la misma sesión; al matar la sesión se abre otra en el siguiente tick | `evidencia/v3.4/logcat_after.txt`, `ps_su.txt`, `kill_recovery.txt` |

**Antes:** CODM quedaba clavado en ~90 fps en BR (89–90 medidos) aunque el panel y Android pidieran 120.
**Ahora:** ~120 fps sostenidos en BR, sin frames perdidos ni jank en la medición acumulada. El lobby sigue a 60 fps por diseño del juego.

La medición de 119,84 fps se hizo a las 20:35, **después** de reactivar el módulo y reiniciar, sin GameManager custom, sin whitelist de batería y con `peak_refresh_rate=null`: el 120 lo sostienen el spoof, la capa Vulkan y las prefs de cuenta.

## 4. Por qué antes eran 90 y ahora 120

CODM decide su límite según la identidad del dispositivo, no solo según Android. La pantalla ya estaba a 120 Hz y GameManager recibía 120, pero el juego presentaba 90.

Intentos descartados o insuficientes:

| Intento | Resultado |
| --- | --- |
| GameManager `--fps 120` solo | 89,7 fps |
| Spoof Lenovo Y700 (props) | 89,9 fps |
| Spoof RedMagic 9 Pro (props) | 88,8 fps |
| Frida hookeando identidad GL | El anticheat mata el proceso (SIGBUS); descartado por inseguro |
| Módulo Zygisk de referencia (GameUnlocker) | Confirma el diseño: falsear GL/Vulkan sin inyectar en el juego |

La combinación implementada:

1. **Spoof NX789J / SM8750 / REDMAGIC 10 Pro antes de zygote** (`post-fs-data.sh`). Zygote cachea `Build` y CODM lo lee como NX789J.
2. **Capa Vulkan propia** (`libVkLayer_codmspoof.so`) que reporta Adreno 830 / SM8750. Se carga solo en el proceso de CODM y se borra del disco en cuanto está mapeada.
3. **Prefs de la cuenta activa** a 1/120, aplicadas por el módulo tras el desbloqueo y restauradas por `restore.sh`.

El orden importa: el HAL de audio necesita inicializar como Samsung, pero zygote debe haber cargado ya el `Build` falso. Por eso el módulo spoofea al inicio, deja arrancar el HAL, devuelve las props a Samsung y reinicia el HAL. La identidad Java de CODM sigue siendo NX789J hasta el siguiente reinicio.

## 5. Audio y volumen

- El spoof NX789J rompía el audio: el HAL de Samsung inicializaba como un modelo desconocido y nunca encendía los amplificadores cs35l43.
- `audio_fix.sh` devuelve las props a Samsung **después** del arranque del HAL, reinicia HAL + audioserver y deja el audio funcionando.
- El cuelgue al pulsar volumen era el efecto `volumemonitor_hw` de `/vendor/etc/audio_effects_sec.xml`, que bloqueaba `EffectHalHidl::command` y abortaba audioserver. El módulo monta un XML sin esa línea.
- Verificado en partida: amplificadores On, PID de audioserver/HAL estables tras subir y bajar volumen, sin crashes de audio.

El único crash del buffer de crash de esa sesión fue `dex2oat64` compilando un split de DeepSeek Chat; no tiene relación con CODM, el audio ni el módulo.

## 5.1 Overlay de FPS (Perf Z)

El monitor de FPS real es el plugin **Perf Z** (`com.samsung.android.perf_z` 4.1.05), no Game Tools ni "Game Sight" (este último es la mira/AimView). Cadena verificada:

1. GOS detecta CODM como juego (`SemGameManager.isGamePackage(...)=true`) y avisa a **Game Lab** (`com.samsung.android.game.gamelab` 5.1.07).
2. Game Lab arranca `PerfZService` y le pasa el paquete del juego (en la prueba tardó ~17 s desde el lanzamiento).
3. Perf Z pide a GOS `perf_data` cada ~2 s; recibe `fps`, `tfps`, `cpu_load` y dibuja una ventana `TYPE_APPLICATION_OVERLAY` (tipo 2038) con FPS y CPU.

Bloqueo encontrado: la preferencia `visibility` estaba en `1` (HIDE) en `/data/data/com.samsung.android.perf_z/shared_prefs/com.samsung.android.perf_z_preferences.xml`. El servicio arrancaba y la ventana existía, pero quedaba `GONE` (`mViewVisibility=0x8`, sin superficie). Se puso en `0` (SHOW) conservando propietario `10352:10352` y modo `660`. El appop `SYSTEM_ALERT_WINDOW` ya estaba en `allow`.

También fue necesario el arreglo de GOS de esta sesión: `App.onCreate` mata el proceso si `Build.MANUFACTURER` no es `samsung`; el spoof ahora mantiene `manufacturer=samsung` con modelo NX789J. Sin GOS vivo, Perf Z no tiene datos.

Resultado en partida BR real: el panel muestra **FPS 120** en el mapa (`evidencia/perfz_br_game_1.png`), 100 en el avión (`evidencia/perfz_br_game_2.png`) y 54-60 en lobby (`evidencia/perfz_codm_3.png`). El log de Perf Z confirma `metric=FPS, value=120` de forma intermitente durante la partida.

Este ajuste es un dato de app, no un cambio de sistema. No depende del módulo para dibujar, pero sin módulo CODM vuelve a su límite de 90. Para ocultarlo, usar el botón mostrar/ocultar del panel o volver a `visibility=1`.

## 5.2 Perfil de fluidez y prueba A/B

Desde v2.4 el módulo incluye un perfil que se aplica solo con CODM vivo: asegura
`cmd game mode performance` (guardando el modo previo) y lo restaura al cerrar el
juego. Se controla con `toggle.sh on|off|status` o con el botón **Acción** de
Magisk. No toca GPU, CPU, resolución, densidad, animaciones ni térmica.

A/B en una partida BR real (misma partida, ventanas de 65 s, jugador quieto,
térmica 2, SKIN 40,2 → 40,9 °C; evidencia `logs/ab/B0..B3.txt`):

| Ventana | 8 ms | 16 ms | 18–149 ms | ≥150 ms | Perdidos | fps medios |
| --- | --- | --- | --- | --- | --- | --- |
| ON | 7.456 | 181 | 2 | 1 | 0 | 117,5 |
| OFF | 7.562 | 173 | 2 | 0 | 0 | 117,2 |
| ON | 7.590 | 158 | 2 | 0 | 0 | 117,4 |

Las tres ventanas son equivalentes: el juego ya está en el techo del panel. La
GPU se mantiene en 220 MHz por política del sistema (el rango disponible llega a
719 MHz) incluso con el perfil activo, así que un suelo de reloj no tendría
efecto; forzarlo solo añadiría calor y consumo. Por eso el perfil se limita a
GameManager y a su reversión. Pendiente: validar en combate intenso (humo,
explosiones); el overlay Perf Z permite verlo en vivo.

## 6. Reversibilidad

Flujo recomendado:

1. Cerrar CODM.
2. Desactivar el módulo en Magisk. El vigilante detecta el marcador `disable` y ejecuta `disable_cleanup.sh`: fuerza el cierre de CODM, restaura prefs 0/90, oculta Perf Z, restaura GameManager y elimina capa/prop/estado del juego.
3. Reiniciar.

Si el teléfono se apaga antes de que el vigilante reaccione, ejecutar `restore.sh` con CODM cerrado y después desactivar y reiniciar. `restore.sh` solo toca lo que el módulo cambió (prefs, Perf Z, capa, prop, workers y props Samsung); **no** resetea GameManager, whitelist ni refresco, porque eran ajustes originales y el reset los alteraba.

**Auditoría stock (25/10/2026, módulo desactivado + reinicio):** XML `e635…1b89` con `volumemonitor_hw`, props `SM-S918B`/`SM8550`/`kalama`, prefs de la cuenta de prueba en 0/90 (otras cuentas intactas), Perf Z `visibility=1` y cerrado, GameManager `performance`, `debug.vulkan.layers` vacío, capa ausente, sin procesos del módulo, sin montajes, resolución/densidad intactas y sin artefactos. Log: `logs/audit_stock_after_disable.txt`.

**Reactivación (25/10/2026):** XML `9e9725af…a296d1` montado sin `volumemonitor_hw`, `post-fs-data` con `NX789J`/`nubia`, `audio_fix` devolviendo `SM-S918B`, prefs 1/120, Perf Z visible, watcher vivo y capa mapeada en el proceso de CODM (pid 18449, archivo `(deleted)`) y borrada del disco. Log: `logs/audit_module_enabled.txt`.

**Prueba v3.2 — Desactivar desde la app (26/10/2026):** «Restaurar todo y dejar
stock» → «Desactivar módulo» → «Aceptar y reiniciar». Tras el reinicio:
`module.active=0`, props `SM-S918B`/`samsung`/`dm3q`/`SM8550`, sin monturas de
audio ni capa, prefs 0/90, GFX 1552×720/q1, Perf Z `visibility=1`, sin workers.
La app mostró «MODULO INACTIVO», interruptores de perfil/Perf Z grises y
deshabilitados, y el estado «perfil sin efecto · overlay sin efecto». Después se
quitó `disable`, se reinició y volvió `module.active=1`, prefs 1/120, cuenta de
prueba y audio parcheado. Evidencia: `evidencia/v3.2/after_disable_stock.txt`,
`status_after_disable.txt`, `app_module_inactive.png`, `status_reactivated.txt`.

**Prueba v3.2 — Eliminar desde la app (26/10/2026):** «Eliminar módulo y esta
app» → «Aceptar y eliminar». El script fuera del módulo restauró datos, borró
`/data/adb/modules/codm_s23_120`, desinstaló `com.aj.codmcontrol`, se eliminó a sí
mismo y reinició. Tras el reinicio no existía el módulo, ni la app, ni
`modules_update`, ni el script; props stock, sin monturas, prefs 0/90 y GFX
1552×720/q1. Se restauró el módulo desde un `tar` del propio teléfono, se
reinstaló el APK 1.1 build 6 y se reinició; quedó activo, 120, cuenta confirmada,
audio parcheado y GFX «Nativo» reaplicado desde la app (resaltado naranja).
Evidencia: `evidencia/v3.2/after_remove_stock.txt`,
`prefs_after_remove.xml`, `status_after_redeploy.txt`,
`app_final_nativo.png`, `app_final_top.png`.

**Excepción honesta:** si el módulo se desinstala, `uninstall.sh` ejecuta `restore.sh`. La carpeta desactivada en `/data/adb/modules` es inerte; para eliminarla del todo, desinstalar el módulo en Magisk. El root (Magisk/Zygisk/etc.) es un cambio aparte, previo al módulo. Análisis completo: `INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md`.

## 7. Entrega no-root

`../herramientas/codm_perf/` (en la raíz del workspace) sigue disponible para teléfonos sin root:

| Archivo | Función |
| --- | --- |
| `codm_perf.ps1` | `apply`, `verify`, `restore`, `status` por ADB, sin root |
| `measure_codm.sh` | Medidor que se sube temporalmente a `/data/local/tmp` en `verify` |
| `README.md` | Uso, opciones, checklist, límites y fuentes |

Probado en el S23 Ultra: ajusta GameManager, whitelist y refresco; en pruebas reales se quedó en el límite de 90 fps del juego (60 en lobby). Sirve para estabilidad y scheduling, **no** para desbloquear 120: sin root no se puede spoofear la identidad antes de zygote, montar el XML ni cargar la capa Vulkan.

**Conclusión de la investigación no-root (25/10/2026):** en un teléfono Android arbitrario sin root la probabilidad de replicar este 120 es **0–2 %** (en la práctica, 0 %). La única vía no-root que garantiza 120 es que el modelo esté aceptado por el servidor de CODM (lista interna no pública): entonces se activa desde los ajustes del juego y no hace falta módulo (100 %). Apps, archivos en carpetas, Shizuku, accesibilidad u overlays no pueden cambiar `Build`, escribir los datos privados de CODM, montar `/vendor` ni cargar una capa externa en una app no debuggable. Detalle técnico y fuentes: `INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md`.

## 8. Límites y pendientes

- **Otras marcas:** solo el S23 Ultra está verificado. Estimaciones: S23 Ultra 95 %, otros Samsung Snapdragon 40–60 % tal cual (85–90 % portado), otras marcas Snapdragon 2–5 % tal cual (30–50 % portado), Exynos/Pixel 1–20 %. No hay lista oficial pública de modelos con 120 en BR; el marketing de RedMagic describe 144 fps por interpolación y el soporte de ROG Phone 9 no está verificado. El módulo es específico del S23 Ultra (props, GPU y XML de audio Samsung); detalle en `INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md`.
- **Actualizaciones de CODM:** pueden cambiar la detección de dispositivo y romper el 120.
- **Apps Samsung que leen `Build`:** pueden ver NX789J (Game Booster/PerfZ). No afecta a CODM ni al audio.
- **Riesgo de ban:** falsear identidad puede violar los términos de servicio; la política móvil prohíbe el software no autorizado y los "injectors", y la general menciona suspensiones permanentes y bans de hardware, aunque no se verificó su aplicación a CODM. Estimación subjetiva: ~1 % por sesión, 5–15 % a 3 meses, 15–35 % a 12 meses sin otros cheats; con cheats de combate, >90 %. No hay estadística oficial. Detalle en `INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md`.
- **Lobby:** 60 fps por diseño; los 120 son en partida BR.
- **Prefs de CODM:** único dato de juego modificado; se aplica y se revierte desde el módulo.
- **Overlay Perf Z:** lo gestiona el módulo desde v2.4: al arrancar guarda el valor original y pone `visibility=0`; al desactivar o ejecutar `restore.sh` lo devuelve a `1` y cierra la app. No es un ajuste permanente del sistema.
- **Perfil de fluidez:** el A/B se hizo con el jugador quieto en una partida BR real; falta validarlo en combate intenso con humo/explosiones.
- **Relojes y térmica:** el módulo no fuerza GPU/CPU ni eleva límites térmicos. El sistema mantiene la GPU en 220 MHz y puede bajar la pantalla a 90 fps si el teléfono se calienta; es intencional para no forzar calor ni consumo.
- **Baldosa (v3.4):** no se re-ejercitó en esta ronda porque `click-tile` no hace nada si la baldosa no está en el panel; usa las mismas llamadas `Root.status()`/`Root.ctl()` ya probadas. Prueba de hardware pendiente para esta ronda.
- **Red (v3.4):** `fq_codel` no se pudo aplicar a `wlan0` (raíz `mq`; injertar en bandas da ENOENT) y sustituir la raíz rompería el `clsact` de netd. Sin ganancia medible; no se integró nada. Detalle en `research/net_qdisc/README.md`.

## 9. Reglas para el próximo trabajo

- Responder en español; separar verificado de pendiente.
- No tocar las otras cuentas de CODM.
- No inyectar código en CODM: el anticheat mata el proceso.
- No modificar animaciones del sistema ni ajustes de desarrollador.
- Medir siempre en partida real con SurfaceFlinger y capturas puntuales, sin sondeo continuo.
- Mantener todos los cambios dentro del módulo; si se toca, volver a probar `restore`/reactivar de punta a punta.
