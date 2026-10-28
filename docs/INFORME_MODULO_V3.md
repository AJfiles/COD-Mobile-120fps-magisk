# Informe del módulo CODM 120 v3.3 — S23 Ultra (26/10/2026)

> **Anexo v5.0 (28/10/2026) — universal y cuenta-agnóstico.** La entrega vigente
> pasa a **v5.0 (`versionCode 14`)**; app sin cambios (1.5/10). `account_mode=auto`
> sigue la cuenta activa del teléfono, la registra sola y guarda originales por
> paquete/UID; si no puede leer la activa con varias cuentas, **no escribe**
> (`CUENTA_AMBIGUA`). `spoof=compat` cubre equipos no listados solo con el modelo
> NX789J; en KernelSU el spoof se deja en `system.prop`. **Verificado en frío en
> SM-S918B/Magisk 30.7:** zip `build/codm_s23_120_v5.0.zip` SHA-256
> `416a00a5e629a623d22584cd1bc4ffc3754f8ba145c993e24537187927304c9f`,
> reinicio + PIN, 5 workers, `prefs=1/120`, `prefs.orig=0/90`,
> `keys.insert=0` y `doctor=120_LISTO` (`evidencia/v5_universal/`). **Inserción
> de claves: experimento negativo**; el juego mantuvo el 1/120 insertado ~45 s y
> lo reescribió a 90, y al cerrar eliminó las claves. `keys_insert` queda en 0
> por defecto; el camino que funciona es activar 120 una vez en Ajustes de CODM
> y dejar que el módulo lo mantenga con el juego cerrado. **Porcentaje honesto:**
> instalación/gestión ≈100 % de root Android 11+ con CODM; 120 real ≈40 %
> (panel ≥120 Hz; 37,4 % del mercado 2026; rango 35–55 %). Solo SM-S918B está
> verificado en hardware. Módulos similares analizados (ULTRA-EXTREME-UNLOCKER,
> Flame-Unlocker, GameUnlocker, AlexGfxCodm) y qué se adoptó o rechazó:
> `research/codm_config/UNIVERSAL.md` §11. Durante la prueba se detectó y reparó
> un duplicado de claves por carrera con el worker; el estado final quedó en una
> sola pareja 1/120 (`repair_prefs_<uid>.sh`, `status_restored.txt`). El HUD de BR
> al 50 % queda a cargo del usuario desde el editor del juego y no forma parte de
> esta entrega.
>
> **Anexo v4.1 (27/10/2026) — persistencia entre actualizaciones.** La entrega
> vigente pasa a **v4.1 (`versionCode 13`)**; app sin cambios (1.5/10). Magisk,
> KernelSU y APatch reemplazan el directorio del módulo al actualizarlo, así que
> los originales guardados en `run/` se perdían y una actualización podía tomar
> 1/120 como valor de fábrica. v4.1 mueve los registros de reversión y los
> ajustes a `/data/adb/codm_s23_120_state` mediante `files/state_env.sh`, con
> adopción automática de `run/` y `perf_state`; `restore.sh` y
> `disable_cleanup.sh` borran ese directorio solo cuando no queda nada pendiente
> y devuelven error si falla una restauración. **Verificado en SM-S918B**:
> flash v4.0→v4.1 + reinicio conservó `prefs.orig=0/90`; restore→0/90 y
> apply→1/120 sin perder el original (`evidencia/v4_universal/v41_persistencia.txt`).
> **Ciclo completo de reversibilidad verificado:** `restore.sh` (RC=0) dejó
> prefs 0/90, props stock, capa/Perf Z fuera y borró `STATE_DIR`; tras reiniciar,
> `prefs_watch` capturó el original real 0/90 y reaplicó 1/120, con
> `doctor=120_LISTO`, workers watch/prefs, cuenta auto-confirmada y capa mapeada
> al abrir CODM (`v41_restore_cycle.txt`, `v41_cycle_after_restore.txt`,
> `app_15_v41_after_restore.png`). Artefacto desplegado:
> `build/codm_s23_120_v4.1.zip` SHA-256 `3bb783dbe0aa12fe3efa0af29958a8711ede8997e005db28737694e48255888d`.
>
> **Anexo v4.0 (27/10/2026) — multiequipo.** La entrega v4.0
> **v4.0 (`versionCode 12`)** con app **1.5 (`versionCode 10`)**. Cambios
> verificados en SM-S918B/Magisk 30.7: descubrimiento de paquetes CODM por huella
> de PlayerPrefs (global, Garena, Tencent CN/KR, VNG); `game_prefs.sh` con
> originales por paquete/UID y adopción de los de v3; `prefs_watch.sh` que
> reaplica al cerrar el juego y refresca el doctor tras el desbloqueo;
> `doctor` con veredicto; perfiles `auto` (spoof/capa/audio solo dm3q);
> `restore.sh`/`disable_cleanup.sh` dinámicos; app 1.5 con resolución real de
> `su` y «Abrir CODM» por componente+`pidof`. Evidencia:
> `evidencia/v4_universal/` (`status_before_reboot.txt`,
> `status_after_reboot.txt`, `codm_launched.png`, `app_15_status.png`).
> Diseño, garantías y matriz: `research/codm_config/UNIVERSAL.md`.
> **Pendiente de hardware:** otras marcas, Android 15/16, regionales y
> KernelSU/APatch. El HUD de BR al 50% (editor del juego; ficheros cifrados)
> queda a cargo del usuario y no forma parte de la entrega del módulo.
> El resto de este informe describe v3.3 y sigue siendo válido salvo en los
> puntos que el anexo sustituye (versión, app y alcance por equipo).

