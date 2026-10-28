#!/system/bin/sh
# Diagnostico de solo lectura para cualquier equipo/region.
# No escribe prefs ni props. Cachea el refresco del panel en run/display.maxhz.
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/codm_env.sh"
. "$MODDIR/files/root_compat.sh"
root_prepare
mkdir -p "$RUN_DIR" 2>/dev/null

verdict=
notes=

display_maxhz() {
    d=$(dumpsys display 2>/dev/null | grep -o 'fps=[0-9.]*' | sed 's/fps=//' | sort -n | tail -1)
    [ -n "$d" ] || d=$(dumpsys SurfaceFlinger 2>/dev/null | grep -o 'fps=[0-9.]*' | sed 's/fps=//' | sort -n | tail -1)
    [ -n "$d" ] || return 1
    printf '%s\n' "$d" | cut -d. -f1
}

now=$(date +%s 2>/dev/null)
last=$(cat "$RUN_DIR/display.epoch" 2>/dev/null)
case "$last" in ''|*[!0-9]*) last=0 ;; esac
maxhz=$(cat "$RUN_DIR/display.maxhz" 2>/dev/null)
if [ -z "$maxhz" ] || [ $((now - last)) -gt 600 ]; then
    newhz=$(display_maxhz 2>/dev/null)
    if [ -n "$newhz" ]; then
        maxhz=$newhz
        printf '%s\n' "$maxhz" >"$RUN_DIR/display.maxhz"
        printf '%s\n' "$now" >"$RUN_DIR/display.epoch"
    fi
fi

sdk=$(getprop ro.build.version.sdk)
case "$sdk" in ''|*[!0-9]*) sdk=0 ;; esac
uid0=$(id -u 2>/dev/null)
pkgs=$(codm_packages force)
pkg=$(printf '%s\n' "$pkgs" | head -1)
prefs=
if [ -n "$pkg" ]; then
    prefs=$(codm_prefs "$pkg")
fi
running=0
[ -n "$pkg" ] && codm_pkg_running "$pkg" && running=1
conf=$(cat "$ACCOUNT_CONF" 2>/dev/null)
active=
[ -n "$pkg" ] && active=$(codm_active_uid "$pkg" 2>/dev/null)
fps=
fpslevel=
enable=
framerate=
uids=
target=
if [ -n "$prefs" ]; then
    fpslevel=$(sed -n 's/.*name="FPSLevel" value="\([^"]*\)".*/\1/p' "$prefs" | head -1)
    uids=$(codm_uids "$prefs")
    target=$(codm_targets "$pkg" "$prefs" | head -1)
    if [ -n "$target" ]; then
        enable=$(sed -n "s/.*name=\"CODM_${target}_iMSDK_King_EnableFramerateCustomize\" value=\"\([^\"]*\)\".*/\1/p" "$prefs" | head -1)
        framerate=$(sed -n "s/.*name=\"CODM_${target}_iMSDK_King_FramerateCustomizeValue\" value=\"\([^\"]*\)\".*/\1/p" "$prefs" | head -1)
    fi
fi

echo "root.uid=${uid0:-?}"
echo "root.manager=$ROOT_MANAGER"
echo "game.package=$pkg"
echo "game.packages=$(printf '%s' "$pkgs" | tr '\n' ',')"
echo "game.installed=$([ -n "$pkg" ] && echo 1 || echo 0)"
echo "game.running=$running"
echo "prefs.file=$prefs"
echo "prefs.readable=$([ -n "$prefs" ] && echo 1 || echo 0)"
echo "account.mode=$ACCOUNT_MODE"
echo "account.active=${active:-}"
echo "account.confirmed=${conf:-}"
echo "account.uids=$(printf '%s' "$uids" | tr '\n' ',')"
echo "framerate.enable=${enable:-}"
echo "framerate.value=${framerate:-}"
echo "fpslevel=${fpslevel:-}"
echo "display.maxHz=${maxhz:-}"
echo "spoof.profile=$SPOOF_PROFILE"
echo "layer.profile=$LAYER_PROFILE"
echo "fpslevel.manage=$FPSLEVEL_MANAGE"
echo "android.sdk=${sdk:-}"
echo "account.target=${target:-}"
echo "keys.insert=$KEYS_INSERT"
echo "spoof.via=$(cat "$RUN_DIR/spoof.via" 2>/dev/null)"
echo "spoof.systemProp=$([ -f "$MODDIR/system.prop" ] && echo 1 || echo 0)"

