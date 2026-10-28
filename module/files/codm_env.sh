#!/system/bin/sh
# Entorno comun v4: configuracion, paquetes CODM, prefs y cuentas.
# Se carga con MODDIR ya definido: . "$MODDIR/files/codm_env.sh"
# No escribe nada: solo lee y cachea la lista de paquetes.

[ -n "$MODDIR" ] || MODDIR=$(cd "${0%/*}/.." && pwd)
RUN_DIR=$MODDIR/run
LOG_DIR=$MODDIR/logs
CONF_FILE=$MODDIR/config
mkdir -p "$RUN_DIR" "$LOG_DIR" 2>/dev/null
. "$MODDIR/files/state_env.sh"

cfg() {
    v=
    if [ -r "$CONF_FILE" ]; then
        v=$(sed -n "s/^$1=//p" "$CONF_FILE" 2>/dev/null | head -1)
    fi
    [ -n "$v" ] || v=$2
    printf '%s\n' "$v"
}

SPOOF_PROFILE=$(cfg spoof auto)
LAYER_PROFILE=$(cfg layer auto)
FPSLEVEL_MANAGE=$(cfg fpslevel 1)
APPLY_ALL=$(cfg apply_all 0)
ACCOUNT_MODE=$(cfg account_mode auto)
GFX_UNIVERSAL=$(cfg gfx_universal 0)
KEYS_INSERT=$(cfg keys_insert 0)
export SPOOF_PROFILE LAYER_PROFILE FPSLEVEL_MANAGE APPLY_ALL ACCOUNT_MODE GFX_UNIVERSAL KEYS_INSERT

# Paquetes conocidos por region. La lista es solo una pista: la huella del XML
# (PREF_FP) descubre cualquier ID nuevo o regional.
KNOWN_PKGS="com.activision.callofduty.shooter com.garena.game.codm com.tencent.tmgp.cod com.tencent.tmgp.kr.codm com.vng.codmvn"
PREF_FP="iMSDK_King_FramerateCustomizeValue"

# Lista de paquetes CODM instalados. Cache de 120 s para que el estado de la app
# no recorra /data/data en cada refresco. Uso: codm_packages [force]
codm_packages() {
    force=$1
    cache=$RUN_DIR/packages.cache
    epoch_f=$RUN_DIR/packages.epoch
    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    old=$(cat "$epoch_f" 2>/dev/null)
    case "$old" in ''|*[!0-9]*) old=0 ;; esac
    if [ "$force" != force ] && [ -s "$cache" ] && [ "$now" -ge "$old" ] &&
       [ $((now - old)) -lt 120 ]; then
        cat "$cache"
        return 0
    fi

    list=
    seen=
    add_pkg() {
        case "$1" in ''|*[!a-zA-Z0-9._]*) return 0 ;; esac
        case " $seen " in *" $1 "*) return 0 ;; esac
        seen="$seen $1"
        list=${list:+$list
}$1
    }

    for p in ${CODM_PKGS:-}; do
        add_pkg "$p"
    done
    if [ -r "$MODDIR/game.packages" ]; then
        while IFS= read -r p; do
            case "$p" in ''|'#'*) continue ;; esac
            add_pkg "$p"
        done <"$MODDIR/game.packages"
    fi
    for p in $KNOWN_PKGS; do
        [ -n "$(pm path "$p" 2>/dev/null)" ] && add_pkg "$p"
    done
    # Huella: cualquier paquete cuyo XML de PlayerPrefs contenga las claves de
    # framerate de CODM. Cubre regiones y cambios de ID sin mantener una lista.
    for d in /data/data/*; do
        [ -d "$d" ] || continue
        p=${d##*/}
        [ "$p" = "com.aj.codmcontrol" ] && continue
        [ -d "$d/shared_prefs" ] || continue
        hit=0
        for f in "$d"/shared_prefs/*[Pp]layerprefs*.xml; do
            [ -f "$f" ] || continue
            if grep -q "$PREF_FP" "$f" 2>/dev/null; then
                hit=1
                break
            fi
        done
        [ "$hit" = 1 ] && add_pkg "$p"
    done

    printf '%s\n' "$list" >"$cache"
    # Lista vacia (arranque temprano, CE aun bloqueado): no se cachea como
    # valida para que el siguiente sondeo la recalcule de inmediato.
    if [ -n "$list" ]; then
        printf '%s\n' "$now" >"$epoch_f"
    else
        printf '0\n' >"$epoch_f"
    fi
    printf '%s\n' "$list"
}

codm_primary_pkg() {
    codm_packages | head -1
}

# Ruta del XML de PlayerPrefs del juego. Uso: codm_prefs <pkg>
codm_prefs() {
    base=/data/data/$1/shared_prefs
    for f in "$base/$1.v2.playerprefs.xml" "$base"/*[Pp]layerprefs*.xml; do
        if [ -r "$f" ]; then
            printf '%s\n' "$f"
            return 0
        fi
    done
    return 1
}

# UIDs con namespace de framerate dentro de un XML.
codm_uids() {
    sed -n 's/.*name="CODM_\([0-9][0-9]*\)_iMSDK_King_EnableFramerateCustomize".*/\1/p' "$1" 2>/dev/null | sort -u
}

