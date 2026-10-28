# CODM 120 FPS + Control — universal (v5.1) · by AJ

Módulo único que concentra todo el trabajo sobre el teléfono. Todo cambio de
sistema vive dentro del módulo; los datos de app que se modifican (framerate de la
cuenta activa, GFX visual y visibilidad de Perf Z) se aplican y se revierten
desde el propio módulo. La app de control viaja **dentro** del módulo: se instala
sola al arrancar y se quita al desinstalar el módulo.

Repositorio: <https://github.com/AJfiles/call-of-duty-mobile-120fps-magisk>

Informe de la fase v3 (9 encargos, verificado vs pendiente):
`../docs/INFORME_MODULO_V3.md`. Auditoría de reversibilidad, compatibilidad, ban y
viabilidad sin root: `../docs/INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md`.
Investigación y diseño universal: `../docs/UNIVERSAL.md`.

Resultado medido en partida BR real: **119,84 fps** en mapa; 23.271 frames,
0 dropped, 0 jank, 99,08 % a 8 ms (`../docs/evidencia/timestats_br.txt`).

Overlay de FPS de Samsung (**Perf Z**): se muestra u oculta desde la app o desde
`codmctl.sh`, y al desactivar el módulo o restaurar vuelve a su visibilidad
original (1/HIDE en esta unidad). Verificado en partida BR a **120 fps** con la
captura del overlay del autor.

## Novedades v5.1 (28/10/2026) — limpieza para publicación

- **Sin cambios funcionales.** Se quitan identificadores del entorno de prueba
  (PIN, serial, UID de la cuenta usada para verificar) y se ajustan los enlaces
  de esta documentación al árbol público. El mecanismo, los perfiles, el doctor
  y la reversión son idénticos a v5.0.
- En `files/account.sh` y `tools/codmctl.sh` la constante `KNOWN` queda vacía:
  no hay UID privilegiada. En `account_mode=auto` (por defecto) la cuenta activa
  se registra sola, así que el comportamiento para el usuario no cambia.
- ZIP reconstruido y verificado en frío en SM-S918B/Magisk 30.7 (misma batería de
  comprobaciones que v5.0: workers, prefs, originales y `doctor`).

## Novedades v5.0 (28/10/2026) — cualquier teléfono root, cualquier cuenta

- **Cuenta-agnóstico real.** `account_mode=auto` sigue la cuenta activa del
  teléfono (`lastUserId.xml`), la registra sola y guarda originales por
  paquete/UID. Nunca cae a «todas» por descarte: si hay varias cuentas y no se
  puede leer la activa, no escribe. `apply_all=1`/`account_mode=all` son opt-in.
  Probado en frío con seis escenarios sintéticos (activa, cambio de cuenta,
  confirmada, ambiguo, única, apply_all) y en hardware con una cuenta de prueba.
- **Instalación portable.** Mismos scripts POSIX para Magisk, KernelSU y APatch;
  `spoof=auto` completo solo en dm3q, `compat` (solo modelo NX789J) para
  cualquier equipo y `on` (perfil completo) opt-in. En KernelSU, que no trae
  `resetprop`, `customize.sh` deja el spoof en `system.prop` para el arranque.
- **Inserción de claves: experimento negativo y cerrado.** Con CODM cerrado, el
  módulo borró e insertó `1/120` correctamente (backup + readback); el juego
  arrancó con 120 y a los ~45 s lo reescribió a **90**, y al cerrar eliminó las
  claves. La inserción local **no crea el ajuste de cuenta**. Por eso
  `keys_insert` queda en **0** por defecto: el camino que funciona es activar
  120 una vez en Ajustes de CODM (el spoof `compat` ayuda a que el menú lo
  ofrezca) y dejar que el módulo lo mantenga con el juego cerrado. `keys_insert=1`
  sigue disponible como experimental, con aviso del juego.
- **Porcentaje honesto**: instalación y gestión ≈ **100 %** de teléfonos root
  Android 11+ con CODM instalado (Magisk/KernelSU/APatch); 120 real ≈ **40 %**
  (panel ≥120 Hz; 37,4 % del mercado móvil 2026, con sesgo de gama alta; rango
  conservador 35–55 %). Panel de 90 Hz → 90; panel de 60 Hz → no. Solo
  SM-S918B/Magisk 30.7/Android 14 está verificado en hardware.
