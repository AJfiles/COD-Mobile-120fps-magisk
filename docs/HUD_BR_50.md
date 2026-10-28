# HUD de BR al 50% (todo menos el mapa) — estado y límite

Fecha: 2026-10-27/28. Cuenta: de prueba (UID redactada). Equipo: SM-S918B (Android 14,
CODM global). Módulo v4.1/13, app 1.5/10. Evidencia:
`s23ultra/evidencia/v3.5_hud_br/`.

Objetivo del usuario: bajar la opacidad del HUD de BR al 50% **en todos los
elementos menos el mapa**, sin mover ni redimensionar nada, solo en esta cuenta.

---

## 1. Los ficheros del HUD no son editables a mano

Ruta real (almacenamiento externo de la app, no `/data/data`):

```
/sdcard/Android/data/com.activision.callofduty.shooter/files/Config/hud/
    HUDLayoutConfig_BR_Auto_<uid>.json
    HUDLayoutConfig_BR_Manaul_<uid>.json
    HUDLayoutConfig_BR2_Auto_<uid>.json
    HUDLayoutConfig_BR2_Manaul_<uid>.json
```

Los cuatro empiezan con la **misma cabecera de 16 bytes** y siguen con datos de
alta entropía, no texto:

| Fichero | Bytes | SHA-256 |
|---|---|---|
| BR_Auto | 1344 | `fa46c4294acba3ebecd66610cc0c1133b89f76f8aac05530334c41afcc82a28a` |
| BR_Manaul | 10304 | `b258c8c9049c0559c83587c392e7cac623e3dd1337d63e8319ae7ad22e4ecc8a` |
| BR2_Auto | 688 | `e9627ca02dcef0012033eb6331bb578e4892bed03e525d76bbb85bc1b53841be` |
| BR2_Manaul | 3312 | `15a51b9ac4a4083b2d37808a6f39e69220dd112b1ee170539fc0632bf1de8d7d` |

```
7d 13 3e 35 e1 b8 53 13 ae ad a0 fe c0 68 7e 15   (idéntico en los cuatro)
```

No hay JSON, ni claves de opacidad legibles, ni estructura parseable: es un
binario opaco producido por el juego. Editarlo a mano no es viable ni seguro;
cualquier byte cambiado puede corromper el layout. **No se ha editado ningún
fichero del HUD.**

## 2. Lo que sí ofrece el juego

El editor de HUD de BR (Ajustes → Controles → Personalizar) expone, **por
elemento seleccionado**, dos deslizadores:

- **Escala** (p. ej. 40% en la captura).
- **Opacidad** (p. ej. 53% en la captura).

y los botones `RESTABLECER`, `SALIR`, `GUARDAR Y USAR`; al salir con cambios
pregunta `GUARDAR` / `DESCARTAR`.

Evidencia: `07_crop_slider.png`, `07_crop_slider2.png`, `07_pilot_50.png`,
`08_after_exit.png`, `09_after_discard.png`.

**Prueba piloto:** se seleccionó un elemento (nombre en pantalla «Conf. de
nube») y se dejó su opacidad en **53%**, sin moverlo ni cambiar su escala. Al
salir se eligió **DESCARTAR**. Resultado: los cuatro ficheros conservan
exactamente los hashes de la tabla anterior (verificado con el juego abierto,
tras el arranque de las 23:35), es decir, el descarte no dejó rastro y el HUD
sigue original.

## 3. Por qué no se aplica por ADB en todos los elementos

- CODM es Unity: no hay árbol de accesibilidad (`uiautomator dump`) con los
  elementos del HUD; solo píxeles.
- Seleccionar cada elemento exige tocar sus coordenadas; un toque mal calculado
  puede **mover** un elemento en vez de seleccionarlo, que es justo lo que el
  encargo prohíbe.
- Hay decenas de elementos; algunos son información estática sin control de
  opacidad y otros (mapa) deben excluirse. Sin una lista fiable de elementos y
  de sus zonas, automatizar es «tocar a ciegas».
- El 0% de opacidad puede **eliminar botones** que dejan de responder; por eso
  el objetivo es 50%, nunca 0%.
- El plan aprobado ordena detenerse sin guardar si la navegación no es fiable.
  Se detuvo en el piloto, sin guardar.

**Conclusión:** el 50% de todo el HUD menos el mapa se hace **desde el editor
del juego**, no por fichero ni por ADB. Es un paso manual de unos minutos en el
dispositivo.

## 4. Procedimiento manual (para el usuario)

1. Abrir CODM → Ajustes → Controles → Personalizar HUD del modo **BR**.
2. Elegir el layout que se use en BR (el editor muestra `BR/General`).
3. Para cada elemento **ajustable** (botones y paneles con deslizador
   Opacidad): seleccionarlo, poner Opacidad ≈50% y **no tocar Escala ni
   posición**. Si el deslizador es discreto, usar el escalón más cercano y
   anotarlo.
4. **No tocar el mapa** (minimapa): dejarlo al 100%.
5. No usar 0% en ningún botón.
6. `GUARDAR Y USAR` (no `SALIR`/`DESCARTAR`).
7. Capturar pantalla del editor y cerrar CODM.

Si un elemento no muestra deslizador de Opacidad, no es ajustable: se documenta
y se deja como está.

## 5. Verificación y reversibilidad (pendiente, gate H1)

Con el juego cerrado, tras guardar:

1. Comparar los cuatro hashes con los de la tabla. Si cambian, el guardado es
   local y persistente.
2. Copiar los `.orig.json` de `evidencia/v3.5_hud_br/` sobre los ficheros
   actuales (mismos permisos/owner, CODM cerrado) y abrir el juego:
   - si el HUD vuelve al original, **manda el fichero local** y el módulo puede
     gestionarlo (H2: `files/hud.sh` con `apply|restore|status`, preset y
     originales por UID);
   - si el servidor lo sobrescribe, el HUD es server-side: no se integra en el
     módulo y el cambio queda solo en la cuenta.
3. Solo si H1 demuestra que el fichero local manda se toca el módulo. Hasta
   entonces, el módulo **no** gestiona el HUD y `module.prop` no cambia por esto.

## 6. Respaldos

- Módulo completo previo: `backup/codm_s23_120_pre_hud_20261027.tar`
  (SHA-256 `57fa96d37b5ae13e10587a0d44aebba73b49ae33226d9218b38068d4c59fe038`).
- HUD originales de la cuenta de prueba: `evidencia/v3.5_hud_br/HUDLayoutConfig_*.orig.json`
  (hashes en `hashes_before.txt`).
- `playerprefs.orig.xml` (SHA-256
  `4d10867c45344656b51d033094e1225cd79bf72424a2a2a7daa18b4039a5798b`) y
  `keys_before.txt` con los valores de fábrica de las claves gráficas.
- APK previa al cambio: `fc201640e78dcb76e1202a0a8b21e3e36d4689005cd1363b208a9968563ae088`.

## 7. Estado

- [x] Respaldos y hashes de los cuatro HUD de BR/BR2 de la cuenta de prueba.
- [x] Confirmado que los ficheros son binarios opacos (cabecera fija).
- [x] Confirmado que el editor tiene opacidad **por elemento**, sin slider
      global documentado; piloto al 53% descartado sin cambios.
- [ ] Aplicar el 50% a todos los elementos menos el mapa desde el editor.
- [ ] Gate H1 (persistencia local vs servidor).
- [ ] Gate H2 (integración en el módulo) solo si H1 pasa.

No se declara hecho: el HUD sigue con los valores originales.
