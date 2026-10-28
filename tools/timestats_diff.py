#!/usr/bin/env python3
"""Compara dos volcados de `dumpsys SurfaceFlinger --timestats -dump`.

Uso: python timestats_diff.py <baseline.txt> <final.txt>
"""

import re
import sys


def hist_from(lines, header):
    for i, line in enumerate(lines):
        if header in line:
            for j in range(i, min(i + 3, len(lines))):
                if "ms=" in lines[j]:
                    return {int(k): int(v) for k, v in re.findall(r"(\d+)ms=(\d+)", lines[j])}
    return {}


LAYER_RE = re.compile(
    r"^displayRefreshRate = (\d+) fps\nrenderRate = (\d+) fps\nuid = (\d+)\nlayerName = (.*)$",
    re.M,
)


def parse(path):
    text = open(path, encoding="utf-8", errors="replace").read()

    def scalar(name):
        m = re.search(rf"^{re.escape(name)} = (\d+)", text, re.M)
        return int(m.group(1)) if m else None

    d = {
        "path": path,
        "statsStart": scalar("statsStart"),
        "statsEnd": scalar("statsEnd"),
        "totalFrames": scalar("totalFrames"),
        "missedFrames": scalar("missedFrames"),
        "refreshRateSwitches": scalar("refreshRateSwitches"),
        "displayOnTime": scalar("displayOnTime"),
        "configs": [],
        "timeline": {},
        "layers": [],
    }

    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if lines[i].startswith("totalP2PTime"):
            block = []
            j = i
            while j < len(lines) and lines[j].strip():
                block.append(lines[j])
                j += 1
            d["configs"].append({
                "totalP2PTime": int(re.search(r"= (\d+)", lines[i]).group(1)),
                "p2p": hist_from(block, "presentToPresent histogram"),
                "frameDuration": hist_from(block, "frameDuration histogram"),
            })
            i = j
        else:
            i += 1

    for idx, line in enumerate(lines):
        if "Global aggregated jank payload" in line:
            block = []
            j = idx
            while j < len(lines) and lines[j].strip():
                block.append(lines[j])
                j += 1
            tl_text = "\n".join(block)
            for key in ("displayRefreshRate", "renderRate", "totalTimelineFrames", "jankyFrames",
                        "sfLongCpuJankyFrames", "sfLongGpuJankyFrames", "sfUnattributedJankyFrames",
                        "appUnattributedJankyFrames", "sfSchedulingJankyFrames",
                        "sfPredictionErrorJankyFrames", "appBufferStuffingJankyFrames"):
                m = re.search(rf"^{key} = (\d+)", tl_text, re.M)
                if m:
                    d["timeline"][key] = int(m.group(1))

    matches = list(LAYER_RE.finditer(text))
    for n, m in enumerate(matches):
        end = matches[n + 1].start() if n + 1 < len(matches) else len(text)
        block = text[m.start():end]
        blines = block.splitlines()
        layer = {
            "refresh": int(m.group(1)),
            "render": int(m.group(2)),
            "uid": int(m.group(3)),
            "name": m.group(4).strip(),
            "hist": {},
        }
        for line in blines[4:]:
            km = re.match(r"^(\w+) = (.*)$", line)
            if not km:
                continue
            key, value = km.group(1), km.group(2).strip()
            layer[key] = int(value) if value.isdigit() else value
        for hname in ("present2present", "present2presentDelta", "latch2present",
                      "desired2present", "acquire2present", "post2present", "post2acquire"):
            layer["hist"][hname] = hist_from(blines, f"{hname} histogram")
        d["layers"].append(layer)

    return d


def codm_layers(d):
    return [l for l in d["layers"] if "callofduty" in l["name"]]


def sum_hist(h):
    return sum(h.values())


def classify(hist):
    buckets = {
        "120Hz (7-9ms)": (7, 9),
        "90Hz (10-12ms)": (10, 12),
        "60Hz (13-17ms)": (13, 17),
        "lento (18-149ms)": (18, 149),
        "congelacion (>=150ms)": (150, 10 ** 9),
    }
    out = {}
    for label, (lo, hi) in buckets.items():
        out[label] = sum(c for b, c in hist.items() if lo <= b <= hi)
    out["<7ms"] = sum(c for b, c in hist.items() if b < 7)
    return out


