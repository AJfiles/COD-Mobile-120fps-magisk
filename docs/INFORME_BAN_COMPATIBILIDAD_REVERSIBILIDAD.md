# Auditoría de reversibilidad, compatibilidad, riesgo de ban y viabilidad sin root

**Fecha:** 25–26 de octubre de 2026
**Dispositivo auditado:** Samsung Galaxy S23 Ultra SM-S918B (dm3q), Android 14, build S918BXXU8CYB6, 2316×1080, panel 120 Hz, Magisk 30.7.
**Módulo:** `codm_s23_120` v2.4 (versionCode 6), en `/data/adb/modules/codm_s23_120`.
**Cuenta CODM:** cuenta de prueba (única tocada; UID redactada).
**Evidencia cruda:** `logs/audit_stock_after_disable.txt`, `logs/audit_module_enabled.txt`, `logs/pre_reboot_disable.txt`, `logs/watch.log`, `logs/audio_fix.log`, `logs/prefs.log`.

> **Cómo leer los porcentajes de este informe.** No existe ninguna estadística oficial de compatibilidad ni de baneos por este tipo de módulo. Todos los porcentajes son **estimaciones de ingeniería** basadas en las dependencias técnicas verificadas, en la política pública de Activision y en pruebas de este dispositivo. Se indican como bandas amplias, no como garantías. Lo que sí está verificado en hardware se marca como **VERIFICADO**; lo demás se marca como **ESTIMADO**.

---

## 0. Respuestas directas

| Pregunta | Respuesta corta |
| --- | --- |
| ¿Queda algo fuera del módulo? | **No.** Con el módulo desactivado y el teléfono reiniciado, el XML de audio, las props, las prefs de CODM, Perf Z, GameManager, la capa Vulkan y los procesos vuelven a stock. Solo queda la carpeta inerte del módulo en `/data/adb/modules`. |
| ¿Apagar el módulo devuelve el juego a su estado original? | **Sí, el estado auditado es stock** (sección 2). El juego vuelve a su límite de 90 fps en BR porque desaparecen el spoof, la capa y las prefs 120; la medición de 90 es de pruebas previas sin módulo, no de este ciclo (en este ciclo no se jugó partida). |
| ¿Sirve solo en Samsung? | **Tal cual, solo está verificado en este S23 Ultra.** El desbloqueo de 120 no es un truco "Samsung": el juego cree que el teléfono es un **RedMagic 10 Pro (NX789J)**. Lo específicamente Samsung es el arreglo de audio (HAL, amplificadores cs35l43, GOS, Perf Z). En otras marcas habría que portar el audio y validar GPU/props. Porcentajes en la sección 3. |
| ¿Riesgo de ban? | **Existe y no es cuantificable con rigor.** Es una modificación de identidad del dispositivo y una capa Vulkan dentro del proceso del juego; la política móvil prohíbe el software de terceros no autorizado y los "injectors". La política general de la franquicia menciona sanciones temporales, permanentes y de hardware, pero **no está verificado que el ban de hardware se aplique a CODM**. Estimación subjetiva: **~1 % por sesión, 5–15 % a 3 meses, 15–35 % a 12 meses** en uso normal sin otros cheats. Sección 4. |
| ¿Se puede lograr en un teléfono sin root? | **No para un teléfono arbitrario.** 0 % de replicar este 120 sin root. Solo es 100 % posible si el modelo ya está aceptado por el servidor de CODM (lista interna no pública; entonces no hace falta módulo). Sección 5. |
| ¿Qué se puede mejorar? | Perfil térmico adaptativo, compatibilidad multi-modelo/multi-región, auto-detección de cuenta, verificación de actualizaciones del juego, interfaz de estado y restauración de un toque. Sección 6. |

---

## 1. Qué se toca exactamente

### 1.1 Inventario técnico

