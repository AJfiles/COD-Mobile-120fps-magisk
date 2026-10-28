#!/system/bin/sh
# Devuelve las props originales guardadas para que el HAL de audio (cs35l43)
# inicialice la ruta del altavoz y encienda los amplificadores. Las apps ya
# heredaron la identidad del arranque; CODM conserva su capa y sus prefs.
# Solo dm3q recibe este tratamiento: en otros equipos el modulo no toca audio.
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
LOG=$MODDIR/logs/audio_fix.log
DONE=$MODDIR/run/audio_done
mkdir -p "$MODDIR/logs" "$MODDIR/run" 2>/dev/null
log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

. "$MODDIR/files/root_compat.sh"
root_prepare

if [ -f "$DONE" ]; then
    log "audio ya ajustado en este arranque; salgo"
    exit 0
fi
if [ ! -f "$SPOOF_FLAG" ]; then
    log "sin spoof aplicado; el audio no se toca"
    : >"$DONE"
    exit 0
fi
if ! orig_is_dm3q; then
    log "equipo distinto de dm3q; el audio no se toca"
    : >"$DONE"
    exit 0
fi
if [ ! -f "$ORIG_PROPS" ]; then
    log "faltan props originales; no se toca el audio"
    : >"$DONE"
    exit 0
fi
if [ -z "$RP" ]; then
    log "resetprop no disponible; no se toca el audio"
    : >"$DONE"
    exit 0
fi

i=0
while [ -z "$(pidof android.hardware.audio.service_64)" ] && [ "$i" -lt 90 ]; do
    sleep 1
    i=$((i + 1))
done
sleep 5
log "inicio (espera ${i}s) model=$(getprop ro.product.model)"

restore_orig_props "$ORIG_PROPS" || {
    log "no se pudieron restaurar las props; no se reinicia el HAL"
    exit 1
}
: >"$MODDIR/run/props_restored"
log "props originales restauradas: model=$(getprop ro.product.model) device=$(getprop ro.product.device)"

HAL=$(pidof android.hardware.audio.service_64)
AS=$(pidof audioserver)
log "reinicio hal=$HAL as=$AS"
[ -n "$HAL" ] && kill -9 "$HAL"
[ -n "$AS" ] && kill -9 "$AS"
sleep 12
: >"$DONE"
log "fin hal=$(pidof android.hardware.audio.service_64) as=$(pidof audioserver) model=$(getprop ro.product.model)"