Este documento cierra los 9 encargos de la fase v3 sobre el módulo `codm_s23_120`.
Complementa `INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md` (riesgo y reversibilidad)
y `INFORME_CODM_120FPS.md` (investigación y medición original). Todo lo que sigue
distingue **verificado en hardware**, **implementado sin hardware para probar** y
**resultado negativo comprobado**.

- Equipo de prueba: Samsung SM-S918B (dm3q), Android 14 / API 34, One UI 60101, 2316×1080, 120 Hz.
- Root: Magisk 30.7 + Zygisk Next + Shamiko + LSPosed. Serial SM-S918B.
- Módulo: `codm_s23_120` **v3.3** (`versionCode 10`), único en `/data/adb/modules/codm_s23_120`.
- App: **CODM Control by AJ 1.3** (`versionCode 8`), empaquetada dentro del módulo
  como `app/CODMControl.apk`, SHA-256
  `84d3c4cf6aee8b15033dcb691169ac1ff5389fad8ccba1ba014b43d3a49ae5de`.
- Evidencia: `evidencia/v3.1/` (fase de los 9 encargos), `evidencia/v3.2/`
  (ronda de app, interruptores, GFX y restauración probada en hardware) y
  `evidencia/v3.3/` (app dentro del módulo: instalación y eliminación).

## 1. Resumen de los 9 encargos

| # | Encargo | Estado | Dónde se resuelve |
| --- | --- | --- | --- |
| 1 | Soporte KernelSU/APatch además de Magisk | Implementado; **sin hardware KSU/APatch para verificar** | `files/root_compat.sh`, `customize.sh`, app con `su -M` y fallback |
| 2 | Audio que no afecte a otras marcas; solo el juego | Implementado y acotado; **probado solo en dm3q** | `customize.sh` retira el XML fuera de dm3q; `post-fs-data.sh` y `audio_fix.sh` solo actúan en dm3q |
| 3 | Detección automática de cuenta (`lastUserId.xml`) con confirmación | **Verificado en hardware** | `files/account.sh`, `tools/codmctl.sh`, tarjeta CUENTA ACTIVA |
| 4 | Android 15/16 y One UI 7/8 | Implementado con fallbacks; **no verificable aquí** | Detección de gestor, rutas de `resetprop`, variantes de `cmd game`, FGS `specialUse`, tile API 34 |
| 5 | Baldosa en Ajustes rápidos y notificación de estado | **Verificado en hardware** | `CodmTileService`, `StatusService`, `BootReceiver` |
| 6 | No tocar ajustes de combate | **Verificado por diseño y búsqueda de escrituras** | Solo se escriben 2 claves de framerate y 3 claves visuales |
| 7 | No forzar relojes ni térmica | **Verificado por diseño y búsqueda de escrituras** | `files/perf_mode.sh` solo usa el modo de GameManager; sin cpufreq/thermal |
| 8 | App tipo GFX y más ajustes del juego | Implementado; resaltado real verificado; **persistencia negativa** al abrir CODM | `files/gfx.sh`, tarjeta GFX; presets de resolución 3D y calidad Unity |
| 9 | App que verifique módulo activo, con logs y completa | **Verificado en activo e inactivo en hardware** | `MainActivity`, `Root`, `AppLog`, `CodmTileService` |

## 2. Verificación tras reinicio real (26/10/2026)

Secuencia comprobada después de reiniciar con PIN, sin abrir la app manualmente:

