#!/system/bin/sh
# Deteccion y confirmacion de la cuenta activa de CODM.
# Funciona con cualquier paquete regional detectado por codm_env.sh.
# En auto, la cuenta activa se registra sola (no hay UID especial): el modulo
# sirve con cualquier cuenta y sigue el cambio cuando el usuario cambia de
# cuenta. La confirmacion manual sigue disponible para account_mode=confirmed.
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/codm_env.sh"
RUN=$RUN_DIR
DET=$RUN/account.detected
CONF=$ACCOUNT_CONF
LOG=$LOG_DIR/account.log
KNOWN=  # vacio: sin UID privilegiada; en auto se registra la cuenta activa
mkdir -p "$RUN" "$LOG_DIR" 2>/dev/null
log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

valid_uid() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ ${#1} -ge 10 ] && [ ${#1} -le 25 ]
}

read_active() {
    pkg=$(codm_primary_pkg)
    [ -n "$pkg" ] || { log "sin paquete CODM detectado"; return 3; }
    uid=$(codm_active_uid "$pkg")
    [ -n "$uid" ] || { log "lastUserId no accesible o sin clave"; return 4; }
    valid_uid "$uid" || return 5
    printf '%s\n' "$uid"
}

detect() {
    uid=$(read_active)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        log "deteccion fallida rc=$rc"
        return "$rc"
    fi
    printf '%s\n' "$uid" >"$DET"
    conf=$(cat "$CONF" 2>/dev/null)
    if [ "$ACCOUNT_MODE" = auto ] && [ "$conf" != "$uid" ]; then
        printf '%s\n' "$uid" >"$CONF"
        log "cuenta activa $uid registrada (auto)"
    elif [ "$uid" = "$KNOWN" ] && [ -z "$conf" ]; then
        printf '%s\n' "$uid" >"$CONF"
        log "cuenta conocida $uid auto-confirmada"
    fi
    log "cuenta activa detectada: $uid"
    printf '%s\n' "$uid"
}

confirm() {
    uid=$1
    if [ -z "$uid" ]; then
        uid=$(cat "$DET" 2>/dev/null)
    fi
    if ! valid_uid "$uid"; then
        echo "UID invalido"
        return 2
    fi
    cur=$(read_active) || {
        echo "no puedo leer la cuenta activa; abre CODM e inicia sesion"
        return 3
    }
    if [ "$uid" != "$cur" ]; then
        echo "la cuenta activa es $cur, no $uid; vuelve a detectar"
        return 6
    fi
    printf '%s\n' "$uid" >"$CONF"
    log "cuenta $uid confirmada por el usuario"
    echo "$uid"
}

status() {
    det=$(cat "$DET" 2>/dev/null)
    conf=$(cat "$CONF" 2>/dev/null)
    pkg=$(codm_primary_pkg)
    prefs=$(codm_prefs "$pkg" 2>/dev/null)
    cur=$(read_active 2>/dev/null)
    target=
    if [ -n "$prefs" ]; then
        target=$(codm_targets "$pkg" "$prefs" | head -1)
    fi
    echo "package=${pkg:-}"
    echo "mode=$ACCOUNT_MODE"
    echo "detected=${det:-}"
    echo "confirmed=${conf:-}"
    echo "active=${cur:-}"
    echo "target=${target:-}"
    if [ -n "$cur" ] && [ "$cur" = "$target" ]; then
        echo "match=1"
    else
        echo "match=0"
    fi
    if [ "$cur" = "$KNOWN" ]; then
        echo "known=1"
    else
        echo "known=0"
    fi
}

case "$1" in
    detect|"")
        detect
        ;;
    confirm)
        confirm "$2"
        ;;
    clear)
        rm -f "$CONF"
        log "confirmacion borrada"
        echo "confirmacion borrada"
        ;;
    status)
        status
        ;;
    *)
        echo "uso: $0 detect|confirm <uid>|clear|status" >&2
        exit 2
        ;;
esac
