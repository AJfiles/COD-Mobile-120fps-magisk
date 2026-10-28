#!/system/bin/sh
# Compatibilidad v3: restaura todos los paquetes/UID modificados.
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
exec sh "$MODDIR/files/game_prefs.sh" restore "$@"