- **Verificado en frío**: zip v5.0 instalado en Magisk, reinicio y desbloqueo,
  `module.version=v5.0/14`, 5 workers, `prefs=1/120`, `prefs.orig=0/90`,
  `doctor=120_LISTO`, app 1.5/10. Durante la prueba se detectó un duplicado de
  claves por una carrera con el worker; se reparó con el worker detenido y el
  estado final quedó en una sola pareja 1/120
  (`../docs/evidencia/status_v5_reboot.txt`).

## Novedades v4.1 (27/10/2026) — estado persistente

Magisk, KernelSU y APatch **reemplazan el directorio del módulo al actualizarlo**:
todo lo guardado en `run/` se pierde. En v4.0 eso incluía los originales para
revertir, así que una actualización podía guardar 1/120 como si fuera el valor de
fábrica. v4.1 saca ese estado a `/data/adb/codm_s23_120_state`:

- `files/state_env.sh` define `STATE_DIR` y **adopta** los ficheros antiguos de
  `run/` y `perf_state` sin pisar los ya persistidos.
- Persisten `prefs.orig.*`, `fpslevel.orig.*`, `gfx.orig`, `gfx.state`,
  `perfz.orig`, `perf.state`, `orig_props.txt`, `account.confirmed` y
  `perf_state` (perfil de fluidez). Los locks, pid, cachés y veredictos siguen
  en `run/` porque son efímeros.
- `restore.sh` y `disable_cleanup.sh` borran `STATE_DIR` solo cuando no queda
  ningún registro por revertir, y ahora devuelven error si una restauración falla.
- **Verificado en SM-S918B**: flash v4.0→v4.1 + reinicio → `prefs.orig=0/90`
  conservado; `game_prefs.sh restore` dejó 0/90 y `apply` volvió a 1/120 sin
  perder el original (`../docs/evidencia/v41_persistencia.txt`).

## Novedades v4.0 / app 1.5 (27/10/2026)

Objetivo: que el módulo funcione en cualquier teléfono, marca y versión de
Android, con garantías verificables aunque el equipo no se pueda probar.

- **Descubrimiento por huella, no por nombre.** Detecta CODM global, Garena,
  Tencent CN/KR y VNG por sus PlayerPrefs (`iMSDK_King_FramerateCustomizeValue`),
  no por el ID del paquete. Un ID regional nuevo o futuro se detecta igual; se
  puede añadir uno a mano en `game.packages` o con `CODM_PKGS`.
- **Perfiles `auto`.** `spoof=auto` y `layer=auto` conservan el comportamiento
  verificado del S23 Ultra (dm3q: spoof NX789J + capa Adreno 830) y **no tocan**
  identidad, GPU ni audio en otros equipos. `spoof=on|off` y `layer=on|off` son
  opt-in; el resto de ajustes vive en `config`.
- **Prefs por cuenta y por paquete.** `files/game_prefs.sh` guarda originales en
  `$STATE_DIR/prefs.orig.<pkg>.<uid>` (adopta los `run/prefs.orig.<uid>` de v3),
  verifica cada escritura, revierte si falla y aplica a la cuenta confirmada
  (o a la activa/todas según `account_mode`). Nunca escribe con el juego abierto.
- **Trabajador de prefs** (`files/prefs_watch.sh`): reaplica cuando el juego está
  cerrado y recalcula el doctor tras el desbloqueo (en el arranque `/data` está
  cifrado y no se puede diagnosticar).
- **Doctor** (`codmctl.sh doctor`): root, paquetes, XML, cuentas, FPSLevel,
  framerate, panel, perfiles y un veredicto (`120_LISTO`, `FALTA_ULTRA`,
  `PANEL_60`, `SIN_JUEGO`, `ESPERA_DESBLOQUEO`…). La app lo muestra.
- **Abrir CODM** resuelve el componente real y confirma el proceso; `am start`
  devuelve 0 aunque no resuelva, así que ya no se declara éxito sin `pidof`.
