#!/system/bin/sh
# API de control del modulo para la app CODM Control y para uso manual.
# v4: cualquier paquete/region CODM, varias cuentas, doctor y lanzamiento
# dinamico. La salida de estado conserva las claves v3 que consume la app.
MODDIR=$(cd "${0%/*}/.." && pwd)
PATH=/system/bin:/system/xbin:/debug_ramdisk
export PATH
. "$MODDIR/files/root_compat.sh"
root_prepare
. "$MODDIR/files/codm_env.sh"
PKG=$(codm_primary_pkg)
[ -n "$PKG" ] || PKG=com.activision.callofduty.shooter
PREFS=$(codm_prefs "$PKG" 2>/dev/null)
[ -n "$PREFS" ] || PREFS=/data/data/$PKG/shared_prefs/$PKG.v2.playerprefs.xml
RUN=$RUN_DIR
LOGDIR=$LOG_DIR
KNOWN=  # vacio: account.known=0 salvo que se configure una UID en el futuro
AUDIO_XML=$MODDIR/system/vendor/etc/audio_effects_sec.xml

if [ "$(id -u)" != 0 ]; then
    echo "ERROR=root requerido"
    exit 1
fi

active() { [ ! -f "$MODDIR/disable" ]; }
require_active() {
    active || { echo "ERROR=modulo desactivado en el gestor root"; exit 3; }
}

emit() {
    v=$2
    v=$(printf '%s' "$v" | tr '\n\r' '  ')
    echo "$1=$v"
}

read_key() {
    sed -n "s/.*name=\"$1\" value=\"\([^\"]*\)\".*/\1/p" "$2" 2>/dev/null | head -1
}
alive() {
    [ -n "$1" ] && [ -d "/proc/$1" ] && grep -q "$2" "/proc/$1/cmdline" 2>/dev/null
}
worker() {
    p=$(cat "$RUN/$1.pid" 2>/dev/null)
    if alive "$p" "$MODDIR/files/$2"; then echo 1; else echo 0; fi
}

game_running() { codm_any_running; }
layer_mapped() {
    for p in $(codm_packages); do
        for pid in $(pidof "$p" 2>/dev/null); do
            grep -q codmspoof "/proc/$pid/maps" 2>/dev/null && return 0
        done
    done
    return 1
}

max_hz() {
    m=$(cat "$RUN/display.maxhz" 2>/dev/null)
    if [ -z "$m" ]; then
        d=$(dumpsys display 2>/dev/null | grep -o 'fps=[0-9.]*' | sed 's/fps=//' | sort -n | tail -1)
        [ -n "$d" ] && m=$(printf '%s\n' "$d" | cut -d. -f1)
        if [ -n "$m" ]; then
            printf '%s\n' "$m" >"$RUN/display.maxhz"
            date +%s >"$RUN/display.epoch" 2>/dev/null
        fi
    fi
    printf '%s\n' "$m"
}

orig_backup() {
    uid=$1
    if [ -f "$STATE_DIR/prefs.orig.$PKG.$uid" ]; then
        echo "$STATE_DIR/prefs.orig.$PKG.$uid"
    elif [ -f "$STATE_DIR/prefs.orig.$uid" ]; then
        echo "$STATE_DIR/prefs.orig.$uid"
    fi
}

