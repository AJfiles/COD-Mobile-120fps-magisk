#!/system/bin/sh
# Instala o actualiza la app de control desde la copia que viaja en el modulo.
# Se lanza en cada arranque: si la app falta o es mas antigua que la copia, la
# instala con pm; si ya esta igual o mas nueva, no hace nada.
PKG=com.aj.codmcontrol
case "$0" in */*) MODDIR=${0%/*};; *) MODDIR=.;; esac
MODDIR=$(cd "$MODDIR/.." && pwd)
LOG=$MODDIR/logs/app.log
APK=$MODDIR/app/CODMControl.apk
WANT=$(cat "$MODDIR/app/version.txt" 2>/dev/null)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
mkdir -p "$MODDIR/logs"

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

[ -f "$APK" ] || { log "copia de la app ausente; no se instala"; exit 0; }

n=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$n" -lt 60 ]; do
    sleep 5
    n=$((n + 1))
done

path=$(pm path "$PKG" 2>/dev/null | head -1)
case "$path" in
    /system/*)
        log "app del sistema detectada ($path); sin cambios"
        exit 0
        ;;
esac

cur=""
if [ -n "$path" ]; then
    cur=$(dumpsys package "$PKG" 2>/dev/null \
        | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1)
fi
if [ -n "$cur" ] && [ -n "$WANT" ] && [ "$cur" -ge "$WANT" ] 2>/dev/null; then
    log "app ya instalada v$cur (modulo v$WANT); sin cambios"
    exit 0
fi

if pm install -r "$APK" >/dev/null 2>&1; then
    log "app instalada desde el modulo (era '${cur:-ausente}', modulo v${WANT:-?})"
else
    log "pm install fallo (era '${cur:-ausente}', modulo v${WANT:-?})"
fi