- **Restauración universal** (`restore.sh`, `disable_cleanup.sh`): todos los
  paquetes/UID modificados, GFX (solo dm3q), Perf Z, GameManager, capa y props.
- **App 1.5** (`versionCode 10`, SHA-256
  `91b3f1c1da707ef1594974b9d92f6e83d8cf5aa3654ca70d26e426831cdafed1`)
  con resolución real de `su` (`/debug_ramdisk`, KSU, APatch, Magisk, `-M`),
  «Abrir CODM» por paquete y estado con doctor. Sin permisos nuevos.
- **Verificado en frío en SM-S918B** (Magisk 30.7): arranque → 5 workers,
  `doctor=120_LISTO` tras desbloquear, app 1.5 instalada por el módulo, CODM
  abierto por `game launch`, capa confirmada en el proceso, cierre limpio y
  prefs 1/120 intactas (evidencia local del autor, no incluida en el repo).
- **Pendiente de hardware**: otros fabricantes/Android 15-16, Garena/Tencent/VNG,
  KernelSU/APatch. La matriz y el protocolo de prueba están en
  `../docs/UNIVERSAL.md`; no se declara funcionamiento en esos
  equipos sin medirlo.

## Novedades v3.4 / app 1.4 (27/10/2026)

- **Un solo aviso de superusuario por arranque de la app.** Antes, el refresco de
  estado cada 30 s lanzaba un proceso `su` nuevo y Magisk mostraba su aviso de
  «Le concediste privilegios de superusuario…» cada vez. La app 1.4 abre **una
  única sesión root persistente** (`su --mount-master` + shell con marcadores
  privados) por proceso y todos los comandos (estado, interruptores, logs, GFX,
  restauración) viajan por ella. Verificado: 1 petición `su` en una ventana de
  150 s con el estado refrescando cada 30 s; si la sesión muere, la siguiente
  llamada abre una nueva (un aviso extra, aceptable).
- **Sin tocar Magisk.** No se desactivan notificaciones ni se edita `magisk.db`,
  no hay permisos nuevos ni INTERNET; la sesión vive en el proceso de la app y
  muere con él.
- **Red: experimento negativo y descartado.** Se probó `fq_codel` con `tc` fuera
  del módulo: el `mq` de `wlan0` no admite injertar qdisc en sus bandas (ENOENT
  incluso con `pfifo_fast`) y sustituir el qdisc raíz borraría el `clsact` de
  netd (firewall/contabilidad). Sin ganancia medible para el UDP del juego, no se
  integra nada; `wlan0` sigue como estaba. Detalle local, no publicado.
- App **1.4** (`versionCode 9`) empaquetada en `app/CODMControl.apk`
  (`app/version.txt` = 9). SHA-256:
  `fc201640e78dcb76e1202a0a8b21e3e36d4689005cd1363b208a9968563ae088`.
  Evidencia de la ronda en el archivo local del autor.

## Novedades v3.3 / app 1.3 (26/10/2026)

- **La app viaja en el módulo.** El APK se empaqueta en `app/CODMControl.apk`
  junto a `app/version.txt` (versionCode que se espera). Al arrancar, el worker
  `files/install_app.sh` instala o actualiza la app con `pm install -r` solo si
  está ausente o es más antigua que la del módulo; nunca toca una copia del
  sistema.
- **Desinstalar el módulo desinstala la app.** Magisk ejecuta `uninstall.sh` antes
  del desbloqueo, así que la limpieza no puede tocar los datos de app en ese
  momento. `uninstall.sh` copia el módulo a `/data/local/tmp/codm_deferred` y
  lanza un worker desprendido que, tras `sys.boot_completed`, ejecuta `restore.sh`,
  desinstala `com.aj.codmcontrol` con `pm uninstall`, borra `/data/data` y
  `/data/user_de/0` de la app, y se autolimpia.
- **Marca AJ** en `module.prop` (name/author/description), en el banner de
  `customize.sh`, en el nombre de la app («CODM Control by AJ») y en el pie de la
  interfaz («CODM Control v1.3 · by AJ»).
