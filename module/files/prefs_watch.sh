#!/system/bin/sh
# Worker de prefs: reaplica el framerate cuando el juego esta cerrado.
# Cubre el primer arranque (la cuenta aun no existe), cambios de cuenta y
# reescrituras del juego al salir. Idempotente: solo escribe si hace falta.
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/codm_env.sh"
LOG=$LOG_DIR/prefs.log
LOCK=$RUN_DIR/prefs_watch.lock
mkdir -p "$LOG_DIR" "$RUN_DIR" 2>/dev/null

if ! mkdir "$LOCK" 2>/dev/null; then
    other=$(cat "$LOCK/pid" 2>/dev/null)
    if [ -n "$other" ] && [ -d "/proc/$other" ] &&
       grep -q "prefs_watch.sh" "/proc/$other/cmdline" 2>/dev/null; then
        exit 0
    fi
    rm -rf "$LOCK"
    mkdir "$LOCK" 2>/dev/null || exit 1
fi
echo $$ >"$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT
trap 'exit 0' INT TERM

echo "$(date '+%F %T') worker prefs v4 iniciado (pid $$)" >>"$LOG"
while :; do
    [ -e "$MODDIR/disable" ] && { echo "$(date '+%F %T') modulo desactivado; worker prefs sale" >>"$LOG"; break; }
    if ! codm_any_running; then
        sh "$MODDIR/files/game_prefs.sh" apply --quiet >>"$LOG" 2>&1
    fi
    # Primer ciclo tras el desbloqueo: recalcula el veredicto del doctor, que
    # en el arranque solo pudo ver /data cifrado.
    if [ ! -e "$RUN_DIR/doctor.unlocked" ] &&
       [ "$(getprop sys.user.0.ce_available 2>/dev/null)" = "true" ]; then
        sh "$MODDIR/files/doctor.sh" >/dev/null 2>&1
        : >"$RUN_DIR/doctor.unlocked"
    fi
    sleep 30
done