| Elemento | Dónde vive | Cuándo se toca | Persistencia | Cómo se revierte |
| --- | --- | --- | --- | --- |
| Identidad del dispositivo (modelo, marca, device, fingerprint, SoC, board) | Props en memoria (`resetprop`) | `post-fs-data.sh`, antes de que arranque zygote | Hasta el siguiente reinicio; luego `audio_fix.sh` devuelve la identidad Samsung al HAL | Reinicio; `restore.sh` también las devuelve |
| `debug.vulkan.layers` | Prop de sistema en memoria | Solo mientras la UI de CODM está abierta | Segundos; se limpia tras mapear la capa | `watch.sh`, `restore.sh`, cierre del juego |
| Capa Vulkan `libVkLayer_codmspoof.so` | Copia temporal en `lib/arm64` de la app; luego solo en memoria del proceso | Al abrir la UI de CODM | La copia se borra a los ~5 s; el mapa queda `(deleted)` hasta que muere el proceso | Cierre del juego; `restore.sh`; `disable_cleanup.sh` |
| Prefs de framerate de CODM | `/data/data/com.activision.callofduty.shooter/shared_prefs/...playerprefs.xml` | Al arrancar el módulo, con el juego cerrado | Datos de app; solo dos claves de la cuenta de prueba | `restore_game_prefs.sh` (0/90), automático al desactivar o `restore.sh` |
| Visibilidad de Perf Z | `/data/data/com.samsung.android.perf_z/shared_prefs/...preferences.xml` | Al arrancar el módulo | Dato de app (0 = mostrar) | `perfz.sh hide`, automático al desactivar o `restore.sh` |
| Modo de GameManager | Servicio GOS | Solo con CODM vivo; guarda el modo previo y lo restaura | Temporal | `perf_mode.sh restore`; en esta unidad el modo original ya era `performance` |
| XML de audio | `/vendor/etc/audio_effects_sec.xml` | Magisk monta una copia parcheada al arrancar | Solo mientras el módulo está activo; la partición no se escribe | Desactivar el módulo y reiniciar |
| HAL de audio y audioserver | Servicios del sistema | `audio_fix.sh` los reinicia una vez tras el spoof | No persiste; vuelven a arrancar solos | Reinicio |
| Whitelist de batería, `peak_refresh_rate`, resolución, densidad, animaciones | Ajustes del sistema | **No se tocan** | — | — |
| APK, código, memoria o archivos del juego | `base.apk` y splits | **No se tocan** | — | — |

### 1.2 Lo que el módulo NO hace

- No modifica el APK ni los splits de CODM.
- No inyecta código, no hookea funciones, no lee ni escribe memoria del juego.
- No cambia sensibilidad, calidad gráfica, texturas, miras, retroceso ni ningún ajuste de combate.
- No toca compras, moneda, progreso ni datos de la cuenta.
- No cambia resolución, densidad, animaciones del sistema ni ajustes de desarrollador.
- No fuerza relojes de CPU/GPU ni límites térmicos.
- No toca las otras cuentas de CODM del teléfono.

### 1.3 Lo que sí puede ver el juego

Esto es lo relevante para el riesgo de ban:

1. **Identidad Java (`android.os.Build`)**: modelo `NX789J`, marca `nubia`, device `NX789J`, fingerprint de Nubia, SoC `SM8750`.
2. **Identidad nativa (`getprop`)**: tras `audio_fix.sh` vuelve a `SM-S918B`/`SM8550`; es decir, **Build Java y props nativas no coinciden**.
3. **GPU**: la capa Vulkan reporta **Adreno 830**; el hardware real es **Adreno 740**.
4. **Librería en el proceso**: `libVkLayer_codmspoof.so` aparece mapeada en `/proc/<pid>/maps` como `(deleted)` mientras el juego vive.
5. **Entorno root**: Magisk, Zygisk Next, Shamiko y LSPosed son detectables por la app si esta consulta el entorno.
6. **Telemetría de rendimiento**: 120 fps en BR en un modelo que el servidor no tiene como compatible es, en sí, un dato anómalo.
7. **Prefs del juego**: `EnableFramerateCustomize=1` y `FramerateCustomizeValue=120` en una cuenta/dispositivo no soportado.

