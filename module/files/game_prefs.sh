#!/system/bin/sh
# Aplica/restaura el framerate de 120 en todos los paquetes CODM detectados.
# - Una sola pasada por invocacion; el worker prefs_watch.sh la repite.
# - Nunca escribe con el juego abierto.
# - Guarda originales por paquete y UID; adopta los backups de v3.
# - Intenta FPSLevel=5 (ULTRA) una vez y registra si el juego lo reescribe.
# Uso: game_prefs.sh apply|restore|status [--quiet]
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/codm_env.sh"
LOG=$LOG_DIR/prefs.log
STATE=$RUN_DIR/prefs.state
QUIET=0
[ "$2" = "--quiet" ] && QUIET=1
mkdir -p "$LOG_DIR" "$RUN_DIR" 2>/dev/null

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }
say() { [ "$QUIET" = 1 ] || echo "$*"; }

read_key() {
    sed -n "s/.*name=\"$2\" value=\"\([^\"]*\)\".*/\1/p" "$1" 2>/dev/null | head -1
}

valid_num() {
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    return 0
}

record() {
    pkg=$1
    uid=$2
    en=$3
    fr=$4
    printf '%s\n' "$uid" >"$RUN_DIR/prefs.applied.$pkg"
    if [ "$pkg" = "$(codm_primary_pkg)" ]; then
        printf '%s\n' "$uid" >"$RUN_DIR/prefs.applied"
    fi
    tmp=$RUN_DIR/prefs.state.tmp
    [ -f "$STATE" ] && awk -F'|' -v p="$pkg" -v u="$uid" '!($1==p && $2==u)' "$STATE" >"$tmp"
    [ -f "$tmp" ] || : >"$tmp"
    printf '%s|%s|%s|%s\n' "$pkg" "$uid" "$en" "$fr" >>"$tmp"
    mv -f "$tmp" "$STATE"
}

# Aplica las claves de una cuenta y verifica la lectura. Devuelve 1 si la
# escritura no se confirmo (el llamador restaura el XML previo).
write_account() {
    file=$1
    uid=$2
    en=$3
    fr=$4
    fps_new=$5
    tmp=$RUN_DIR/prefs_apply.tmp
    set -- -e "/name=\"CODM_${uid}_iMSDK_King_EnableFramerateCustomize\"/ s/value=\"[0-9]*\"/value=\"$en\"/" \
        -e "/name=\"CODM_${uid}_iMSDK_King_FramerateCustomizeValue\"/ s/value=\"[0-9]*\"/value=\"$fr\"/"
    if [ -n "$fps_new" ]; then
        set -- "$@" -e "s|name=\"FPSLevel\" value=\"[0-9]*\"|name=\"FPSLevel\" value=\"$fps_new\"|"
    fi
    sed "$@" "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
    cat "$tmp" >"$file" || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
    now_en=$(read_key "$file" "CODM_${uid}_iMSDK_King_EnableFramerateCustomize")
    now_fr=$(read_key "$file" "CODM_${uid}_iMSDK_King_FramerateCustomizeValue")
    [ "$now_en" = "$en" ] && [ "$now_fr" = "$fr" ]
}

# Crea las claves que falten para una cuenta nueva sin tocar las existentes.
# Solo se llama con el juego cerrado; el tipo (int/long/string) se copia de otra
# cuenta del mismo XML y, si no hay ninguna, se usa int como el juego.
insert_keys() {
    file=$1
    uid=$2
    e_name="CODM_${uid}_iMSDK_King_EnableFramerateCustomize"
    f_name="CODM_${uid}_iMSDK_King_FramerateCustomizeValue"
    tag=$(sed -n 's/.*<\([a-z]*\) name="CODM_[0-9][0-9]*_iMSDK_King_EnableFramerateCustomize".*/\1/p' "$file" | head -1)
    case "$tag" in
        int|long|string) ;;
        *) tag=int ;;
    esac
    need_e=1
    need_f=1
    grep -q "name=\"$e_name\"" "$file" && need_e=0
    grep -q "name=\"$f_name\"" "$file" && need_f=0
    [ "$need_e" = 0 ] && [ "$need_f" = 0 ] && return 0
    tmp=$RUN_DIR/prefs_insert.tmp
    awk -v e="$e_name" -v f="$f_name" -v t="$tag" -v ne="$need_e" -v nf="$need_f" '
        /<\/map>/ && !done {
            if (ne) printf "    <%s name=\"%s\" value=\"1\" />\n", t, e
            if (nf) printf "    <%s name=\"%s\" value=\"120\" />\n", t, f
            done=1
        }
        { print }
        END { if (!done) exit 1 }
    ' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
    cat "$tmp" >"$file" || { rm -f "$tmp"; return 1; }
    rm -f "$tmp"
    [ "$(read_key "$file" "$e_name")" = "1" ] &&
        [ "$(read_key "$file" "$f_name")" = "120" ]
}

