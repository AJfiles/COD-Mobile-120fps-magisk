#!/system/bin/sh
# Enciende o apaga el perfil de fluidez del modulo sin reiniciar.
# No desactiva el desbloqueo de 120 (spoof + capa + prefs): para eso,
# restore.sh + desactivar el modulo en Magisk + reiniciar.
case "$0" in */*) MODDIR=${0%/*};; *) MODDIR=.;; esac
MODDIR=$(cd "$MODDIR" && pwd)
LOG=$MODDIR/logs/toggle.log
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
mkdir -p "$MODDIR/logs" 2>/dev/null
log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

. "$MODDIR/files/codm_env.sh"
FLAG=$STATE_DIR/perf_state
running() { codm_any_running; }
cur_pkg() { p=$(codm_running_pkg); printf '%s\n' "${p:-$(codm_primary_pkg)}"; }

status() {
    if [ "$(cat "$FLAG" 2>/dev/null)" = "off" ]; then
        echo "perfil de fluidez: APAGADO"
    else
        echo "perfil de fluidez: ENCENDIDO"
    fi
    if [ -f "$STATE_DIR/perf.state" ]; then
        echo "aplicado ahora: si"
    else
        echo "aplicado ahora: no (se aplica al abrir CODM)"
    fi
}

case "$1" in
    on)
        echo on >"$FLAG"
        pkg=$(cur_pkg)
        running && CODM_PKG="$pkg" sh "$MODDIR/files/perf_mode.sh" apply
        log "perfil de fluidez ENCENDIDO (aplicado ahora: $([ -f "$STATE_DIR/perf.state" ] && echo si || echo no))"
        echo "perfil de fluidez ENCENDIDO"
        ;;
    off)
        echo off >"$FLAG"
        pkg=$(cur_pkg)
        running && CODM_PKG="$pkg" sh "$MODDIR/files/perf_mode.sh" restore
        log "perfil de fluidez APAGADO"
        echo "perfil de fluidez APAGADO"
        ;;
    status|"")
        status
        ;;
    *)
        echo "uso: $0 on|off|status" >&2
        exit 2
        ;;
esac