---

## 2. Verificación de reversibilidad (extremo a extremo)

### 2.1 Método

1. Se ejecutó la limpieza al marcar el módulo como desactivado (`disable_cleanup.sh`): prefs 0/90, Perf Z oculto, GameManager intacto, capa y prop limpias.
2. Se reinició con el módulo desactivado.
3. Se desbloqueó con PIN y se ejecutó una auditoría de solo lectura (`audit_stock_after_disable.sh`).
4. Se volvió a activar el módulo, se reinició y se ejecutó la auditoría contraria (`audit_module_enabled.sh`).
5. Se abrió CODM para comprobar que la capa se arma y se carga; luego se cerró y se verificó la limpieza.

### 2.2 Resultado con el módulo desactivado + reiniciado (VERIFICADO)

| Comprobación | Resultado |
| --- | --- |
| Marcador `disable` | Presente |
| XML de audio | SHA-256 `e635c4ea…1b89` (stock), con `volumemonitor_hw`, sin montajes del módulo |
| Props | `ro.product.model=SM-S918B`, `brand=samsung`, `manufacturer=samsung`, `device=dm3q`, `board=kalama`, `soc=SM8550`, fingerprint Samsung |
| Procesos del módulo | Ninguno; sin `watch.sh`, `audio_fix.sh`, `perfz.sh` ni `apply_game_prefs.sh` |
| `debug.vulkan.layers` | Vacío |
| Copia de la capa | Ausente de `lib/arm64` |
| Perf Z | `visibility=1` (oculto), app cerrada |
| Prefs CODM de la cuenta de prueba | `EnableFramerateCustomize=0`, `FramerateCustomizeValue=90` (original) |
| Prefs otras cuentas | una cuenta: 1/120 (ya era así); otra: Enable=1; intactas |
| GameManager | `performance` (era el modo original; el módulo no lo alteró) |
| Resolución y densidad | 1440×3088 física, override 1080×2316; 450/411 dpi (sin cambios) |
| `peak_refresh_rate` | `null` global, `120` en system (original) |
| Artefactos | Sin `/sdcard/codm_ab`, sin scripts nuestros en `/data/local/tmp`, sin backups `.bak_codmfix` |
| Directorio de la app | `base.apk` y splits con fecha de instalación original; `lib/arm64` solo con las librerías del juego |
| CODM | Cerrado |

**Conclusión:** con el módulo desactivado, el sistema y el juego quedan en el estado original. Lo único que permanece es la carpeta del módulo en `/data/adb/modules`, que Magisk no monta cuando está desactivado.

### 2.3 Resultado con el módulo activo + reiniciado (VERIFICADO)

| Comprobación | Resultado |
| --- | --- |
| `post-fs-data.log` | `model=NX789J brand=nubia` antes de zygote |
| `audio_fix.log` | Inicio `model=NX789J` → fin `model=SM-S918B`; HAL y audioserver reiniciados |
| XML de audio | SHA-256 `9e9725af…a296d1`, montado, `volumemonitor_hw=0` |
| Watcher | Vivo (`/proc/2679/cmdline` = `watch.sh`) |
| Prefs de la cuenta de prueba | 1/120; otras cuentas intactas |
| Perf Z | `visibility=0` (visible), app cerrada hasta abrir el juego |
| Apertura de CODM | `wm_create_activity` → prop activa → capa copiada → **mapeada en pid 18449** → prop limpia y copia borrada |
| Cierre de CODM | `proc_kill` → prop limpia, perfil restaurado, `run/perf_state` y `run/game_ui` eliminados |

### 2.4 Qué queda y cómo borrarlo del todo

