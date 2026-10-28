#!/system/bin/sh
# Presets visuales de CODM: resolucion de render 3D y calidad Unity.
# Solo toca claves visuales conocidas de la cuenta confirmada; nunca FOV,
# sensibilidad, MSAA por cuenta ni ningun ajuste de combate.
# Requiere CODM cerrado: el juego reescribe el XML al salir.
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/codm_env.sh"
PKG=$(codm_primary_pkg)
[ -n "$PKG" ] || PKG=com.activision.callofduty.shooter
ACCOUNT=$MODDIR/files/account.sh
PREFS=$(codm_prefs "$PKG" 2>/dev/null)
RUN=$RUN_DIR
LOG=$LOG_DIR/gfx.log
ORIG=$STATE_DIR/gfx.orig
STATE=$STATE_DIR/gfx.state
K_W='Screenmanager%20Resolution%20Width'
K_H='Screenmanager%20Resolution%20Height'
K_Q='UnityGraphicsQuality'
mkdir -p "$RUN" "$LOG_DIR" 2>/dev/null
log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

is_dm3q() {
    d=$(awk -F '\t' '$1=="ro.product.device" { print $2; exit }' "$ORIG_PROPS" 2>/dev/null)
    [ -n "$d" ] && [ "$d" != "__UNSET__" ] || d=$(getprop ro.product.device)
    case "$d" in
        dm3q*) return 0 ;;
    esac
    return 1
}
gfx_allowed() { is_dm3q && return 0; [ "$GFX_UNIVERSAL" = "1" ]; }

die() { echo "$*"; log "error: $*"; exit 1; }

key_get() {
    sed -n "s/.*name=\"$1\" value=\"\([^\"]*\)\".*/\1/p" "$PREFS" 2>/dev/null | head -1
}

preset_values() {
    case "$1" in
        bajo)       W=1158; H=540;  Q=0 ;;
        equilibrado) W=1552; H=720; Q=1 ;;
        alto)       W=1930; H=900;  Q=2 ;;
        nativo)     W=2316; H=1080; Q=3 ;;
        *) return 1 ;;
    esac
}

require_context() {
    [ -r "$PREFS" ] || die "no puedo leer las prefs de CODM"
    if pidof "$PKG" >/dev/null 2>&1; then
        die "CODM esta abierto; cierralo antes de cambiar graficos"
    fi
    uid=$(sh "$ACCOUNT" detect 2>>"$LOG")
    [ -n "$uid" ] || die "no puedo detectar la cuenta activa"
    targets=$(codm_targets "$PKG" "$PREFS")
    case " $targets " in
        *" $uid "*) ;;
        *) die "la cuenta activa $uid no es objetivo (modo $ACCOUNT_MODE)";;
    esac
    for k in "$K_W" "$K_H" "$K_Q"; do
        [ -n "$(key_get "$k")" ] || die "falta la clave $k; no se toca el XML"
    done
}

save_orig() {
    [ -f "$ORIG" ] && return 0
    {
        echo "width=$(key_get "$K_W")"
        echo "height=$(key_get "$K_H")"
        echo "quality=$(key_get "$K_Q")"
    } >"$ORIG"
    cp -p "$PREFS" "$MODDIR/logs/gfx_backup_$(date +%s).xml" 2>/dev/null
    log "originales guardados: $(cat "$ORIG" | tr '\n' ' ')"
}

write_keys() {
    w=$1; h=$2; q=$3
    tmp=$RUN/gfx.tmp
    sed -e "s|name=\"$K_W\" value=\"[^\"]*\"|name=\"$K_W\" value=\"$w\"|" \
        -e "s|name=\"$K_H\" value=\"[^\"]*\"|name=\"$K_H\" value=\"$h\"|" \
        -e "s|name=\"$K_Q\" value=\"[^\"]*\"|name=\"$K_Q\" value=\"$q\"|" \
        "$PREFS" >"$tmp" || { rm -f "$tmp"; return 1; }
    cat "$tmp" >"$PREFS" || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
    [ "$(key_get "$K_W")" = "$w" ] && [ "$(key_get "$K_H")" = "$h" ] && [ "$(key_get "$K_Q")" = "$q" ]
}

status() {
    det=$(cat "$RUN/account.detected" 2>/dev/null)
    conf=$(cat "$ACCOUNT_CONF" 2>/dev/null)
    sw=$(sed -n 's/^preset=//p' "$STATE" 2>/dev/null | head -1)
    echo "package=$PKG"
    echo "available=$(gfx_allowed && echo 1 || echo 0)"
    echo "width=$(key_get "$K_W")"
    echo "height=$(key_get "$K_H")"
    echo "quality=$(key_get "$K_Q")"
    echo "preset=$sw"
    ov=0
    if [ -n "$sw" ] && preset_values "$sw"; then
        if [ "$(key_get "$K_W")" != "$W" ] || [ "$(key_get "$K_H")" != "$H" ] ||
           [ "$(key_get "$K_Q")" != "$Q" ]; then
            ov=1
        fi
    fi
    echo "overridden=$ov"
    echo "modified=$([ -f "$ORIG" ] && echo 1 || echo 0)"
    echo "active=${det:-}"
    echo "confirmed=${conf:-}"
    echo "running=$(pidof "$PKG" >/dev/null 2>&1 && echo 1 || echo 0)"
}

case "$1" in
    status)
        status
        ;;
    apply)
        preset_values "$2" || die "preset desconocido: ${2:-ninguno}"
        gfx_allowed || die "presets GFX calibrados para S23 Ultra (dm3q); usa los ajustes del juego o gfx_universal=1 en config"
        require_context
        save_orig
        if write_keys "$W" "$H" "$Q"; then
            {
                echo "preset=$2"
                echo "width=$W"
                echo "height=$H"
                echo "quality=$Q"
            } >"$STATE"
            echo "GFX $2 aplicado: ${W}x${H}, calidad Unity $Q"
            log "aplicado $2: ${W}x${H} q=$Q cuenta $uid"
        else
            die "no se pudo escribir la resolucion; el XML quedo sin cambios utiles"
        fi
        ;;
    restore)
        [ -f "$ORIG" ] || { echo "no hay backup de GFX"; exit 0; }
        if pidof "$PKG" >/dev/null 2>&1; then
            die "CODM esta abierto; cierralo antes de restaurar graficos"
        fi
        w=$(sed -n 's/^width=//p' "$ORIG" | head -1)
        h=$(sed -n 's/^height=//p' "$ORIG" | head -1)
        q=$(sed -n 's/^quality=//p' "$ORIG" | head -1)
        case "$w$h$q" in *[!0-9]*|'') die "backup GFX invalido" ;; esac
        if write_keys "$w" "$h" "$q"; then
            rm -f "$ORIG" "$STATE"
            echo "GFX restaurado: ${w}x${h}, calidad Unity $q"
            log "restaurado ${w}x${h} q=$q"
        else
            die "no se pudo restaurar el XML"
        fi
        ;;
    *)
        echo "uso: $0 status|apply bajo|equilibrado|alto|nativo|restore" >&2
        exit 2
        ;;
esac
