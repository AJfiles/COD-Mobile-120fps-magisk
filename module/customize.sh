#!/system/bin/sh
# Instalacion del modulo en Magisk, KernelSU o APatch.
# El XML de audio de Samsung solo se conserva en el S23 Ultra (dm3q); en el
# resto de equipos se retira antes de montar el overlay para no tocar el audio.
if ! type ui_print >/dev/null 2>&1; then
    ui_print() { echo "$1"; }
fi

MODPATH=${MODPATH:-$PWD}
DEV=$(getprop ro.product.device)
MODEL=$(getprop ro.product.model)
MFR=$(getprop ro.product.manufacturer)
REL=$(getprop ro.build.version.release)
SDK=$(getprop ro.build.version.sdk)
ABI=$(getprop ro.product.cpu.abi)

ui_print ""
ui_print "CODM 120 FPS multiequipo · by AJ"
ui_print "- Equipo: $MODEL ($DEV), $MFR"
ui_print "- Android $REL (SDK $SDK), ABI $ABI"

case "$DEV" in
    dm3q*)
        ui_print "- Perfil verificado dm3q: spoof NX789J + capa Vulkan + audio Samsung"
        ;;
    *)
        rm -f "$MODPATH/system/vendor/etc/audio_effects_sec.xml"
        rmdir "$MODPATH/system/vendor/etc" "$MODPATH/system/vendor" "$MODPATH/system" 2>/dev/null
        ui_print "- Perfil auto: sin spoof, sin capa Vulkan y sin tocar audio"
        ui_print "- Detecta CODM global/Garena/Tencent/VNG y aplica 1/120 a la cuenta activa"
        ui_print "- Opcional: config con spoof=on / layer=on (bajo tu riesgo)"
        ;;
esac

case "$ABI" in
    arm64*) ;;
    *) ui_print "! ABI $ABI: la capa Vulkan incluida es arm64 y no se cargara (las prefs siguen)" ;;
esac

# KernelSU no incluye resetprop. Si el usuario pidio spoof=compat/on en config,
# se dejan las props en system.prop para que el gestor las aplique al arrancar.
SPOOF_CFG=$(sed -n 's/^spoof=//p' "$MODPATH/config" 2>/dev/null | head -1)
case "$SPOOF_CFG" in
    compat|on)
        . "$MODPATH/files/root_compat.sh"
        root_prepare
        if [ -z "$RP" ]; then
            {
                echo "# codm_s23_120 spoof ($ROOT_MANAGER): se aplica al arrancar; borra este archivo y reinicia para revertir"
                if [ "$SPOOF_CFG" = compat ]; then
                    spoof_model_list
                else
                    spoof_full_list
                fi | sed 's/ / = /'
            } >"$MODPATH/system.prop"
            chmod 644 "$MODPATH/system.prop" 2>/dev/null
            ui_print "- $ROOT_MANAGER sin resetprop: spoof=$SPOOF_CFG se aplicara al reiniciar (system.prop)"
            ui_print "- Para cambiar de perfil de identidad, edita config y reinstala el modulo"
        fi
        ;;
esac

chmod 755 "$MODPATH"/*.sh "$MODPATH"/files/*.sh "$MODPATH"/tools/*.sh 2>/dev/null
chmod 644 "$MODPATH/config" "$MODPATH/module.prop" 2>/dev/null

if [ -f "$MODPATH/app/CODMControl.apk" ]; then
    set_perm_recursive "$MODPATH/app" 0 0 0755 0644 2>/dev/null \
        || chmod -R 755 "$MODPATH/app" 2>/dev/null
    ui_print "- App de control incluida (CODM Control by AJ): se instala sola al arrancar"
    ui_print "- Al desinstalar el modulo, la app y sus datos se quitan tambien"
fi

ui_print "- Instalado. Reinicia para aplicar el perfil."
ui_print ""