apply_pkg() {
    pkg=$1
    file=$(codm_prefs "$pkg")
    if [ -z "$file" ]; then
        log "$pkg: sin XML de PlayerPrefs; nada que aplicar"
        return 0
    fi
    if codm_pkg_running "$pkg"; then
        log "$pkg: juego abierto; no se escriben prefs"
        return 0
    fi
    active=$(codm_active_uid "$pkg" 2>/dev/null)
    if [ -n "$active" ]; then
        if [ "$active" != "$(cat "$RUN_DIR/account.detected" 2>/dev/null)" ]; then
            printf '%s\n' "$active" >"$RUN_DIR/account.detected"
            log "$pkg: cuenta activa $active"
        fi
        if [ "$ACCOUNT_MODE" = auto ] &&
           [ "$(cat "$ACCOUNT_CONF" 2>/dev/null)" != "$active" ]; then
            printf '%s\n' "$active" >"$ACCOUNT_CONF"
            log "$pkg: cuenta activa $active registrada (auto)"
        fi
    fi
    targets=$(codm_targets "$pkg" "$file")
    if [ -z "$targets" ]; then
        log "$pkg: sin cuenta objetivo (se reintentara)"
        return 0
    fi

    fps_cur=$(read_key "$file" FPSLevel)
    fps_new=
    if [ "$FPSLEVEL_MANAGE" = 1 ] && valid_num "$fps_cur" && [ "$fps_cur" != "5" ]; then
        fps_new=5
    fi

    rc=0
    for uid in $targets; do
        en=$(read_key "$file" "CODM_${uid}_iMSDK_King_EnableFramerateCustomize")
        fr=$(read_key "$file" "CODM_${uid}_iMSDK_King_FramerateCustomizeValue")
        rec_en=${en:-ABSENT}
        rec_fr=${fr:-ABSENT}
        orig=$STATE_DIR/prefs.orig.$pkg.$uid
        orig_created=0
        if [ -z "$en" ] || [ -z "$fr" ]; then
            if [ "$KEYS_INSERT" != 1 ]; then
                log "$pkg/$uid: claves ausentes y keys_insert=0; no se toca (activa 120 en Ajustes de CODM)"
                say "ERROR=$pkg/$uid: claves ausentes; abre Ajustes de CODM y activa 120 (keys_insert=1 es experimental)"
                rc=1
                continue
            fi
            if [ ! -f "$orig" ]; then
                {
                    echo "enable=$rec_en"
                    echo "framerate=$rec_fr"
                } >"$orig"
                orig_created=1
                cp -p "$file" "$STATE_DIR/prefs.xml.orig.$pkg.$uid" 2>/dev/null
                log "$pkg/$uid: claves ausentes ($rec_en/$rec_fr); XML respaldado"
            fi
            before=$RUN_DIR/prefs.beforewrite.$pkg
            cp -p "$file" "$before" 2>/dev/null
            if insert_keys "$file" "$uid"; then
                en=$(read_key "$file" "CODM_${uid}_iMSDK_King_EnableFramerateCustomize")
                fr=$(read_key "$file" "CODM_${uid}_iMSDK_King_FramerateCustomizeValue")
                log "$pkg/$uid: claves insertadas; leidas $en/$fr"
            else
                [ -f "$before" ] && cat "$before" >"$file"
                rm -f "$before"
                if [ "$orig_created" = 1 ]; then
                    rm -f "$orig" "$STATE_DIR/prefs.xml.orig.$pkg.$uid"
                fi
                log "$pkg/$uid: insercion no confirmada; XML restaurado"
                say "ERROR=$pkg/$uid: no se pudieron insertar las claves"
                rc=1
                continue
            fi
            rm -f "$before"
        fi
        if [ ! -f "$orig" ]; then
            legacy=$STATE_DIR/prefs.orig.$uid
            if [ -f "$legacy" ] && [ "$pkg" = "$(codm_primary_pkg)" ] &&
               grep -q '^enable=' "$legacy" 2>/dev/null; then
                cp -f "$legacy" "$orig"
                log "$pkg/$uid: backup v3 adoptado ($(tr '\n' ' ' <"$legacy"))"
            else
                {
                    echo "enable=$rec_en"
                    echo "framerate=$rec_fr"
                } >"$orig"
                cp -p "$file" "$LOG_DIR/prefs_backup_${pkg}_${uid}.xml" 2>/dev/null
                log "$pkg/$uid: originales guardados $rec_en/$rec_fr"
            fi
        fi

        if [ "$en" = "1" ] && [ "$fr" = "120" ] && [ -z "$fps_new" ]; then
            record "$pkg" "$uid" "$rec_en" "$rec_fr"
            continue
        fi

        if [ -n "$fps_new" ] && [ ! -f "$STATE_DIR/fpslevel.orig.$pkg" ]; then
            printf '%s\n' "$fps_cur" >"$STATE_DIR/fpslevel.orig.$pkg"
            log "$pkg: FPSLevel original $fps_cur"
        fi

        before=$RUN_DIR/prefs.beforewrite.$pkg
        cp -p "$file" "$before" 2>/dev/null
        if write_account "$file" "$uid" 1 120 "$fps_new"; then
            record "$pkg" "$uid" "$rec_en" "$rec_fr"
            say "OK=$pkg/$uid: framerate 1/120$([ -n "$fps_new" ] && echo ", FPSLevel 5")"
            log "$pkg/$uid: aplicado 1/120$([ -n "$fps_new" ] && echo " FPSLevel=5")"
        else
            [ -f "$before" ] && cat "$before" >"$file"
            log "$pkg/$uid: escritura no confirmada; XML restaurado"
            say "ERROR=$pkg/$uid: escritura no confirmada"
            rc=1
        fi
        rm -f "$before"
    done
    return "$rc"
}