do_status() {
    conf=$(cat "$ACCOUNT_CONF" 2>/dev/null)
    det=$(cat "$RUN/account.detected" 2>/dev/null)
    if [ -z "$det" ] && [ -r "$PREFS" ]; then
        det=$(sh "$MODDIR/files/account.sh" detect 2>/dev/null)
        [ -n "$conf" ] || conf=$(cat "$ACCOUNT_CONF" 2>/dev/null)
    fi
    ver=$(sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -1)
    vc=$(sed -n 's/^versionCode=//p' "$MODDIR/module.prop" 2>/dev/null | head -1)
    profile=$(cat "$STATE_DIR/perf_state" 2>/dev/null)
    [ "$profile" = off ] || profile=on
    pkgs=$(codm_packages)
    uids=$(codm_uids "$PREFS" 2>/dev/null)

    emit module.path "$MODDIR"
    emit module.active "$(active && echo 1 || echo 0)"
    emit module.version "$ver"
    emit module.versionCode "$vc"
    emit module.manager "$ROOT_MANAGER"
    emit module.managerVersion "$ROOT_VERSION"
    emit module.resetprop "$([ -n "$RP" ] && echo 1 || echo 0)"
    emit app.packaged "$([ -f "$MODDIR/app/CODMControl.apk" ] && echo 1 || echo 0)"
    emit app.wanted "$(cat "$MODDIR/app/version.txt" 2>/dev/null)"
    emit app.installed "$([ -n "$(pm path com.aj.codmcontrol 2>/dev/null)" ] && echo 1 || echo 0)"
    emit app.system "$(pm path com.aj.codmcontrol 2>/dev/null | grep -q '^package:/system' && echo 1 || echo 0)"
    emit app.version "$(dumpsys package com.aj.codmcontrol 2>/dev/null \
        | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1)"
    emit device.model "$(getprop ro.product.model)"
    emit device.device "$(getprop ro.product.device)"
    emit device.original "$(orig_prop ro.product.device 2>/dev/null || getprop ro.product.device)"
    emit device.dm3q "$(orig_is_dm3q && echo 1 || echo 0)"
    emit android.release "$(getprop ro.build.version.release)"
    emit android.sdk "$(getprop ro.build.version.sdk)"
    emit android.oneui "$(getprop ro.build.version.oneui)"
    emit android.security "$(getprop ro.build.version.security_patch)"
    emit spoof.boot "$([ -f "$SPOOF_FLAG" ] && echo 1 || echo 0)"
    emit spoof.propsAdjusted "$([ -f "$RUN/props_restored" ] && echo 1 || echo 0)"
    emit spoof.profile "$SPOOF_PROFILE"
    emit spoof.action "$(cat "$RUN/spoof.profile" 2>/dev/null)"
    emit spoof.via "$(cat "$RUN/spoof.via" 2>/dev/null)"
    emit spoof.systemProp "$([ -f "$MODDIR/system.prop" ] && echo 1 || echo 0)"
    emit keys.insert "$KEYS_INSERT"
    emit account.detected "$det"
    emit account.confirmed "$conf"
    emit account.target "$(codm_targets "$PKG" "$PREFS" 2>/dev/null | head -1)"
    emit account.known "$([ "$det" = "$KNOWN" ] && echo 1 || echo 0)"
    emit account.match "$([ -n "$det" ] && [ "$det" = "$conf" ] && echo 1 || echo 0)"
    emit game.package "$PKG"
    emit game.packages "$(printf '%s' "$pkgs" | tr '\n' ',')"
    emit game.installed "$([ -n "$pkgs" ] && echo 1 || echo 0)"
    emit game.launchable "$([ -n "$(pm path "$PKG" 2>/dev/null)" ] && echo 1 || echo 0)"
    emit game.running "$(game_running && echo 1 || echo 0)"
    emit layer.armed "$([ -f "$RUN/game_ui" ] && echo 1 || echo 0)"
    emit layer.mapped "$(layer_mapped && echo 1 || echo 0)"
    emit layer.profile "$LAYER_PROFILE"
    emit perf.profile "$profile"
    emit perf.applied "$([ -f "$STATE_DIR/perf.state" ] && echo 1 || echo 0)"
    emit perf.savedMode "$(sed -n 's/^game_mode=//p' "$STATE_DIR/perf.state" 2>/dev/null | head -1)"
    emit prefs.readable "$([ -r "$PREFS" ] && echo 1 || echo 0)"
    if [ -r "$PREFS" ]; then
        uid=$(codm_targets "$PKG" "$PREFS" 2>/dev/null | head -1)
        [ -n "$uid" ] || uid=$conf
        [ -n "$uid" ] || uid=$det
        [ -n "$uid" ] || uid=$(printf '%s\n' "$uids" | head -1)
        emit prefs.uid "$uid"
        emit prefs.enable "$(read_key "CODM_${uid}_iMSDK_King_EnableFramerateCustomize" "$PREFS")"
        emit prefs.framerate "$(read_key "CODM_${uid}_iMSDK_King_FramerateCustomizeValue" "$PREFS")"
        emit gfx.width "$(read_key 'Screenmanager%20Resolution%20Width' "$PREFS")"
        emit gfx.height "$(read_key 'Screenmanager%20Resolution%20Height' "$PREFS")"
        emit gfx.quality "$(read_key 'UnityGraphicsQuality' "$PREFS")"
        emit fpslevel "$(read_key 'FPSLevel' "$PREFS")"
    else
        emit prefs.uid ""
        emit prefs.enable ""
        emit prefs.framerate ""
        emit gfx.width ""
        emit gfx.height ""
        emit gfx.quality ""
        emit fpslevel ""
    fi
    emit prefs.mode "$ACCOUNT_MODE"
    emit prefs.accounts "$(printf '%s' "$uids" | tr '\n' ',')"
    applied=$(cat "$RUN/prefs.applied" 2>/dev/null)
    [ -n "$applied" ] || applied=$(cat "$RUN/prefs.applied.$PKG" 2>/dev/null)
    emit prefs.applied "$applied"
    ob=$(orig_backup "$(codm_targets "$PKG" "$PREFS" 2>/dev/null | head -1)")
    emit prefs.orig "$(sed -n 's/^enable=//p' "$ob" 2>/dev/null | head -1)/$(sed -n 's/^framerate=//p' "$ob" 2>/dev/null | head -1)"
    emit gfx.preset "$(sed -n 's/^preset=//p' "$STATE_DIR/gfx.state" 2>/dev/null | head -1)"
    gfx_ov=0
    gw=$(sed -n 's/^width=//p' "$STATE_DIR/gfx.state" 2>/dev/null | head -1)
    if [ -n "$gw" ] && [ -r "$PREFS" ]; then
        gh=$(sed -n 's/^height=//p' "$STATE_DIR/gfx.state" 2>/dev/null | head -1)
        gq=$(sed -n 's/^quality=//p' "$STATE_DIR/gfx.state" 2>/dev/null | head -1)
        if [ "$(read_key 'Screenmanager%20Resolution%20Width' "$PREFS")" != "$gw" ] ||
           [ "$(read_key 'Screenmanager%20Resolution%20Height' "$PREFS")" != "$gh" ] ||
           [ "$(read_key 'UnityGraphicsQuality' "$PREFS")" != "$gq" ]; then
            gfx_ov=1
        fi
    fi
    emit gfx.overridden "$gfx_ov"
    emit gfx.modified "$([ -f "$STATE_DIR/gfx.orig" ] && echo 1 || echo 0)"
    emit gfx.available "$(orig_is_dm3q || [ "$GFX_UNIVERSAL" = 1 ] && echo 1 || echo 0)"
    emit perfz.installed "$([ -d /data/data/com.samsung.android.perf_z ] && echo 1 || echo 0)"
    emit perfz.visibility "$(read_key visibility /data/data/com.samsung.android.perf_z/shared_prefs/com.samsung.android.perf_z_preferences.xml)"
    emit display.maxHz "$(max_hz)"
    if orig_is_dm3q; then
        if [ ! -f "$AUDIO_XML" ]; then
            emit audio.mode "sin-xml"
        elif cmp -s "$AUDIO_XML" /vendor/etc/audio_effects_sec.xml 2>/dev/null; then
            emit audio.mode "dm3q-parcheado"
        else
            emit audio.mode "dm3q-stock"
        fi
    else
        emit audio.mode "no-aplica"
    fi
    emit audio.hal "$(pidof android.hardware.audio.service_64)"
    emit worker.watch "$(worker watch watch.sh)"
    emit worker.app "$(worker app install_app.sh)"
    emit worker.audio "$(worker audio_fix audio_fix.sh)"
    emit worker.prefs "$(worker prefs prefs_watch.sh)"
    emit worker.perfz "$(worker perfz perfz.sh)"
    emit doctor.verdict "$(cat "$RUN/doctor.verdict" 2>/dev/null)"
    emit doctor.notes "$(cat "$RUN/doctor.notes" 2>/dev/null)"
    emit log.path "$LOGDIR"
    emit time.now "$(date '+%F %T')"
}

