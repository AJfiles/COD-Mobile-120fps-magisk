#!/system/bin/sh
# Magisk lo ejecuta al eliminar el modulo, con el directorio aun presente pero
# antes del desbloqueo: los datos cifrados de las apps (prefs de CODM, Perf Z)
# todavia no son accesibles. Por eso se copia lo necesario a /data/local/tmp y
# un trabajador independiente hace el trabajo despues del arranque:
# restaura lo que el modulo cambio, quita la app de control y borra sus datos.
case "$0" in */*) MODDIR=${0%/*};; *) MODDIR=.;; esac
MODDIR=$(cd "$MODDIR" && pwd)
WORK=/data/local/tmp/codm_after_remove.sh
DST=/data/local/tmp/codm_deferred

rm -rf "$DST"
mkdir -p "$DST"
cp -a "$MODDIR/." "$DST/" 2>/dev/null
rm -rf "$DST/logs" "$DST/run/perfz.pid" "$DST/run/service.lock" 2>/dev/null
chmod -R 755 "$DST" 2>/dev/null

cat > "$WORK" <<'EOS'
#!/system/bin/sh
n=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$n" -lt 60 ]; do
    sleep 5
    n=$((n + 1))
done
sleep 5
D=/data/local/tmp/codm_deferred
if [ -f "$D/restore.sh" ]; then
    sh "$D/restore.sh" >/dev/null 2>&1
fi
case "$(pm path com.aj.codmcontrol 2>/dev/null | head -1)" in
    *data/app*) pm uninstall com.aj.codmcontrol >/dev/null 2>&1 ;;
esac
rm -rf /data/data/com.aj.codmcontrol /data/user_de/0/com.aj.codmcontrol
rm -rf "$D"
rm -f /data/local/tmp/codm_after_remove.sh
sync
EOS
chmod 755 "$WORK"

if command -v setsid >/dev/null 2>&1; then
    setsid sh "$WORK" >/dev/null 2>&1 </dev/null &
else
    nohup sh "$WORK" >/dev/null 2>&1 </dev/null &
fi
exit 0