#!/system/bin/sh
# Estado persistente del modulo: registros para revertir y ajustes del usuario.
# Vive fuera de /data/adb/modules porque el gestor root reemplaza el directorio
# entero al actualizar el modulo y run/ se pierde. Se carga con MODDIR definido.
[ -n "$MODDIR" ] || MODDIR=$(cd "${0%/*}/.." && pwd)
STATE_DIR=${STATE_DIR:-/data/adb/codm_s23_120_state}
mkdir -p "$STATE_DIR" 2>/dev/null
ORIG_PROPS=$STATE_DIR/orig_props.txt
ACCOUNT_CONF=$STATE_DIR/account.confirmed

# Adopta registros de la ubicacion volatil de v3/v4.0 sin pisar los persistidos.
for f in prefs.orig.* fpslevel.orig.* gfx.orig gfx.state perfz.orig perf.state \
         orig_props.txt account.confirmed; do
    [ -f "$MODDIR/run/$f" ] || continue
    [ -f "$STATE_DIR/$f" ] && continue
    cp -p "$MODDIR/run/$f" "$STATE_DIR/$f" 2>/dev/null || continue
    rm -f "$MODDIR/run/$f"
done
if [ -f "$MODDIR/perf_state" ] && [ ! -f "$STATE_DIR/perf_state" ]; then
    cp -p "$MODDIR/perf_state" "$STATE_DIR/perf_state" 2>/dev/null && rm -f "$MODDIR/perf_state"
fi
