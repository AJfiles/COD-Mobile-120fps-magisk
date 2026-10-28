#!/system/bin/sh
# Compatibilidad de gestores root: Magisk, KernelSU y APatch.
# Se carga con: . "$MODDIR/files/root_compat.sh"
# No reinicia nada ni modifica props: solo detecta herramientas y ofrece helpers.

[ -n "$MODDIR" ] || MODDIR=$(cd "${0%/*}" && pwd)
RUN_DIR=$MODDIR/run
LOG_DIR=$MODDIR/logs
mkdir -p "$RUN_DIR" "$LOG_DIR" 2>/dev/null
. "$MODDIR/files/state_env.sh"
SPOOF_FLAG=$RUN_DIR/spoofed
ROOT_LOG=$LOG_DIR/root.log

ROOT_MANAGER=
ROOT_VERSION=
RP=

rlog() { echo "$(date '+%F %T') $*" >>"$ROOT_LOG"; }

root_detect() {
    managers=
    ROOT_VERSION=
    if [ -d /data/adb/magisk ] || command -v magisk >/dev/null 2>&1; then
        managers=Magisk
        if [ -x /data/adb/magisk/magisk ]; then
            ROOT_VERSION=$(/data/adb/magisk/magisk -v 2>/dev/null)
        fi
        [ -n "$ROOT_VERSION" ] || ROOT_VERSION=$(magisk -v 2>/dev/null)
    fi
    if [ -d /data/adb/ksu ] || command -v ksud >/dev/null 2>&1; then
        managers=${managers:+$managers+}KernelSU
        v=
        if [ -x /data/adb/ksu/bin/ksud ]; then
            v=$(/data/adb/ksu/bin/ksud -V 2>/dev/null)
            [ -n "$v" ] || v=$(/data/adb/ksu/bin/ksud --version 2>/dev/null)
        fi
        [ -n "$v" ] || v=$(ksud -V 2>/dev/null)
        [ -n "$v" ] || v=$(ksud --version 2>/dev/null)
        [ -n "$ROOT_VERSION" ] || ROOT_VERSION=$v
    fi
    if [ -d /data/adb/ap ] || command -v apd >/dev/null 2>&1; then
        managers=${managers:+$managers+}APatch
        v=
        if [ -x /data/adb/ap/bin/apd ]; then
            v=$(/data/adb/ap/bin/apd -V 2>/dev/null)
            [ -n "$v" ] || v=$(/data/adb/ap/bin/apd --version 2>/dev/null)
        fi
        [ -n "$v" ] || v=$(apd -V 2>/dev/null)
        [ -n "$v" ] || v=$(apd --version 2>/dev/null)
        [ -n "$ROOT_VERSION" ] || ROOT_VERSION=$v
    fi
    [ -n "$managers" ] || managers=desconocido
    ROOT_MANAGER=$managers
}

# resetprop no viene incluido en KernelSU; APatch y Magisk si lo traen (o lo
# exponen mediante su binario principal). Si no existe, el modulo funciona en
# modo degradado: no toca props del sistema y conserva capa, prefs y controles.
rp_detect() {
    RP=
    for c in /debug_ramdisk/resetprop /data/adb/magisk/resetprop \
             /data/adb/ap/bin/resetprop /data/adb/ksu/bin/resetprop \
             /sbin/resetprop /system/bin/resetprop; do
        if [ -x "$c" ]; then
            RP=$c
            break
        fi
    done
    if [ -z "$RP" ] && [ -x /data/adb/magisk/magisk ]; then
        RP="/data/adb/magisk/magisk resetprop"
    fi
    if [ -z "$RP" ] && command -v magisk >/dev/null 2>&1; then
        RP="magisk resetprop"
    fi
    if [ -z "$RP" ] && command -v resetprop >/dev/null 2>&1; then
        RP=resetprop
    fi
}

root_prepare() {
    root_detect
    rp_detect
    export ROOT_MANAGER ROOT_VERSION RP
}

root_log_boot() {
    rlog "gestor=$ROOT_MANAGER version=${ROOT_VERSION:-?} resetprop=${RP:-no}"
}

rp_set() {
    [ -n "$RP" ] || return 127
    $RP "$1" "$2" >/dev/null 2>&1
}

rp_del() {
    [ -n "$RP" ] || return 127
    $RP --delete "$1" >/dev/null 2>&1 || $RP -d "$1" >/dev/null 2>&1
}

