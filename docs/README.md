# Documentación técnica

Estos documentos son los informes de ingeniería del proyecto, conservados para
que cualquiera pueda auditar qué se verificó, cómo se midió y qué sigue
pendiente. No son material promocional: separan explícitamente **verificado en
hardware** de **estimado o pendiente**.

| Documento | Contenido |
| --- | --- |
| [INFORME_MODULO_V3.md](INFORME_MODULO_V3.md) | Los 9 encargos de la fase v3: qué se hizo, qué se verificó y qué quedó pendiente |
| [UNIVERSAL.md](UNIVERSAL.md) | Investigación y diseño de la v5: qué hace universal al módulo, paquetes regionales, perfiles y protocolo de prueba |
| [ESTADO_CODM.md](ESTADO_CODM.md) | Estado del teléfono de prueba, ciclos de reversión y matriz Android 15/16 |
| [INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md](INFORME_BAN_COMPATIBILIDAD_REVERSIBILIDAD.md) | Inventario de lo que se toca, riesgo de ban, compatibilidad por marca y viabilidad sin root |
| [gfx_keys_test.md](gfx_keys_test.md) | Pruebas G1–G4 de las claves gráficas de CODM (FPSLevel, API, Vulkan, bloom) |
| [HUD_BR_50.md](HUD_BR_50.md) | Estudio del HUD de BR: por qué el 50 % de opacidad no se automatiza |

## Evidencia incluida

| Archivo | Qué demuestra |
| --- | --- |
| [evidencia/timestats_br.txt](evidencia/timestats_br.txt) | Partida BR real: capa de CODM a 120 Hz, 23.271 frames, 0 dropped, 0 jank, 99,08 % a 8 ms |
| [evidencia/status_v5.1_reboot.txt](evidencia/status_v5.1_reboot.txt) | Arranque en frío de la v5.1: 5 workers, prefs 1/120, original 0/90, `doctor=120_LISTO`, app 1.5/10 |
| [evidencia/status_v5_reboot.txt](evidencia/status_v5_reboot.txt) | Arranque en frío de la v5.0: workers, prefs 1/120, original 0/90, `doctor=120_LISTO` |
| [evidencia/v41_persistencia.txt](evidencia/v41_persistencia.txt) | Los originales sobreviven a la actualización del módulo (v4.0 → v4.1) |

Las capturas de pantalla y los volcados completos del entorno de prueba no se
publican: contienen datos personales. Los identificadores del dispositivo y de
las cuentas usadas para verificar están redactados en estos documentos
(`UID_PRUEBA`, `UID_OTRA_*`); las referencias a `evidencia/…` y `logs/…`
apuntan al archivo local del autor y no forman parte de este repositorio.