| Paso | Resultado | Evidencia |
| --- | --- | --- |
| `post-fs-data.sh` | Guardó props originales y aplicó spoof NX789J; solo dm3q | `evidencia/v3.1/boot_audio_logs.txt` |
| `audio_fix.sh` | Restauró `model=SM-S918B` y `device=dm3q`; reinició HAL y audioserver | `boot_audio_logs.txt` |
| HAL y audioserver | Vivos: PID 3821 (audioserver) y 3822 (HAL) | `boot_audio_logs.txt` |
| Estado del módulo | Activo, v3.1, Magisk 30.7, `resetprop=1` | `evidencia/v3.1/status_after_reboot.txt` |
| Cuenta | Detectada y confirmada la cuenta de prueba; `match=1` | `status_after_reboot.txt` |
| Prefs | `framerate=120`, `enable=1`, `prefs.orig=0/90` | `status_after_reboot.txt` |
| Audio del módulo | `audio.mode=dm3q-parcheado` | `status_after_reboot.txt` |
| Notificación | Arrancó sola; título «CODM 120 - activo», texto «Perfil ON - 120 fps - cuenta ...00659326» | `evidencia/v3.1/notification_after_boot.txt` |
| Baldosa | Registrada en `sysui_qs_tiles` como `custom(com.aj.codmcontrol/.CodmTileService)` | consulta `settings get secure sysui_qs_tiles` |
| CODM abierto | Capa armada y mapeada (`layer.mapped=1`), perfil aplicado, 120 en prefs | `evidencia/v3.1/watch.log` |
| CODM cerrado | `proc_kill: prop limpia; perfil restaurado`; `layer.*=0`, `perf.applied=0` | `watch.log`, `status_after_reboot.txt` |
| App tras reinicio | Módulo activo, cuenta auto-confirmada, GFX 1552×720/Unity 1, notificación ON | `evidencia/v3.1/app_post_reboot_top.png` |

La medición de rendimiento de referencia sigue siendo la de la fase anterior:
**119,84 fps** en BR real, 23.271 frames, 0 dropped, 0 jank. Este reinicio verificó
el camino de arranque y la capa, no repitió la medición en partida.

**Audio:** la sesión anterior verificó audio audible y amps cs35l43 encendidos. En
este arranque se verificó la parte estructural (props Samsung restauradas, HAL y
audioserver vivos, XML parcheado presente). La confirmación auditiva por el usuario
tras este reinicio concreto queda pendiente.

## 3. Encargo 1 — KernelSU/APatch

Implementado en `files/root_compat.sh`, cargado por `post-fs-data.sh`, `service.sh`,
`audio_fix.sh` y `tools/codmctl.sh`:

- Detecta Magisk (`/data/adb/magisk`, `magisk`), KernelSU (`/data/adb/ksu`, `ksud`)
  y APatch (`/data/adb/ap`, `apd`), con versión cuando está disponible.
- Busca `resetprop` en `/debug_ramdisk`, Magisk, APatch, KernelSU, `/sbin` y
  `/system/bin`; también acepta `magisk resetprop` y `resetprop` en PATH.
- Si no hay `resetprop`, el módulo entra en **modo degradado**: no toca props del
  sistema, deja marcador `run/no_resetprop` y conserva capa, prefs y controles.
- La app ejecuta `su -M` (mount master) tras una prueba de una vez; si no existe,
  usa `su` normal. Esto resuelve el aislamiento de `/data/data` por namespace en
  Android 14 y evita depender de una sintaxis exclusiva de Magisk.

Límite honesto: **KernelSU normalmente no incluye `resetprop`**. Sin él no hay
spoof pre-zygote, y aunque la capa y las prefs funcionen, CODM puede quedarse en
90. APatch y Magisk sí lo aportan según la detección implementada. No hay ningún
equipo KSU/APatch disponible: **no está verificado en hardware**.

## 4. Encargo 2 — Audio acotado, sin tocar otras marcas

El spoof NX789J rompía el audio porque el HAL de Samsung inicializaba como un
modelo desconocido y no encendía los amplificadores cs35l43. Además, el efecto
`volumemonitor_hw` de `/vendor/etc/audio_effects_sec.xml` colgaba audioserver al
pulsar volumen.

Qué hace el módulo y qué no:

- `customize.sh` comprueba `ro.product.device`. Si **no** es `dm3q`, elimina del
  módulo `system/vendor/etc/audio_effects_sec.xml` y los directorios `system/`
  vacíos antes de montar el overlay. En otras marcas **no se monta XML de audio**.
- `post-fs-data.sh` omite el spoof y cualquier cambio de props si no es dm3q.
- `audio_fix.sh` comprueba `orig_is_dm3q`; en otro equipo registra «el audio no se
  toca» y termina. Tampoco reinicia HAL ni audioserver.
- En dm3q, el XML parcheado y el reinicio de HAL son globales al audio del equipo;
  no se pueden limitar a CODM porque el problema es del HAL. Es el precio de que el
  juego y el resto del teléfono suenen; sigue siendo un cambio systemless y
  reversible al desactivar el módulo y reiniciar.