| Resto | ¿Es un cambio del sistema? | Cómo se elimina |
| --- | --- | --- |
| Carpeta `/data/adb/modules/codm_s23_120` | No; es un módulo desactivado | Desinstalar el módulo en Magisk (ejecuta `uninstall.sh` → `restore.sh`) o borrar la carpeta con root |
| Logs dentro de la carpeta del módulo | No; texto informativo | Se van con la carpeta |
| Magisk, Zygisk, Shamiko, LSPosed | No forman parte del módulo | Desinstalar root/parchear boot; es un cambio aparte, previo al módulo |
| Datos normales de CODM (cachés, XML de la app) | No; los genera el propio juego | Se limpian desde Ajustes o borrando datos de la app |

---

## 3. Compatibilidad por marca y modelo

### 3.1 Qué determina que funcione

1. **Root con Magisk/KernelSU/APatch + Zygisk**: sin esto no hay spoof antes de zygote, ni montaje del XML, ni capa Vulkan.
2. **SoC Snapdragon con GPU Adreno**: la capa reporta Adreno 830; en Mali/Immortalis/Xclipse la identidad GPU no coincide y el juego puede no arrancar o ignorar la capa.
3. **Audio Samsung**: el módulo monta un XML de S23 Ultra y reinicia el HAL; en otro modelo el XML puede no corresponder y dejar el audio roto.
4. **GOS de Samsung**: Perf Z y parte del ecosistema de juego dependen de que `Build.MANUFACTURER=samsung`; en otras marcas no existe.
5. **Cuenta**: las prefs están fijadas a una cuenta en v2.4. Desde v4 el módulo descubre la cuenta activa y desde v5 la sigue automáticamente (`account_mode=auto`) en cualquier cuenta.
6. **Lista de dispositivos de CODM**: el servidor decide qué modelos pueden pedir 120 en BR; el módulo lo engaña haciéndose pasar por un RedMagic 10 Pro.

### 3.2 Porcentajes por marca (ESTIMADO)

"Tal cual" = instalar el módulo v2.4 sin cambios, con root, en la misma cuenta. "Portado" = adaptar XML de audio, props, UID y validar GPU.

| Marca / familia | Tal cual | Portado | Motivo |
| --- | --- | --- | --- |
| Samsung Galaxy S23 Ultra SM-S918B (esta unidad) | **95 %** | **100 %** | Verificado en hardware; solo cambia la versión de firmware |
| Samsung S23/S24/S25 (Snapdragon, One UI) | 40–60 % | 85–90 % | Mismo HAL/GOS, pero el XML de audio y las props son de S23 Ultra |
| Samsung con Exynos o gama media | 10–20 % | 40–60 % | GPU no Adreno; GOS existe, pero la capa y el XML pueden no aplicar |
| Nubia RedMagic 10 Pro (NX789J) | Probablemente no lo necesita | — | El spoof de su identidad desbloquea 120 en esta unidad; no hay lista oficial pública y RedMagic vende 144 fps como **interpolación**, no como soporte nativo del juego |
| ASUS ROG Phone 9 / 9 Pro | Sin verificar | — | Solo reportes comunitarios; ASUS y Activision no publican una lista de modelos con 120 en BR |
| Xiaomi / POCO / Redmi (Snapdragon) | 2–5 % | 30–50 % | Sin GOS/XML Samsung; requiere puerto de audio y validación de capa |
| OnePlus / OPPO / realme (Snapdragon) | 2–5 % | 25–45 % | Igual que Xiaomi; varía por ColorOS/OxygenOS |
| Google Pixel (Tensor) | 1–3 % | 10–25 % | GPU Mali; la identidad GPU falseada no coincide |
| Huawei / Honor sin GMS | 0 % | <10 % | CODM no está disponible oficialmente en esos mercados |
| iPhone | 0 % | 0 % | Otro sistema operativo; Magisk no existe |
| Cualquier Android sin root | **0 %** | **0 %** | Bloqueo de sandbox; ver sección 5 |

### 3.3 Lectura correcta de la tabla

