#!/system/bin/sh
# Herramienta de medicion. Muestrea los timestamps de presentacion del layer
# de CODM cada segundo. Se lanza a mano antes de una partida; no es un cambio
# del sistema y vive dentro del modulo.
MODDIR=$(cd "${0%/*}/.." && pwd)
LOG=$MODDIR/logs/frames.log
PIDF=$MODDIR/run/frames.pid
mkdir -p "$MODDIR/logs" "$MODDIR/run" 2>/dev/null
[ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null && exit 0
echo $$ >"$PIDF"
trap 'rm -f "$PIDF"; exit 0' TERM INT HUP
layer=""
i=0
: >"$LOG"
while true; do
    if ! pidof com.activision.callofduty.shooter >/dev/null 2>&1; then
        sleep 2
        continue
    fi
    if [ -z "$layer" ] || [ $((i % 10)) -eq 0 ]; then
        layer=$(dumpsys SurfaceFlinger --list 2>/dev/null | grep 'BLAST' | grep -i activision | head -1)
    fi
    i=$((i + 1))
    if [ -n "$layer" ]; then
        echo "# $(date '+%s') $(cut -d' ' -f1 /proc/uptime) $layer" >>"$LOG"
        dumpsys SurfaceFlinger --latency "$layer" >>"$LOG" 2>/dev/null
    fi
    sz=$(wc -c <"$LOG" 2>/dev/null || echo 0)
    if [ "$sz" -gt 8388608 ]; then
        tail -c 4194304 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
    sleep 1
done
