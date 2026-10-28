#!/system/bin/sh
# Vigilante multi-paquete. Detecta la UI de cualquier CODM instalado, aplica el
# perfil de fluidez y, solo si el perfil de capa lo permite, arma la capa Vulkan.
# Al cerrar el juego restaura el perfil y reaplica 120 en cuanto el XML queda libre.
PKG_FALLBACK=com.activision.callofduty.shooter
LAYER=VK_LAYER_CODM_GPU_SPOOF
case "$0" in */*) MODDIR=${0%/*};; *) MODDIR=.;; esac
MODDIR=$(cd "$MODDIR/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/codm_env.sh"
. "$MODDIR/files/root_compat.sh"
root_prepare
SRC=$MODDIR/files/libVkLayer_codmspoof.so
NAME=libVkLayer_codmspoof.so
LOG=$LOG_DIR/watch.log
ARMED=$RUN_DIR/game_ui
LOCK=$RUN_DIR/watch.lock
CURRENT_PKGS=

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }
set_layer_prop() { setprop debug.vulkan.layers "$LAYER"; }
clear_prop() { setprop debug.vulkan.layers ""; }

layer_enabled() {
    case "$LAYER_PROFILE" in
        on) return 0 ;;
        off) return 1 ;;
        *) orig_is_dm3q && return 0; return 1 ;;
    esac
}

refresh_pkgs() {
    CURRENT_PKGS=$(codm_packages)
    [ -n "$CURRENT_PKGS" ] || CURRENT_PKGS=$PKG_FALLBACK
}

if ! mkdir "$LOCK" 2>/dev/null; then
    other=$(cat "$LOCK/pid" 2>/dev/null)
    if [ -n "$other" ] && [ -d "/proc/$other" ] && grep -q "$MODDIR/files/watch.sh" "/proc/$other/cmdline" 2>/dev/null; then
        log "otro vigilante activo (pid $other); salgo"
        exit 0
    fi
    rm -rf "$LOCK"
    mkdir "$LOCK" 2>/dev/null || exit 1
fi
echo $$ >"$LOCK/pid"
watchdog_pid=
helper_pid=
trap '[ -n "$watchdog_pid" ] && kill "$watchdog_pid" 2>/dev/null; [ -n "$helper_pid" ] && kill "$helper_pid" 2>/dev/null; clear_prop; rm -f "$ARMED"; CODM_PKG="$PKG_FALLBACK" sh "$MODDIR/files/perf_mode.sh" restore >/dev/null 2>&1; rm -rf "$LOCK"' EXIT
trap 'exit 0' INT TERM

game_libdir() {
    pkg=$1
    apk=$(pm path "$pkg" 2>/dev/null | head -n1 | sed 's/^package://')
    [ -n "$apk" ] || return 1
    d=$(dirname "$apk")/lib/arm64
    [ -d "$d" ] || return 1
    echo "$d"
}

target_path() {
    d=$(game_libdir "$1") || return 1
    echo "$d/$NAME"
}

install_layer() {
    pkg=$1
    [ -f "$SRC" ] || { log "install: falta $SRC"; return 1; }
    libdir=$(game_libdir "$pkg") || { log "install: pm path vacio para $pkg"; return 1; }
    target=$libdir/$NAME
    if [ -f "$target" ] && cmp -s "$SRC" "$target"; then
        return 0
    fi
    tmp=$libdir/.codmspoof.new.$(date +%s%N)
    cp -f "$SRC" "$tmp" || { log "install: cp fallo"; return 1; }
    chown system:system "$tmp" 2>/dev/null
    chmod 644 "$tmp"
    restorecon "$tmp" 2>/dev/null
    mv -f "$tmp" "$target" || { log "install: mv fallo"; return 1; }
    log "install: capa copiada para $pkg"
    return 0
}

remove_layer_copy() {
    pkg=$1
    libdir=$(game_libdir "$pkg") || return 0
    target=$libdir/$NAME
    if [ -f "$target" ]; then
        rm -f "$target" && log "copia temporal eliminada ($pkg)"
    fi
}

layer_mapped() {
    pkg=$1
    for p in $(pidof "$pkg" 2>/dev/null); do
        grep -q codmspoof "/proc/$p/maps" 2>/dev/null && return 0
    done
    return 1
}

ui_alive() {
    pkg=$1
    dumpsys activity activities 2>/dev/null | grep -q "ActivityRecord{.*$pkg/"
}

confirm_and_cleanup() {
    pkg=$1
    target=$2
    n=0
    while [ "$n" -lt 300 ]; do
        if layer_mapped "$pkg"; then
            log "capa cargada ($pkg pid $(pidof "$pkg"))"
            sleep 5
            clear_prop
            [ -n "$target" ] && rm -f "$target"
            log "prop limpia; copia temporal eliminada"
            return 0
        fi
        sleep 0.1
        n=$((n + 1))
    done
    clear_prop
    [ -n "$target" ] && rm -f "$target"
    rm -f "$ARMED"
    log "capa NO confirmada en 30 s ($pkg); prop limpia y copia eliminada"
    return 1
}

close_game() {
    reason=$1
    [ -n "$helper_pid" ] && kill "$helper_pid" 2>/dev/null
    clear_prop
    for p in $CURRENT_PKGS; do
        remove_layer_copy "$p"
    done
    CODM_PKG="${2:-$PKG_FALLBACK}" sh "$MODDIR/files/perf_mode.sh" restore >/dev/null 2>&1
    rm -f "$ARMED"
    log "$reason: prop limpia; perfil restaurado"
    # El juego puede reescribir claves al salir: reaplica cuando el XML quedo libre.
    ( sleep 3; sh "$MODDIR/files/game_prefs.sh" apply --quiet >>"$LOG" 2>&1 ) &
}

arm_layer() {
    pkg=$1
    if [ -f "$ARMED" ]; then
        return 0
    fi
    : >"$ARMED"
    printf '%s\n' "$pkg" >"$ARMED"
    CODM_PKG="$pkg" sh "$MODDIR/files/perf_mode.sh" apply >/dev/null 2>&1
    if ! layer_enabled; then
        log "$pkg: UI activa; capa desactivada por perfil ($LAYER_PROFILE)"
        return 0
    fi
    set_layer_prop
    log "$pkg: prop activa"
    if install_layer "$pkg"; then
        target=$(target_path "$pkg" 2>/dev/null)
        ( confirm_and_cleanup "$pkg" "$target" ) &
        helper_pid=$!
    else
        clear_prop
        rm -f "$ARMED"
        log "$pkg: no se pudo instalar la capa; prop limpia"
    fi
}

# Cierra el perfil si el usuario termina la ultima actividad del juego aunque el
# proceso siga vivo por un servicio. Se comprueba una sola vez, 5 s despues.
check_ui_finished() {
    pkg=$1
    sleep 5
    if ! ui_alive "$pkg"; then
        [ -n "$helper_pid" ] && kill "$helper_pid" 2>/dev/null
        CODM_PKG="$pkg" sh "$MODDIR/files/perf_mode.sh" restore >/dev/null 2>&1
        rm -f "$ARMED"
        log "UI cerrada ($pkg); perfil restaurado"
    fi
}

[ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt 65536 ] && mv -f "$LOG" "$LOG.1"
refresh_pkgs
log "inicio del vigilante (pid $$) paquetes=$(printf '%s' "$CURRENT_PKGS" | tr '\n' ' ')"
clear_prop
rm -f "$ARMED"

for p in $CURRENT_PKGS; do
    cur=$(pidof "$p")
    [ -n "$cur" ] || continue
    if layer_mapped "$p"; then
        log "juego ya activo con capa ($p pid $cur)"
        : >"$ARMED"
        printf '%s\n' "$p" >"$ARMED"
    else
        log "juego ya activo SIN capa ($p pid $cur); hay que reiniciarlo"
    fi
done

watchdog() {
    while :; do
        sleep 10
        if [ -e "$MODDIR/disable" ]; then
            if [ ! -f "$RUN_DIR/disable_cleaned" ]; then
                log "marcador disable detectado; restauro datos de app"
                sh "$MODDIR/files/disable_cleanup.sh" >>"$LOG" 2>&1
                : >"$RUN_DIR/disable_cleaned"
            fi
        else
            rm -f "$RUN_DIR/disable_cleaned"
        fi
        refresh_pkgs
        any=0
        for p in $CURRENT_PKGS; do
            pidof "$p" >/dev/null 2>&1 && { any=1; break; }
        done
        if [ "$any" = 1 ]; then
            if [ -f "$ARMED" ] && [ ! -f "$STATE_DIR/perf.state" ]; then
                p=$(head -1 "$ARMED" 2>/dev/null)
                CODM_PKG="${p:-$PKG_FALLBACK}" sh "$MODDIR/files/perf_mode.sh" apply >/dev/null 2>&1
            fi
        else
            if [ -f "$STATE_DIR/perf.state" ] || [ -f "$ARMED" ]; then
                clear_prop
                for p in $CURRENT_PKGS; do
                    remove_layer_copy "$p"
                done
                CODM_PKG="$PKG_FALLBACK" sh "$MODDIR/files/perf_mode.sh" restore >/dev/null 2>&1
                rm -f "$ARMED"
                log "guard: juego cerrado; perfil restaurado"
            fi
        fi
    done
}

watchdog &
watchdog_pid=$!

while :; do
    refresh_pkgs
    logcat -b events -T "$(date '+%m-%d %H:%M:%S.000')" \
        -s am_proc_start:I -s am_proc_died:I -s am_kill:I \
        -s wm_create_activity:I -s wm_resume_activity:I -s wm_restart_activity:I \
        -s wm_relaunch_resume_activity:I -s wm_finish_activity:I -s wm_destroy_activity:I 2>/dev/null |
    while IFS= read -r line; do
        hit=
        for p in $CURRENT_PKGS; do
            case "$line" in
                *"$p,"*|*"$p/"*) hit=$p; break ;;
            esac
        done
        [ -n "$hit" ] || continue
        case "$line" in
            *am_proc_start*)
                case "$line" in
                    *",$hit,next-top-activity,"*|*",$hit,activity,"*|*",$hit,top-activity,"*)
                        arm_layer "$hit"
                        ;;
                    *",$hit,service,"*)
                        log "proc_start service ($hit, segundo plano); no se arma"
                        ;;
                    *)
                        log "proc_start de otro tipo ($hit); no se arma"
                        ;;
                esac
                ;;
            *am_proc_died*)
                close_game "proc_died ($hit)" "$hit"
                ;;
            *am_kill*)
                if ! pidof "$hit" >/dev/null 2>&1; then
                    close_game "proc_kill ($hit)" "$hit"
                fi
                ;;
            *wm_create_activity*|*wm_resume_activity*|*wm_restart_activity*|*wm_relaunch_resume_activity*)
                arm_layer "$hit"
                ;;
            *wm_finish_activity*|*wm_destroy_activity*)
                ( check_ui_finished "$hit" ) &
                ;;
        esac
    done
    log "logcat termino; reinicio en 2 s"
    sleep 2
done