- **No es un módulo "para Samsung" en el sentido del truco de 120.** El 120 se consigue porque el juego cree que el teléfono es un **RedMagic 10 Pro (NX789J)**, una identidad que el servidor acepta para 120 (verificado por spoof en esta unidad). Lo Samsung es el arreglo de audio, GOS y Perf Z.
- **No existe una lista oficial pública de dispositivos con 120 fps en BR.** Ni Activision ni los fabricantes la publican. Que el spoof NX789J funcione demuestra que esa identidad recibe 120, pero no confirma qué otros modelos acepta el servidor ni que un RedMagic 10 Pro real lo ofrezca de serie: su marketing describe 144 fps por interpolación.
- En **otro Samsung** el riesgo no es el rendimiento: es que el XML de audio de S23 Ultra no corresponda a ese modelo y el audio quede roto. Por eso "tal cual" baja al 40–60 %.
- En **otra marca** el trabajo es un port: cambiar el modelo spoofeado, el XML de audio, la identidad GPU de la capa y la UID de la cuenta. No es instalar y listo.
- Estas cifras **no son medidas**: son estimaciones por dependencias técnicas. La única cifra medida es 95 % en esta unidad (todo verificado salvo una prueba de estrés prolongada).

---

## 4. Riesgo de ban

### 4.1 Qué dice la política oficial

La política de Call of Duty: Mobile prohíbe el **"unauthorized third-party software"** y nombra explícitamente los **"injectors, or any other software used to modify game data"**. **No menciona el root de forma explícita.** La política general de la franquicia cita advertencias, suspensiones, **"Permanent bans are lasting and final"**, reseteo de estadísticas y **"Hardware bans apply to the device"**; sin embargo, **no menciona CODM**, así que no está verificado que el ban de hardware se aplique a este juego. El acuerdo de licencia de Activision prohíbe modificar el software o crear trabajos derivados. Fuentes al final.

Sobre el anticheat: Activision no documenta públicamente qué proveedor usa la versión global. Tencent ACE, el candidato habitual para juegos móviles de Tencent, se describe en su material comercial como capaz de **"flagging compromised environments"**, lo que incluye entornos rooteados o emulados. No se ha verificado contractualmente qué módulo exacto lleva CODM ni qué señales evalúa en el servidor.

**Lo importante:** el módulo no es un "cheat de combate", pero sí modifica la identidad del dispositivo y carga una librería propia dentro del proceso del juego. Eso entra en la categoría de modificación no autorizada. **No hay una estadística pública de cuántos usuarios son baneados por este caso concreto.**

### 4.2 Porcentajes estimados

| Escenario | Riesgo estimado | Comentario |
| --- | --- | --- |
| Jugar sin módulo en un dispositivo no soportado | **0 % atribuible** | El juego se queda en 90 fps; no hay modificación |
| Este módulo, uso normal, sin otros cheats | **~1 % por sesión; 5–15 % a 3 meses; 15–35 % a 12 meses** | Estimación subjetiva; depende de cambios del anticheat y de la telemetría del servidor |
| Este módulo + cheats de combate (aimbot, wallhack, etc.) | **>90 %** | La política es explícita y el anticheat es agresivo con esos casos |
| Mostrar en stream la identidad falseada o los logs | Aumenta el riesgo, no cuantificable | La inconsistencia queda publicada |

Las bandas anteriores **no son oficiales**. Se basan en: (a) la modificación es detectable por varias vías; (b) el anticheat de CODM prioriza combate y memoria, no tanto el desbloqueo de fps; (c) una sanción, si llega, puede ser permanente; el ban de hardware aparece en la política general de la franquicia, pero **no se verificó su aplicación a CODM**.

### 4.3 Vectores de detección concretos

1. **Inconsistencia de identidad**: `Build.MODEL=NX789J` y `Build.MANUFACTURER=samsung` a la vez; `Build.SOC_MODEL=SM8750` frente a `SM8550` nativo; fingerprint de Nubia con fabricante Samsung.
2. **GPU**: la capa declara Adreno 830; el driver real es Adreno 740. El renderer y las extensiones Vulkan del driver real pueden delatar la diferencia.
3. **Librería mapeada**: un `.so` con nombre `libVkLayer_codmspoof.so` en el mapa del proceso, aunque el archivo ya no exista en disco.
4. **Entorno root**: Magisk/Zygisk/Shamiko/LSPosed. CODM puede consultar el entorno; el root por sí solo no siempre banea, pero suma.
5. **Telemetría**: 120 fps en BR en un modelo no listado. El servidor ve el rendimiento y el modelo declarado.
6. **Prefs**: los dos valores de framerate en una cuenta que el servidor considera no compatible.