Verificado en dm3q: audio funcionando tras el parche y props restauradas en cada
arranque. **No probado en otra marca**: la lógica de exclusión está verificada por
lectura del instalador, no ejecutada en un equipo no-dm3q.

## 5. Encargo 3 — Cuenta activa con confirmación

- Fuente: `/data/data/com.activision.callofduty.shooter/shared_prefs/lastUserId.xml`,
  clave `4e42c67f78`.
- La cuenta conocida (UID de prueba) se auto-confirmaba solo si no hay otra
  confirmación guardada.
- Cualquier otra UID exige confirmación explícita; `account.sh confirm` vuelve a
  leer `lastUserId.xml` y rechaza la confirmación si no coincide con la cuenta
  activa en ese momento.
- Al arrancar, `apply_game_prefs.sh` solo escribe si la cuenta detectada es igual
  a la confirmada. Las demás cuentas del teléfono no se tocan.
- v3.1 añade que, al confirmar desde la app, se ejecuta `apply_game_prefs.sh` en el
  acto si CODM está cerrado y las prefs son visibles en ese namespace. Si CODM está
  abierto o las prefs no se ven (KSU sin `-M`), el 120 se aplicará en el siguiente
  arranque; la app lo indica en el texto de la tarjeta.
- **v5.0 (28/10/2026) supera este modelo:** `account_mode=auto` sigue la cuenta
  activa y la registra sola; con varias cuentas y sin poder leer la activa no
  escribe. Lo anterior describe v3.4 y se conserva como histórico.
- Evidencia: `evidencia/v3.1/account.log` muestra la confirmación y la comprobación
  «prefs de la cuenta de prueba ya en 120; sin cambios»; el hash del XML no cambió
  durante la prueba.

Cuentas no tocadas: UID_OTRA_1, UID_OTRA_2, UID_OTRA_3, UID_OTRA_4; una de ellas ya tenía 120 de origen y no se «corrigió».

## 6. Encargo 4 — Android 15/16 y One UI 7/8

Trabajo defensivo implementado, **sin equipo para verificarlo**:

| Área | Medida | Riesgo pendiente |
| --- | --- | --- |
| Gestor root | Detección Magisk/KernelSU/APatch y `resetprop` en varias rutas | KSU sin `resetprop` no puede spoofear |
| App | Prueba `su -M` y fallback a `su` | KernelSU puede no soportar `-M`; la app muestra estado parcial |
| GameManager | `cmd game mode`, `cmd game set`, `cmd game set-mode`; si no existe, perfil sin efecto | One UI 7/8 puede cambiar el orden de argumentos |
| Servicio | FGS `specialUse` (0x40000000), targetSdk 35 | Android 15/16 puede exigir justificación adicional |
| Baldosa | `startActivityAndCollapse(PendingIntent)` en API 34+ | Sin cambios previstos |
| Audio | Guardas por dm3q y rutas de HAL estándar | One UI 7/8 puede renombrar el HAL o el XML; el módulo no tocaría audio, pero el parche no aplicaría |
| Props | Lista completa guardada/restaurada y `orig_is_dm3q` | Un layout de props distinto puede requerir ampliar la lista |
| XML systemless | Overlay en `/system/vendor/etc/audio_effects_sec.xml` | Particiones/AVB más estrictas podrían impedir el montaje |

No se afirma compatibilidad verificada con Android 15/16 ni One UI 7/8. Es una
matriz de implementación y riesgos, no una prueba.

## 7. Encargo 5 — Baldosa y notificación

Verificado:

- TileService declarado con `BIND_QUICK_SETTINGS_TILE`; presente en la lista de
  baldosas del sistema. En estado activo muestra «CODM 120» y alterna el perfil;
  con el módulo inactivo se marca `STATE_UNAVAILABLE` y abre la app.
- Servicio en primer plano `isForeground=true foregroundId=120 types=40000000`,
  canal `estado_modulo`, notificación id 120 con acciones.
- La notificación se inicia sola tras el reinicio (`BootReceiver`) y muestra el
  estado real leído del módulo: «CODM 120 - activo» / «Perfil ON - 120 fps -
  cuenta ...00659326».
- Interruptor «Notificación de estado» en la app, activado por defecto; pide
  `POST_NOTIFICATIONS` en Android 13+.

## 8. Encargo 6 — Sin ajustes de combate

El módulo solo escribe estas claves de CODM:

| Clave | Uso |
| --- | --- |
| `CODM_<uid>_iMSDK_King_EnableFramerateCustomize` | 1 |
| `CODM_<uid>_iMSDK_King_FramerateCustomizeValue` | 120 |
| `Screenmanager%20Resolution%20Width` | preset GFX |
| `Screenmanager%20Resolution%20Height` | preset GFX |
| `UnityGraphicsQuality` | preset GFX |

Búsqueda en todo el módulo (`*.sh`, `*.xml`): las únicas apariciones de FOV,
sensibilidad, MSAA, rotación, joystick, armas o `ConfigCache` son dos comentarios
en `files/gfx.sh` que prohíben tocarlos. No hay escrituras. La app tampoco expone
esos ajustes; solo lee/edita las claves de la tabla.

## 9. Encargo 7 — Sin relojes ni térmica

- No hay escrituras a `cpufreq`, `scaling_governor`, `scaling_min/max`, `thermal`
  ni límites de temperatura. La única aparición es un comentario en
  `perf_mode.sh` explicando que forzarlos solo añadiría calor.
- El «perfil» solo asegura el modo `performance` de GameManager mientras CODM vive
  y restaura el modo anterior al salir. En esta unidad el modo original ya era
  `performance`, así que el cambio neto es nulo.
- No se tocan resolución/densidad del sistema, animaciones ni ajustes de
  desarrollador.

## 10. Encargo 8 — App tipo GFX: qué se pudo y qué no

La app ofrece cuatro presets de render 3D más calidad Unity, con backup y
restauración: bajo 1158×540/q0, equilibrado 1552×720/q1, alto 1930×900/q2, nativo
2316×1080/q3.

**Resultado negativo comprobado (26/10/2026):** se aplicó «bajo» con CODM cerrado
(1158×540, q0, `overridden=0`); al abrir CODM y esperar 60 s, el propio juego
reescribió las claves a 1552×720/q1 y el módulo lo detectó (`preset=bajo`,
`overridden=1`). Se restauraron los originales. Evidencia:
`evidencia/v3.1/gfx_negative_result.txt` y `evidencia/v3.0/app_gfx_warning.png`.
Por eso la app avisa que el preset no persiste; no se vende como ajuste permanente.

Inventario de las 1885 claves de `playerprefs.xml` (solo lectura) y búsqueda en
todos los `shared_prefs`:

- Sí existen: `Screenmanager%20Resolution%20Width/Height`, `UnityGraphicsQuality`,
  `FPSLevel`, `kUserGraphicApi`, `CODM_ALL_EnableLobbyDynamicFrameRate`,
  `CODM_ALL_EnableShadow_*_2Show` (toggles de visualización, no calidad).
- **No existe** ninguna clave de distancia de visión, LOD, distancia de dibujado,
  calidad de texturas o calidad de efectos: la búsqueda
  `distance|lod|drawdist|viewdist|texturequality|effectquality|shadowquality`
  no devuelve coincidencias en ningún XML de preferencias del juego.
- `SettingsGraphicStyleBR` es un entero por cuenta (0/2 según la cuenta), pero su
  semántica no está documentada y podría afectar visibilidad/combate: no se toca.
- Forzar claves que el juego reescribe o cuyo significado se desconoce no es un
  ajuste real; sería una promesa falsa. Por eso el alcance se queda en lo que se
  puede verificar y revertir.

Lo que sí queda como mejora real es el framerate (prefs por cuenta) y la identidad
GPU; el resto del apartado gráfico no persiste o no está expuesto.

## 11. Encargo 9 — App completa

Funciones verificadas en hardware:

- Tarjeta ESTADO DEL MÓDULO: activo/inactivo, versión, gestor root, modelo,
  Android/One UI, audio, props, resetprop y estado de CODM/capa.
- Controles: perfil ON/OFF, mostrar/ocultar Perf Z, abrir CODM, actualizar.
- Tarjeta CUENTA ACTIVA: detectar, confirmar y explicación de la regla multcuenta.
- Tarjeta GFX: presets, restauración, aviso de no persistencia y alcance.
- Tarjeta LOGS: selector de logs del módulo, visor monoespaciado, copiar; registro
  propio de cada acción de la app (`AppLog`).
- Restauración completa con confirmación; cierra CODM, restaura prefs, GFX,
  GameManager, Perf Z y props.
- Notificación de estado y baldosa QS; la app se auto-inicia al arrancar si la
  notificación está activada.
- Requiere root; sin root muestra «SIN ACCESO ROOT» y deshabilita controles. No
  pide INTERNET ni permisos ajenos a su función.
- Verificación en vivo: `evidencia/v3.1/app_post_reboot_top.png` (v3.1 activa,
  cuenta auto-confirmada, notificación ON, GFX original).

