# Pruebas de las 4 claves gráficas pendientes (G1–G4)

Fecha: 2026-10-27. Cuenta: de prueba (UID redactada). Dispositivo: SM-S918B (One UI 6.1, Android 14).
Módulo v3.4/11 activo, app 1.4/9. Calidad gráfica del juego: BAJA (sin cambios durante las pruebas).
Evidencia: `s23ultra/evidencia/v3.5_gfx_tests/`.

Método: `dumpsys SurfaceFlinger --timestats -dump` por ventanas (sin sondeo periódico), diff con
`timestats_diff.py`. Edición de claves solo con CODM cerrado, sobre el mismo inodo, y readback.

---

## G1 — FPSLevel (5 = ULTRA, 3 = MUY ALTA)

**Pregunta:** ¿el nivel global limita los 120 de la cuenta, o la cuenta lo overridea?

**Hechos medidos**

| Paso | Resultado |
|---|---|
| Edición por fichero `FPSLevel=5 → 4` con CODM cerrado | Revertida por el juego al arrancar (`FPSLevel=5`); el fichero no manda. |
| Cambio desde el menú del juego a MUY ALTA | Escrito **en vivo** en `playerprefs.xml` (`FPSLevel=3`, readback con el juego abierto). |
| MUY ALTA en precalentamiento BR (3 capturas, >3 min) | Contador del juego: **40 FPS**. Avión: 108. |
| Cambio desde el menú a ULTRA en la partida en curso | Escrito en vivo (`FPSLevel=5`, readback) y **aplicado sin reiniciar**: contador 119–120. |
| Ventana ULTRA en partida (198 s, jugador activo) | **22.997 frames, 0 dropped, 0 janky**; p2p 120 Hz (7–9 ms) = 22.415 (97,5 %), 60 Hz = 535, lentos = 47, congelaciones = 0; 116,2 fps medios incluyendo lobby. |

**Conclusión:** el 120 efectivo depende de `FPSLevel=5 (ULTRA)`. Con MUY ALTA (3) el juego
renderiza a 40 fps en la zona 3D de precalentamiento aunque las claves de cuenta
(`EnableFramerateCustomize=1`, `FramerateCustomizeValue=120`) sigan puestas; por tanto la
configuración de cuenta **no** overridea el nivel global. El cambio desde el menú se persiste
al instante por el propio juego; la edición del XML a mano se pierde al arrancar.

**Límite de la evidencia:** con MUY ALTA no se aisló una ventana `timestats` en suelo de
partida (el usuario revirtió a ULTRA en la misma partida). Los 40 fps de MUY ALTA son lectura
del contador del juego (3 capturas) y observación directa del usuario, no histograma.

Evidencia: `g1_match_launch2.png`, `g1_plane.png`, `g1_plane2.png` (40 FPS, MUY ALTA);
`g1_inmatch1.png` (108, MUY ALTA); `g1_ultra_current.png`, `state_now.png`, `state_now2.png`
(119–120, ULTRA); `g1_ultra_t1.txt` → `g1_ultra_t2.txt` (ventana 198 s).

---

## G2 — kUserGraphicApi (1 → 0)

**Resultado: la clave no es controlable por fichero.**
Con CODM cerrado se escribió `kUserGraphicApi=0` (readback correcto). Al arrancar el juego
(PID 9453) el propio juego la reescribió a **1** en ~20 s. No hay ventana en partida que medir:
el valor 0 no se aplica en esta build.

**Línea base (Vulkan):** el arranque del 21:41 (PID 25882) carga
`VK_LAYER_CODM_GPU_SPOOF` desde `libVkLayer_codmspoof.so` y `AdrenoVK-0`
(`/vendor/lib64/hw/vulkan.adreno.so`); SurfaceFlinger registra «Vulkan swapchain already set up».
GPU reportada por el juego: Adreno 830 Vulkan 1.1.0 (spoof). Evidencia:
`g2_baseline_vulkan_logcat.txt`.

**Conclusión:** el API gráfico lo decide el juego; no se puede forzar GLES desde el XML.

---

## G3 — CODM_ALL_EnableVulkan (1 → 0)

**Resultado: persiste, pero no cambia el API en este equipo.**
`CODM_ALL_EnableVulkan=0` sobrevivió al arranque (readback 0), el juego puso
`kUserGraphicApi=2` y **siguió usando Vulkan**: log del PID 11946 con
`GPMSDK … Adreno (TM) 830 Vulkan 1.1.0` y la capa mapeada (`codmspoof` ×4 en `/proc/<pid>/maps`).
No hubo cambio de API ni de capa que medir.

**Conclusión:** el valor 0 se interpreta como «automático» (o se ignora) y en este hardware
auto resuelve a Vulkan. No sirve para desactivar Vulkan ni la capa.

---

## G4 — CODM_ALL_EnableBloom_Br_2Show (0 → 1)

**Resultado: la clave no es controlable por fichero.**
Con CODM cerrado se escribió 1 (readback 1). Al arrancar (PID 14321) el juego la reescribió a
**0**. No hay efecto visual que evaluar: el valor 1 no sobrevive al arranque.

**Conclusión:** el bloom de BR no es ajustable por XML en esta build; se descarta.

---

## Resumen G1–G4

| Clave | ¿Persiste al arrancar? | ¿Afecta al rendimiento/API? | Uso |
|---|---|---|---|
| `FPSLevel` | Solo el valor puesto desde el menú del juego | **Sí: 3 → 40 fps; 5 → 120** | Obligatorio en ULTRA |
| `kUserGraphicApi` | No (el juego la reescribe) | No controlable | Descartada |
| `CODM_ALL_EnableVulkan` | Sí | Ninguno observado (auto → Vulkan) | Inútil en este equipo |
| `CODM_ALL_EnableBloom_Br_2Show` | No (el juego la reescribe) | No controlable | Descartada |

**Implicación para portabilidad:** el único ajuste load-bearing es el par
`EnableFramerateCustomize=1` + `FramerateCustomizeValue=120` **junto con `FPSLevel=5`**. El módulo
actual no gestiona `FPSLevel`; en un equipo nuevo, sin ULTRA seleccionado en el menú, los 120
no están garantizados.

---

## Restauración

Valores finales objetivo: `FPSLevel=5`, `kUserGraphicApi=1`, `CODM_ALL_EnableVulkan=1`,
`CODM_ALL_EnableBloom_Br_2Show=0`. Calidad gráfica del juego: BAJA. Se verifica por readback
tras cerrar el juego al final de cada brazo.