# Cuenta activa segun lastUserId.xml (clave 4e42c67f78). Algunas versiones
# renombran el fichero: se busca cualquier lastUserId/UserId si el nombre
# exacto no existe.
codm_active_uid() {
    pkg=$1
    base=/data/data/$pkg/shared_prefs
    for f in "$base/lastUserId.xml" "$base"/*[Uu]serId*.xml; do
        [ -r "$f" ] || continue
        uid=$(sed -n 's/.*name="4e42c67f78"[^>]*>\([0-9][0-9]*\)<.*/\1/p' "$f" | head -1)
        case "$uid" in
            ''|*[!0-9]*) continue ;;
        esac
        printf '%s\n' "$uid"
        return 0
    done
    return 1
}

codm_pkg_running() {
    [ -n "$1" ] && pidof "$1" >/dev/null 2>&1
}

codm_any_running() {
    for p in $(codm_packages); do
        pidof "$p" >/dev/null 2>&1 && return 0
    done
    return 1
}

# Primer paquete CODM en ejecucion (vacio si ninguno).
codm_running_pkg() {
    for p in $(codm_packages); do
        if pidof "$p" >/dev/null 2>&1; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

# Cuentas objetivo de un paquete.
# auto: la cuenta activa (aunque aun no tenga claves: game_prefs las inserta si
# keys_insert=1, experimental). Si no hay lastUserId, la confirmada; si el XML
# solo tiene una cuenta, esa. Nunca cae a "todas": escribir en otra cuenta por
# descarte es lo que no debe hacer un modulo instalado en un telefono ajeno.
codm_targets() {
    pkg=$1
    file=$2
    conf=$(cat "$ACCOUNT_CONF" 2>/dev/null)
    active=$(codm_active_uid "$pkg" 2>/dev/null)
    uids=$(codm_uids "$file")
    has_uid() { printf '%s\n' "$uids" | grep -qx "$1"; }
    if [ "$APPLY_ALL" = 1 ] && [ "$ACCOUNT_MODE" = auto ]; then
        printf '%s\n' "$uids"
        return 0
    fi
    case "$ACCOUNT_MODE" in
        confirmed)
            [ -n "$conf" ] && has_uid "$conf" && printf '%s\n' "$conf"
            ;;
        active)
            [ -n "$active" ] && printf '%s\n' "$active"
            ;;
        all)
            printf '%s\n' "$uids"
            ;;
        *)
            if [ -n "$active" ]; then
                printf '%s\n' "$active"
            elif [ -n "$conf" ] && has_uid "$conf"; then
                printf '%s\n' "$conf"
            elif [ "$(printf '%s\n' "$uids" | grep -c .)" = 1 ]; then
                printf '%s\n' "$uids"
            fi
            ;;
    esac
}