- La tarjeta del módulo en la app muestra `App: viaja en el modulo (vN, instalada
  vM)` leyendo `app.packaged/app.wanted/app.installed/app.version` de
  `codmctl.sh`.
- **Ciclo probado en hardware:** módulo instalado → app instalada/actualizada por
  el módulo (`app instalada desde el modulo`); eliminar el módulo con el marcador
  `remove` → módulo y app ausentes, `/data/data` de la app borrado, prefs 0/90.
  Evidencia en el archivo local del autor.

Desactivar (marcador `disable`) deja módulo y app instalados pero inertes;
eliminar (marcador `remove`) borra módulo, app y sus datos.

## Novedades v3.2 / app 1.1 (26/10/2026)

- Interruptores en naranja (ON) y gris (OFF); el track de One UI se fuerza a
  opacidad completa para que el naranja no se vea marrón.
- «Abrir CODM» funciona con `<queries>` y fallback `monkey`; verificado con el
  juego cerrado.
- El preset GFX aplicado queda resaltado en naranja; si no hay preset guardado,
  se resalta el que coincide con los valores actuales. «Nativo» 2316×1080/q3
  quedó en naranja tras aplicarlo (captura local del autor).
- «Restaurar todo y dejar stock» abre un selector con dos caminos, cada uno pide
  aceptar y reinicia:
  - **Desactivar módulo:** restaura datos, crea el marcador `disable` y deja el
    módulo instalado pero apagado.
  - **Eliminar módulo y esta app:** restaura, borra
    `/data/adb/modules/codm_s23_120`, desinstala esta app y reinicia.
- Con el módulo apagado la app muestra «MODULO INACTIVO», interruptores grises y
  controles deshabilitados; el estado dice «sin efecto» y las opciones no actúan.
- Ciclo completo probado en hardware: desactivar → stock → reactivar, y
  eliminar → stock → reinstalar. Evidencia en el archivo local del autor.

## Contenido

| Ruta | Función |
| --- | --- |
| `post-fs-data.sh` | Aplica el spoof NX789J antes de zygote, solo en dm3q; guarda props originales |
| `service.sh` | Lanza audio, vigilante Vulkan, worker de prefs, Perf Z e instalador de la app con bloqueo anti-duplicados |
| `files/root_compat.sh` | Detecta Magisk/KernelSU/APatch, versión y `resetprop`; helpers comunes |
| `files/audio_fix.sh` | Solo dm3q: devuelve props Samsung, reinicia HAL y deja audio sano |
| `files/watch.sh` | Arma la capa Vulkan solo con UI de CODM, aplica el perfil y limpia al cerrar |
| `files/codm_env.sh` | Descubre paquetes CODM (global/Garena/Tencent/VNG) por huella de PlayerPrefs, resuelve XML, cuentas y perfiles de `config` |
| `files/game_prefs.sh` | Motor único `apply\|restore\|status`: 1/120 por cuenta, originales exactos por paquete/UID, verificación y reversión |
| `files/state_env.sh` | Estado persistente en `/data/adb/codm_s23_120_state`: sobrevive a las actualizaciones del módulo y adopta los ficheros de v3/v4.0 |
| `files/prefs_watch.sh` | Worker que reaplica 1/120 con el juego cerrado y refresca el doctor tras el desbloqueo |
| `files/doctor.sh` | Diagnóstico de solo lectura con veredicto (`120_LISTO`, `FALTA_ULTRA`, `PANEL_60`…) |
| `files/account.sh` | Lee `lastUserId.xml`; en `auto` registra la cuenta activa y en `confirmed` exige confirmación |
| `files/apply_game_prefs.sh` | Envoltorio v3 de `game_prefs.sh apply` (compatibilidad) |
| `files/restore_game_prefs.sh` | Envoltorio v3 de `game_prefs.sh restore` (compatibilidad) |
| `files/gfx.sh` | Presets visuales 3D/Unity con backup, restauración y detección de override |
| `files/install_app.sh` | Instala/actualiza la app del módulo al arrancar (`pm install -r`); nunca toca una copia del sistema |
| `app/CODMControl.apk` + `app/version.txt` | Copia de la app que viaja en el módulo y el versionCode esperado |
| `config` + `game.packages` | Perfiles (`spoof`, `layer`, `fpslevel`, `account_mode`, `apply_all`, `keys_insert`, `gfx_universal`) y paquetes extra declarados a mano |
| `files/libVkLayer_codmspoof.so` | Capa que reporta Adreno 830 / SM8750 |
| `files/perfz.sh` | Controla Perf Z (SHOW/HIDE) y al desactivar restaura la visibilidad original (1 en esta unidad) |
| `files/perf_mode.sh` | Asegura GameManager `performance` mientras CODM vive y restaura el modo al salir |
| `files/disable_cleanup.sh` | Limpieza al marcar el módulo como desactivado |
| `tools/codmctl.sh` | API de estado y control usada por la app y por consola |
| `toggle.sh` / `action.sh` | Interruptor del perfil (consola / botón Acción de Magisk) |
| `system/vendor/etc/audio_effects_sec.xml` | XML sin `volumemonitor_hw`; `customize.sh` lo retira fuera de dm3q |
| `customize.sh` | Instalación; elimina el XML de audio en equipos que no son dm3q |
| `restore.sh` | Limpieza completa: workers, prefs exactas, GFX, Perf Z, capa y props |
| `uninstall.sh` | Al eliminar el módulo copia el árbol a `/data/local/tmp/codm_deferred` y lanza la limpieza diferida (restore + desinstalar app) |

