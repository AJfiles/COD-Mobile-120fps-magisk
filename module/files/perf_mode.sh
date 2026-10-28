#!/system/bin/sh
# Perfil de fluidez solo mientras CODM esta vivo.
# apply: guarda el modo de GameManager y asegura "performance".
# restore: devuelve exactamente el modo guardado.
# No toca GPU/CPU, resolucion, densidad, animaciones ni ajustes de desarrollador:
# forzar relojes o thermal solo agregaria calor. En equipos sin "cmd game"
# (Android no Samsung) el perfil queda inactivo y se registra, sin romper nada.
PKG=${CODM_PKG:-com.activision.callofduty.shooter}
case "$0" in */*) MODDIR=${0%/*};; *) MODDIR=.;; esac
MODDIR=$(cd "$MODDIR/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/state_env.sh"
LOG=$MODDIR/logs/perf.log
STATE=$STATE_DIR/perf.state
FLAG=$STATE_DIR/perf_state
mkdir -p "$MODDIR/logs" "$MODDIR/run" 2>/dev/null

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

perf_enabled() {
    [ "$(cat "$FLAG" 2>/dev/null)" != "off" ]
}

game_available() {
    command -v cmd >/dev/null 2>&1 || return 1
    cmd game list-modes "$PKG" >/dev/null 2>&1
}

game_mode_now() {
    cmd game list-modes "$PKG" 2>/dev/null |
        sed -n 's/.*current mode: \([a-zA-Z_]*\).*/\1/p' | head -n1
}

# Android 14/15 usan "cmd game mode <modo> <pkg>"; se intentan variantes
# equivalentes por si One UI 7/8 o un port cambia el orden de argumentos.
set_game_mode() {
    mode=$1
    cmd game mode "$mode" "$PKG" >/dev/null 2>&1 && return 0
    cmd game set "$PKG" "$mode" >/dev/null 2>&1 && return 0
    cmd game set-mode "$mode" "$PKG" >/dev/null 2>&1 && return 0
    return 1
}

apply() {
    if ! perf_enabled; then
        log "apply: perfil apagado por toggle; no aplico"
        return 0
    fi
    if [ -f "$STATE" ]; then
        log "apply: ya estaba aplicado"
        return 0
    fi
    : >"$STATE"
    echo "game_pkg=$PKG" >>"$STATE"

    if ! game_available; then
        log "GameManager no disponible en este equipo; perfil sin efecto"
        echo "game_mode=unavailable" >>"$STATE"
        return 0
    fi
    mode=$(game_mode_now)
    if [ -n "$mode" ]; then
        echo "game_mode=$mode" >>"$STATE"
        if [ "$mode" != "performance" ]; then
            if set_game_mode performance; then
                log "GameManager: $mode -> performance"
            else
                log "GameManager: no pude cambiar $mode -> performance"
            fi
        else
            log "GameManager: ya en performance"
        fi
    else
        log "GameManager: no pude leer el modo actual"
    fi
    log "perfil aplicado"
}

restore() {
    [ -f "$STATE" ] || return 0
    saved_pkg=$(sed -n 's/^game_pkg=//p' "$STATE" | head -1)
    [ -n "$saved_pkg" ] && PKG=$saved_pkg
    while IFS='=' read -r key value; do
        if [ "$key" = "game_mode" ] && [ -n "$value" ] && [ "$value" != "unavailable" ]; then
            cur=$(game_mode_now)
            if [ "$cur" != "$value" ]; then
                if set_game_mode "$value"; then
                    log "GameManager restaurado a $value"
                else
                    log "GameManager: no pude restaurar $value (actual $cur)"
                fi
            fi
        fi
    done <"$STATE"
    rm -f "$STATE"
    log "perfil restaurado"
}

case "$1" in
    apply) apply ;;
    restore) restore ;;
    *) echo "uso: $0 apply|restore" >&2; exit 2 ;;
esac
