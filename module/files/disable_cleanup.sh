#!/system/bin/sh
# Se ejecuta cuando el gestor root crea el marcador "disable". Deja los datos de
# app como estaban antes del modulo: prefs de CODM originales, Perf Z oculto y
# GameManager en su modo guardado. No desmonta el XML ni devuelve props: eso lo
# completa el reinicio.
case "$0" in */*) MODDIR=${0%/*};; *) MODDIR=.;; esac
MODDIR=$(cd "$MODDIR" && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/codm_env.sh"
LOG=$LOG_DIR/disable.log
mkdir -p "$LOG_DIR" "$RUN_DIR" 2>/dev/null
log() { echo "$(date '+%F %T') $*" >>"$LOG"; }

log "=== desactivacion detectada ==="
pkgs=$(codm_packages force)
for p in $pkgs; do
    if pidof "$p" >/dev/null 2>&1; then
        log "CODM abierto ($p); se cierra para restaurar las prefs"
        am force-stop "$p" >/dev/null 2>&1
    fi
done
sleep 2

CODM_PKG="$(printf '%s\n' "$pkgs" | head -1)" sh "$MODDIR/files/perf_mode.sh" restore >>"$LOG" 2>&1 &&
    log "GameManager restaurado"
rc=0
sh "$MODDIR/files/gfx.sh" restore >>"$LOG" 2>&1 && log "GFX restaurado" || rc=1
sh "$MODDIR/files/game_prefs.sh" restore >>"$LOG" 2>&1 && log "prefs de CODM restauradas" || rc=1
sh "$MODDIR/files/perfz.sh" hide >>"$LOG" 2>&1 && log "Perf Z oculto" || rc=1

for p in $pkgs; do
    apk=$(pm path "$p" 2>/dev/null | head -n1 | sed 's/^package://')
    if [ -n "$apk" ]; then
        target=$(dirname "$apk")/lib/arm64/libVkLayer_codmspoof.so
        [ -f "$target" ] && rm -f "$target" && log "capa del juego eliminada ($p)"
    fi
done
setprop debug.vulkan.layers ""
rm -f "$RUN_DIR/game_ui"

left=$(ls "$STATE_DIR"/prefs.orig.* "$STATE_DIR"/fpslevel.orig.* \
        "$STATE_DIR"/gfx.orig "$STATE_DIR"/perfz.orig 2>/dev/null)
if [ -z "$left" ]; then
    rm -rf "$STATE_DIR"
    log "estado persistente eliminado (sin registros pendientes)"
else
    log "quedan registros de reversión en $STATE_DIR; se conservan"
    rc=1
fi

log "datos de app restaurados; reinicia para completar stock"
log "=== fin ==="
exit "$rc"