# Propiedades que toca el spoof. Guardar y restaurar esta misma lista evita
# dejar rastros y permite devolver el valor exacto de cada equipo.
CODM_PROPS="
ro.product.product.model ro.product.product.brand ro.product.product.manufacturer ro.product.product.device ro.product.product.name
ro.product.vendor.model ro.product.vendor.brand ro.product.vendor.manufacturer ro.product.vendor.device ro.product.vendor.name
ro.product.odm.model ro.product.odm.brand ro.product.odm.manufacturer ro.product.odm.device ro.product.odm.name
ro.product.system.model ro.product.system.brand ro.product.system.manufacturer ro.product.system.device ro.product.system.name
ro.product.system_ext.model ro.product.system_ext.brand ro.product.system_ext.manufacturer ro.product.system_ext.device ro.product.system_ext.name
ro.product.model ro.product.brand ro.product.manufacturer ro.product.device ro.product.name
ro.product.board ro.board.platform ro.build.product ro.build.fingerprint ro.build.id
ro.build.display.id ro.build.version.incremental ro.soc.model ro.soc.manufacturer ro.product.marketname
"

save_orig_props() {
    file=${1:-$ORIG_PROPS}
    tmp=$file.tmp
    : >"$tmp" || return 1
    for p in $CODM_PROPS; do
        v=$(getprop "$p")
        if [ -z "$v" ]; then
            printf '%s\t%s\n' "$p" "__UNSET__" >>"$tmp"
        else
            printf '%s\t%s\n' "$p" "$v" >>"$tmp"
        fi
    done
    mv -f "$tmp" "$file"
}

restore_orig_props() {
    file=${1:-$ORIG_PROPS}
    [ -f "$file" ] || return 1
    [ -n "$RP" ] || return 1
    while IFS="$(printf '\t')" read -r p v; do
        case "$p" in
            ro.*) ;;
            *) continue ;;
        esac
        if [ "$v" = "__UNSET__" ]; then
            rp_del "$p"
        else
            rp_set "$p" "$v"
        fi
    done <"$file"
    return 0
}

orig_prop() {
    [ -f "$ORIG_PROPS" ] || return 1
    awk -F '\t' -v k="$1" '$1==k { print $2; exit }' "$ORIG_PROPS"
}

orig_is_dm3q() {
    d=$(orig_prop ro.product.device 2>/dev/null)
    [ -n "$d" ] || d=$(getprop ro.product.device)
    case "$d" in
        dm3q*) return 0 ;;
        *) return 1 ;;
    esac
}

# Modo compat: solo el modelo, igual que los modulos que desbloquean 120 en
# equipos fuera de la lista del juego. Es menos invasivo que el perfil completo
# (no toca marca, huella ni SoC) y se puede aplicar en cualquier telefono.
spoof_model_list() {
    for p in ro.product.model ro.product.odm.model ro.product.system.model \
             ro.product.vendor.model ro.product.system_ext.model \
             ro.product.product.model; do
        printf '%s %s\n' "$p" NX789J
    done
}

# Perfil completo verificado en dm3q.
spoof_full_list() {
    for part in product vendor odm system system_ext; do
        printf '%s %s\n' "ro.product.$part.model" NX789J
        printf '%s %s\n' "ro.product.$part.brand" nubia
        printf '%s %s\n' "ro.product.$part.manufacturer" samsung
        printf '%s %s\n' "ro.product.$part.device" NX789J
        printf '%s %s\n' "ro.product.$part.name" NX789J
    done
    printf '%s %s\n' ro.product.model NX789J
    printf '%s %s\n' ro.product.brand nubia
    printf '%s %s\n' ro.product.manufacturer samsung
    printf '%s %s\n' ro.product.device NX789J
    printf '%s %s\n' ro.product.name NX789J
    printf '%s %s\n' ro.product.board sun
    printf '%s %s\n' ro.board.platform sun
    printf '%s %s\n' ro.build.product NX789J
    printf '%s %s\n' ro.build.fingerprint \
        "nubia/NX789J/NX789J:15/AP3A.241105.008/20241212.120000:user/release-keys"
    printf '%s %s\n' ro.build.id AP3A.241105.008
    printf '%s %s\n' ro.build.display.id AP3A.241105.008
    printf '%s %s\n' ro.build.version.incremental 20241212.120000
    printf '%s %s\n' ro.soc.model SM8750
    printf '%s %s\n' ro.soc.manufacturer Qualcomm
    printf '%s %s\n' ro.product.marketname "REDMAGIC 10 Pro"
}

apply_prop_list() {
    while read -r p v; do
        [ -n "$p" ] && rp_set "$p" "$v"
    done
}

spoof_props() { spoof_full_list | apply_prop_list; }
spoof_props_model() { spoof_model_list | apply_prop_list; }