**No se ofrece aquí ninguna técnica para ocultar estos vectores.** Si el riesgo de ban no es aceptable, la opción segura es no usar el módulo. El usuario ya asumió el riesgo con una cuenta nueva.

### 4.4 Comparación honesta

- **Riesgo de usar solo ajustes oficiales en un equipo soportado:** 0 %.
- **Riesgo de este módulo:** bajo-medio, pero real y no medible con precisión.
- **Riesgo de un cheat de combate:** alto; no es comparable.

---

## 5. Viabilidad en teléfonos sin root

### 5.1 Respuesta corta

**0–2 %** de conseguir este mismo 120 en un teléfono Android arbitrario **sin root** y sin máquina virtual. En la práctica: **no es posible**. La única vía no-root que garantiza 120 es que el modelo esté aceptado por el servidor de CODM (lista interna no pública); en ese caso se activa desde los ajustes del juego y no hace falta módulo.

### 5.2 Por qué no es posible

| Requisito para el 120 | Por qué falla sin root |
| --- | --- |
| Cambiar `Build.MODEL` antes de zygote | `ro.product.*` es de solo lectura; zygote cachea `Build` al arrancar. Ninguna app ni `adb shell` normal puede reescribir esas props. |
| Escribir `EnableFramerateCustomize=1` y `FramerateCustomizeValue=120` | El XML está en `/data/data/com.activision.callofduty.shooter`, sandbox de la app. Sin root no se puede leer ni escribir; `run-as` solo funciona en apps debug. |
| Cargar una capa Vulkan dentro de CODM | Android solo carga capas externas si la app es debug, si el sistema es `userdebug` o si la app declara `injectLayers` en el manifiesto. CODM no es debug y no se puede modificar su manifiesto sin recompilar/firmar el APK. |
| Montar un XML de audio parcheado | `/vendor` es de solo lectura y se monta con SELinux; hace falta una superposición de Magisk. |
| Colocar un archivo "en una carpeta especial" | Android no ejecuta código desde `/sdcard`; las carpetas de sistema y las librerías nativas de otra app están fuera del alcance de una app normal. |
| `adb shell` sin root | Corre como usuario `shell`: puede ver logs, otorgar permisos y cambiar algunos ajustes globales, pero no las props `ro.*`, ni datos privados de otra app, ni el proceso del juego. |
| Shizuku / ADB elevado | Da acceso a APIs de sistema con permisos de shell, no a datos privados de CODM ni a props de arranque. |

### 5.3 Caminos evaluados

| Camino | ¿Puede dar 120? | Comentario |
| --- | --- | --- |
| Modelo aceptado por el servidor de CODM | **Sí, si el modelo está aceptado** | No hay lista oficial pública. El spoof NX789J demuestra que esa identidad recibe 120, pero no se verificó en un RedMagic real ni qué otros modelos acepta el servidor |
| App de "GFX tools" o potenciadores | **No** | Suelen requerir root o solo dibujan overlays; no cambian la lista de dispositivos del juego |
| Archivo instalado en una carpeta | **No** | Sin root no hay carpeta ejecutable ni acceso al sandbox de CODM |
| ADB / Shizuku | **No para 120** | Puede ajustar GameManager o refresco; el juego sigue en su límite |
| Accesibilidad / overlay | **No** | Solo dibuja sobre la pantalla; no cambia `Build` ni las prefs |
| Máquina virtual o cloud gaming | Excluido por el usuario | Además no es render local en el teléfono |
| ROM personalizada / bootloader desbloqueado | Es otro modelo de seguridad | Deja de ser un teléfono "stock sin root"; implica riesgos y pérdida de garantía |
| Exploit del sistema | No recomendado | Riesgo de seguridad, inestabilidad y violación de términos; no se investiga aquí |

