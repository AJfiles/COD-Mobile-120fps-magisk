#!/system/bin/sh
# Boton de accion del modulo en Magisk: alterna el perfil de fluidez.
case "$0" in */*) MODDIR=${0%/*};; *) MODDIR=.;; esac
MODDIR=$(cd "$MODDIR" && pwd)
. "$MODDIR/files/state_env.sh"
FLAG=$STATE_DIR/perf_state
if [ "$(cat "$FLAG" 2>/dev/null)" = "off" ]; then
    sh "$MODDIR/toggle.sh" on
else
    sh "$MODDIR/toggle.sh" off
fi