restore_key() {
    file=$1
    uid=$2
    key=$3
    val=$4
    tmp=$RUN_DIR/prefs_restore.tmp
    if [ "$val" = "ABSENT" ]; then
        sed "/name=\"CODM_${uid}_iMSDK_King_${key}\"/d" "$file" >"$tmp" &&
            cat "$tmp" >"$file"
    else
        sed "/name=\"CODM_${uid}_iMSDK_King_${key}\"/ s/value=\"[0-9]*\"/value=\"$val\"/" \
            "$file" >"$tmp" && cat "$tmp" >"$file"
    fi
    rm -f "$tmp"
    if [ "$val" = "ABSENT" ]; then
        ! grep -q "name=\"CODM_${uid}_iMSDK_King_${key}\"" "$file"
    else
        [ "$(read_key "$file" "CODM_${uid}_iMSDK_King_${key}")" = "$val" ]
    fi
}

restore_one() {
    pkg=$1
    file=$2
    uid=$3
    orig=$4
    orig_e=$(sed -n 's/^enable=//p' "$orig" | head -1)
    orig_v=$(sed -n 's/^framerate=//p' "$orig" | head -1)
    valid_or_absent() {
        [ "$1" = "ABSENT" ] || valid_num "$1"
    }
    if ! valid_or_absent "$orig_e" || ! valid_or_absent "$orig_v"; then
        log "$pkg/$uid: backup invalido ($orig_e/$orig_v); no se toca"
        return 1
    fi
    if ! grep -q "CODM_${uid}_iMSDK_King_EnableFramerateCustomize" "$file" &&
       ! grep -q "CODM_${uid}_iMSDK_King_FramerateCustomizeValue" "$file"; then
        log "$pkg/$uid: claves ausentes; backup conservado"
        return 0
    fi
    before=$RUN_DIR/prefs.beforerestore.$pkg
    cp -p "$file" "$before" 2>/dev/null
    if restore_key "$file" "$uid" EnableFramerateCustomize "$orig_e" &&
       restore_key "$file" "$uid" FramerateCustomizeValue "$orig_v"; then
        rm -f "$orig" "$STATE_DIR/prefs.orig.$uid" \
              "$STATE_DIR/prefs.xml.orig.$pkg.$uid" "$before"
        tmp=$RUN_DIR/prefs.state.tmp
        [ -f "$STATE" ] && awk -F'|' -v p="$pkg" -v u="$uid" '!($1==p && $2==u)' "$STATE" >"$tmp"
        [ -f "$tmp" ] && mv -f "$tmp" "$STATE"
        say "OK=$pkg/$uid: restaurado $orig_e/$orig_v"
        log "$pkg/$uid: restaurado $orig_e/$orig_v"
        return 0
    fi
    [ -f "$before" ] && cat "$before" >"$file"
    rm -f "$before"
    log "$pkg/$uid: restauracion no confirmada"
    say "ERROR=$pkg/$uid: restauracion no confirmada"
    return 1
}

