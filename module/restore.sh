#!/system/bin/sh
# Limpieza completa para desactivar el modulo sin dejar rastro:
# detiene trabajadores, borra la capa de todos los paquetes, restaura prefs de
# CODM, GFX, Perf Z, GameManager y devuelve las props originales del arranque.
# Uso: sh /data/adb/modules/codm_s23_120/restore.sh
# Despues: desactivar el modulo en el gestor root y reiniciar.
MODDIR=$(cd "${0%/*}" && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
LOG=$MODDIR/logs/restore.log
mkdir -p "$MODDIR/logs" "$MODDIR/run" 2>/dev/null
. "$MODDIR/files/root_compat.sh"
root_prepare
. "$MODDIR/files/codm_env.sh"
log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

log "=== restore $(date) ==="

alive() {
    [ -n "$1" ] && [ -d "/proc/$1" ] && grep -q "$2" "/proc/$1/cmdline" 2>/dev/null
}
stop_worker() {
    name=$1
    script=$2
    pidf=$MODDIR/run/$name.pid
    p=$(cat "$pidf" 2>/dev/null)
    if alive "$p" "$script"; then
        # watch/prefs corren con setsid: matar el grupo alcanza al pipeline.
        kill -TERM "$p" 2>/dev/null
        kill -TERM -"$p" 2>/dev/null
        sleep 1
        kill -9 "$p" 2>/dev/null
        kill -9 -"$p" 2>/dev/null
        log "detenido $name (pid $p)"
    fi
    rm -f "$pidf"
}
stop_worker watch "$MODDIR/files/watch.sh"
stop_worker audio_fix "$MODDIR/files/audio_fix.sh"
stop_worker prefs "$MODDIR/files/prefs_watch.sh"
stop_worker perfz "$MODDIR/files/perfz.sh"
rm -rf "$MODDIR/run/watch.lock" "$MODDIR/run/prefs_watch.lock" 2>/dev/null
rm -f "$MODDIR/run/game_ui" "$MODDIR/run/disable_cleaned" 2>/dev/null
setprop debug.vulkan.layers ""

if [ -f "$MODDIR/system.prop" ] && grep -q '^# codm_s23_120' "$MODDIR/system.prop"; then
    rm -f "$MODDIR/system.prop"
    : >"$MODDIR/run/spoof.needs_reboot"
    log "system.prop de spoof eliminado; la identidad original vuelve al reiniciar"
fi

pkgs=$(codm_packages force)
for p in $pkgs; do
    if pidof "$p" >/dev/null 2>&1; then
        # Necesario para que el juego no reescriba las prefs al salir.
        am force-stop "$p" >/dev/null 2>&1
        log "CODM cerrado ($p) para restaurar datos"
    fi
done
sleep 2

for p in $pkgs; do
    apk=$(pm path "$p" 2>/dev/null | head -n1 | sed 's/^package://')
    if [ -n "$apk" ]; then
        target=$(dirname "$apk")/lib/arm64/libVkLayer_codmspoof.so
        [ -f "$target" ] && rm -f "$target" && log "capa del juego eliminada ($p)"
    fi
    rm -f "/data/data/$p/shared_prefs/$p.v2.playerprefs.xml.bak_codmfix" 2>/dev/null
done

CODM_PKG="$(printf '%s\n' "$pkgs" | head -1)" sh "$MODDIR/files/perf_mode.sh" restore >/dev/null 2>&1 &&
    log "GameManager restaurado a su modo guardado"
rc=0
sh "$MODDIR/files/gfx.sh" restore >/dev/null 2>&1 && log "GFX restaurado" || { log "GFX sin backup o no restaurado"; rc=1; }
sh "$MODDIR/files/game_prefs.sh" restore >>"$LOG" 2>&1 && log "prefs de CODM restauradas" || { log "prefs de CODM no restauradas"; rc=1; }
sh "$MODDIR/files/perfz.sh" hide >/dev/null 2>&1 && log "Perf Z oculto" || { log "Perf Z no restaurado"; rc=1; }

if [ -n "$RP" ] && [ -f "$ORIG_PROPS" ]; then
    if restore_orig_props "$ORIG_PROPS"; then
        : >"$MODDIR/run/props_restored"
        rm -f "$SPOOF_FLAG"
        log "props originales restauradas: model=$(getprop ro.product.model) device=$(getprop ro.product.device)"
    else
        log "no se pudieron restaurar las props originales"
        rc=1
    fi
else
    log "sin props guardadas; el reinicio devuelve la identidad original"
fi

# El estado persistente solo se borra cuando no queda nada por revertir.
left=$(ls "$STATE_DIR"/prefs.orig.* "$STATE_DIR"/fpslevel.orig.* \
        "$STATE_DIR"/gfx.orig "$STATE_DIR"/perfz.orig 2>/dev/null)
if [ -z "$left" ]; then
    rm -rf "$STATE_DIR"
    log "estado persistente eliminado (sin registros pendientes)"
else
    log "quedan registros de reversión en $STATE_DIR; se conservan"
fi

log "limpio; desactiva el modulo en el gestor root y reinicia para quitar XML y capa"
log "=== fin restore ==="
exit "$rc"