### 5.4 La herramienta no-root que ya existe

`../herramientas/codm_perf/` ajusta GameManager, whitelist de batería y refresco por ADB sin root. En pruebas reales **no pasó de 90 fps** en BR (60 en lobby). Sirve para estabilidad y scheduling, no para desbloquear 120. Es la prueba empírica de que el límite no está en Android sino en la identificación que hace el juego.

---

## 6. Qué más se puede mejorar en el módulo

### 6.1 Seguridad y reversibilidad

| Mejora | Prioridad | Por qué |
| --- | --- | --- |
| Autodiagnóstico al arrancar (XML montado, prefs accesibles, capa ABI correcta) | Alta | Detecta un módulo roto antes de que el usuario entre a partida |
| Restauración automática si se desinstala o se apaga el teléfono sin limpieza | Alta | Ya existe `uninstall.sh` y `disable_cleanup.sh`; falta cubrir apagado forzado |
| Verificación de versión de CODM y aviso si cambia el esquema de prefs | Alta | Una actualización del juego puede dejar las prefs en un estado inválido |
| Botón de pánico / Acción para restaurar todo sin reiniciar | Media | Útil si el audio o el juego fallan en plena sesión |
| Registro de auditoría exportable | Media | Permite demostrar qué se tocó y qué se restauró |

### 6.2 Compatibilidad

| Mejora | Prioridad | Por qué |
| --- | --- | --- |
| Detección automática de la cuenta activa (`lastUserId.xml`) con confirmación | Alta | Hoy la UID está fijada a mano; permitiría usar la misma instalación con otra cuenta sin tocar las demás |
| XML de audio por modelo (S23/S24/S25, Snapdragon/Exynos) | Alta | Es el principal motivo de fallo fuera del S23 Ultra |
| Paquete configurable (`com.activision.callofduty.shooter` y variantes regionales) | Media | CODM Garena/VNG usan otros paquetes |
| Soporte KernelSU/APatch además de Magisk | Media | Amplía la base de dispositivos rooteados |
| Pruebas en Android 15/16 y One UI 7/8 | Media | Cambios de SELinux y de GOS pueden romper el arranque |
| Modo "solo audio" o "solo 120" para aislar fallos | Media | Facilita el soporte en otros modelos |

### 6.3 Rendimiento y estabilidad

| Mejora | Prioridad | Por qué |
| --- | --- | --- |
| Perfil térmico adaptativo 120→90 con histéresis y aviso | Alta | Mantiene fluidez sin forzar calor; hoy el sistema ya baja a 90 si se calienta, pero el módulo no lo comunica |
| Medición de frame-time y jank por sesión, sin sondeo continuo | Alta | Permite decidir con datos si el perfil ayuda en combate intenso |
| Prueba A/B en combate con humo/explosiones | Alta | El A/B actual se hizo con el jugador quieto |
| No forzar relojes (mantener la decisión actual) | — | Ya verificado: la GPU va a 220 MHz y aun así entrega 120; forzarla solo añade calor |
| Reducir el uso de `logcat` del watcher a solo eventos | Baja | Ya usa el búfer de eventos; se puede medir su impacto |

### 6.4 Interfaz y uso

| Mejora | Prioridad | Por qué |
| --- | --- | --- |
| Baldosa en Ajustes rápidos y notificación de estado | Media | Hoy se depende del botón Acción de Magisk |
| Pantalla de estado: perfil, fps objetivo, temperatura, última sesión | Media | Hace visible lo que el módulo está haciendo |
| Restauración de un toque con confirmación | Media | Reduce el riesgo de dejar prefs a medias |
| Guía de desinstalación con verificación | Baja | El usuario puede comprobar el estado stock sin comandos |

### 6.5 Hacia el juego