restore_pkg() {
    pkg=$1
    file=$(codm_prefs "$pkg")
    if [ -z "$file" ]; then
        log "$pkg: sin XML; no hay nada que restaurar"
        return 0
    fi
    if codm_pkg_running "$pkg"; then
        log "$pkg: juego abierto; no se restaura"
        say "ERROR=$pkg: cierra el juego antes de restaurar"
        return 2
    fi
    rc=0
    for orig in "$STATE_DIR"/prefs.orig."$pkg".*; do
        [ -f "$orig" ] || continue
        uid=${orig##*.}
        restore_one "$pkg" "$file" "$uid" "$orig" || rc=1
    done
    # Backups de v3 sin paquete en el nombre (solo el paquete primario).
    if [ "$pkg" = "$(codm_primary_pkg)" ]; then
        for orig in "$STATE_DIR"/prefs.orig.[0-9]*; do
            [ -f "$orig" ] || continue
            uid=${orig##*.}
            restore_one "$pkg" "$file" "$uid" "$orig" || rc=1
        done
    fi
    fps_orig=$STATE_DIR/fpslevel.orig.$pkg
    if [ -f "$fps_orig" ]; then
        val=$(cat "$fps_orig" 2>/dev/null)
        if valid_num "$val"; then
            cp -p "$file" "$RUN_DIR/prefs.beforerestore.$pkg" 2>/dev/null
            tmp=$RUN_DIR/fps_restore.tmp
            sed "s|name=\"FPSLevel\" value=\"[0-9]*\"|name=\"FPSLevel\" value=\"$val\"|" "$file" >"$tmp" &&
                cat "$tmp" >"$file"
            rm -f "$tmp"
            if [ "$(read_key "$file" FPSLevel)" = "$val" ]; then
                rm -f "$fps_orig" "$RUN_DIR/prefs.beforerestore.$pkg"
                say "OK=$pkg: FPSLevel restaurado a $val"
            else
                [ -f "$RUN_DIR/prefs.beforerestore.$pkg" ] && cat "$RUN_DIR/prefs.beforerestore.$pkg" >"$file"
                log "$pkg: FPSLevel no restaurado"
            fi
        fi
    fi
    if ! ls "$STATE_DIR"/prefs.orig."$pkg".* >/dev/null 2>&1; then
        rm -f "$RUN_DIR/prefs.applied.$pkg"
    fi
    [ -f "$RUN_DIR/prefs.applied" ] || rm -f "$RUN_DIR/prefs.applied.$pkg" 2>/dev/null
    return "$rc"
}

status() {
    pkgs=$(codm_packages)
    if [ -z "$pkgs" ]; then
        echo "packages="
        return 0
    fi
    for pkg in $pkgs; do
        file=$(codm_prefs "$pkg")
        echo "package=$pkg"
        echo "prefs=${file:-}"
        echo "running=$(codm_pkg_running "$pkg" && echo 1 || echo 0)"
        if [ -n "$file" ]; then
            echo "fpslevel=$(read_key "$file" FPSLevel)"
            for uid in $(codm_uids "$file"); do
                echo "account.$uid.enable=$(read_key "$file" "CODM_${uid}_iMSDK_King_EnableFramerateCustomize")"
                echo "account.$uid.framerate=$(read_key "$file" "CODM_${uid}_iMSDK_King_FramerateCustomizeValue")"
                echo "account.$uid.backup=$([ -f "$STATE_DIR/prefs.orig.$pkg.$uid" ] || [ -f "$STATE_DIR/prefs.orig.$uid" ] && echo 1 || echo 0)"
            done
        fi
    done
}

acquire_lock() {
    LOCK=$RUN_DIR/prefs.op.lock
    n=0
    while ! mkdir "$LOCK" 2>/dev/null; do
        other=$(cat "$LOCK/pid" 2>/dev/null)
        if [ -n "$other" ] && [ -d "/proc/$other" ] &&
           grep -q "game_prefs.sh" "/proc/$other/cmdline" 2>/dev/null; then
            n=$((n + 1))
            if [ "$n" -ge 20 ]; then
                say "ERROR=otra operacion de prefs en curso"
                log "otra operacion de prefs en curso; se omite"
                return 1
            fi
            sleep 1
        else
            rm -rf "$LOCK"
        fi
    done
    echo $$ >"$LOCK/pid"
    trap 'rm -rf "$LOCK"' EXIT
    trap 'exit 1' INT TERM
}

cmd=${1:-apply}
case "$cmd" in
    apply)
        acquire_lock || exit 1
        pkgs=$(codm_packages force)
        if [ -z "$pkgs" ]; then
            log "sin paquetes CODM detectados; se reintentara"
            say "ERROR=CODM no detectado"
            exit 0
        fi
        rc=0
        for pkg in $pkgs; do
            apply_pkg "$pkg" || rc=1
        done
        exit "$rc"
        ;;
    restore)
        acquire_lock || exit 1
        rc=0
        for pkg in $(codm_packages force); do
            restore_pkg "$pkg" || rc=1
        done
        exit "$rc"
        ;;
    status)
        status
        ;;
    *)
        echo "uso: $0 apply|restore|status [--quiet]" >&2
        exit 2
        ;;
esac