do_logs() {
    name=$1
    lines=${2:-200}
    case "$lines" in ''|*[!0-9]*) lines=200 ;; esac
    [ "$lines" -gt 1000 ] && lines=1000
    case "$name" in
        all)
            for n in post-fs-data service root audio_fix prefs account gfx perfz perf_mode toggle watch restore disable; do
                f=$LOGDIR/$n.log
                [ -s "$f" ] || continue
                echo "===== $n.log ====="
                tail -n 50 "$f"
                echo
            done
            ;;
        post-fs-data|service|root|audio_fix|prefs|account|gfx|perfz|perf_mode|toggle|watch|restore|disable)
            f=$LOGDIR/$name.log
            if [ -f "$f" ]; then tail -n "$lines" "$f"; else echo "(sin registro $name)"; fi
            ;;
        *)
            echo "ERROR=log desconocido"
            exit 2
            ;;
    esac
}

launch_pkg() {
    pkg=$1
    # am devuelve 0 aunque no resuelva el intent: se usa el componente real y
    # se confirma que el proceso existe antes de declarar exito.
    act=$(cmd package resolve-activity --brief -a android.intent.action.MAIN \
        -c android.intent.category.LAUNCHER "$pkg" 2>/dev/null | tail -n1)
    case "$act" in
        */*) am start -n "$act" >/dev/null 2>&1 ;;
        *) monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 ;;
    esac
    n=0
    while [ "$n" -lt 20 ]; do
        pidof "$pkg" >/dev/null 2>&1 && return 0
        sleep 1
        n=$((n + 1))
    done
    return 1
}

cmd=${1:-status}
case "$cmd" in
    status)
        do_status
        ;;
    logs)
        do_logs "$2" "$3"
        ;;
    doctor)
        require_active
        sh "$MODDIR/files/doctor.sh"
        ;;
    compat)
        require_active
        sh "$MODDIR/files/doctor.sh"
        echo "estimate.install=~100% de telefonos root Android 11+ con CODM instalado (Magisk/KernelSU/APatch)"
        echo "estimate.120=~40% de telefonos root (panel >=120 Hz; 37.4% del mercado movil 2026, sesgo de gama alta; verificado solo en SM-S918B)"
        ;;
    toggle)
        require_active
        sh "$MODDIR/toggle.sh" "${2:-status}"
        ;;
    perfz)
        require_active
        sh "$MODDIR/files/perfz.sh" "${2:-show}"
        ;;
    account)
        require_active
        sub=${2:-status}
        case "$sub" in
            detect) sh "$MODDIR/files/account.sh" detect ;;
            confirm)
                out=$(sh "$MODDIR/files/account.sh" confirm "$3")
                rc=$?
                echo "$out"
                [ "$rc" -eq 0 ] || exit "$rc"
                if [ -r "$PREFS" ]; then
                    sh "$MODDIR/files/apply_game_prefs.sh" >>"$LOGDIR/account.log" 2>&1
                else
                    echo "prefs no visibles en este namespace; 120 se aplicara al reiniciar"
                fi
                ;;
            clear) sh "$MODDIR/files/account.sh" clear ;;
            status) sh "$MODDIR/files/account.sh" status ;;
            *) echo "ERROR=uso account detect|confirm <uid>|clear|status"; exit 2 ;;
        esac
        ;;
    gfx)
        require_active
        sub=${2:-status}
        case "$sub" in
            status) sh "$MODDIR/files/gfx.sh" status ;;
            apply) sh "$MODDIR/files/gfx.sh" apply "$3" ;;
            restore) sh "$MODDIR/files/gfx.sh" restore ;;
            *) echo "ERROR=uso gfx status|apply <preset>|restore"; exit 2 ;;
        esac
        ;;
    prefs)
        require_active
        sub=${2:-apply}
        case "$sub" in
            apply)
                [ -r "$PREFS" ] || { echo "ERROR=prefs de CODM no visibles"; exit 4; }
                if game_running; then echo "ERROR=cierra CODM antes de reaplicar 120"; exit 4; fi
                sh "$MODDIR/files/apply_game_prefs.sh" >>"$LOGDIR/prefs.log" 2>&1
                uid=$(codm_targets "$PKG" "$PREFS" 2>/dev/null | head -1)
                [ -n "$uid" ] || uid=$(cat "$ACCOUNT_CONF" 2>/dev/null)
                [ -n "$uid" ] || uid=$(cat "$RUN/account.detected" 2>/dev/null)
                [ -n "$uid" ] || uid=$(printf '%s\n' "$(codm_uids "$PREFS")" | head -1)
                e=$(read_key "CODM_${uid}_iMSDK_King_EnableFramerateCustomize" "$PREFS")
                f=$(read_key "CODM_${uid}_iMSDK_King_FramerateCustomizeValue" "$PREFS")
                if [ "$e" = "1" ] && [ "$f" = "120" ]; then
                    echo "OK=120 reaplicado a $uid (enable=1, framerate=120)"
                else
                    echo "ERROR=prefs quedaron ${e:-n/d}/${f:-n/d}; revisa la cuenta activa"
                    exit 1
                fi
                ;;
            status)
                uid=$(codm_targets "$PKG" "$PREFS" 2>/dev/null | head -1)
                [ -n "$uid" ] || uid=$(cat "$ACCOUNT_CONF" 2>/dev/null)
                [ -n "$uid" ] || uid=$(cat "$RUN/account.detected" 2>/dev/null)
                echo "package=$PKG"
                echo "uid=$uid"
                echo "enable=$(read_key "CODM_${uid}_iMSDK_King_EnableFramerateCustomize" "$PREFS")"
                echo "framerate=$(read_key "CODM_${uid}_iMSDK_King_FramerateCustomizeValue" "$PREFS")"
                echo "fpslevel=$(read_key FPSLevel "$PREFS")"
                ;;
            *) echo "ERROR=uso prefs apply|status"; exit 2 ;;
        esac
        ;;
    game)
        require_active
        sub=${2:-}
        case "$sub" in
            launch)
                [ -n "$(pm path "$PKG" 2>/dev/null)" ] || { echo "ERROR=CODM no instalado"; exit 4; }
                if launch_pkg "$PKG"; then
                    echo "OK=CODM abierto ($PKG)"
                else
                    echo "ERROR=no pude abrir $PKG"
                    exit 1
                fi
                ;;
            close)
                if game_running; then
                    for p in $(codm_packages); do
                        pidof "$p" >/dev/null 2>&1 && am force-stop "$p" >/dev/null 2>&1
                    done
                    echo "OK=CODM cerrado"
                else
                    echo "OK=CODM ya estaba cerrado"
                fi
                sleep 1
                CODM_PKG="$PKG" sh "$MODDIR/files/perf_mode.sh" restore >>"$LOGDIR/perf.log" 2>&1
                rm -f "$RUN/game_ui"
                sleep 2
                sh "$MODDIR/files/apply_game_prefs.sh" >>"$LOGDIR/prefs.log" 2>&1
                ;;
            retry)
                [ -n "$PKG" ] || { echo "ERROR=CODM no instalado"; exit 4; }
                if game_running; then
                    for p in $(codm_packages); do
                        pidof "$p" >/dev/null 2>&1 && am force-stop "$p" >/dev/null 2>&1
                    done
                    sleep 2
                fi
                rm -f "$RUN/game_ui"
                if launch_pkg "$PKG"; then
                    echo "OK=CODM reiniciado; la capa se arma al detectar la UI"
                else
                    echo "ERROR=no pude abrir CODM"
                    exit 1
                fi
                ;;
            *) echo "ERROR=uso game launch|close|retry"; exit 2 ;;
        esac
        ;;
    module)
        require_active
        sub=${2:-}
        case "$sub" in
            disable)
                if sh "$MODDIR/restore.sh" >>"$LOGDIR/module.log" 2>&1; then
                    : >"$MODDIR/disable"
                    echo "OK=modulo desactivado y datos restaurados; reinicia"
                else
                    echo "ERROR=la restauracion fallo; no se desactiva"
                    exit 1
                fi
                ;;
            remove)
                if ! sh "$MODDIR/restore.sh" >>"$LOGDIR/module.log" 2>&1; then
                    echo "ERROR=la restauracion fallo; no se elimina"
                    exit 1
                fi
                cat > /data/local/tmp/codm_remove.sh <<'EOS'
#!/system/bin/sh
sleep 4
rm -rf /data/adb/modules/codm_s23_120
rm -rf /data/adb/modules_update/codm_s23_120
rm -rf /data/adb/codm_s23_120_state
case "$(pm path com.aj.codmcontrol 2>/dev/null | head -1)" in
    *data/app*) pm uninstall com.aj.codmcontrol >/dev/null 2>&1 ;;
esac
rm -rf /data/data/com.aj.codmcontrol /data/user_de/0/com.aj.codmcontrol
rm -f /data/local/tmp/codm_remove.sh
sync
sleep 1
svc power reboot >/dev/null 2>&1 || reboot
EOS
                chmod 755 /data/local/tmp/codm_remove.sh
                if command -v setsid >/dev/null 2>&1; then
                    setsid sh /data/local/tmp/codm_remove.sh >/dev/null 2>&1 </dev/null &
                else
                    nohup sh /data/local/tmp/codm_remove.sh >/dev/null 2>&1 </dev/null &
                fi
                echo "OK=modulo y app se eliminaran; el telefono se reiniciara"
                ;;
            *) echo "ERROR=uso module disable|remove"; exit 2 ;;
        esac
        ;;
    restore)
        sh "$MODDIR/restore.sh"
        ;;
    *)
        echo "ERROR=comando desconocido"
        exit 2
        ;;
esac