def fmt(n):
    return f"{n:+,}" if isinstance(n, int) else str(n)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    base = parse(sys.argv[1])
    final = parse(sys.argv[2])

    print(f"Base : {base['path']}")
    print(f"Final: {final['path']}")
    valid = base["statsStart"] == final["statsStart"]
    if not valid:
        print(f"AVISO: statsStart distinto ({base['statsStart']} != {final['statsStart']}); "
              "las deltas no son validas, se muestran valores absolutos del final.")
    window = None
    if valid and base["statsEnd"] and final["statsEnd"]:
        window = final["statsEnd"] - base["statsEnd"]
        print(f"Ventana: {window} s (statsStart={final['statsStart']})")

    print("\n== Global ==")
    if valid:
        dt = final["totalFrames"] - base["totalFrames"]
        dm = final["missedFrames"] - base["missedFrames"]
        ds = final["refreshRateSwitches"] - base["refreshRateSwitches"]
        do = final["displayOnTime"] - base["displayOnTime"]
        print(f"frames presentados: {dt:+,}   perdidos: {dm:+,}   cambios refresco: {ds:+,}   displayOn: {do:+,} ms")
        if window:
            print(f"FPS medios de la ventana (incluye lobby): {dt / window:.2f}")
    else:
        print(f"totalFrames={final['totalFrames']} missed={final['missedFrames']} "
              f"refreshSwitches={final['refreshRateSwitches']}")

    print("\n== displayConfigStats ==")
    for n, cfg in enumerate(final["configs"], 1):
        ref = base["configs"][n - 1] if n - 1 < len(base["configs"]) and valid else None
        frames = sum_hist(cfg["p2p"])
        line = f"config #{n}: totalP2PTime={cfg['totalP2PTime']} ms  frames={frames}"
        if ref:
            line += (f"  (delta: {cfg['totalP2PTime'] - ref['totalP2PTime']:+,} ms, "
                     f"{frames - sum_hist(ref['p2p']):+,} frames)")
        print(line)
        print("  cadencia: " + ", ".join(f"{k}={v}" for k, v in classify(cfg["p2p"]).items()))

    print("\n== Capa CODM ==")
    base_by_key = {(l["name"], l["refresh"], l["uid"]): l for l in codm_layers(base)}
    for l in codm_layers(final):
        ref = base_by_key.get((l["name"], l["refresh"], l["uid"])) if valid else None
        tag = "delta" if ref else "absoluto"
        print(f"\n{l['name']}")
        print(f"  modo: {tag}; refresh={l['refresh']} render={l['render']} uid={l['uid']}")
        keys = ("totalFrames", "droppedFrames", "lateAcquireFrames", "badDesiredPresentFrames",
                "totalTimelineFrames", "jankyFrames", "sfLongCpuJankyFrames", "sfLongGpuJankyFrames",
                "sfUnattributedJankyFrames", "appUnattributedJankyFrames", "sfSchedulingJankyFrames",
                "sfPredictionErrorJankyFrames", "appBufferStuffingJankyFrames")
        for key in keys:
            if key not in l:
                continue
            value = l[key] - (ref.get(key, 0) if ref else 0)
            print(f"  {key}: {value:+,}" if ref else f"  {key}: {l[key]:,}")
        hist = {}
        ref_hist = ref["hist"]["present2present"] if ref else {}
        for b in set(l["hist"]["present2present"]) | set(ref_hist):
            hv = l["hist"]["present2present"].get(b, 0) - ref_hist.get(b, 0)
            if hv:
                hist[b] = hv
        print("  cadencia p2p: " + ", ".join(f"{k}={v}" for k, v in classify(hist).items()))
        total = sum_hist(hist)
        print(f"  frames en histograma: {total:,}")
        if ref and "totalFrames" in l:
            delta_frames = l["totalFrames"] - ref.get("totalFrames", 0)
            if delta_frames and abs(total - delta_frames) > max(3, delta_frames // 100):
                print(f"  AVISO: histograma ({total}) no cuadra con totalFrames ({delta_frames})")
        if total:
            slow = sum(c for b, c in hist.items() if b >= 18)
            stall = sum(c for b, c in hist.items() if b >= 150)
            print(f"  frames >=18ms: {slow:,} ({slow / total * 100:.2f}%)   >=150ms: {stall:,}")

    if valid and "jankyFrames" in final["timeline"]:
        print("\n== Timeline global (delta) ==")
        for key in ("totalTimelineFrames", "jankyFrames", "appUnattributedJankyFrames",
                    "appBufferStuffingJankyFrames", "sfLongCpuJankyFrames", "sfLongGpuJankyFrames"):
            if key in final["timeline"]:
                value = final["timeline"][key] - base["timeline"].get(key, 0)
                print(f"  {key}: {value:+,}")

    return 0 if valid else 1


if __name__ == "__main__":
    sys.exit(main())