if [ "$uid0" != "0" ]; then
    verdict=SIN_ROOT
    notes="ejecuta como root"
elif [ "$(getprop sys.user.0.ce_available 2>/dev/null)" != "true" ]; then
    # /data cifrado: aun no se pueden leer paquetes ni prefs. El worker de
    # prefs vuelve a ejecutar el doctor al desbloquear y aplicar.
    verdict=ESPERA_DESBLOQUEO
    notes="desbloquea el telefono; el worker reintenta cada 30 s"
elif [ "$sdk" -gt 0 ] && [ "$sdk" -lt 30 ]; then
    verdict=ANDROID_VIEJO
    notes="disenado para Android 11+ (SDK 30); en SDK $sdk puede cambiar el formato de prefs"
elif [ -z "$pkgs" ]; then
    verdict=SIN_JUEGO
    notes="instala CODM (global, Garena, Tencent o VNG)"
elif [ -z "$prefs" ]; then
    verdict=SIN_PREFS
    notes="abre CODM e inicia sesion una vez; luego cierra y espera 30 s"
elif [ -z "$target" ]; then
    if [ -n "$uids" ]; then
        verdict=CUENTA_AMBIGUA
        notes="hay varias cuentas y no puedo leer la activa; abre CODM o confirma una con codmctl account confirm"
    else
        verdict=SIN_CUENTA
        notes="abre CODM e inicia sesion; el worker aplicara 1/120 a la cuenta activa"
    fi
elif [ -n "$maxhz" ] && [ "$maxhz" -lt 90 ]; then
    verdict=PANEL_60
    notes="el panel es de ${maxhz} Hz: 120 fps no es posible en este equipo"
elif [ -n "$maxhz" ] && [ "$maxhz" -lt 120 ]; then
    verdict=PANEL_90
    notes="el panel llega a ${maxhz} Hz: se aplica 120, el juego puede limitar a ${maxhz}"
elif [ "$framerate" != "120" ] || [ "$enable" != "1" ]; then
    if [ "$KEYS_INSERT" = 1 ]; then
        verdict=FALTA_120
        notes="el worker aplicara 1/120; si el juego lo revierte a 90, activa 120 en Ajustes del juego y pon keys_insert=0"
    else
        verdict=FALTA_CLAVES
        notes="abre CODM > Ajustes > Graficos > Personalizado 120 una vez; el modulo lo mantiene. keys_insert=1 es experimental y el juego puede revertirlo"
    fi
elif [ "$fpslevel" != "5" ]; then
    verdict=FALTA_ULTRA
    notes="pon graficos en ULTRA una vez en el juego; si el menu no lo ofrece, prueba spoof=compat y reinicia"
else
    verdict=120_LISTO
    notes="claves 1/120 y FPSLevel=5; mide en partida para confirmar el techo real"
fi

if [ "$verdict" = "120_LISTO" ]; then
    compat120=si
elif [ -n "$maxhz" ] && [ "$maxhz" -ge 120 ]; then
    compat120=condicional
else
    compat120=no
fi
echo "compat.120=$compat120"
echo "verdict=$verdict"
echo "notes=$notes"
printf '%s\n' "$verdict" >"$RUN_DIR/doctor.verdict"
printf '%s\n' "$notes" >"$RUN_DIR/doctor.notes"