Pendiente de prueba visual: el estado «módulo inactivo» de la UI (los controles se
deshabilitan y la baldosa queda `UNAVAILABLE` por código; no se desactivó el módulo
para no forzar otro ciclo de reinicio).

## 12. Reversibilidad

- Framerate: `run/prefs.orig.<uid>` guarda los valores exactos por cuenta. En esta
  unidad: `enable=0`, `framerate=90`; `prefs.applied` identifica la cuenta tocada.
- GFX: `run/gfx.orig` guarda ancho, alto y calidad originales; `gfx restore` los
  devuelve y borra el estado.
- Audio/props: `run/orig_props.txt` guarda las props exactas; `audio_fix.sh` las
  restaura en cada arranque; al desactivar el módulo y reiniciar, el XML deja de
  montarse.
- App: es un APK externo opcional; el módulo funciona sin ella. Se puede
  desinstalar sin afectar al juego ni al módulo.
- Desactivación: la app ofrece `module disable` (restaura, crea `disable` y
  reinicia) o `module remove` (restaura, borra módulo y app, y reinicia); también
  se puede desactivar en Magisk/KernelSU/APatch y reiniciar.
- Estado actual tras las pruebas: CODM cerrado, prefs 1/120 con original 0/90,
  GFX Nativo 2316×1080/q3 (`gfx.preset=nativo`, `gfx.modified=1`), módulo activo,
  Perf Z visible, notificación de la app apagada, capa y perfil limpios.

## 13. Pendiente / no verificado

| Tema | Estado |
| --- | --- |
| KernelSU y APatch en hardware | Implementado; sin equipo para probar |
| Android 15/16 y One UI 7/8 | Fallbacks implementados; sin equipo para probar |
| Instalación en otra marca | Exclusión de audio y spoof por dm3q implementada; no ejecutada en otro equipo |
| Audio audible tras este reinicio | Estructura y HAL verificados; falta oído del usuario |
| 120 fps en partida tras este reinicio | Capa y prefs verificadas; medición de fps no repetida |
| UI con módulo inactivo | **Verificado en hardware:** interruptores grises, controles deshabilitados y texto «sin efecto» |
| Desactivar/eliminar desde la app | **Verificado en hardware:** ambos restauran, reinician y dejan stock |
| Reinstalación tras eliminar | **Verificado:** módulo desde respaldo del teléfono + APK 1.1 build 6; 120 y cuenta restaurados |
| Cuenta nueva distinta de la conocida | Requiere confirmación explícita; no se probó para no tocar otras cuentas |
| Persistencia de GFX | Resultado negativo verificado: CODM reescribe al abrir |
| Distancia de visión / LOD | No existe clave expuesta en las prefs del juego |

## 14. Archivos clave y artefactos

| Ruta | Función |
| --- | --- |
| `modules/codm_s23_120/files/root_compat.sh` | Detección de Magisk/KSU/APatch y `resetprop` |
| `modules/codm_s23_120/customize.sh` | Retira el XML de audio fuera de dm3q |
| `modules/codm_s23_120/files/account.sh` | Detección/confirmación por `lastUserId.xml` |
| `modules/codm_s23_120/files/apply_game_prefs.sh` | 1/120 solo a la cuenta confirmada, con originales exactos |
| `modules/codm_s23_120/files/restore_game_prefs.sh` | Restaura los valores exactos por UID |
| `modules/codm_s23_120/files/gfx.sh` | Presets visuales con backup y detección de override |
| `modules/codm_s23_120/tools/codmctl.sh` | API de estado/control; confirmar aplica 120 si procede |
| `modules/codm_s23_120/files/install_app.sh` | Instala/actualiza la app del módulo al arrancar; ignora copias del sistema |
| `modules/codm_s23_120/app/` | `CODMControl.apk` + `version.txt` (la app que viaja en el módulo) |
| `modules/codm_s23_120/uninstall.sh` | Limpieza diferida al eliminar: copia a `/data/local/tmp/codm_deferred` y actúa tras `sys.boot_completed` |
| `codmcontrol/` | App Android: estado, cuenta, GFX, logs, restauración, tile y notificación |
| `evidencia/v3.1/` | Estado, notificación, logs y prueba GFX de la fase de 9 encargos |
| `evidencia/v3.2/` | Interruptores, GFX, selector de restauración, desactivar/eliminar y reinstalación |
| `evidencia/v3.3/` | App dentro del módulo: instalación al arrancar y eliminación con el módulo |

## 15. Ronda v3.2 — app 1.1 y restauración (26/10/2026)

Esta ronda no cambia el mecanismo del 120: corrige la app de control y prueba en
hardware los dos caminos de restauración.