- **Validar en combate intenso** antes de añadir cualquier tuning adicional.
- **No tocar ajustes de combate** (sensibilidad, miras, retroceso): el módulo debe seguir siendo solo de identidad/rendimiento.
- **Medir el coste real del watcher**: logcat de eventos + comprobaciones cada 10 s; si se detecta impacto, subir el intervalo.
- **Mantener el principio de no forzar relojes ni térmica**: el techo real es el panel y el sistema ya gestiona el calor.
- **Documentar cada actualización de CODM** que cambie la lista de dispositivos o el esquema de prefs.

---

## 7. Metodología, límites y fuentes

### 7.1 Metodología

- Auditorías de solo lectura ejecutadas como root en el teléfono, con scripts versionados en `research/codm_config/`.
- Comparación de hashes SHA-256 del XML de audio stock y parcheado.
- Lectura de props, mounts, procesos, `/proc/<pid>/maps`, prefs XML y GameManager.
- Ciclo completo desactivar → reiniciar → auditar → reactivar → reiniciar → auditar.
- Prueba de apertura y cierre de CODM para confirmar el armado y la limpieza de la capa.

### 7.2 Límites

- La compatibilidad fuera del S23 Ultra es **estimada**, no medida.
- **No existe una lista oficial pública de dispositivos con 120 fps en BR**; la compatibilidad de un modelo concreto no puede confirmarse contra una fuente de Activision.
- El riesgo de ban **no tiene estadística oficial**; las bandas son subjetivas.
- La política general de la franquicia menciona bans de hardware, pero **no se verificó que se apliquen a CODM**.
- La prueba de 120 en partida es de una sesión anterior (119,84 fps; 23.271 frames, 0 perdidos). En este ciclo no se jugó una partida completa; solo se verificó el mecanismo.
- Una actualización de CODM, de One UI o de Magisk puede invalidar el mecanismo.

### 7.3 Fuentes

- Call of Duty: Mobile — Security & Enforcement Policy (prohíbe "unauthorized third-party software", "injectors" y software que modifique datos del juego; no menciona root): https://support.activision.com/cod-mobile/articles/call-of-duty-mobile-security-enforcement-policy
- Call of Duty — Security and Enforcement Policy (advertencias, suspensiones, "Permanent bans are lasting and final", reseteo de estadísticas, "Hardware bans apply to the device"; no menciona CODM): https://support.activision.com/articles/call-of-duty-security-and-enforcement-policy
- Activision — Software License and Service Agreement: https://www.activision.com/legal/software-terms-of-use
- Android Developers — Security tips (sandbox, datos privados): https://developer.android.com/training/articles/security-tips
- Android NDK — Vulkan validation layers (capas externas; solo app debug, build userdebug o metadato `injectLayers`): https://developer.android.com/ndk/guides/graphics/validation-layer
- Android Open Source Project — Add system properties (`ro.*` de solo lectura, writable only by `init`): https://source.android.com/docs/core/architecture/configuration/add-system-properties
- Tencent Cloud — Anti-Cheat Expert, "flagging compromised environments": https://www.tencentcloud.com/dynamic/blogs/sample-article/101481
- REDMAGIC (cuenta oficial) — RedMagic 10 Pro y 144 fps en CODM: el material describe **interpolación** de frames, no soporte nativo del juego: https://www.facebook.com/redmagicgaming/videos/fyi-the-redmagic10pro-now-supports-144fps-in-codm-/1030928538894190/
- Reporte comunitario, **no confirmado por ASUS ni Activision**, sobre 144 MP / 120 BR en ROG Phone 9 Pro y RedMagic 10 Pro: https://www.facebook.com/LeakersOnDuty/posts/select-high-end-devices-like-rog-phone-9-pro-and-redmagic-10-pro-will-get-144-fp/668457595697733/

> Las fuentes de redes sociales se usan solo como contexto de la lista de dispositivos; no son documentación oficial de Activision. No se encontró una lista oficial pública de modelos compatibles con 120 fps en BR. La política oficial es la que rige el riesgo.
