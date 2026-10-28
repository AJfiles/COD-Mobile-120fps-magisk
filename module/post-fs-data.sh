#!/system/bin/sh
# Perfil de identidad antes de zygote.
# auto: full solo en dm3q (perfil verificado). compat/on: cualquier equipo.
# Si el gestor no trae resetprop (KernelSU), customize.sh genera system.prop
# con las mismas props y este script confirma que el gestor ya las aplico.
MODDIR=${0%/*}
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
LOG=$MODDIR/logs/post-fs-data.log
mkdir -p "$MODDIR/logs" "$MODDIR/run" 2>/dev/null
exec >>"$LOG" 2>&1
echo "=== post-fs-data $(date) ==="

. "$MODDIR/files/root_compat.sh"
root_prepare
. "$MODDIR/files/codm_env.sh"
root_log_boot post-fs-data

rm -f "$SPOOF_FLAG" "$RUN_DIR/spoof_skipped" "$RUN_DIR/no_resetprop" \
      "$RUN_DIR/audio_done" "$RUN_DIR/props_restored" "$RUN_DIR/spoof.via" \
      "$RUN_DIR/spoof.mode"

cur_dev=$(getprop ro.product.device)
cur_mfr=$(getprop ro.product.manufacturer)
echo "equipo original: device=$cur_dev manufacturer=$cur_mfr model=$(getprop ro.product.model)"

spoof_mode() {
    case "$SPOOF_PROFILE" in
        on) echo full ;;
        compat) echo compat ;;
        off) echo off ;;
        *)
            case "$cur_dev" in
                dm3q*) echo full ;;
                *) echo off ;;
            esac
            ;;
    esac
}
mode=$(spoof_mode)

# Un system.prop generado en una instalacion anterior sigue aplicandose aunque
# config diga off: se reporta como activo hasta reinstalar sin el.
if [ "$mode" = "off" ] && [ -f "$MODDIR/system.prop" ] &&
   grep -q '^# codm_s23_120' "$MODDIR/system.prop"; then
    : >"$SPOOF_FLAG"
    echo "system.prop" >"$RUN_DIR/spoof.via"
    echo "on" >"$RUN_DIR/spoof.profile"
    echo "AVISO: system.prop de spoof sigue activo; reinstala el modulo para quitarlo"
    echo "=== fin $(date) ==="
    exit 0
fi

if [ "$mode" = "off" ]; then
    echo "off" >"$RUN_DIR/spoof.profile"
    echo "spoof omitido: perfil=$SPOOF_PROFILE device=$cur_dev"
    : >"$RUN_DIR/spoof_skipped"
    echo "=== fin $(date) ==="
    exit 0
fi
echo "$mode" >"$RUN_DIR/spoof.mode"

if [ -z "$RP" ]; then
    if [ "$(getprop ro.product.model)" = "NX789J" ]; then
        : >"$SPOOF_FLAG"
        echo "system.prop" >"$RUN_DIR/spoof.via"
        echo "on" >"$RUN_DIR/spoof.profile"
        echo "spoof aplicado por system.prop ($mode): model=$(getprop ro.product.model) device=$(getprop ro.product.device)"
    else
        echo "resetprop no disponible ($ROOT_MANAGER) y sin system.prop aplicado; modo degradado"
        echo "off" >"$RUN_DIR/spoof.profile"
        : >"$RUN_DIR/no_resetprop"
    fi
    echo "=== fin $(date) ==="
    exit 0
fi

if ! save_orig_props "$ORIG_PROPS"; then
    echo "ERROR: no se pudieron guardar las props originales; no se aplica el spoof"
    echo "=== fin $(date) ==="
    exit 0
fi
echo "props originales guardadas en $ORIG_PROPS"

case "$mode" in
    full) spoof_props ;;
    compat) spoof_props_model ;;
esac
if [ "$(getprop ro.product.model)" = "NX789J" ]; then
    : >"$SPOOF_FLAG"
    echo "$mode" >"$RUN_DIR/spoof.via"
    echo "on" >"$RUN_DIR/spoof.profile"
    echo "spoof aplicado ($mode): model=$(getprop ro.product.model) brand=$(getprop ro.product.brand) device=$(getprop ro.product.device)"
else
    echo "ERROR: resetprop no confirmo el spoof; se deja el sistema intacto"
    echo "off" >"$RUN_DIR/spoof.profile"
fi

echo "=== fin $(date) ==="
