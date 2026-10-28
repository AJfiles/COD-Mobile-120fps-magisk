#!/system/bin/sh
# Muestra u oculta el overlay Perf Z desde los datos de la app.
# show (por defecto): visibility=0 (SHOW); hide: devuelve el valor original (1=HIDE).
# Solo toca la clave visibility; conserva dueno, modo y contexto SELinux al escribir
# sobre el mismo inodo. Fuerza el cierre de Perf Z para que relea la preferencia.
PKG=com.samsung.android.perf_z
XML=/data/data/$PKG/shared_prefs/${PKG}_preferences.xml
case "$0" in */*) MODDIR=${0%/*};; *) MODDIR=.;; esac
MODDIR=$(cd "$MODDIR/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/state_env.sh"
LOG=$MODDIR/logs/perfz.log
STATE=$STATE_DIR/perfz.orig
TMP=$MODDIR/run/perfz.tmp
mkdir -p "$MODDIR/logs" "$MODDIR/run" 2>/dev/null

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }
if [ ! -d "/data/data/$PKG" ]; then
    log "Perf Z no instalado; overlay sin cambios"
    exit 0
fi
read_vis() { sed -n 's/.*name="visibility" value="\([0-9]*\)".*/\1/p' "$XML" 2>/dev/null | head -1; }
force_stop() { am force-stop "$PKG" >/dev/null 2>&1; }

wait_xml() {
    n=0
    while [ ! -r "$XML" ] && [ "$n" -lt 180 ]; do
        sleep 10
        n=$((n + 1))
    done
    [ -r "$XML" ]
}

set_vis() {
    val=$1
    cur=$(read_vis)
    if [ "$cur" = "$val" ]; then
        log "visibility ya en $val; no se escribe"
        return 0
    fi
    force_stop
    sleep 0.3
    sed "s/\(name=\"visibility\" value=\"\)[0-9]*\(\"\)/\1$val\2/" "$XML" >"$TMP" || {
        log "sed fallo; no se aplica"
        rm -f "$TMP"
        return 1
    }
    cat "$TMP" >"$XML" || {
        log "escritura fallo; no se aplica"
        rm -f "$TMP"
        return 1
    }
    rm -f "$TMP"
    log "visibility $cur -> $val"
    force_stop
    return 0
}

show() {
    wait_xml || { log "XML no accesible; overlay sin cambios"; return 0; }
    if [ ! -f "$STATE" ]; then
        # En esta unidad el valor original verificado era 1 (HIDE).
        echo 1 >"$STATE"
        log "valor original guardado: 1"
    fi
    set_vis 0
}

hide() {
    orig=$(cat "$STATE" 2>/dev/null)
    [ -n "$orig" ] || orig=1
    if [ -r "$XML" ]; then
        set_vis "$orig"
    else
        force_stop
        log "XML no accesible; Perf Z cerrado sin cambiar visibilidad"
    fi
    rm -f "$STATE"
}

case "$1" in
    show|"") show ;;
    hide) hide ;;
    *) echo "uso: $0 show|hide" >&2; exit 2 ;;
esac