| Cambio | Resultado | Evidencia |
| --- | --- | --- |
| Abrir CODM | `<queries>` + fallback `monkey`; abrió el juego con la app | `evidencia/v3.2/open_codm.png` |
| Interruptores | Naranja real ON / gris OFF; track de One UI con `PorterDuff.SRC` | `app_1d.png`, `app_final_top.png` |
| Preset GFX | Resaltado según `gfx.preset` o los valores actuales; Nativo en naranja | `app_final_nativo.png` |
| Selector de restauración | Dos tarjetas, confirmación y reinicio; ya no se corta el diálogo | `restore_dialog2.png`, `restore_confirm_disable.png`, `restore_confirm_remove.png` |
| Módulo inactivo | «MODULO INACTIVO», interruptores grises y controles deshabilitados; estado «sin efecto» | `app_module_inactive.png`, `ui_inactive_switches_off.xml` |
| Desactivar | Stock verificado y reactivación devuelve 120/cuenta | `after_disable_stock.txt`, `status_reactivated.txt` |
| Eliminar | Módulo, app, script, monturas y props fuera; stock verificado; reinstalado desde respaldo | `after_remove_stock.txt`, `status_after_redeploy.txt` |
| Logs | Vista seleccionable sin foco; ya no salta el scroll al refrescar | `app_1e.png` |
| Notificación | ON/OFF en caliente; el servicio foreground arranca y para | `notif_state.png` |

Comportamiento exacto de las dos opciones:

- **Desactivar módulo:** ejecuta `restore.sh` (workers, prefs exactas 0/90, GFX,
  Perf Z, GameManager, capa y props), escribe `disable` y reinicia. El módulo
  sigue instalado; la app muestra el estado inactivo. Para volver: quitar
  `disable` y reiniciar; verificado que vuelve 1/120 y la cuenta confirmada.
- **Eliminar módulo y esta app:** restaura igual y lanza un script fuera del
  módulo (`/data/local/tmp/codm_remove.sh`) que borra
  `/data/adb/modules/codm_s23_120`, desinstala `com.aj.codmcontrol`, se borra a
  sí mismo y reinicia. Verificado que no quedan módulo, app, monturas, props
  falsas ni procesos; para volver hay que reinstalar módulo y APK.

Sobre «más optimización»: no se añadieron relojes, límites térmicos, GOS fps/compile
ni overlays de terceros. El A/B de la fase anterior dio 117,5 / 117,2 / 117,4 fps
sin diferencia y el techo es el panel de 120 Hz; forzar relojes solo subiría
temperatura y consumo. Las palancas seguras del juego (resolución 3D y calidad
Unity) ya están expuestas, avisando de que CODM puede reescribirlas al abrir.

## 16. Ronda v3.3 — la app viaja en el módulo (26/10/2026)

Objetivo: que instalar el módulo instale la app y que desinstalarlo la quite, más
la marca de identidad AJ. El mecanismo del 120 no cambia.

| Cambio | Resultado | Evidencia |
| --- | --- | --- |
| App dentro del módulo | El APK vive en `app/CODMControl.apk` + `app/version.txt`; `customize.sh` ajusta permisos | `status_final_v33.txt` (`app.packaged=1`) |
| Instalación al arrancar | `files/install_app.sh` instala/actualiza solo si falta o es más vieja (`pm install -r`); log «app instalada desde el modulo» | `evidencia/v3.3/app.log` |
| Eliminar el módulo quita la app | `uninstall.sh` copia a `/data/local/tmp/codm_deferred` y un worker diferido restaura y desinstala tras `sys.boot_completed` | `after_remove_final.txt`, `after_remove_deferred.txt` |
| Marca AJ | `module.prop` (name/author/description), banner de `customize.sh`, app «CODM Control by AJ», pie de la interfaz | `app_v13_top.png`, `ui_app_v13.xml` |
| Estado en la app | La tarjeta del módulo muestra «App: viaja en el modulo (vN, instalada vM)» | `ui_app_v13.xml` |

Detalle del eliminado: Magisk ejecuta `uninstall.sh` **antes** del desbloqueo, con
los datos de app inaccesibles; por eso la restauración de prefs y la desinstalación
se difieren a un worker que copia el árbol del módulo a `/data/local/tmp/codm_deferred`
y actúa tras el arranque. El guard de desinstalación usa el patrón `*data/app*`
(la salida de `pm path` es `package:/data/app/…`, no `/data/app/…`). Verificado que
tras eliminar no quedan módulo, app, `/data/data` de la app ni procesos, y que las
prefs de CODM vuelven a 0/90 y Perf Z a su visibilidad original.

## 17. Ronda v3.4 — una sola sesión root y red (27/10/2026)