## Verificar

```sh
su -c 'getprop ro.product.model'            # SM-S918B tras el arranque
su -c 'su -M -c "sh /data/adb/modules/codm_s23_120/tools/codmctl.sh status"'
su -c 'tinymix | grep "AMP Enable Switch"'  # On mientras suena audio
su -c 'cat /data/adb/modules/codm_s23_120/logs/watch.log'
su -c 'cat /data/adb/modules/codm_s23_120/logs/audio_fix.log'
su -c 'cat /data/adb/modules/codm_s23_120/logs/prefs.log'
```

Al abrir CODM, `watch.log` debe mostrar `wm_create_activity: prop activa`,
`capa cargada` y después `prop limpia; copia temporal eliminada`. La capa no debe
quedar en `lib/arm64` del juego. `prefs.log` debe mostrar 1/120 para la UID
confirmada. Un servicio en segundo plano de CODM no debe armar la capa.

En Android 14, la app usa `su -M` para ver `/data/data` de CODM; sin ese flag solo
ve su propio directorio. Si el gestor root no lo soporta, la app cae a `su` normal
y el estado puede aparecer parcial.

## Cuenta activa

- Se lee `shared_prefs/lastUserId.xml` (clave `4e42c67f78`) del paquete detectado.
- En v5, `account_mode=auto` (por defecto) sigue la cuenta activa: la registra en
  `run/account.confirmed` y aplica/guarda originales solo a esa. Si cambias de
  cuenta en el juego, el worker se adapta en la siguiente pasada.
- Si hay varias cuentas y no se puede leer la activa, **no escribe**; el doctor
  devuelve `CUENTA_AMBIGUA`. Nunca se aplica a «todas» por descarte.
- `account_mode=confirmed` mantiene el comportamiento v4 (solo la confirmada),
  `active` exige leer la activa y `all` solo con `apply_all=1` explícito.
- La cuenta usada para verificar en hardware es una cuenta de prueba; las
  demás cuentas del XML no se tocan salvo que sean la activa.
- Al confirmar desde la app se aplica 120 en el acto si CODM está cerrado y las
  prefs son visibles; si no, se aplicará en el siguiente arranque.
- Otra cuenta del teléfono de prueba ya tenía `FramerateCustomizeValue=120` de
  origen; no se modificó.

## KernelSU y APatch

`root_compat.sh` detecta el gestor y busca `resetprop` en las rutas de Magisk,
KernelSU, APatch, `/debug_ramdisk`, `/sbin` y `/system/bin`. Si no lo encuentra,
el módulo entra en modo degradado: no toca props del sistema y mantiene capa,
prefs y controles.

