#!/system/bin/sh
# Compatibilidad v3: aplica el framerate una sola vez y termina.
# El worker de arranque es prefs_watch.sh; la app puede llamar a este script
# tras confirmar una cuenta y esperar el resultado.
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
exec sh "$MODDIR/files/game_prefs.sh" apply "$@"