Objetivo: que Magisk muestre su aviso de superusuario **una sola vez por arranque
de la app**, sin desactivar notificaciones ni tocar `magisk.db`, y probar si un
qdisc de baja latencia mejora los ms del juego. El mecanismo del 120 no cambia.

| Cambio | Resultado | Evidencia |
| --- | --- | --- |
| Causa del aviso repetido | `StatusService` refresca cada 30 s y cada refresco lanzaba un `su` nuevo (`su: request from uid=[10384]`, PID distinto cada vez; 51 peticiones en el búfer) | `evidencia/v3.4/antes_observacion.txt` |
| Sesión root persistente | Nuevo `RootShell.java`: un `su -M` por proceso de app, handshake con nonce privado y comandos delimitados por marcadores; lectura única y timeouts (40 s normal, 240 s restauración, 20 s reinicio) | `evidencia/v3.4/logcat_after.txt` |
| Aviso una sola vez | Ventana limpia de 150 s con el estado refrescando cada 30 s: **1** petición `su` y **un** proceso `su -M` hijo de la app | `evidencia/v3.4/logcat_after.txt`, `evidencia/v3.4/ps_su.txt` |
| Interruptores y Actualizar | Perfil OFF y ON desde la notificación por la misma sesión, `rc=0`, sin peticiones nuevas; «Actualizar» en la app tampoco abrió otra | `evidencia/v3.4/app.log`, `logcat_after.txt` |
| Recuperación | Matar el `su` de la sesión: el siguiente tick abre una sesión nueva y el estado vuelve; cuesta un aviso extra, documentado | `evidencia/v3.4/kill_recovery.txt` |
| Baldosa | No re-ejercitada: no está en el panel de ajustes rápidos y `click-tile` no ejecuta el servicio; usa `Root.status()`/`Root.ctl()` igual que la app | `evidencia/v3.4/tile_toggle.txt` |
| App 1.4 (9) en el módulo | `app/CODMControl.apk` + `app/version.txt`=9; SHA-256 `fc201640…ae088`; módulo v3.4 (`versionCode 11`) | `evidencia/v3.4/status_final_v34.txt` |
| Red (qdisc) | **Negativo**: `wlan0` es `mq` y no admite injertar `fq_codel` en sus bandas (ENOENT); sustituir la raíz borraría el `clsact` de netd. Sin ganancia, no se integra nada | `research/net_qdisc/README.md` |

Diseño de la sesión: se intentan variantes `su -M`, `su -M -c "exec /system/bin/sh"`,
`su -c "exec /system/bin/sh"` y `su`, con `redirectErrorStream`; el handshake
exige `id -u` = 0 en 15 s. Cada comando se envuelve con un prefijo único
(`AJ<hex>_B<seq>` / `_E<seq> <rc>`), se ejecuta con `</dev/null` y el lector
descarta banner y prompt de Magisk. El búfer está acotado a 2 MB y el shell se
mata si un comando agota su tiempo; la siguiente llamada lo reabre. La sesión
vive solo en el proceso de la app: sin Binder, sin exportar y muere con ella.
Los comandos destructivos que reinician (`svc power reboot`) matan la sesión; el
fallback existente sigue funcionando y puede costar un aviso extra.

Sobre la red: la línea base fue router 17,9 ms avg / 6,5 mdev, 8.8.8.8 20,7 / 5,7,
1.1.1.1 72,9 / 5,8, 0 % pérdida; los 50–60 ms de CODM son ruta/servidor. Se
descartó tocar `wlan0` y no quedó script ni residuo (detalle en
`research/net_qdisc/README.md`).

## 18. Conclusión

Los 9 encargos están implementados. En el S23 Ultra quedaron verificados el
arranque completo, la cuenta automática, las prefs 1/120 con original 0/90, el
audio estructural, la capa Vulkan, la notificación, la baldosa y la app tanto con
el módulo activo como inactivo. En v3.2 se probaron además, de punta a punta,
desactivar, reactivar, eliminar y reinstalar. En v3.3 la app se entrega dentro del
módulo: se instala/actualiza al arrancar y se elimina junto con el módulo; todo con
la marca AJ. En v3.4 la app mantiene una sola sesión root por arranque (1 petición
`su` en 150 s, aviso único de Magisk) y la prueba de qdisc para la red quedó
descartada por falta de mecanismo y de ganancia. Los puntos que no se pueden
verificar aquí (KSU/APatch, Android 15/16, One UI 7/8, otra marca) están marcados
como pendientes, no como éxitos; la baldosa tampoco se re-ejercitó en v3.4 porque
no está en el panel. El único
resultado negativo de fondo es el GFX: CODM reescribe resolución y calidad al abrir
y no expone distancia de visión; la app lo dice en pantalla y conserva la
restauración.