Límite: KernelSU no suele incluir `resetprop`; sin él no hay spoof pre-zygote y
CODM puede quedarse en 90 aunque la capa y las prefs funcionen. APatch y Magisk
sí lo aportan. **Verificado solo en Magisk 30.7 / SM-S918B**; KSU y APatch están
implementados pero no probados en hardware.

## GFX visual

Presets: bajo 1158×540/q0, equilibrado 1552×720/q1, alto 1930×900/q2, nativo
2316×1080/q3. Solo tocan resolución de render 3D y calidad Unity, con backup.
La resolución del teléfono no se toca: son únicamente preferencias del juego.

Resultado verificado (26/10/2026): CODM **reescribe** esas claves al abrir. Se
aplicó «bajo» con el juego cerrado (1158×540/q0); al abrirlo volvió a 1552×720/q1
y el módulo lo reporta como `gfx.overridden=1`. El preset no persiste; la app lo
avisa y permite restaurar. No existe clave de distancia de visión, LOD ni calidad
de texturas/efectos en las preferencias del juego: no se fuerza nada inventado.

## Overlay de FPS (Perf Z)

El overlay es el plugin **Perf Z** de Samsung (`com.samsung.android.perf_z` 4.1.05),
no Game Tools ni "Game Sight". El interruptor de la app lo muestra u oculta en
caliente y guarda el valor original (`run/perfz.orig`); al desactivar o ejecutar
`restore.sh` se devuelve a su valor original. En esta unidad el original es `1`
(visible), así que tras restaurar queda visible. El auto-ocultado al arrancar
depende de que el worker vea `/data/data`; en los arranques de prueba registró
«Perf Z no instalado» y lo dejó visible, mientras que el interruptor de la app sí
funciona con el teléfono desbloqueado.

## Perfil de fluidez (interruptor)

Se aplica solo mientras CODM está vivo: asegura el modo `performance` de
GameManager (guardando el modo previo) y al morir el proceso o al apagar el perfil
devuelve ese modo. No toca GPU, CPU, resolución, densidad, animaciones ni ajustes
de desarrollador. En esta unidad el modo original ya era `performance`, así que el
cambio neto es nulo.

Medición A/B en partida BR real (ventanas de 65 s, térmica 2, SKIN 40,2 → 40,9 °C):
las tres ventanas ON/OFF/ON dieron 117,5 / 117,2 / 117,4 fps, sin diferencias:
el juego ya está en el techo del panel. La GPU permanece en 220 MHz y sostiene 120;
no se fuerza ningún reloj porque no mejora frames y sí subiría temperatura.

## App de control (viaja en el módulo)

**CODM Control by AJ 1.5** (`versionCode 10`, APK
`app/CODMControl.apk`, SHA-256
`91b3f1c1da707ef1594974b9d92f6e83d8cf5aa3654ca70d26e426831cdafed1`) ofrece estado
del módulo, perfil, Perf Z, abrir/cerrar/reintentar CODM, diagnóstico 120,
reaplicar 120, cuenta activa, GFX con resaltado real del preset, visor de logs con
copia, restauración con elección desactivar/eliminar, interruptor de notificación
y baldosa QS. Mantiene una sola sesión root por arranque para que Magisk muestre
su aviso una sola vez. «Abrir CODM» usa el paquete detectado y confirma el
proceso; el estado muestra el paquete y el veredicto del doctor. Requiere root,
no pide INTERNET. Sin root muestra «SIN ACCESO ROOT» y deshabilita controles. Con
el módulo inactivo todos los controles del módulo se ven grises/deshabilitados y
no actúan; el interruptor de notificación es de la app y sigue disponible.

La app **no es opcional de instalar a mano**: el módulo la trae y la mantiene al
día. Instalar el módulo la instala; desinstalar el módulo la quita junto con sus
datos (ver «Desactivar y volver a stock»).

## Desactivar y volver a stock

La app «Restaurar todo y dejar stock» abre un selector con dos opciones. Cada una
pide aceptar, avisa del reinicio y reinicia el teléfono:

1. **Desactivar módulo.** Cierra CODM, ejecuta `restore.sh` (workers, capa, prefs
   exactas, GFX, Perf Z, GameManager y props) y escribe el marcador `disable`; el
   módulo sigue instalado y se puede reactivar en Magisk, KernelSU o APatch.
