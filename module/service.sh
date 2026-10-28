#!/system/bin/sh
# Magisk, KernelSU y APatch ejecutan este script al final del arranque.
# Trabajadores:
#  - audio_fix.sh: solo en dm3q, devuelve props originales y reinicia el HAL.
#  - watch.sh: detecta la UI de cualquier paquete CODM, arma la capa si el
#    perfil lo permite, aplica el perfil de fluidez y limpia al cerrar.
#  - prefs_watch.sh: mantiene 1/120 en la cuenta activa mientras el juego
#    esta cerrado (primer arranque, cambios de cuenta, reescrituras al salir).
#  - perfz.sh: muestra el overlay Perf Z (Samsung) si esta instalado.
#  - install_app.sh: instala la app de control incluida en el modulo si falta.
MODDIR=${0%/*}
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
LOG=$MODDIR/logs/service.log
mkdir -p "$MODDIR/logs" "$MODDIR/run" 2>/dev/null

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }
alive() {
    [ -n "$1" ] && [ -d "/proc/$1" ] && grep -q "$2" "/proc/$1/cmdline" 2>/dev/null
}

. "$MODDIR/files/root_compat.sh"
root_prepare
root_log_boot service

start_worker() {
    name=$1
    script=$2
    pidf=$MODDIR/run/$name.pid
    if [ -f "$pidf" ]; then
        old=$(cat "$pidf" 2>/dev/null)
        if alive "$old" "$script"; then
            log "$name ya activo (pid $old)"
            return 0
        fi
    fi
    if [ -x /system/bin/setsid ]; then
        /system/bin/setsid /system/bin/sh "$script" >>"$LOG" 2>&1 &
    else
        nohup /system/bin/sh "$script" >>"$LOG" 2>&1 &
    fi
    echo $! >"$pidf"
    log "$name lanzado (pid $!)"
}

# Evita dos servicios si el script se relanza sin reiniciar.
lock=$MODDIR/run/service.lock
if ! mkdir "$lock" 2>/dev/null; then
    old=$(cat "$lock/pid" 2>/dev/null)
    if alive "$old" "$MODDIR/service.sh"; then
        log "servicio ya activo (pid $old); salgo"
        exit 0
    fi
    rm -rf "$lock"
    mkdir "$lock" 2>/dev/null || exit 1
fi
echo $$ >"$lock/pid"

log "servicio de arranque (pid $$) gestor=$ROOT_MANAGER model=$(getprop ro.product.model)"
# Limpia un estado de perfil que haya quedado de una sesion anterior.
sh "$MODDIR/files/perf_mode.sh" restore >/dev/null 2>&1
rm -f "$MODDIR/run/doctor.unlocked"
start_worker audio_fix "$MODDIR/files/audio_fix.sh"
start_worker watch "$MODDIR/files/watch.sh"
start_worker prefs "$MODDIR/files/prefs_watch.sh"
start_worker perfz "$MODDIR/files/perfz.sh"
start_worker app "$MODDIR/files/install_app.sh"
# Deja cacheado el veredicto del doctor para el estado de la app.
sh "$MODDIR/files/doctor.sh" >/dev/null 2>&1
log "trabajadores lanzados"