2. **Eliminar módulo y esta app.** Restaura igual y luego, ya con el teléfono
   arrancado, un worker diferido copiado a `/data/local/tmp/codm_deferred` borra
   `/data/adb/modules/codm_s23_120`, desinstala `com.aj.codmcontrol` con sus datos
   y reinicia. No se puede deshacer; para volver hay que reinstalar módulo y app.

Alternativa manual: desactivar en el gestor root y reiniciar; si el vigilante no
reacciona, ejecutar antes `su -c 'sh /data/adb/modules/codm_s23_120/restore.sh'`.

Con eso desaparecen el XML montado, el spoof, el vigilante y la capa; las prefs de
CODM vuelven a los valores guardados en `/data/adb/codm_s23_120_state/prefs.orig.*`
(en esta unidad 0/90), el GFX vuelve a 1552×720/q1 y Perf Z a su visibilidad
original (`1`, visible). Al desactivar, la app queda instalada pero en «MODULO
INACTIVO»; al eliminar, la app y sus datos se borran con el módulo.

**Verificado en hardware (26/10/2026):** desactivar dejó props stock, sin monturas,
prefs 0/90, GFX 1552×720/q1, Perf Z visible, app en «MODULO INACTIVO» con
interruptores grises y controles deshabilitados; después se reactivó y volvió a
120 con la cuenta confirmada. Eliminar dejó el módulo, la app y sus datos ausentes;
el `uninstall.sh` diferido restauró prefs/GFX/Perf Z/props y desinstaló la app tras
arrancar. Se reinstalaron desde un respaldo del propio teléfono y se volvió a
verificar 120. Evidencia en el archivo local del autor (textos
`after_disable_stock.txt`, `after_remove_stock.txt`, `status_after_redeploy.txt`,
`after_remove_final.txt`, `status_final_v33.txt` y capturas de la app).

## Límites honestos

- Todo lo anterior requiere root. Sin root no se puede spoofear antes de zygote,
  montar el XML ni cargar la capa en el proceso de CODM.
- La copia de la capa en el juego existe solo durante el arranque del proceso; se
  elimina en cuanto Vulkan la mapea.
- No se tocan animaciones del sistema ni ajustes de desarrollador.
- El teléfono debe reiniciarse para que un cambio de estado del módulo tenga
  efecto completo (el XML y el spoof son de arranque).
- Solo se modifica la cuenta activa (o la confirmada, según `account_mode`); el
  resto no se toca.
- El lobby de CODM sigue a 60 fps por diseño; los 120 son en partida BR.
- Eliminar el módulo también desinstala la app de control; no queda módulo, capa
  ni XML, pero para volver hay que reinstalar ambos.
- El GFX escribe solo preferencias del juego; CODM puede reescribirlas al abrir y
  la app lo muestra como «No persistió».
- El A/B se hizo con el jugador quieto dentro de una partida BR real; no cubre
  combate intenso con humo/explosiones. El overlay Perf Z permite verlo en vivo.
- El perfil no eleva los límites térmicos de Samsung. Si el teléfono se calienta,
  el sistema puede bajar la pantalla a 90 fps según su tabla térmica.
- **Universalidad con límites**: prefs y descubrimiento son independientes de la
  marca; el 120 real depende del panel, de la GPU y de que el juego honre la
  clave. En equipos sin panel ≥120 Hz o sin root no hay 120 y el doctor lo dice.
  El spoof y la capa solo se activan solos en dm3q; fuera de ahí son opt-in y
  pueden romper servicios.
- **No se inventa el ajuste de cuenta**: `keys_insert=1` puede insertar las
  claves, pero el juego las reescribe a 90 si el ajuste no está activado en la
  cuenta. La ruta universal es activar 120 una vez en Ajustes del juego y dejar
  que el módulo lo mantenga con el juego cerrado.
- Verificado en S23 Ultra SM-S918B con Android 14 / One UI 6.1.1. Android 15/16,
  One UI 7/8, KernelSU, APatch y otras marcas están implementados pero no probados.
